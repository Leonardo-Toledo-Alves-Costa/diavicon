import os
import io
import uuid
import numpy as np
import matplotlib.pyplot as plt
from scipy.interpolate import griddata
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from supabase import create_client, Client

# --- 1. CONFIGURAÇÃO SUPABASE ---
# Você vai definir essas variáveis de ambiente no servidor (Render/Railway)
SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://thmmxgzwjrydxrrfoaay.supabase.co")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRobW14Z3p3anJ5ZHhycmZvYWF5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzMDAwMDksImV4cCI6MjA5MTg3NjAwOX0.KTpJ5lZdTVjATItWyFmuBd9-n1M3LL7wDg2Wj1zYrVE")


supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

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
    potencial_id: str # ID para nomear a imagem

# --- 3. ENDPOINT DE GERAÇÃO ---
@app.post("/gerar-mapa-calor")
async def gerar_mapa_calor(req: MapaRequest):
    if not req.leituras:
        raise HTTPException(status_code=400, detail="Sem leituras para interpolar")

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
        res = supabase.storage.from_("projetos").upload(
            file_name,
            buf.read(),
            file_options={"content-type": "image/png", "cache-control": "3600", "upsert": "true"}
        )
        
        # Obter URL Pública
        public_url = supabase.storage.from_("projetos").get_public_url(file_name)
        
        # G. (Opcional) Já gravar a URL diretamente no banco de dados na tabela do potencial
        supabase.table("ponto_ensaio_potencial").update({"imagem_mapa_calor": public_url}).eq("id", req.potencial_id).execute()

        return {"status": "success", "url": public_url}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro no upload do Supabase: {str(e)}")

# Para rodar localmente e testar:
# uvicorn main:app --reload --port 8000