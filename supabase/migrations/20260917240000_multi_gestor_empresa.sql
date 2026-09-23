-- "Tornar Gestor da empresa" é uma CONCESSÃO (grant/revoke) do papel de
-- Gestor (is_admin_empresa), não mais uma troca atômica de administrador
-- principal único: mais de um colaborador pode ser Gestor (e acessar o
-- Painel da empresa) ao mesmo tempo. Remove o índice único que limitava a
-- empresa a 1 único is_admin_empresa=true (criado em 20260902050000) e
-- ajusta o gatilho de auto-promoção pra só agir quando o Gestor excluído
-- era o ÚLTIMO da empresa — com mais de um Gestor, os outros continuam
-- valendo e não precisa promover ninguém.

begin;

drop index if exists public.usuarios_one_primary_admin_per_company_idx;

create or replace function public.promote_admin_before_primary_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_other_gestor uuid;
  v_successor uuid;
begin
  if OLD.is_admin_empresa is not true or OLD.empresa_id is null then
    return OLD;
  end if;

  select u.id into v_other_gestor
  from public.usuarios u
  where u.empresa_id = OLD.empresa_id
    and u.id <> OLD.id
    and u.is_admin_empresa is true
  limit 1;

  if v_other_gestor is not null then
    return OLD;
  end if;

  select u.id into v_successor
  from public.usuarios u
  where u.empresa_id = OLD.empresa_id
    and u.id <> OLD.id
    and u.ativo is true
    and u.is_admin_empresa is false
    and u.is_admin is true
  order by u.criado_em asc nulls last, u.id asc
  limit 1;

  if v_successor is null then
    raise exception using errcode = '23514', message = 'A empresa precisa manter um administrador principal.';
  end if;

  update public.usuarios
  set is_admin_empresa = false
  where id = OLD.id;

  update public.usuarios
  set is_admin_empresa = true,
      is_admin = false
  where id = v_successor;

  return OLD;
end;
$$;

commit;
