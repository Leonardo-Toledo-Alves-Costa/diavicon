-- Disabled profiles keep their own row available only while completing an invite.
-- Company, address and role visibility requires an active profile.

drop policy if exists auth_users_select_own on public.usuarios;
create policy auth_users_select_own
on public.usuarios
for select
to authenticated
using (
  id = (select auth.uid())
  and (
    ativo = true
    or coalesce((select auth.jwt()) -> 'app_metadata' ->> 'onboarding', '') = 'invite'
  )
);

drop policy if exists auth_users_update_own on public.usuarios;
create policy auth_users_update_own
on public.usuarios
for update
to authenticated
using (
  id = (select auth.uid())
  and (
    ativo = true
    or coalesce((select auth.jwt()) -> 'app_metadata' ->> 'onboarding', '') = 'invite'
  )
)
with check (
  id = (select auth.uid())
  and ativo = true
);

drop policy if exists auth_companies_select_member on public.empresas;
create policy auth_companies_select_member
on public.empresas
for select
to authenticated
using (
  exists (
    select 1
    from public.usuarios u
    where u.id = (select auth.uid())
      and u.ativo = true
      and u.empresa_id = empresas.id
  )
);

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
      and u.is_admin_empresa = true
  )
)
with check (
  exists (
    select 1
    from public.usuarios u
    where u.id = (select auth.uid())
      and u.ativo = true
      and u.empresa_id = empresas.id
      and u.is_admin_empresa = true
  )
);

drop policy if exists auth_addresses_select_related on public.enderecos;
create policy auth_addresses_select_related
on public.enderecos
for select
to authenticated
using (
  exists (
    select 1
    from public.usuarios u
    where u.id = (select auth.uid())
      and (
        u.ativo = true
        or coalesce((select auth.jwt()) -> 'app_metadata' ->> 'onboarding', '') = 'invite'
      )
      and u.endereco_id = enderecos.id
  )
  or exists (
    select 1
    from public.empresas e
    join public.usuarios u on u.empresa_id = e.id
    where u.id = (select auth.uid())
      and u.ativo = true
      and e.endereco_id = enderecos.id
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
      and u.is_admin_empresa = true
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
      and u.is_admin_empresa = true
      and e.endereco_id = enderecos.id
  )
);

drop policy if exists auth_user_roles_select_own on public.usuario_papeis;
create policy auth_user_roles_select_own
on public.usuario_papeis
for select
to authenticated
using (
  usuario_id = (select auth.uid())
  and exists (
    select 1 from public.usuarios u
    where u.id = (select auth.uid()) and u.ativo = true
  )
);
