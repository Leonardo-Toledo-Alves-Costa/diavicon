-- Modelos de relatório para RDO — mesmo conceito de `modelos_relatorios`
-- (usado pelos relatórios de ensaio), mas sem `tipo_ensaio_id`: RDO não é
-- uma linha de `tipos_ensaio`, é um relatório de projeto à parte.
--
-- ATENÇÃO: esta tabela já foi criada manualmente no Supabase com o schema
-- abaixo (sem `eh_padrao`/`duplicado_de_id`, `schema_json` como `json` em
-- vez de `jsonb`) — o CREATE TABLE aqui é só documentação/referência para um
-- ambiente novo. Se a tabela já existe no seu projeto, rode só a parte de
-- RLS (a partir do `alter table ... enable row level security`) — o app já
-- foi ajustado pra não depender de `eh_padrao`/`duplicado_de_id`.
create table public.modelo_relatorio_rdo (
  id uuid not null default gen_random_uuid(),
  criado_em timestamp with time zone not null default now(),
  empresa_id uuid references public.empresas(id),
  schema_json json,
  criado_por uuid references public.usuarios(id),
  nome text,
  descricao text,
  constraint modelo_relatorio_rdo_pkey primary key (id)
);

create index modelo_relatorio_rdo_empresa_id_idx on public.modelo_relatorio_rdo (empresa_id);

alter table public.modelo_relatorio_rdo enable row level security;

-- Mesma regra de "campos personalizáveis": a empresa vê os próprios modelos
-- + os modelos padrão da Diavicon (DIAVICON_EMPRESA_ID no app).
create policy modelo_relatorio_rdo_select
on public.modelo_relatorio_rdo
for select to authenticated
using (
  empresa_id = private.active_actor_company_id()
  or empresa_id = '96b9a6b9-32d0-453e-9f69-74a2691ac5cc'
);

create policy modelo_relatorio_rdo_insert
on public.modelo_relatorio_rdo
for insert to authenticated
with check (empresa_id = private.active_actor_company_id());

create policy modelo_relatorio_rdo_update
on public.modelo_relatorio_rdo
for update to authenticated
using (empresa_id = private.active_actor_company_id())
with check (empresa_id = private.active_actor_company_id());

create policy modelo_relatorio_rdo_delete
on public.modelo_relatorio_rdo
for delete to authenticated
using (empresa_id = private.active_actor_company_id());
