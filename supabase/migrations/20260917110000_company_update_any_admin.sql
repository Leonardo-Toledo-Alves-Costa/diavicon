-- `auth_companies_update_admin` (20260902110000_auth_rls_active_state.sql)
-- only let the PRIMARY admin (is_admin_empresa) update the `empresas` row —
-- every other admin check in the app (the `convidar-funcionario` and
-- `auth-operations` Edge Functions, `companyAdminCanAct`) treats
-- `is_admin_empresa = true` OR `is_admin = true` as "is an admin of this
-- company". A secondary admin hitting "editar informações da empresa" and
-- getting silently blocked by RLS is the direct result of that mismatch.
-- Widen the table policy to the same rule used everywhere else. Also widens
-- `auth_addresses_update_related`'s company branch the same way — editing
-- company info in the app (empresa_informacoes_screen.dart) updates the
-- linked `enderecos` row in the same save flow, so it was hitting the exact
-- same silent block (an UPDATE whose USING clause matches zero rows is not
-- an error in Postgres/PostgREST — it just quietly changes nothing).

begin;

drop policy if exists auth_companies_update_admin on public.empresas;
create policy auth_companies_update_admin
on public.empresas
for update
to authenticated
using (
  exists (
    select 1
    from public.usuarios u
    where u.id = (select auth.uid())
      and u.ativo = true
      and u.empresa_id = empresas.id
      and (u.is_admin_empresa = true or u.is_admin = true)
  )
)
with check (
  exists (
    select 1
    from public.usuarios u
    where u.id = (select auth.uid())
      and u.ativo = true
      and u.empresa_id = empresas.id
      and (u.is_admin_empresa = true or u.is_admin = true)
  )
);

drop policy if exists auth_addresses_update_related on public.enderecos;
create policy auth_addresses_update_related
on public.enderecos
for update
to authenticated
using (
  exists (
    select 1
    from public.usuarios u
    where u.id = (select auth.uid())
      and u.ativo = true
      and u.endereco_id = enderecos.id
  )
  or exists (
    select 1
    from public.empresas e
    join public.usuarios u on u.empresa_id = e.id
    where u.id = (select auth.uid())
      and u.ativo = true
      and (u.is_admin_empresa = true or u.is_admin = true)
      and e.endereco_id = enderecos.id
  )
)
with check (
  exists (
    select 1
    from public.usuarios u
    where u.id = (select auth.uid())
      and u.ativo = true
      and u.endereco_id = enderecos.id
  )
  or exists (
    select 1
    from public.empresas e
    join public.usuarios u on u.empresa_id = e.id
    where u.id = (select auth.uid())
      and u.ativo = true
      and (u.is_admin_empresa = true or u.is_admin = true)
      and e.endereco_id = enderecos.id
  )
);

notify pgrst, 'reload schema';

commit;
