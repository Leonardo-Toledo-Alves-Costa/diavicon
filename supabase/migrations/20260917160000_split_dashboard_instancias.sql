-- Replaces the single `dashboard_instancias` table (projeto_id/estrutura_id/
-- elemento_id all nullable on one row) with 4 tables, one per nível de
-- aplicação — requested after repeated `dashboard_instancias_elemento_id_fkey`
-- violations on estrutura/projeto dashboards. The application code
-- (lib/features/dashboards_bi/screens/dashboard_screen.dart) already scopes
-- which id it sends per nível via `_idsParaNivel`, so this migration doesn't
-- fix a live bug by itself (that bug is still being diagnosed) — it makes
-- the wrong-id class of bug structurally impossible going forward: a
-- projeto/estrutura dashboard is now stored in a table that has no
-- `elemento_id` column at all to put a bad value into.
--
-- `dashboard_modelos` (the templates) is untouched — it still holds
-- `nivel_aplicacao` to distinguish which of the 4 kinds a template is for.
--
-- The old `dashboard_instancias` table is RENAMED (not dropped) to
-- `dashboard_instancias_legado`, and its rows are copied into the matching
-- new table by `nivel_aplicacao` — nothing is deleted, so this is safe to
-- apply even with real data already in the old table.

begin;

-- ---------------------------------------------------------------------------
-- 1. New tables — same non-id columns as the old table, but only the ONE id
--    column that nível actually uses, and it's NOT NULL.
-- ---------------------------------------------------------------------------

create table if not exists public.dashboard_estruturas_monitoradas (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  modelo_id uuid not null references public.dashboard_modelos(id) on delete cascade,
  estrutura_id uuid not null references public.estruturas(id) on delete cascade,
  empresa_id uuid not null references public.empresas(id) on delete cascade,
  nivel_aplicacao text not null default 'estrutura_multi_projeto',
  filtros_gerais_id json,
  overrides_json json,
  unique (estrutura_id)
);

create table if not exists public.dashboard_projetos (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  modelo_id uuid not null references public.dashboard_modelos(id) on delete cascade,
  projeto_id uuid not null references public.projetos(id) on delete cascade,
  empresa_id uuid not null references public.empresas(id) on delete cascade,
  nivel_aplicacao text not null default 'projeto',
  filtros_gerais_id json,
  overrides_json json,
  unique (projeto_id)
);

create table if not exists public.dashboard_estruturas (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  modelo_id uuid not null references public.dashboard_modelos(id) on delete cascade,
  projeto_id uuid references public.projetos(id) on delete cascade,
  estrutura_id uuid not null references public.estruturas(id) on delete cascade,
  empresa_id uuid not null references public.empresas(id) on delete cascade,
  nivel_aplicacao text not null default 'estrutura_no_projeto',
  filtros_gerais_id json,
  overrides_json json,
  unique (estrutura_id)
);

create table if not exists public.dashboard_elementos (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  modelo_id uuid not null references public.dashboard_modelos(id) on delete cascade,
  projeto_id uuid references public.projetos(id) on delete cascade,
  estrutura_id uuid references public.estruturas(id) on delete cascade,
  elemento_id uuid not null references public.elementos_estruturais(id) on delete cascade,
  empresa_id uuid not null references public.empresas(id) on delete cascade,
  nivel_aplicacao text not null default 'elemento_no_projeto',
  filtros_gerais_id json,
  overrides_json json,
  unique (elemento_id)
);

-- ---------------------------------------------------------------------------
-- 2. Migrate existing rows from the old table, by nivel_aplicacao. Rows
--    whose scoping id no longer exists (the exact orphaned-data scenario
--    reported) are simply not copied — they'd fail the new NOT NULL FK
--    anyway, and the old row stays intact in the renamed legacy table.
-- ---------------------------------------------------------------------------

insert into public.dashboard_estruturas_monitoradas (id, criado_em, modelo_id, estrutura_id, empresa_id, filtros_gerais_id, overrides_json)
select id, criado_em, modelo_id, estrutura_id, empresa_id, filtros_gerais_id, overrides_json
from public.dashboard_instancias
where nivel_aplicacao = 'estrutura_multi_projeto' and estrutura_id is not null
on conflict do nothing;

