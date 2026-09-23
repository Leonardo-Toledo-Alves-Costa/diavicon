-- Authentication/company lifecycle hardening.
-- This migration intentionally does not change project or project-team tables.

begin;

-- Pending invitations occupy a company seat but are not active accounts.
alter table public.usuarios
  add column if not exists convite_pendente boolean;

update public.usuarios
set convite_pendente = false
where convite_pendente is null;

alter table public.usuarios
  alter column convite_pendente set default false,
  alter column convite_pendente set not null;

alter table public.usuarios
  drop constraint if exists usuarios_active_pending_check;

alter table public.usuarios
  add constraint usuarios_active_pending_check
  check (not (ativo is true and convite_pendente is true));

create index if not exists usuarios_empresa_quota_idx
  on public.usuarios (empresa_id)
  where empresa_id is not null and (ativo is true or convite_pendente is true);

create unique index if not exists usuarios_one_primary_admin_per_company_idx
  on public.usuarios (empresa_id)
  where empresa_id is not null and is_admin_empresa is true;

-- CNPJ uniqueness is based on digits, so masked and unmasked values collide.
create unique index if not exists empresas_cnpj_normalized_uidx
  on public.empresas (regexp_replace(cnpj, '[^0-9]', '', 'g'))
  where nullif(regexp_replace(cnpj, '[^0-9]', '', 'g'), '') is not null;

-- Freemium is the stable default used by company creation.  The unique
-- partial index below guarantees that the catalog has at most one default.
alter table public.planos
  add column if not exists is_default boolean;

update public.planos
set is_default = false
where is_default is null or is_default is true;

update public.planos
set is_default = true,
    qtd_user = 5
where id = '26114287-b125-4792-89f2-f933081b2e72'::uuid;

alter table public.planos
  alter column is_default set default false,
  alter column is_default set not null;

create unique index if not exists planos_one_default_uidx
  on public.planos (is_default)
  where is_default is true;

-- Company creation and protected lifecycle state are server-only.
drop policy if exists auth_companies_insert_authenticated on public.empresas;
drop policy if exists auth_companies_insert_anon on public.empresas;
revoke insert on public.empresas from anon, authenticated;

-- Preserve the company profile editor's safe fields while protecting identity,
-- lifecycle and billing fields from direct Data API updates.
revoke update on public.empresas from anon, authenticated;
grant update (
  nome,
  descricao,
  tipo,
  tamanho,
  foto_url,
  foto_capa,
  site,
  linkedin,
  instagram,
  email_contato,
  whatsapp,
  youtube,
  ramo_atuacao,
  sobre,
  endereco_id
) on public.empresas to authenticated;
revoke update (plano_id, cnpj, ativo) on public.empresas from anon, authenticated;

-- Plans are a read-only catalog to clients.
alter table public.planos enable row level security;
drop policy if exists planos_catalog_select on public.planos;
drop policy if exists planos_catalog_select_anon on public.planos;
drop policy if exists planos_catalog_select_authenticated on public.planos;
create policy planos_catalog_select_anon
on public.planos
for select
to anon
using (true);
create policy planos_catalog_select_authenticated
on public.planos
for select
to authenticated
using (true);
revoke insert, update, delete on public.planos from anon, authenticated;
grant select on public.planos to anon, authenticated;

