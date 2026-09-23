-- Status de geração de relatórios de RDO — mesmo conceito de
-- `relatorio_ensaio` (usado pelos relatórios de ensaio), mas sem
-- `tipo_ensaio_id`/`estrutura_id`: RDO é escopado por projeto + empresa
-- executante, não por ensaio/estrutura.
--
-- ATENÇÃO: esta tabela já foi criada manualmente no Supabase com o schema
-- abaixo (`empresa_autora_id`, não `empresa_id`; `conteudo` como `text` —
-- serializado com jsonEncode/jsonDecode no app, não `jsonb`) — o CREATE
-- TABLE aqui é só documentação/referência. Se a tabela já existe no seu
-- projeto, rode só a parte de RLS (a partir do `alter table ... enable row
-- level security`).
create table public.relatorio_rdo (
  id uuid not null default gen_random_uuid(),
  criado_em timestamp with time zone not null default now(),
  criado_por uuid references public.usuarios(id),
  conteudo text,
  status text,
  projeto_id uuid references public.projetos(id),
  empresa_autora_id uuid references public.empresas(id),
  constraint relatorio_rdo_pkey primary key (id)
);

create index relatorio_rdo_projeto_id_idx on public.relatorio_rdo (projeto_id);
create index relatorio_rdo_empresa_autora_id_idx on public.relatorio_rdo (empresa_autora_id);

alter table public.relatorio_rdo enable row level security;

-- Mesma regra de visibilidade do RDO em si: gestora/cliente ativo do
-- projeto veem os relatórios de todas as empresas; qualquer empresa sempre
-- vê os relatórios que ela mesma gerou.
create policy relatorio_rdo_select
on public.relatorio_rdo
for select to authenticated
using (
  empresa_autora_id = private.active_actor_company_id()
  or exists (
    select 1
    from public.projetos p
    where p.id = relatorio_rdo.projeto_id
      and (
        p.empresa_gestora_id = private.active_actor_company_id()
        or (
          p.empresa_cliente_id = private.active_actor_company_id()
          and p.status_vinculo_cliente = 'ativo'
        )
      )
  )
);

create policy relatorio_rdo_insert
on public.relatorio_rdo
for insert to authenticated
with check (
  empresa_autora_id = private.active_actor_company_id()
  and private.can_access_project(projeto_id)
);

create policy relatorio_rdo_update
on public.relatorio_rdo
for update to authenticated
using (empresa_autora_id = private.active_actor_company_id())
with check (empresa_autora_id = private.active_actor_company_id());

create policy relatorio_rdo_delete
on public.relatorio_rdo
for delete to authenticated
using (empresa_autora_id = private.active_actor_company_id());
