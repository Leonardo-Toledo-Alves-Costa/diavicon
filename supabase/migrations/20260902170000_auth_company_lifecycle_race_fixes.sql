-- Close the final lifecycle races around administrator transfer and succession.

begin;

create or replace function public.transfer_primary_admin(
  p_empresa_id uuid,
  p_current_primary_id uuid,
  p_target_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_lock_id uuid;
begin
  if p_empresa_id is null or p_current_primary_id is null or p_target_id is null
     or p_current_primary_id = p_target_id then
    raise exception using errcode = '22023', message = 'Dados de transferência inválidos.';
  end if;

  -- Serialize every lifecycle operation for this company and acquire both
  -- user row locks in UUID order before validating either role.
  perform pg_advisory_xact_lock(hashtextextended(p_empresa_id::text, 0));

  for v_lock_id in
    select u.id
    from public.usuarios u
    where u.id in (p_current_primary_id, p_target_id)
    order by u.id
    for update
  loop
    null;
  end loop;

  if not exists (
    select 1
    from public.usuarios
    where id = p_current_primary_id
      and empresa_id = p_empresa_id
      and ativo is true
      and is_admin_empresa is true
  ) then
    raise exception using errcode = '42501', message = 'Administrador principal inválido.';
  end if;

  if not exists (
    select 1
    from public.usuarios
    where id = p_target_id
      and empresa_id = p_empresa_id
      and ativo is true
      and is_admin is true
      and is_admin_empresa is false
  ) then
    raise exception using errcode = '22023', message = 'O alvo precisa ser um administrador comum ativo.';
  end if;

  update public.usuarios
  set is_admin_empresa = false,
      is_admin = true
  where id = p_current_primary_id
    and empresa_id = p_empresa_id
    and ativo is true
    and is_admin_empresa is true;
  if not found then
    raise exception using errcode = 'P0001', message = 'O administrador principal foi alterado durante a transferência.';
  end if;

  update public.usuarios
  set is_admin_empresa = true,
      is_admin = false
  where id = p_target_id
    and empresa_id = p_empresa_id
    and ativo is true
    and is_admin is true
    and is_admin_empresa is false;
  if not found then
    raise exception using errcode = 'P0001', message = 'O alvo foi alterado durante a transferência.';
  end if;

  return true;
end;
$$;

revoke all on function public.transfer_primary_admin(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.transfer_primary_admin(uuid, uuid, uuid) to service_role;

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

  -- Lock the chosen successor while it is still eligible.  If another
  -- lifecycle operation changes it before this point, the row is rechecked
  -- by the guarded UPDATE and the delete is rolled back if necessary.
  select u.id
  into v_successor
  from public.usuarios u
  where u.empresa_id = OLD.empresa_id
    and u.id <> OLD.id
    and u.ativo is true
    and u.is_admin is true
    and u.is_admin_empresa is false
  order by u.criado_em asc nulls last, u.id asc
  limit 1
  for update;

  if v_successor is null then
    raise exception using
      errcode = '23514',
      message = 'A empresa precisa manter um administrador principal.';
  end if;

  update public.usuarios
  set is_admin_empresa = true,
      is_admin = false
  where id = v_successor
    and empresa_id = OLD.empresa_id
    and ativo is true
    and is_admin is true
    and is_admin_empresa is false;
  if not found then
    raise exception using
      errcode = '23514',
      message = 'O sucessor deixou de ser um administrador comum ativo.';
  end if;

  return OLD;
end;
$$;

drop trigger if exists usuarios_primary_admin_delete on public.usuarios;
create trigger usuarios_primary_admin_delete
after delete on public.usuarios
for each row
execute function public.promote_admin_before_primary_delete();

revoke all on function public.promote_admin_before_primary_delete() from public, anon, authenticated;

commit;