-- Internal functions are intentionally exposed only through service_role.
create or replace function public.create_company_for_user(
  p_user_id uuid,
  p_company jsonb,
  p_address jsonb,
  p_cargo text default null,
  p_titulo_principal text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_address_id uuid;
  v_company_id uuid;
  v_plan_id uuid;
begin
  if p_user_id is null then
    raise exception using errcode = '22023', message = 'Usuário inválido.';
  end if;

  select id into v_plan_id
  from public.planos
  where is_default is true;

  if v_plan_id is null then
    raise exception using errcode = 'P0001', message = 'Plano padrão não configurado.';
  end if;

  insert into public.enderecos (
    endereco, cidade, estado, cep, bairro, numero, complemento, pais
  ) values (
    p_address ->> 'endereco',
    p_address ->> 'cidade',
    p_address ->> 'estado',
    p_address ->> 'cep',
    p_address ->> 'bairro',
    p_address ->> 'numero',
    p_address ->> 'complemento',
    coalesce(nullif(p_address ->> 'pais', ''), 'Brasil')
  ) returning id into v_address_id;

  insert into public.empresas (
    nome, cnpj, endereco_id, plano_id, ativo, tipo, tamanho,
    foto_url, site, linkedin
  ) values (
    nullif(btrim(p_company ->> 'nome'), ''),
    nullif(btrim(p_company ->> 'cnpj'), ''),
    v_address_id,
    v_plan_id,
    true,
    coalesce(nullif(btrim(p_company ->> 'tipo'), ''), 'Profissional'),
    p_company ->> 'tamanho',
    p_company ->> 'foto_url',
    p_company ->> 'site',
    p_company ->> 'linkedin'
  ) returning id into v_company_id;

  update public.usuarios
  set empresa_id = v_company_id,
      is_admin_empresa = true,
      is_admin = false,
      ativo = true,
      convite_pendente = false,
      cargo = coalesce(nullif(btrim(p_cargo), ''), cargo),
      titulo_principal = coalesce(nullif(btrim(p_titulo_principal), ''), titulo_principal)
  where id = p_user_id
    and empresa_id is null;

  if not found then
    raise exception using errcode = '23505', message = 'Este usuário já está vinculado a uma empresa.';
  end if;

  return v_company_id;
end;
$$;

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
  v_plan_id uuid;
begin
  if p_user_id is null or p_empresa_id is null then
    raise exception using errcode = '22023', message = 'Usuário ou empresa inválidos.';
  end if;

  -- Serialize all seat changes for one company, including concurrent invites.
  perform pg_advisory_xact_lock(hashtextextended(p_empresa_id::text, 0));

  select e.plano_id, p.qtd_user
  into v_plan_id, v_limit
  from public.empresas e
  left join public.planos p on p.id = e.plano_id
  where e.id = p_empresa_id and e.ativo is true;

  if not found then
    raise exception using errcode = 'P0002', message = 'Empresa não encontrada ou inativa.';
  end if;

  select count(*) into v_used
  from public.usuarios
  where empresa_id = p_empresa_id
    and (ativo is true or convite_pendente is true);

  if coalesce(v_limit, 0) > 0 and v_used >= v_limit then
    raise exception using errcode = 'P0001', message = 'O limite de usuários do plano foi atingido.';
  end if;

  insert into public.usuarios (
    id, empresa_id, nome, sobrenome, cargo, ativo, convite_pendente, email
  ) values (
    p_user_id, p_empresa_id, nullif(btrim(p_nome), ''),
    nullif(btrim(p_sobrenome), ''), nullif(btrim(p_cargo), ''),
    false, true, nullif(btrim(p_email), '')
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

  select p.qtd_user into v_limit
  from public.empresas e
  left join public.planos p on p.id = e.plano_id
  where e.id = p_empresa_id and e.ativo is true;

  if not found then
    raise exception using errcode = 'P0002', message = 'Empresa não encontrada ou inativa.';
  end if;

  if not exists (
    select 1 from public.usuarios
    where id = p_user_id and empresa_id = p_empresa_id and ativo is false
  ) then
    return false;
  end if;

  select count(*) into v_used
  from public.usuarios
  where empresa_id = p_empresa_id
    and (ativo is true or convite_pendente is true);

  if coalesce(v_limit, 0) > 0 and v_used >= v_limit then
    raise exception using errcode = 'P0001', message = 'O limite de usuários do plano foi atingido.';
  end if;

  update public.usuarios
  set ativo = true, convite_pendente = false
  where id = p_user_id and empresa_id = p_empresa_id and ativo is false;

  return found;
end;
$$;

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
begin
  if p_empresa_id is null or p_current_primary_id is null or p_target_id is null
     or p_current_primary_id = p_target_id then
    raise exception using errcode = '22023', message = 'Dados de transferência inválidos.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_empresa_id::text, 0));

  if not exists (
    select 1 from public.usuarios
    where id = p_current_primary_id
      and empresa_id = p_empresa_id
      and ativo is true
      and is_admin_empresa is true
  ) then
    raise exception using errcode = '42501', message = 'Administrador principal inválido.';
  end if;

  if not exists (
    select 1 from public.usuarios
    where id = p_target_id
      and empresa_id = p_empresa_id
      and ativo is true
      and is_admin_empresa is false
      and is_admin is true
  ) then
    raise exception using errcode = '22023', message = 'O alvo precisa ser um administrador comum ativo.';
  end if;

  -- Clear the unique primary slot before assigning it to the target.
  update public.usuarios
  set is_admin_empresa = false, is_admin = true
  where id = p_current_primary_id;

  update public.usuarios
  set is_admin_empresa = true, is_admin = false
  where id = p_target_id;

  return true;
end;
$$;

revoke all on function public.create_company_for_user(uuid, jsonb, jsonb, text, text) from public, anon, authenticated;
revoke all on function public.create_invited_profile_if_capacity(uuid, uuid, text, text, text, text) from public, anon, authenticated;
revoke all on function public.reactivate_user_if_capacity(uuid, uuid) from public, anon, authenticated;
revoke all on function public.transfer_primary_admin(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.create_company_for_user(uuid, jsonb, jsonb, text, text) to service_role;
grant execute on function public.create_invited_profile_if_capacity(uuid, uuid, text, text, text, text) to service_role;
grant execute on function public.reactivate_user_if_capacity(uuid, uuid) to service_role;
grant execute on function public.transfer_primary_admin(uuid, uuid, uuid) to service_role;

-- If the primary admin is deleted outside the Edge Function, promote the
-- oldest active common admin.  A company cannot lose its primary admin.
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

drop trigger if exists usuarios_primary_admin_delete on public.usuarios;
create trigger usuarios_primary_admin_delete
before delete on public.usuarios
for each row
execute function public.promote_admin_before_primary_delete();

commit;
