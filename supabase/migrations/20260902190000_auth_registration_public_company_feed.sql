-- Authenticated registration, controlled company feed and service RLS.

begin;

-- A user's own inactive row is needed to distinguish an inactive account from
-- an account that has not completed registration.  It is never visible to a
-- different user or to anonymous callers.
drop policy if exists auth_users_insert_own on public.usuarios;
drop policy if exists auth_users_select_own on public.usuarios;
create policy auth_users_select_own
on public.usuarios
for select
to authenticated
using (id = (select auth.uid()));

revoke insert on public.usuarios from anon, authenticated;
revoke all on public.usuarios from anon;
revoke all on public.empresas from anon;
revoke all on public.enderecos from anon;
revoke all on public.usuario_papeis from anon;

-- The client can only read its own company through the table.  Public company
-- discovery is exposed below through authenticated, field-limited functions.
revoke all on public.empresa_servicos from anon;
grant select, insert, update, delete on public.empresa_servicos to authenticated;
alter table public.empresa_servicos enable row level security;

drop policy if exists empresa_services_select_own_company on public.empresa_servicos;
create policy empresa_services_select_own_company
on public.empresa_servicos
for select
to authenticated
using (
  exists (
    select 1
    from public.usuarios u
    where u.id = (select auth.uid())
      and u.ativo is true
      and u.empresa_id = empresa_servicos.empresa_id
  )
);

drop policy if exists empresa_services_insert_admin on public.empresa_servicos;
create policy empresa_services_insert_admin
on public.empresa_servicos
for insert
to authenticated
with check (
  exists (
    select 1
    from public.usuarios u
    where u.id = (select auth.uid())
      and u.ativo is true
      and (u.is_admin_empresa is true or u.is_admin is true)
      and u.empresa_id = empresa_servicos.empresa_id
  )
);

drop policy if exists empresa_services_update_admin on public.empresa_servicos;
create policy empresa_services_update_admin
on public.empresa_servicos
for update
to authenticated
using (
  exists (
    select 1
    from public.usuarios u
    where u.id = (select auth.uid())
      and u.ativo is true
      and (u.is_admin_empresa is true or u.is_admin is true)
      and u.empresa_id = empresa_servicos.empresa_id
  )
)
with check (
  exists (
    select 1
    from public.usuarios u
    where u.id = (select auth.uid())
      and u.ativo is true
      and (u.is_admin_empresa is true or u.is_admin is true)
      and u.empresa_id = empresa_servicos.empresa_id
  )
);

drop policy if exists empresa_services_delete_admin on public.empresa_servicos;
create policy empresa_services_delete_admin
on public.empresa_servicos
for delete
to authenticated
using (
  exists (
    select 1
    from public.usuarios u
    where u.id = (select auth.uid())
      and u.ativo is true
      and (u.is_admin_empresa is true or u.is_admin is true)
      and u.empresa_id = empresa_servicos.empresa_id
  )
);

-- Gallery rows follow the service tenant.  Public service details use the
-- SECURITY DEFINER function below instead of exposing this table.
alter table public.empresa_servicos_galeria enable row level security;
revoke all on public.empresa_servicos_galeria from anon;
grant select, insert, update, delete on public.empresa_servicos_galeria to authenticated;

drop policy if exists empresa_service_gallery_select_own_company on public.empresa_servicos_galeria;
create policy empresa_service_gallery_select_own_company
on public.empresa_servicos_galeria
for select
to authenticated
using (
  exists (
    select 1
    from public.empresa_servicos s
    join public.usuarios u on u.empresa_id = s.empresa_id
    where s.id = empresa_servicos_galeria.servico_id
      and u.id = (select auth.uid())
      and u.ativo is true
  )
);

drop policy if exists empresa_service_gallery_write_admin on public.empresa_servicos_galeria;
create policy empresa_service_gallery_write_admin
on public.empresa_servicos_galeria
for all
to authenticated
using (
  exists (
    select 1
    from public.empresa_servicos s
    join public.usuarios u on u.empresa_id = s.empresa_id
    where s.id = empresa_servicos_galeria.servico_id
      and u.id = (select auth.uid())
      and u.ativo is true
      and (u.is_admin_empresa is true or u.is_admin is true)
  )
)
with check (
  exists (
    select 1
    from public.empresa_servicos s
    join public.usuarios u on u.empresa_id = s.empresa_id
    where s.id = empresa_servicos_galeria.servico_id
      and u.id = (select auth.uid())
      and u.ativo is true
      and (u.is_admin_empresa is true or u.is_admin is true)
  )
);

