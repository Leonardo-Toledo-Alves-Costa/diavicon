-- PENDENTE — ainda NÃO aplicado no Supabase (decisão de 18/09/2026: RLS
-- dos gastos fica para depois). Enquanto isso o sigilo por empresa depende
-- só dos filtros do app (lib/features/gastos/repositories/gastos_repository.dart)
-- e as tabelas respondem a qualquer chave, inclusive a anônima.
--
-- Escrito para as tabelas EXATAMENTE como foram criadas no painel — não
-- altera coluna nenhuma:
--   categoria_gastos: id, criado_em, empresa_id, nome, descricao
--   gastos:           id, criado_em, criado_por, projeto_id, empresa_id,
--                     categoria, reembolsavel, valor (centavos), meio,
--                     anexo_url, anexo_tipo
--
-- Regras (as mesmas que o app já aplica nas consultas):
--   * Todo gasto pertence a quem lançou (`criado_por`) e à empresa dele.
--   * O dono vê, edita e exclui os próprios gastos.
--   * O admin da empresa VÊ todos os gastos da empresa, mas não edita nem
--     exclui os de terceiros.
--   * Ninguém vê gastos de outra empresa, nem num projeto compartilhado.
--   * Categorias: lê as da empresa e as padrão DIAVICON; só o admin da
--     empresa cria, renomeia e exclui.
--
-- Pode rodar mais de uma vez sem erro.

begin;

-- ---------------------------------------------------------------------------
-- categoria_gastos
-- ---------------------------------------------------------------------------
alter table public.categoria_gastos enable row level security;

revoke all on public.categoria_gastos from anon;
grant select, insert, update, delete on public.categoria_gastos to authenticated;

drop policy if exists categoria_gastos_select on public.categoria_gastos;
create policy categoria_gastos_select on public.categoria_gastos
for select to authenticated
using (
  empresa_id = private.active_actor_company_id()
  or empresa_id = '96b9a6b9-32d0-453e-9f69-74a2691ac5cc'::uuid -- DIAVICON (padrão)
);

drop policy if exists categoria_gastos_insert on public.categoria_gastos;
create policy categoria_gastos_insert on public.categoria_gastos
for insert to authenticated
with check (
  empresa_id = private.active_actor_company_id()
  and private.is_active_company_admin(empresa_id)
);

drop policy if exists categoria_gastos_update on public.categoria_gastos;
create policy categoria_gastos_update on public.categoria_gastos
for update to authenticated
using (
  empresa_id = private.active_actor_company_id()
  and private.is_active_company_admin(empresa_id)
)
with check (
  empresa_id = private.active_actor_company_id()
  and private.is_active_company_admin(empresa_id)
);

drop policy if exists categoria_gastos_delete on public.categoria_gastos;
create policy categoria_gastos_delete on public.categoria_gastos
for delete to authenticated
using (
  empresa_id = private.active_actor_company_id()
  and private.is_active_company_admin(empresa_id)
);

-- ---------------------------------------------------------------------------
-- gastos
-- ---------------------------------------------------------------------------
alter table public.gastos enable row level security;

revoke all on public.gastos from anon;
grant select, insert, update, delete on public.gastos to authenticated;

drop policy if exists gastos_select on public.gastos;
create policy gastos_select on public.gastos
for select to authenticated
using (
  empresa_id = private.active_actor_company_id()
  and (
    criado_por = (select auth.uid())
    or private.is_active_company_admin(empresa_id)
  )
);

drop policy if exists gastos_insert on public.gastos;
create policy gastos_insert on public.gastos
for insert to authenticated
with check (
  criado_por = (select auth.uid())
  and empresa_id = private.active_actor_company_id()
  and private.can_access_project(projeto_id)
);

drop policy if exists gastos_update on public.gastos;
create policy gastos_update on public.gastos
for update to authenticated
using (
  criado_por = (select auth.uid())
  and empresa_id = private.active_actor_company_id()
)
with check (
  criado_por = (select auth.uid())
  and empresa_id = private.active_actor_company_id()
  and private.can_access_project(projeto_id)
);

drop policy if exists gastos_delete on public.gastos;
create policy gastos_delete on public.gastos
for delete to authenticated
using (
  criado_por = (select auth.uid())
  and empresa_id = private.active_actor_company_id()
);

notify pgrst, 'reload schema';

commit;
