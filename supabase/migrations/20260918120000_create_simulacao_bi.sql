-- Biblioteca de simulações de Monte Carlo (Padrões da empresa > Dashboard >
-- Modelos de simulação). Pode rodar mais de uma vez sem erro.
--
-- Mesmo desenho de `variavel_bi` e `dashboard_modelos`: as simulações da
-- DIAVICON valem como padrão para todas as empresas (somente leitura; o app
-- oferece "duplicar para minha empresa"), e a linhagem da duplicação fica em
-- `simulacao_origem_id`. Um card de dashboard que parte de um modelo COPIA a
-- configuração — editar ou excluir o modelo não altera os dashboards.

begin;

create table if not exists public.simulacao_bi (
  id uuid not null default gen_random_uuid(),
  criado_em timestamp with time zone not null default now(),
  criado_por uuid,
  empresa_id uuid not null,
  nome text not null,
  descricao text,
  configuracao jsonb not null,
  simulacao_origem_id uuid,
  constraint simulacao_bi_pkey primary key (id),
  constraint simulacao_bi_criado_por_fkey
    foreign key (criado_por) references public.usuarios(id) on delete set null,
  constraint simulacao_bi_empresa_id_fkey
    foreign key (empresa_id) references public.empresas(id) on delete cascade,
  constraint simulacao_bi_simulacao_origem_id_fkey
    foreign key (simulacao_origem_id) references public.simulacao_bi(id) on delete set null
);

create index if not exists simulacao_bi_empresa_id_idx on public.simulacao_bi (empresa_id);

-- Acesso: só usuários logados. Lê as da própria empresa e as da DIAVICON;
-- escreve só as da própria empresa.
alter table public.simulacao_bi enable row level security;

revoke all on public.simulacao_bi from anon;
grant select, insert, update, delete on public.simulacao_bi to authenticated;

drop policy if exists simulacao_bi_select on public.simulacao_bi;
create policy simulacao_bi_select on public.simulacao_bi
for select to authenticated
using (
  empresa_id = private.active_actor_company_id()
  or empresa_id = '96b9a6b9-32d0-453e-9f69-74a2691ac5cc'::uuid -- DIAVICON (padrão)
);

drop policy if exists simulacao_bi_insert on public.simulacao_bi;
create policy simulacao_bi_insert on public.simulacao_bi
for insert to authenticated
with check (empresa_id = private.active_actor_company_id());

drop policy if exists simulacao_bi_update on public.simulacao_bi;
create policy simulacao_bi_update on public.simulacao_bi
for update to authenticated
using (empresa_id = private.active_actor_company_id())
with check (empresa_id = private.active_actor_company_id());

drop policy if exists simulacao_bi_delete on public.simulacao_bi;
create policy simulacao_bi_delete on public.simulacao_bi
for delete to authenticated
using (empresa_id = private.active_actor_company_id());

commit;
