-- Tighten authentication-related ownership policies without changing
-- unrelated business tables.

drop policy if exists auth_companies_update_member on public.empresas;
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
      and u.empresa_id = empresas.id
      and u.is_admin_empresa = true
  )
)
with check (
  exists (
    select 1
    from public.usuarios u
    where u.id = (select auth.uid())
      and u.empresa_id = empresas.id
      and u.is_admin_empresa = true
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
      and u.endereco_id = enderecos.id
  )
  or exists (
    select 1
    from public.empresas e
    join public.usuarios u on u.empresa_id = e.id
    where u.id = (select auth.uid())
      and u.is_admin_empresa = true
      and e.endereco_id = enderecos.id
  )
)
with check (
  exists (
    select 1
    from public.usuarios u
    where u.id = (select auth.uid())
      and u.endereco_id = enderecos.id
  )
  or exists (
    select 1
    from public.empresas e
    join public.usuarios u on u.empresa_id = e.id
    where u.id = (select auth.uid())
      and u.is_admin_empresa = true
      and e.endereco_id = enderecos.id
  )
);

drop policy if exists auth_user_roles_insert_own on public.usuario_papeis;
drop policy if exists auth_user_roles_update_own on public.usuario_papeis;
