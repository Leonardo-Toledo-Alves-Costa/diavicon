-- Prova de Carga Dinâmica (acelerometria): vibração e deslocamento.
-- As tabelas já foram criadas no Supabase pelo painel; este arquivo é a
-- referência da estrutura final (útil para um ambiente novo). O que ajusta o
-- banco de verdade é 20260919210000_prova_carga_dinamica_ajuste.sql, que
-- também cria gatilhos, permissões e bucket. Pode rodar mais de uma vez.
--
-- O ensaio é ligado a projeto, estrutura e local (não a um elemento):
--   pontos_ensaios_geral (tipo "Prova de Carga Dinâmica", sem elemento)
--    └─ prova_carga_dinamica             1 por ensaio
--        ├─ prova_carga_dinamica_sensor    ponto físico na planta (ou apoio fixo)
--        ├─ prova_carga_dinamica_arquivo   cada arquivo de aquisição importado
--        │    └─ prova_carga_dinamica_canal  cada coluna = sensor + eixo
--        ├─ prova_carga_dinamica_estagio   janelas de tempo (substitui o CSV de deltas)
--        └─ prova_carga_dinamica_resultado estágio × canal (vibração e deslocamento)
--
-- Projeto, estrutura, empresa autora e autor vêm de pontos_ensaios_geral pelo
-- ponto_id; não se repetem aqui.
--
-- As amostras NÃO ficam no banco. O web app converte o CSV/TXT do equipamento
-- em Float32 (little-endian, gzip), em blocos, e grava no bucket privado
-- ensaios-importacoes:
--   <projeto_id>/pcd/<prova_id>/serie/<canal_id>/<n>.f32.gz   série em blocos
--   <projeto_id>/pcd/<prova_id>/resumo/<canal_id>.json        mín/máx a cada 0,5 s
--   <projeto_id>/pcd/<prova_id>/desloc/<estagio_id>/<canal_id>.f32.gz
-- Abrir um estágio baixa só os blocos daquela janela.
--
-- Vibração pela escala de Zeller com a AMPLITUDE do deslocamento (meio pico a
-- pico), como na definição: S = 10·log10(16·π⁴·A²·f³ / 0,1), A em cm, f em Hz.
--
-- Reanalisar sobrescreve o resultado (único por estágio + canal).

begin;

create table if not exists public.prova_carga_dinamica (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  ponto_id uuid not null unique references public.pontos_ensaios_geral (id) on delete cascade,
  local_id uuid references public.estruturas_locais (id) on delete set null,
  planta_id uuid references public.estruturas_plantas (id) on delete set null,

  nome text,
  data_ensaio date,
  responsavel text,
  equipamento text,                          -- Aq.Data, SAD, Signal Vista…
  taxa_amostragem_hz numeric default 400,
  unidade text default 'g',

  -- Critério de norma: f > 1,2·f_crit (NBR 6118, 23.3).
  uso_estrutura text,                        -- passarela, arquibancada, ponte…
  freq_critica_hz numeric,

  -- Valores padrão da análise: banda do filtro, faixa de busca, distância
  -- entre picos em Hz, proeminência, método do espectro, passa-alta do
  -- deslocamento. Cada resultado guarda os que usou.
  parametros jsonb default '{}'::jsonb,
  -- Dimensões e contorno para a animação do deslocamento.
  geometria jsonb default '{}'::jsonb,

  status text not null default 'rascunho'
    check (status in ('rascunho', 'em_analise', 'concluido')),

  -- Resumo (listas, painéis, relatórios), atualizado pelo app ao salvar.
  freq_natural_min_hz numeric,
  vibracao_max_db numeric,
  pior_faixa text,
  atende_norma boolean,
  desloc_max_mm numeric,

  observacoes text,
  conclusao text
);

create table if not exists public.prova_carga_dinamica_sensor (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  prova_id uuid not null references public.prova_carga_dinamica (id) on delete cascade,
  codigo text not null,                      -- PI-02
  nome text,
  -- 'apoio' = ponto fixo (deslocamento zero) para a animação, sem canal.
  tipo text not null default 'medicao' check (tipo in ('medicao', 'apoio', 'virtual')),
  -- Marcação na planta (0–1000) e coordenadas reais (m).
  pos_x double precision,
  pos_y double precision,
  x_m double precision,
  y_m double precision,
  elemento_id uuid references public.elementos_estruturais (id) on delete set null,
  descricao text,
  ordem double precision default 0,
  unique (prova_id, codigo)
);

create table if not exists public.prova_carga_dinamica_arquivo (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  prova_id uuid not null references public.prova_carga_dinamica (id) on delete cascade,
  nome_original text,
  formato_origem text,                       -- csv_um_canal, txt_multicanal, sad_csv
  tamanho_original_bytes bigint,
  sha256 text,                               -- evita importar o mesmo arquivo 2×
  taxa_amostragem_hz numeric,
  n_amostras bigint,
  duracao_s numeric,
  -- Posição do início deste arquivo na linha do tempo do ensaio (s).
  inicio_s numeric not null default 0,
  inicio_aquisicao timestamptz,
  cabecalho jsonb default '{}'::jsonb,
  -- Série convertida no bucket (pasta base dos canais deste arquivo).
  caminho_base text,
  formato_serie text default 'f32le_gzip',
  amostras_por_bloco bigint default 240000,  -- 10 min a 400 Hz
  n_blocos bigint,
  unique (prova_id, sha256)
);

