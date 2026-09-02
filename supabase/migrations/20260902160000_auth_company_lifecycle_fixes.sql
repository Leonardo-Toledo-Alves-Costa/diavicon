-- Correct the company lifecycle primitives from auth_company_lifecycle.

begin;

-- Resolve the default by its stable business name, not by a deployment UUID.
do $$
declare
  v_freemium_count integer;
  v_freemium_id uuid;
begin
  select count(*)
  into v_freemium_count
  from public.planos
  where lower(btrim(nome)) = 'freemium';

  if v_freemium_count <> 1 then
    raise exception using
      errcode = 'P0001',
      message = 'É necessário haver exatamente um plano Freemium.';
  end if;

  select id
  into v_freemium_id
  from public.planos
  where lower(btrim(nome)) = 'freemium';

  update public.planos
  set is_default = false;

  update public.planos
  set is_default = true,
      qtd_user = 5
  where id = v_freemium_id;
end;
$$;

-- An AFTER DELETE trigger sees the deleted row as gone.  If no successor is
-- available, raising here aborts the original delete transaction.
create or replace function public.promote_admin_before_primary_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_successor uuid;
begin
  if OLD.is_admin_empresa is not true or OLD.empresa_id is null then
    return OLD;
  end if;

  select u.id
  into v_successor
  from public.usuarios u
  where u.empresa_id = OLD.empresa_id
    and u.ativo is true
    and u.is_admin_empresa is not true
    and u.is_admin is true
  order by u.criado_em asc nulls last, u.id asc
  limit 1;

  if v_successor is null then
    raise exception using
      errcode = '23514',
      message = 'A empresa precisa manter um administrador principal.';
  end if;

  update public.usuarios
  set is_admin_empresa = true,
      is_admin = false
  where id = v_successor;

  return OLD;
end;
$$;

drop trigger if exists usuarios_primary_admin_delete on public.usuarios;
create trigger usuarios_primary_admin_delete
after delete on public.usuarios
for each row
execute function public.promote_admin_before_primary_delete();

revoke all on function public.promote_admin_before_primary_delete() from public, anon, authenticated;

-- A stale invite JWT is useful only while the row is still pending.
drop policy if exists auth_users_select_own on public.usuarios;
create policy auth_users_select_own
on public.usuarios
for select
to authenticated
using (
  id = (select auth.uid())
  and (
    ativo is true
    or (
      convite_pendente is true
      and coalesce((select auth.jwt()) -> 'app_metadata' ->> 'onboarding', '') = 'invite'
    )
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
    ativo is true
    or (
      convite_pendente is true
      and coalesce((select auth.jwt()) -> 'app_metadata' ->> 'onboarding', '') = 'invite'
    )
  )
)
with check (
  id = (select auth.uid())
  and ativo is true
  and convite_pendente is false
);

create or replace function public.create_invited_profile_if_capacity(
  p_user_id uuid,
  p_empresa_id uuid,
  p_nome text,
  p_sobrenome text,
  p_cargo text,
  p_email text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_limit bigint;
  v_used bigint;
begin
  if p_user_id is null or p_empresa_id is null then
    raise exception using errcode = '22023', message = 'Usuário ou empresa inválidos.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_empresa_id::text, 0));

  select p.qtd_user
  into v_limit
  from public.empresas e
  left join public.planos p on p.id = e.plano_id
  where e.id = p_empresa_id
    and e.ativo is true;

  if not found or coalesce(v_limit, 0) < 1 then
    raise exception using errcode = 'P0001', message = 'O plano da empresa não possui uma quota válida.';
  end if;

  select count(*)
  into v_used
  from public.usuarios
  where empresa_id = p_empresa_id
    and (ativo is true or convite_pendente is true);

  if v_used >= v_limit then
    raise exception using errcode = 'P0001', message = 'O limite de usuários do plano foi atingido.';
  end if;

  insert into public.usuarios (
    id, empresa_id, nome, sobrenome, cargo, ativo, convite_pendente, email
  ) values (
    p_user_id,
    p_empresa_id,
    nullif(btrim(p_nome), ''),
    nullif(btrim(p_sobrenome), ''),
    nullif(btrim(p_cargo), ''),
    false,
    true,
    nullif(btrim(p_email), '')
  );

  return p_user_id;
end;
$$;

create or replace function public.reactivate_user_if_capacity(
  p_user_id uuid,
  p_empresa_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_limit bigint;
  v_used bigint;
begin
  if p_user_id is null or p_empresa_id is null then
    raise exception using errcode = '22023', message = 'Usuário ou empresa inválidos.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_empresa_id::text, 0));

  select p.qtd_user
  into v_limit
  from public.empresas e
  left join public.planos p on p.id = e.plano_id
  where e.id = p_empresa_id
    and e.ativo is true;

  if not found or coalesce(v_limit, 0) < 1 then
    raise exception using errcode = 'P0001', message = 'O plano da empresa não possui uma quota válida.';
  end if;

  if not exists (
    select 1
    from public.usuarios
    where id = p_user_id
      and empresa_id = p_empresa_id
      and ativo is false
      and convite_pendente is false
      and is_admin_empresa is not true
  ) then
    return false;
  end if;

  select count(*)
  into v_used
  from public.usuarios
  where empresa_id = p_empresa_id
    and (ativo is true or convite_pendente is true);

  if v_used >= v_limit then
    raise exception using errcode = 'P0001', message = 'O limite de usuários do plano foi atingido.';
  end if;

  update public.usuarios
  set ativo = true,
      convite_pendente = false
  where id = p_user_id
    and empresa_id = p_empresa_id
    and ativo is false
    and convite_pendente is false
    and is_admin_empresa is not true;

  return found;
end;
$$;

revoke all on function public.create_invited_profile_if_capacity(uuid, uuid, text, text, text, text) from public, anon, authenticated;
revoke all on function public.reactivate_user_if_capacity(uuid, uuid) from public, anon, authenticated;
grant execute on function public.create_invited_profile_if_capacity(uuid, uuid, text, text, text, text) to service_role;
grant execute on function public.reactivate_user_if_capacity(uuid, uuid) to service_role;

commit;
