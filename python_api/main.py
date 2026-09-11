import os
import io
import uuid
import numpy as np
import matplotlib.pyplot as plt
from scipy.interpolate import griddata
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from supabase import create_client, Client
from supabase.lib.client_options import ClientOptions

# --- 1. CONFIGURAÇÃO SUPABASE ---
# Você vai definir essas variáveis de ambiente no servidor (Render/Railway)
SUPABASE_URL = os.environ.get("SUPABASE_URL", "").strip()
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "").strip()


def _supabase_config() -> tuple[str, str]:
    if not SUPABASE_URL.startswith(("https://", "http://")):
        raise HTTPException(status_code=500, detail="SUPABASE_URL não configurada corretamente no ambiente")
    if not SUPABASE_KEY or "=" in SUPABASE_KEY:
        raise HTTPException(status_code=500, detail="SUPABASE_KEY não configurada corretamente no ambiente")
    return SUPABASE_URL, SUPABASE_KEY


app = FastAPI(title="Gerador de Mapa de Potencial")

# --- 2. MODELOS DE DADOS (Payload do Flutter) ---
class LeituraModel(BaseModel):
    linha: int
    coluna: int
    potencial_mv: float

class MapaRequest(BaseModel):
    linhas: int
    colunas: int
    espacamento_x: float
    espacamento_y: float
    leituras: list[LeituraModel]
    potencial_id: uuid.UUID

# --- 3. ENDPOINT DE GERAÇÃO ---
@app.post("/gerar-mapa-calor")
async def gerar_mapa_calor(req: MapaRequest, request: Request):
    authorization = request.headers.get("authorization", "")
    if not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Sessão Supabase obrigatória")
    access_token = authorization[7:].strip()
    if not access_token:
        raise HTTPException(status_code=401, detail="Token Supabase ausente")

    # Keep the user's JWT on every Storage and PostgREST request. Using the
    # process-wide anon client here would bypass the caller's identity and
    # make the RLS policy on ponto_ensaio_potencial ineffective.
    supabase_url, supabase_key = _supabase_config()
    request_supabase: Client = create_client(
        supabase_url,
        supabase_key,
        options=ClientOptions(
            headers={"Authorization": f"Bearer {access_token}"},
        ),
    )

    if not req.leituras:
        raise HTTPException(status_code=400, detail="Sem leituras para interpolar")

    # Confirm authorization before doing CPU work or writing to Storage.
    ponto = request_supabase.table("ponto_ensaio_potencial").select("id").eq(
        "id", str(req.potencial_id)
    ).maybe_single().execute()
    if not ponto.data:
        raise HTTPException(status_code=403, detail="Ponto de potencial não autorizado ou inexistente")

    # A. Extrair coordenadas reais (X, Y) e valores Z (em módulo)
    pontos_x = []
    pontos_y = []
    valores_z = []

    for l in req.leituras:
        pontos_x.append(l.coluna * req.espacamento_x)
        # Invertemos o Y para que o topo (linha 0) fique em cima na imagem
        pontos_y.append((req.linhas - l.linha - 1) * req.espacamento_y) 
        valores_z.append(abs(l.potencial_mv)) # Garantir valores em módulo

    pts = np.array(list(zip(pontos_x, pontos_y)))
    z = np.array(valores_z)

    # B. Criar o grid de alta resolução para a imagem
    grid_x, grid_y = np.mgrid[
        0 : (req.colunas - 1) * req.espacamento_x : 200j, 
        0 : (req.linhas - 1) * req.espacamento_y : 200j
    ]

    # C. Interpolação Cúbica (Suavidade do Mapa)
    grid_z = griddata(pts, z, (grid_x, grid_y), method='cubic')
    
    # Preencher NaN (bordas fora da malha convexa) com o método 'nearest'
    grid_z_nearest = griddata(pts, z, (grid_x, grid_y), method='nearest')
    grid_z = np.where(np.isnan(grid_z), grid_z_nearest, grid_z)

    # D. Gerar o Gráfico Matplotlib (Fundo Transparente)
    fig, ax = plt.subplots(figsize=(req.colunas, req.linhas), dpi=100)
    fig.patch.set_alpha(0) # Fundo transparente
    ax.axis('off')         # Remover eixos

    # Define o gradiente de cores da Norma (Verde -> Laranja -> Vermelho)
    # Ajuste os limites 'vmin' e 'vmax' conforme necessário (Ex: 0 a 400mV)
    levels = np.linspace(0, max(400, np.max(z)), 100)
    contour = ax.contourf(grid_x, grid_y, grid_z, levels=levels, cmap='RdYlGn_r', alpha=1.0)
    
    # Bônus: Linhas isopotenciais (Curvas de nível) para dar aspeto técnico
    ax.contour(grid_x, grid_y, grid_z, levels=10, colors='black', linewidths=0.5, alpha=0.5)

    # E. Salvar imagem num buffer de memória
    buf = io.BytesIO()
    plt.savefig(buf, format='png', bbox_inches='tight', pad_inches=0, transparent=True)
    plt.close(fig)
    buf.seek(0)

    # F. Upload para o Supabase Storage
    file_name = f"mapas/{req.potencial_id}_{uuid.uuid4().hex[:8]}.png"
    
    try:
        request_supabase.storage.from_("projetos").upload(
            file_name,
            buf.read(),
            file_options={"content-type": "image/png", "cache-control": "3600", "upsert": "true"}
        )
        
        # Obter URL Pública
        public_url = request_supabase.storage.from_("projetos").get_public_url(file_name)
        
        # G. (Opcional) Já gravar a URL diretamente no banco de dados na tabela do potencial
        updated = request_supabase.table("ponto_ensaio_potencial").update(
            {"imagem_mapa_calor": public_url}
        ).eq("id", str(req.potencial_id)).select("id").execute()
        if not updated.data or len(updated.data) != 1:
            request_supabase.storage.from_("projetos").remove([file_name])
            raise HTTPException(status_code=403, detail="Ponto de potencial não autorizado para atualização")

        return {"status": "success", "url": public_url}
        
    except HTTPException:
        raise
    except Exception:
        # If upload succeeded but a later operation failed, avoid orphaning it.
        try:
            request_supabase.storage.from_("projetos").remove([file_name])
        except Exception:
            pass
        raise HTTPException(status_code=500, detail="Erro ao gerar ou salvar o mapa de potencial")

# Para rodar localmente e testar:
# uvicorn main:app --reload --port 8000