create table if not exists public.prova_carga_dinamica_canal (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  prova_id uuid not null references public.prova_carga_dinamica (id) on delete cascade,
  arquivo_id uuid not null references public.prova_carga_dinamica_arquivo (id) on delete cascade,
  sensor_id uuid references public.prova_carga_dinamica_sensor (id) on delete set null,
  coluna text not null,                      -- PI-02-Z
  eixo text check (eixo in ('X', 'Y', 'Z')),
  unidade text default 'g',
  fator_escala numeric not null default 1,   -- contagens → g, se preciso
  media_removida numeric,                    -- linha de base tirada do sinal
  rms numeric,
  max_abs numeric,
  -- Leituras saturadas ou inválidas: contadas e marcadas, nunca zeradas.
  limite_saturacao numeric,
  n_saturadas integer not null default 0,
  n_invalidas integer not null default 0,
  caminho_serie text,                        -- pasta dos blocos deste canal
  caminho_resumo text,                       -- JSON mín/máx para o gráfico geral
  ativo boolean not null default true,
  unique (arquivo_id, coluna)
);

create index if not exists prova_carga_dinamica_canal_prova_idx
  on public.prova_carga_dinamica_canal (prova_id);

create table if not exists public.prova_carga_dinamica_estagio (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz default now(),
  prova_id uuid not null references public.prova_carga_dinamica (id) on delete cascade,
  ordem bigint default 0,
  nome text not null,                        -- "1 caminhão 25 km/h"
  tipo_carregamento text,                    -- ambiente, pessoas, veiculo, impacto, outro
  t_inicio_s numeric not null,               -- segundos na linha do tempo do ensaio
  t_fim_s numeric not null,
  freq_excitacao_hz numeric,                 -- Freq_Op da planilha antiga
  descricao text,
  ativo boolean not null default true,
  check (t_fim_s > t_inicio_s)
);

create index if not exists prova_carga_dinamica_estagio_prova_idx
  on public.prova_carga_dinamica_estagio (prova_id, ordem);

create table if not exists public.prova_carga_dinamica_resultado (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  prova_id uuid not null references public.prova_carga_dinamica (id) on delete cascade,
  estagio_id uuid not null references public.prova_carga_dinamica_estagio (id) on delete cascade,
  canal_id uuid not null references public.prova_carga_dinamica_canal (id) on delete cascade,

  -- Parâmetros usados (null = padrão da prova).
  t_inicio_s numeric,                        -- ajuste da janela só deste canal
  t_fim_s numeric,
  banda_min_hz numeric,
  banda_max_hz numeric,
  busca_min_hz numeric,
  busca_max_hz numeric,
  distancia_picos_hz numeric,
  proeminencia numeric,
  pico_escolhido bigint not null default 1 check (pico_escolhido between 1 and 3),
  ajuste_manual boolean not null default false,

  -- Frequência
  freq_natural_hz numeric,
  pico_1_hz numeric,                         -- 3 maiores picos, do maior ao menor
  pico_2_hz numeric,
  pico_3_hz numeric,
  atende_freq_critica boolean,
  -- Aceleração (g): bruta e filtrada na banda
  acel_max numeric,
  acel_min numeric,
  acel_max_filtrada numeric,
  acel_min_filtrada numeric,
  amplitude_acel numeric,                    -- (máx − mín) / 2 da filtrada
  -- Vibração (Zeller, pela amplitude)
  amplitude_desloc_mm numeric,               -- amplitude_acel·g / (2πf)²
  vibracao_db numeric,
  faixa_vibracao text
    check (faixa_vibracao in ('sem_dano', 'danos_leves', 'danos_severos', 'colapso')),
  -- Espectro reduzido (~300 pontos) para reabrir o gráfico sem reprocessar.
  espectro jsonb,

  -- Deslocamento por dupla integração (passa-alta antes de cada integração)
  desloc_passa_alta_hz numeric,
  desloc_max_mm numeric,
  desloc_min_mm numeric,
  desloc_pp_mm numeric,
  desloc_rms_mm numeric,
  desloc_taxa_hz numeric,                    -- taxa da série gravada (ex.: 20 Hz)
  desloc_serie_caminho text,

  unique (estagio_id, canal_id)
);

create index if not exists prova_carga_dinamica_resultado_prova_idx
  on public.prova_carga_dinamica_resultado (prova_id);
create index if not exists prova_carga_dinamica_resultado_canal_idx
  on public.prova_carga_dinamica_resultado (canal_id);

commit;

-- Gatilhos, permissões (RLS), tipo de ensaio e bucket:
-- ver 20260919210000_prova_carga_dinamica_ajuste.sql.
