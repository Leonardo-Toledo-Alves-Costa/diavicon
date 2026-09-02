-- RLS for authentication and onboarding data only.
-- Anonymous requests receive no access because there are no policies for anon.

alter table public.usuarios enable row level security;
alter table public.empresas enable row level security;
alter table public.enderecos enable row level security;
alter table public.usuario_papeis enable row level security;

drop policy if exists auth_users_select_own on public.usuarios;
create policy auth_users_select_own
on public.usuarios
for select
to authenticated
using ((select auth.uid()) is not null and id = (select auth.uid()));

drop policy if exists auth_users_insert_own on public.usuarios;
create policy auth_users_insert_own
on public.usuarios
for insert
to authenticated
with check ((select auth.uid()) is not null and id = (select auth.uid()));

drop policy if exists auth_users_update_own on public.usuarios;
create policy auth_users_update_own
on public.usuarios
for update
to authenticated
using ((select auth.uid()) is not null and id = (select auth.uid()))
with check ((select auth.uid()) is not null and id = (select auth.uid()));

drop policy if exists auth_companies_select_member on public.empresas;
create policy auth_companies_select_member
on public.empresas
for select
to authenticated
using (
  id = (
    select u.empresa_id
    from public.usuarios u
    where u.id = (select auth.uid())
  )
);

drop policy if exists auth_companies_insert_authenticated on public.empresas;
create policy auth_companies_insert_authenticated
on public.empresas
for insert
to authenticated
with check ((select auth.uid()) is not null);

drop policy if exists auth_companies_update_member on public.empresas;
create policy auth_companies_update_member
on public.empresas
for update
to authenticated
using (
  id = (
    select u.empresa_id
    from public.usuarios u
    where u.id = (select auth.uid())
  )
)
with check (
  id = (
    select u.empresa_id
    from public.usuarios u
    where u.id = (select auth.uid())
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
      and u.endereco_id = enderecos.id
  )
  or exists (
    select 1
    from public.empresas e
    join public.usuarios u on u.empresa_id = e.id
    where u.id = (select auth.uid())
      and e.endereco_id = enderecos.id
  )
);

drop policy if exists auth_addresses_insert_authenticated on public.enderecos;
create policy auth_addresses_insert_authenticated
on public.enderecos
for insert
to authenticated
with check ((select auth.uid()) is not null);

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
      and e.endereco_id = enderecos.id
  )
);

drop policy if exists auth_user_roles_select_own on public.usuario_papeis;
create policy auth_user_roles_select_own
on public.usuario_papeis
for select
to authenticated
using (usuario_id = (select auth.uid()));

drop policy if exists auth_user_roles_insert_own on public.usuario_papeis;
create policy auth_user_roles_insert_own
on public.usuario_papeis
for insert
to authenticated
with check (usuario_id = (select auth.uid()));

drop policy if exists auth_user_roles_update_own on public.usuario_papeis;
create policy auth_user_roles_update_own
on public.usuario_papeis
for update
to authenticated
using (usuario_id = (select auth.uid()))
with check (usuario_id = (select auth.uid()));