create index if not exists empresa_servicos_active_company_idx
  on public.empresa_servicos (empresa_id, criado_em desc);
create index if not exists empresas_active_ramo_idx
  on public.empresas (ativo, ramo_atuacao, nome);

-- The function is callable only by the auth-operations service role.  The
-- function still verifies the canonical Auth e-mail and confirmation state so
-- a client cannot complete a registration for another account.
create or replace function public.complete_self_registration(
  p_user_id uuid,
  p_email text,
  p_profile_type text,
  p_profile jsonb,
  p_address jsonb,
  p_company jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog, auth
as $$
declare
  v_auth_email text;
  v_confirmed_at timestamptz;
  v_existing_empresa_id uuid;
  v_existing_endereco_id uuid;
  v_existing_ativo boolean;
  v_existing_convite boolean;
  v_endereco_id uuid;
  v_empresa_id uuid;
  v_plan_id uuid;
  v_type text;
  v_nome text;
  v_sobrenome text;
  v_celular text;
  v_perfil text;
  v_escolaridade text;
  v_titulo text;
  v_foto_url text;
  v_cnpj text;
  v_digits text;
begin
  if p_user_id is null or p_email is null or p_profile_type is null
     or p_profile is null or p_address is null then
    raise exception using errcode = '22023', message = 'Dados de cadastro inválidos.';
  end if;

  select lower(u.email), u.email_confirmed_at
  into v_auth_email, v_confirmed_at
  from auth.users u
  where u.id = p_user_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'Usuário Auth não encontrado.';
  end if;
  if v_auth_email is distinct from lower(btrim(p_email)) then
    raise exception using errcode = '42501', message = 'O e-mail da sessão não corresponde ao cadastro.';
  end if;
  if v_confirmed_at is null then
    raise exception using errcode = '42501', message = 'Confirme o e-mail antes de concluir o cadastro.';
  end if;

  v_type := lower(btrim(p_profile_type));
  if v_type not in ('academico', 'academic', 'empresa', 'company') then
    raise exception using errcode = '22023', message = 'Tipo de perfil inválido.';
  end if;

  -- A retry for the same account is safe and does not create a second address,
  -- company or profile.
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));
  select u.empresa_id, u.endereco_id, u.ativo, u.convite_pendente
  into v_existing_empresa_id, v_existing_endereco_id, v_existing_ativo, v_existing_convite
  from public.usuarios u
  where u.id = p_user_id
  for update;

  if v_existing_convite is true or v_existing_empresa_id is not null then
    if v_type in ('empresa', 'company') and v_existing_empresa_id is not null then
      return jsonb_build_object('status', 'active', 'user_id', p_user_id, 'empresa_id', v_existing_empresa_id);
    end if;
    raise exception using errcode = '23505', message = 'Este perfil já está vinculado a uma empresa ou convite.';
  end if;

  v_nome := nullif(btrim(p_profile ->> 'nome'), '');
  v_sobrenome := nullif(btrim(p_profile ->> 'sobrenome'), '');
  v_celular := nullif(btrim(coalesce(p_profile ->> 'celular', p_profile ->> 'telefone')), '');
  v_perfil := nullif(btrim(p_profile ->> 'perfil'), '');
  v_escolaridade := nullif(btrim(p_profile ->> 'escolaridade'), '');
  v_titulo := nullif(btrim(coalesce(p_profile ->> 'titulo_principal', p_profile ->> 'formacao')), '');
  v_foto_url := nullif(btrim(p_profile ->> 'foto_url'), '');
  if v_nome is null or v_sobrenome is null then
    raise exception using errcode = '22023', message = 'Nome e sobrenome são obrigatórios.';
  end if;

  if v_existing_endereco_id is null then
    insert into public.enderecos (
      endereco, cidade, estado, cep, bairro, numero, complemento, pais
    ) values (
      nullif(btrim(p_address ->> 'endereco'), ''),
      nullif(btrim(p_address ->> 'cidade'), ''),
      nullif(btrim(p_address ->> 'estado'), ''),
      nullif(btrim(p_address ->> 'cep'), ''),
      nullif(btrim(p_address ->> 'bairro'), ''),
      nullif(btrim(p_address ->> 'numero'), ''),
      nullif(btrim(p_address ->> 'complemento'), ''),
      coalesce(nullif(btrim(p_address ->> 'pais'), ''), 'Brasil')
    ) returning id into v_endereco_id;
  else
    v_endereco_id := v_existing_endereco_id;
    update public.enderecos
    set endereco = nullif(btrim(p_address ->> 'endereco'), ''),
        cidade = nullif(btrim(p_address ->> 'cidade'), ''),
        estado = nullif(btrim(p_address ->> 'estado'), ''),
        cep = nullif(btrim(p_address ->> 'cep'), ''),
        bairro = nullif(btrim(p_address ->> 'bairro'), ''),
        numero = nullif(btrim(p_address ->> 'numero'), ''),
        complemento = nullif(btrim(p_address ->> 'complemento'), ''),
        pais = coalesce(nullif(btrim(p_address ->> 'pais'), ''), 'Brasil')
    where id = v_endereco_id;
  end if;

  if v_type in ('academico', 'academic') then
    if exists (select 1 from public.usuarios where id = p_user_id) then
      update public.usuarios
      set nome = v_nome,
          sobrenome = v_sobrenome,
          email = v_auth_email,
          celular = v_celular,
          perfil = coalesce(v_perfil, 'academico'),
          escolaridade = v_escolaridade,
          titulo_principal = v_titulo,
          foto_url = coalesce(v_foto_url, foto_url),
          endereco_id = v_endereco_id,
          ativo = true,
          convite_pendente = false,
          is_admin_empresa = false,
          is_admin = false
      where id = p_user_id;
    else
      insert into public.usuarios (
        id, nome, sobrenome, email, celular, perfil, escolaridade,
        titulo_principal, foto_url, endereco_id, ativo, convite_pendente,
        is_admin_empresa, is_admin
      ) values (
        p_user_id, v_nome, v_sobrenome, v_auth_email, v_celular,
        coalesce(v_perfil, 'academico'), v_escolaridade, v_titulo,
        v_foto_url, v_endereco_id, true, false, false, false
      );
    end if;
    return jsonb_build_object('status', 'active', 'user_id', p_user_id, 'empresa_id', null);
  end if;

  if p_company is null then
    raise exception using errcode = '22023', message = 'Dados da empresa são obrigatórios.';
  end if;
  if nullif(btrim(p_company ->> 'nome'), '') is null
     or nullif(btrim(p_company ->> 'cnpj'), '') is null then
    raise exception using errcode = '22023', message = 'Nome e CNPJ da empresa são obrigatórios.';
  end if;

  v_digits := regexp_replace(p_company ->> 'cnpj', '[^0-9]', '', 'g');
  if length(v_digits) <> 14 or v_digits ~ '^(.)\1{13}$' then
    raise exception using errcode = '22023', message = 'CNPJ inválido.';
  end if;
  v_cnpj := substr(v_digits, 1, 2) || '.' || substr(v_digits, 3, 3) || '.' ||
            substr(v_digits, 6, 3) || '/' || substr(v_digits, 9, 4) || '-' || substr(v_digits, 13, 2);

  select id into v_plan_id from public.planos where is_default is true;
  if v_plan_id is null then
    raise exception using errcode = 'P0001', message = 'Plano padrão não configurado.';
  end if;

  insert into public.empresas (
    nome, cnpj, descricao, tipo, ativo, endereco_id, plano_id, tamanho,
    foto_url, site, linkedin, instagram, email_contato, whatsapp, youtube,
    ramo_atuacao, foto_capa, sobre
  ) values (
    nullif(btrim(p_company ->> 'nome'), ''),
    v_cnpj,
    nullif(btrim(p_company ->> 'descricao'), ''),
    coalesce(nullif(btrim(p_company ->> 'tipo'), ''), 'Profissional'),
    true,
    v_endereco_id,
    v_plan_id,
    nullif(btrim(coalesce(p_company ->> 'tamanho', p_company ->> 'colaboradores')), ''),
    nullif(btrim(p_company ->> 'foto_url'), ''),
    nullif(btrim(p_company ->> 'site'), ''),
    nullif(btrim(p_company ->> 'linkedin'), ''),
    nullif(btrim(p_company ->> 'instagram'), ''),
    nullif(btrim(p_company ->> 'email_contato'), ''),
    nullif(btrim(p_company ->> 'whatsapp'), ''),
    nullif(btrim(p_company ->> 'youtube'), ''),
    nullif(btrim(p_company ->> 'ramo_atuacao'), ''),
    nullif(btrim(p_company ->> 'foto_capa'), ''),
    nullif(btrim(p_company ->> 'sobre'), '')
  ) returning id into v_empresa_id;

  if exists (select 1 from public.usuarios where id = p_user_id) then
    update public.usuarios
    set nome = v_nome,
        sobrenome = v_sobrenome,
        email = v_auth_email,
        celular = v_celular,
        perfil = coalesce(v_perfil, 'empresa'),
        escolaridade = v_escolaridade,
        titulo_principal = v_titulo,
        foto_url = coalesce(v_foto_url, foto_url),
        endereco_id = v_endereco_id,
        empresa_id = v_empresa_id,
        ativo = true,
        convite_pendente = false,
        is_admin_empresa = true,
        is_admin = false,
        cargo = coalesce(nullif(btrim(p_profile ->> 'cargo'), ''), cargo)
    where id = p_user_id;
  else
    insert into public.usuarios (
      id, nome, sobrenome, email, celular, perfil, escolaridade,
      titulo_principal, foto_url, endereco_id, empresa_id, ativo,
      convite_pendente, is_admin_empresa, is_admin, cargo
    ) values (
      p_user_id, v_nome, v_sobrenome, v_auth_email, v_celular,
      coalesce(v_perfil, 'empresa'), v_escolaridade, v_titulo, v_foto_url,
      v_endereco_id, v_empresa_id, true, false, true, false,
      nullif(btrim(p_profile ->> 'cargo'), '')
    );
  end if;

  return jsonb_build_object('status', 'active', 'user_id', p_user_id, 'empresa_id', v_empresa_id);
