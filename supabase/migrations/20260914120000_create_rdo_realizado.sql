-- RDO (Relatório Diário de Obra) — tabela fornecida pelo time de backend.
--
-- Regra de visibilidade (aplicada em RLS, espelhando o app):
--   * gestora do projeto e cliente vinculado (status_vinculo_cliente = 'ativo')
--     enxergam o RDO de TODAS as empresas do projeto;
--   * qualquer outra empresa (colaboradora comum) só enxerga o próprio RDO.
-- Reaproveita os helpers de private.* já criados em
-- 20260908010000_project_team_rls_hardening.sql (active_actor_company_id,
-- can_access_project) em vez de duplicar a lógica de papel.

create table public.rdo_realizado (
  id uuid not null default gen_random_uuid(),
  criado_em timestamp with time zone not null default now(),
  projeto_id uuid default gen_random_uuid(),
  empresa_id uuid default gen_random_uuid(),
  criado_user_id uuid default gen_random_uuid(),
  equipe json,
  data text,
  manha_chegada text,
  manha_inicio text,
  manha_saida text,
  manha_cond_trabalho text,
  manha_cond_clima text,
  tarde_chegada text,
  tarde_inicio text,
  tarde_saida text,
  tarde_cond_trabalho text,
  tarde_cond_clima text,
  noite_chegada text,
  noite_inicio text,
  noite_saida text,
  noite_cond_trabalho text,
  noite_cond_clima text,
  atividades_realizadas text,
  equipamentos_utilizados text,
  observacoes text,
  status text,
  constraint rdo_realizado_pkey primary key (id),
  constraint rdo_realizado_empresa_id_fkey foreign key (empresa_id) references public.empresas(id),
  constraint rdo_realizado_criado_user_id_fkey foreign key (criado_user_id) references public.usuarios(id),
  constraint rdo_realizado_projeto_id_fkey foreign key (projeto_id) references public.projetos(id)
);

create index rdo_realizado_projeto_id_idx on public.rdo_realizado (projeto_id);
create index rdo_realizado_empresa_id_idx on public.rdo_realizado (empresa_id);

alter table public.rdo_realizado enable row level security;

-- Leitura: gestora/cliente ativo do projeto veem tudo; qualquer empresa
-- sempre enxerga o próprio RDO (cobre a colaboradora comum).
create policy rdo_realizado_select
on public.rdo_realizado
for select to authenticated
using (
  empresa_id = private.active_actor_company_id()
  or exists (
    select 1
    from public.projetos p
    where p.id = rdo_realizado.projeto_id
      and (
        p.empresa_gestora_id = private.active_actor_company_id()
        or (
          p.empresa_cliente_id = private.active_actor_company_id()
          and p.status_vinculo_cliente = 'ativo'
        )
      )
  )
);

-- Criação: só quem executa a obra (gestora ou colaboradora aceita) registra
-- RDO da própria empresa — o cliente só revisa, nunca cria.
create policy rdo_realizado_insert
on public.rdo_realizado
for insert to authenticated
with check (
  empresa_id = private.active_actor_company_id()
  and private.can_access_project(projeto_id)
  and not exists (
    select 1
    from public.projetos p
    where p.id = rdo_realizado.projeto_id
      and p.empresa_cliente_id = private.active_actor_company_id()
      and p.status_vinculo_cliente = 'ativo'
  )
);

-- Atualização: dono do RDO (edição), gestora do projeto (gestão) ou cliente
-- ativo (só troca o status — o app só expõe esse caminho pra cliente; RLS
-- não restringe coluna a coluna aqui, mesma granularidade já usada nas
-- demais tabelas do projeto).
create policy rdo_realizado_update
on public.rdo_realizado
for update to authenticated
using (
  empresa_id = private.active_actor_company_id()
  or exists (
    select 1
    from public.projetos p
    where p.id = rdo_realizado.projeto_id
      and (
        p.empresa_gestora_id = private.active_actor_company_id()
        or (
          p.empresa_cliente_id = private.active_actor_company_id()
          and p.status_vinculo_cliente = 'ativo'
        )
      )
  )
)
with check (
  empresa_id = private.active_actor_company_id()
  or exists (
    select 1
    from public.projetos p
    where p.id = rdo_realizado.projeto_id
      and (
        p.empresa_gestora_id = private.active_actor_company_id()
        or (
          p.empresa_cliente_id = private.active_actor_company_id()
          and p.status_vinculo_cliente = 'ativo'
        )
      )
  )
);

-- Exclusão: só o dono do RDO ou a gestora do projeto — o cliente nunca
-- apaga RDO de outra empresa.
create policy rdo_realizado_delete
on public.rdo_realizado
for delete to authenticated
using (
  empresa_id = private.active_actor_company_id()
  or exists (
    select 1
    from public.projetos p
    where p.id = rdo_realizado.projeto_id
      and p.empresa_gestora_id = private.active_actor_company_id()
  )
);