insert into public.dashboard_projetos (id, criado_em, modelo_id, projeto_id, empresa_id, filtros_gerais_id, overrides_json)
select id, criado_em, modelo_id, projeto_id, empresa_id, filtros_gerais_id, overrides_json
from public.dashboard_instancias
where nivel_aplicacao = 'projeto' and projeto_id is not null
on conflict do nothing;

insert into public.dashboard_estruturas (id, criado_em, modelo_id, projeto_id, estrutura_id, empresa_id, filtros_gerais_id, overrides_json)
select id, criado_em, modelo_id, projeto_id, estrutura_id, empresa_id, filtros_gerais_id, overrides_json
from public.dashboard_instancias
where nivel_aplicacao = 'estrutura_no_projeto' and estrutura_id is not null
on conflict do nothing;

insert into public.dashboard_elementos (id, criado_em, modelo_id, projeto_id, estrutura_id, elemento_id, empresa_id, filtros_gerais_id, overrides_json)
select id, criado_em, modelo_id, projeto_id, estrutura_id, elemento_id, empresa_id, filtros_gerais_id, overrides_json
from public.dashboard_instancias
where nivel_aplicacao = 'elemento_no_projeto' and elemento_id is not null
on conflict do nothing;

alter table public.dashboard_instancias rename to dashboard_instancias_legado;

-- ---------------------------------------------------------------------------
-- 3. RLS + grants — same shape as every other empresa-scoped BI table:
--    any ACTIVE user of the same empresa can read/write. Grants are
--    explicit because this session found three separate tables (empresas,
--    usuarios, notificacoes) where the RLS policy was fine but the base
--    table GRANT to `authenticated` was simply never issued.
-- ---------------------------------------------------------------------------

alter table public.dashboard_estruturas_monitoradas enable row level security;
alter table public.dashboard_projetos enable row level security;
alter table public.dashboard_estruturas enable row level security;
alter table public.dashboard_elementos enable row level security;

grant select, insert, update, delete on public.dashboard_estruturas_monitoradas to authenticated;
grant select, insert, update, delete on public.dashboard_projetos to authenticated;
grant select, insert, update, delete on public.dashboard_estruturas to authenticated;
grant select, insert, update, delete on public.dashboard_elementos to authenticated;

create policy dashboard_estruturas_monitoradas_empresa on public.dashboard_estruturas_monitoradas
for all to authenticated
using (exists (select 1 from public.usuarios u where u.id = auth.uid() and u.ativo = true and u.empresa_id = dashboard_estruturas_monitoradas.empresa_id))
with check (exists (select 1 from public.usuarios u where u.id = auth.uid() and u.ativo = true and u.empresa_id = dashboard_estruturas_monitoradas.empresa_id));

create policy dashboard_projetos_empresa on public.dashboard_projetos
for all to authenticated
using (exists (select 1 from public.usuarios u where u.id = auth.uid() and u.ativo = true and u.empresa_id = dashboard_projetos.empresa_id))
with check (exists (select 1 from public.usuarios u where u.id = auth.uid() and u.ativo = true and u.empresa_id = dashboard_projetos.empresa_id));

create policy dashboard_estruturas_empresa on public.dashboard_estruturas
for all to authenticated
using (exists (select 1 from public.usuarios u where u.id = auth.uid() and u.ativo = true and u.empresa_id = dashboard_estruturas.empresa_id))
with check (exists (select 1 from public.usuarios u where u.id = auth.uid() and u.ativo = true and u.empresa_id = dashboard_estruturas.empresa_id));

create policy dashboard_elementos_empresa on public.dashboard_elementos
for all to authenticated
using (exists (select 1 from public.usuarios u where u.id = auth.uid() and u.ativo = true and u.empresa_id = dashboard_elementos.empresa_id))
with check (exists (select 1 from public.usuarios u where u.id = auth.uid() and u.ativo = true and u.empresa_id = dashboard_elementos.empresa_id));

notify pgrst, 'reload schema';

commit;