end;
$$;

revoke all on function public.complete_self_registration(uuid, text, text, jsonb, jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.complete_self_registration(uuid, text, text, jsonb, jsonb, jsonb)
  to service_role;

-- Authenticated users can discover only the public fields returned by these
-- functions.  A user must have an active profile; anonymous callers have no
-- EXECUTE privilege.
create or replace function public.list_public_companies(
  p_search text default null,
  p_ramo text default null,
  p_limit integer default 30,
  p_offset integer default 0
)
returns table (
  empresa_id uuid,
  nome text,
  descricao text,
  foto_url text,
  foto_capa text,
  ramo_atuacao text,
  cidade text,
  estado text,
  qtd_servicos bigint
)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_actor_id uuid := (select auth.uid());
  v_cidade text;
  v_estado text;
  v_limit integer := least(greatest(coalesce(p_limit, 30), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_search text := nullif(btrim(p_search), '');
  v_ramo text := nullif(btrim(p_ramo), '');
begin
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'Autenticação obrigatória.';
  end if;
  select e.cidade, e.estado into v_cidade, v_estado
  from public.usuarios u
  left join public.enderecos e on e.id = u.endereco_id
  where u.id = v_actor_id and u.ativo is true;
  if not found then
    raise exception using errcode = '42501', message = 'Usuário ativo é obrigatório.';
  end if;

  return query
  select e.id, e.nome, e.descricao, e.foto_url, e.foto_capa, e.ramo_atuacao,
         a.cidade, a.estado, count(s.id)::bigint
  from public.empresas e
  left join public.enderecos a on a.id = e.endereco_id
  left join public.empresa_servicos s on s.empresa_id = e.id
  where e.ativo is true
    and (v_search is null or e.nome ilike '%' || v_search || '%')
    and (v_ramo is null or v_ramo = 'Todos' or e.ramo_atuacao = v_ramo)
  group by e.id, e.nome, e.descricao, e.foto_url, e.foto_capa, e.ramo_atuacao,
           a.cidade, a.estado
  order by case when lower(coalesce(a.cidade, '')) = lower(coalesce(v_cidade, ''))
                     and lower(coalesce(a.estado, '')) = lower(coalesce(v_estado, '')) then 0
                when lower(coalesce(a.estado, '')) = lower(coalesce(v_estado, '')) then 1
                else 2 end,
           lower(coalesce(e.nome, '')), e.id
  limit v_limit offset v_offset;
end;
$$;

create or replace function public.get_public_company(p_empresa_id uuid)
returns table (
  empresa_id uuid,
  nome text,
  cnpj text,
  descricao text,
  sobre text,
  foto_url text,
  foto_capa text,
  cidade text,
  estado text,
  linkedin text,
  instagram text,
  youtube text,
  site text,
  email_contato text,
  whatsapp text,
  ramo_atuacao text,
  qtd_servicos bigint
)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_actor_id uuid := (select auth.uid());
begin
  if v_actor_id is null or not exists (
    select 1 from public.usuarios where id = v_actor_id and ativo is true
  ) then
    raise exception using errcode = '42501', message = 'Usuário ativo é obrigatório.';
  end if;
  return query
  select e.id, e.nome, e.cnpj, e.descricao, e.sobre, e.foto_url, e.foto_capa,
         a.cidade, a.estado, e.linkedin, e.instagram, e.youtube, e.site,
         e.email_contato, e.whatsapp, e.ramo_atuacao, count(s.id)::bigint
  from public.empresas e
  left join public.enderecos a on a.id = e.endereco_id
  left join public.empresa_servicos s on s.empresa_id = e.id
  where e.id = p_empresa_id and e.ativo is true
  group by e.id, e.nome, e.cnpj, e.descricao, e.sobre, e.foto_url, e.foto_capa,
           a.cidade, a.estado, e.linkedin, e.instagram, e.youtube, e.site,
           e.email_contato, e.whatsapp, e.ramo_atuacao;
end;
$$;

create or replace function public.list_public_company_services(
  p_empresa_id uuid default null,
  p_search text default null,
  p_categoria text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  servico_id uuid,
  empresa_id uuid,
  nome text,
  objetivo text,
  foto_principal text,
  categoria text,
  link_anexo text,
  nome_anexo text,
  descricao text,
  empresa_nome text,
  empresa_foto_url text,
  cidade text,
  estado text
)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_actor_id uuid := (select auth.uid());
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_search text := nullif(btrim(p_search), '');
  v_categoria text := nullif(btrim(p_categoria), '');
begin
  if v_actor_id is null or not exists (
    select 1 from public.usuarios where id = v_actor_id and ativo is true
  ) then
    raise exception using errcode = '42501', message = 'Usuário ativo é obrigatório.';
  end if;
  return query
  select s.id, s.empresa_id, s.nome, s.objetivo, s.foto_principal, s.categoria,
         s.link_anexo, s.nome_anexo, s.descricao, e.nome, e.foto_url,
         a.cidade, a.estado
  from public.empresa_servicos s
  join public.empresas e on e.id = s.empresa_id and e.ativo is true
  left join public.enderecos a on a.id = e.endereco_id
  where (p_empresa_id is null or s.empresa_id = p_empresa_id)
    and (v_search is null or s.nome ilike '%' || v_search || '%')
    and (v_categoria is null or v_categoria = 'Todos' or s.categoria = v_categoria)
  order by lower(coalesce(s.nome, '')), s.id
  limit v_limit offset v_offset;
end;
$$;

create or replace function public.list_public_service_gallery(p_servico_id uuid)
returns table (id uuid, servico_id uuid, foto_url text)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_actor_id uuid := (select auth.uid());
begin
  if v_actor_id is null or not exists (
    select 1 from public.usuarios where id = v_actor_id and ativo is true
  ) then
    raise exception using errcode = '42501', message = 'Usuário ativo é obrigatório.';
  end if;
  return query
  select g.id, g.servico_id, g.foto_url
  from public.empresa_servicos_galeria g
  join public.empresa_servicos s on s.id = g.servico_id
  join public.empresas e on e.id = s.empresa_id and e.ativo is true
  where g.servico_id = p_servico_id
  order by g.criado_em asc, g.id;
end;
$$;

revoke all on function public.list_public_companies(text, text, integer, integer)
  from public, anon, authenticated;
revoke all on function public.get_public_company(uuid)
  from public, anon, authenticated;
revoke all on function public.list_public_company_services(uuid, text, text, integer, integer)
  from public, anon, authenticated;
revoke all on function public.list_public_service_gallery(uuid)
  from public, anon, authenticated;
grant execute on function public.list_public_companies(text, text, integer, integer) to authenticated;
grant execute on function public.get_public_company(uuid) to authenticated;
grant execute on function public.list_public_company_services(uuid, text, text, integer, integer) to authenticated;
grant execute on function public.list_public_service_gallery(uuid) to authenticated;

commit;
