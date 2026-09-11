-- DIAVICON - Home/Projetos security boundary
--
-- Assumptions validated by the preflight block below:
--   * primary/business identifiers are UUIDs;
--   * projeto_empresas_colaboradoras is the canonical company invitation table;
--   * accepted company links use status = 'aceito';
--   * project/client/team/notification columns match the current Flutter repositories.
--
-- This migration deliberately does not drop policies it does not own. Each allowed
-- operation receives both a narrow PERMISSIVE policy and an equivalent RESTRICTIVE
-- guard. The restrictive guard prevents a legacy permissive policy from widening
-- access. Operations moved to RPCs receive a restrictive false guard.

begin;

-- -----------------------------------------------------------------------------
-- 1. Fail closed when the remote schema differs from the version used by the app.
-- -----------------------------------------------------------------------------

do $preflight$
declare
  v_missing text;
  v_wrong_types text;
begin
  with required_columns(schema_name, table_name, column_name) as (
    values
      ('public', 'usuarios', 'id'),
      ('public', 'usuarios', 'empresa_id'),
      ('public', 'usuarios', 'ativo'),
      ('public', 'usuarios', 'is_admin_empresa'),
      ('public', 'usuarios', 'nome'),
      ('public', 'usuarios', 'sobrenome'),
      ('public', 'empresas', 'id'),
      ('public', 'empresas', 'nome'),
      ('public', 'projetos', 'id'),
      ('public', 'projetos', 'nome'),
      ('public', 'projetos', 'descricao'),
      ('public', 'projetos', 'empresa_gestora_id'),
      ('public', 'projetos', 'empresa_cliente_id'),
      ('public', 'projetos', 'status_vinculo_cliente'),
      ('public', 'projetos', 'status_id'),
      ('public', 'projetos', 'prioridade_id'),
      ('public', 'projetos', 'progresso'),
      ('public', 'projetos', 'image_url'),
      ('public', 'projetos', 'criado_por'),
      ('public', 'status_projeto', 'id'),
      ('public', 'status_projeto', 'nome'),
      ('public', 'prioridade', 'id'),
      ('public', 'prioridade', 'nome'),
      ('public', 'projeto_equipe_interna', 'projeto_id'),
      ('public', 'projeto_equipe_interna', 'usuario_id'),
      ('public', 'projeto_equipe_interna', 'empresa_id'),
      ('public', 'projeto_equipe_interna', 'ativo'),
      ('public', 'projeto_equipe_interna', 'is_gestor'),
      ('public', 'projeto_empresas_colaboradoras', 'id'),
      ('public', 'projeto_empresas_colaboradoras', 'projeto_id'),
      ('public', 'projeto_empresas_colaboradoras', 'empresa_id'),
      ('public', 'projeto_empresas_colaboradoras', 'criado_por'),
      ('public', 'projeto_empresas_colaboradoras', 'status'),
      ('public', 'projeto_convites_cliente', 'projeto_id'),
      ('public', 'projeto_convites_cliente', 'email_convidado'),
      ('public', 'projeto_convites_cliente', 'empresa_nome_temp'),
      ('public', 'projeto_convites_cliente', 'criado_por'),
      ('public', 'projeto_convites_cliente', 'aceito'),
      ('public', 'projeto_convites_cliente', 'foto_url'),
      ('public', 'empresa_clientes', 'gestora_id'),
      ('public', 'empresa_clientes', 'cliente_id'),
      ('public', 'empresa_clientes', 'status_vinculo'),
      ('public', 'notificacoes', 'id'),
      ('public', 'notificacoes', 'usuario_id'),
      ('public', 'notificacoes', 'titulo'),
      ('public', 'notificacoes', 'mensagem'),
      ('public', 'notificacoes', 'tipo'),
      ('public', 'notificacoes', 'lida'),
      ('public', 'notificacoes', 'dados_extras'),
      ('storage', 'objects', 'bucket_id'),
      ('storage', 'objects', 'name')
  )
  select string_agg(format('%I.%I.%I', r.schema_name, r.table_name, r.column_name), ', ')
    into v_missing
  from required_columns r
  left join information_schema.columns c
    on c.table_schema = r.schema_name
   and c.table_name = r.table_name
   and c.column_name = r.column_name
  where c.column_name is null;

  if v_missing is not null then
    raise exception using
      errcode = 'P0001',
      message = 'DIAVICON RLS preflight failed. Missing columns: ' || v_missing,
      hint = 'Run supabase/audit_home_projects_rls.sql and reconcile the remote schema before applying this migration.';
  end if;

  with required_uuid_columns(schema_name, table_name, column_name) as (
    values
      ('public', 'usuarios', 'id'),
      ('public', 'usuarios', 'empresa_id'),
      ('public', 'empresas', 'id'),
      ('public', 'projetos', 'id'),
      ('public', 'projetos', 'empresa_gestora_id'),
      ('public', 'projetos', 'empresa_cliente_id'),
      ('public', 'projetos', 'criado_por'),
      ('public', 'projeto_equipe_interna', 'projeto_id'),
      ('public', 'projeto_equipe_interna', 'usuario_id'),
      ('public', 'projeto_equipe_interna', 'empresa_id'),
      ('public', 'projeto_empresas_colaboradoras', 'id'),
      ('public', 'projeto_empresas_colaboradoras', 'projeto_id'),
      ('public', 'projeto_empresas_colaboradoras', 'empresa_id'),
      ('public', 'projeto_empresas_colaboradoras', 'criado_por'),
      ('public', 'projeto_convites_cliente', 'projeto_id'),
      ('public', 'projeto_convites_cliente', 'criado_por'),
      ('public', 'empresa_clientes', 'gestora_id'),
      ('public', 'empresa_clientes', 'cliente_id'),
      ('public', 'notificacoes', 'id'),
      ('public', 'notificacoes', 'usuario_id')
  )
  select string_agg(
           format('%I.%I.%I (found %s)', r.schema_name, r.table_name, r.column_name, c.udt_name),
           ', '
         )
    into v_wrong_types
  from required_uuid_columns r
  join information_schema.columns c
    on c.table_schema = r.schema_name
   and c.table_name = r.table_name
   and c.column_name = r.column_name
  where c.udt_name <> 'uuid';

  if v_wrong_types is not null then
    raise exception using
      errcode = '42804',
      message = 'DIAVICON RLS preflight failed. Expected UUID columns: ' || v_wrong_types,
      hint = 'Adjust the RPC signatures only after confirming the real remote schema.';
  end if;

  if exists (
    select 1
    from public.projeto_equipe_interna
    group by projeto_id, usuario_id
    having count(*) > 1
  ) then
    raise exception using
      errcode = '23505',
      message = 'DIAVICON RLS preflight failed: duplicate (projeto_id, usuario_id) rows in projeto_equipe_interna.';
  end if;

  if exists (
    select 1
    from public.projeto_empresas_colaboradoras
    group by projeto_id, empresa_id
    having count(*) > 1
  ) then
    raise exception using
      errcode = '23505',
      message = 'DIAVICON RLS preflight failed: duplicate (projeto_id, empresa_id) rows in projeto_empresas_colaboradoras.';
  end if;

  if exists (
    select 1
    from public.empresa_clientes
    group by gestora_id, cliente_id
    having count(*) > 1
  ) then
    raise exception using
      errcode = '23505',
      message = 'DIAVICON RLS preflight failed: duplicate (gestora_id, cliente_id) rows in empresa_clientes.';
  end if;

  if exists (
    select 1
    from public.status_projeto
    group by lower(btrim(nome))
    having count(*) > 1
  ) then
    raise exception using
      errcode = '23505',
      message = 'DIAVICON RLS preflight failed: duplicate case-insensitive names in status_projeto.';
  end if;

  if exists (
    select 1
    from public.prioridade
    group by lower(btrim(nome))
    having count(*) > 1
  ) then
    raise exception using
      errcode = '23505',
      message = 'DIAVICON RLS preflight failed: duplicate case-insensitive names in prioridade.';
  end if;

  if exists (
    select 1
    from public.projeto_empresas_colaboradoras
    where status is null or status not in ('pendente', 'aceito', 'recusado', 'removida')
  ) then
    raise exception using
      errcode = '23514',
      message = 'DIAVICON RLS preflight failed: unsupported status in projeto_empresas_colaboradoras.',
      hint = 'Normalize status values to pendente, aceito, recusado or removida before applying.';
  end if;

  if exists (
    select 1
    from public.projeto_equipe_interna pei
    left join public.usuarios u on u.id = pei.usuario_id
    where u.id is null or u.empresa_id is distinct from pei.empresa_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'DIAVICON RLS preflight failed: project team rows disagree with usuarios.empresa_id.';
  end if;
end
$preflight$;

create unique index if not exists dv_projeto_equipe_project_user_uidx
  on public.projeto_equipe_interna (projeto_id, usuario_id);

create unique index if not exists dv_projeto_empresa_project_company_uidx
  on public.projeto_empresas_colaboradoras (projeto_id, empresa_id);

create unique index if not exists dv_empresa_clientes_manager_client_uidx
  on public.empresa_clientes (gestora_id, cliente_id);

create index if not exists dv_projeto_equipe_user_active_idx
  on public.projeto_equipe_interna (usuario_id, projeto_id)
  where ativo is true;

create index if not exists dv_projeto_empresa_company_status_idx
  on public.projeto_empresas_colaboradoras (empresa_id, projeto_id, status);

create index if not exists dv_projects_manager_idx
  on public.projetos (empresa_gestora_id);

create index if not exists dv_projects_client_idx
  on public.projetos (empresa_cliente_id)
  where empresa_cliente_id is not null;

create index if not exists dv_notifications_user_unread_idx
  on public.notificacoes (usuario_id, lida);

do $constraint$
begin
  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'dv_projeto_empresa_status_check'
      and conrelid = 'public.projeto_empresas_colaboradoras'::regclass
  ) then
    alter table public.projeto_empresas_colaboradoras
      add constraint dv_projeto_empresa_status_check
      check (
        status is not null
        and status in ('pendente', 'aceito', 'recusado', 'removida')
      );
  end if;
end
$constraint$;

-- -----------------------------------------------------------------------------
-- 2. RLS helper functions. All relation names are schema-qualified and the
--    search_path is empty to avoid object-shadowing attacks.
-- -----------------------------------------------------------------------------

create schema if not exists app_private;
revoke all on schema app_private from public, anon, authenticated;
grant usage on schema app_private to authenticated;

create or replace function app_private.current_company_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $function$
  select u.empresa_id
  from public.usuarios u
  where u.id = auth.uid()
    and u.ativo is true
  limit 1
$function$;

create or replace function app_private.is_company_admin(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select coalesce(
    exists (
      select 1
      from public.usuarios u
      where u.id = auth.uid()
        and u.empresa_id = p_company_id
        and u.ativo is true
        and u.is_admin_empresa is true
    ),
    false
  )
$function$;

create or replace function app_private.is_company_admin_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select coalesce(
    exists (
      select 1
      from public.usuarios u
      where u.id = p_user_id
        and u.ativo is true
        and u.is_admin_empresa is true
    ),
    false
  )
$function$;

create or replace function app_private.has_project_access(p_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  with me as (
    select u.id, u.empresa_id, u.is_admin_empresa
    from public.usuarios u
    where u.id = auth.uid()
      and u.ativo is true
      and u.empresa_id is not null
  )
  select coalesce(
    exists (
      select 1
      from public.projetos p
      cross join me
      where p.id = p_project_id
        and (
          exists (
            select 1
            from public.projeto_equipe_interna pei
            where pei.projeto_id = p.id
              and pei.usuario_id = me.id
              and pei.empresa_id = me.empresa_id
              and pei.ativo is true
          )
          or (
            me.is_admin_empresa is true
            and (
              p.empresa_gestora_id = me.empresa_id
              or (
                p.empresa_cliente_id = me.empresa_id
                and p.status_vinculo_cliente = 'ativo'
              )
              or exists (
                select 1
                from public.projeto_empresas_colaboradoras pec
                where pec.projeto_id = p.id
                  and pec.empresa_id = me.empresa_id
                  and pec.status = 'aceito'
              )
            )
          )
        )
    ),
    false
  )
$function$;

create or replace function app_private.can_edit_project(p_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  with me as (
    select u.id, u.empresa_id, u.is_admin_empresa
    from public.usuarios u
    where u.id = auth.uid()
      and u.ativo is true
      and u.empresa_id is not null
  )
  select coalesce(
    exists (
      select 1
      from public.projetos p
      cross join me
      where p.id = p_project_id
        and p.empresa_gestora_id = me.empresa_id
        and (
          me.is_admin_empresa is true
          or exists (
            select 1
            from public.projeto_equipe_interna pei
            where pei.projeto_id = p.id
              and pei.usuario_id = me.id
              and pei.empresa_id = me.empresa_id
              and pei.ativo is true
          )
        )
    ),
    false
  )
$function$;

create or replace function app_private.can_manage_project(p_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  with me as (
    select u.id, u.empresa_id, u.is_admin_empresa
    from public.usuarios u
    where u.id = auth.uid()
      and u.ativo is true
      and u.empresa_id is not null
  )
  select coalesce(
    exists (
      select 1
      from public.projetos p
      cross join me
      where p.id = p_project_id
        and p.empresa_gestora_id = me.empresa_id
        and (
          me.is_admin_empresa is true
          or exists (
            select 1
            from public.projeto_equipe_interna pei
            where pei.projeto_id = p.id
              and pei.usuario_id = me.id
              and pei.empresa_id = me.empresa_id
              and pei.ativo is true
              and pei.is_gestor is true
          )
        )
    ),
    false
  )
$function$;

create or replace function app_private.can_manage_company_team(
  p_project_id uuid,
  p_company_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  with me as (
    select u.id, u.empresa_id, u.is_admin_empresa
    from public.usuarios u
    where u.id = auth.uid()
      and u.ativo is true
      and u.empresa_id is not null
  )
  select coalesce(
    exists (
      select 1
      from me
      where me.empresa_id = p_company_id
        and app_private.has_project_access(p_project_id)
        and (
          me.is_admin_empresa is true
          or exists (
            select 1
            from public.projeto_equipe_interna pei
            where pei.projeto_id = p_project_id
              and pei.usuario_id = me.id
              and pei.empresa_id = me.empresa_id
              and pei.ativo is true
              and pei.is_gestor is true
          )
        )
    ),
    false
  )
$function$;

create or replace function app_private.is_valid_team_member(
  p_user_id uuid,
  p_company_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select coalesce(
    exists (
      select 1
      from public.usuarios u
      where u.id = p_user_id
        and u.empresa_id = p_company_id
        and u.ativo is true
    ),
    false
  )
$function$;

revoke all on function app_private.current_company_id() from public, anon;
revoke all on function app_private.is_company_admin(uuid) from public, anon;
revoke all on function app_private.is_company_admin_user(uuid) from public, anon;
revoke all on function app_private.has_project_access(uuid) from public, anon;
revoke all on function app_private.can_edit_project(uuid) from public, anon;
revoke all on function app_private.can_manage_project(uuid) from public, anon;
revoke all on function app_private.can_manage_company_team(uuid, uuid) from public, anon;
revoke all on function app_private.is_valid_team_member(uuid, uuid) from public, anon;

grant execute on function app_private.current_company_id() to authenticated;
grant execute on function app_private.is_company_admin(uuid) to authenticated;
grant execute on function app_private.is_company_admin_user(uuid) to authenticated;
grant execute on function app_private.has_project_access(uuid) to authenticated;
grant execute on function app_private.can_edit_project(uuid) to authenticated;
grant execute on function app_private.can_manage_project(uuid) to authenticated;
grant execute on function app_private.can_manage_company_team(uuid, uuid) to authenticated;
grant execute on function app_private.is_valid_team_member(uuid, uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Atomic RPCs used by the Flutter repositories.
-- -----------------------------------------------------------------------------

create or replace function public.create_project(
  p_name text,
  p_client_company_id uuid default null,
  p_new_client_email text default null,
  p_new_client_name text default null,
  p_image_url text default null,
  p_new_client_image_url text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_actor_company_id uuid;
  v_actor_name text;
  v_manager_company_name text;
  v_project_id uuid;
  v_has_existing_client boolean := p_client_company_id is not null;
  v_has_new_client boolean :=
    nullif(btrim(p_new_client_email), '') is not null
    or nullif(btrim(p_new_client_name), '') is not null
    or nullif(btrim(p_new_client_image_url), '') is not null;
  v_email text := lower(nullif(btrim(p_new_client_email), ''));
  v_client_name text := nullif(btrim(p_new_client_name), '');
  v_storage_origin text := pg_catalog.regexp_replace(
    auth.jwt() ->> 'iss',
    '/auth/v1/?$',
    ''
  );
  v_project_image_prefix text := 'users/' || v_actor_id::text || '/capas/';
  v_client_image_prefix text := 'users/' || v_actor_id::text || '/clientes/';
  v_project_image_path text := nullif(btrim(p_image_url), '');
  v_client_image_path text := nullif(btrim(p_new_client_image_url), '');
  v_project_image_url text;
  v_client_image_url text;
  v_image_filename text;
begin
  if v_actor_id is null then
    raise exception using errcode = '28000', message = 'Authentication required.';
  end if;

  select
    u.empresa_id,
    nullif(btrim(pg_catalog.concat_ws(' ', u.nome, u.sobrenome)), ''),
    e.nome
    into v_actor_company_id, v_actor_name, v_manager_company_name
  from public.usuarios u
  join public.empresas e on e.id = u.empresa_id
  where u.id = v_actor_id
    and u.ativo is true;

  if v_actor_company_id is null then
    raise exception using errcode = '42501', message = 'Active user with a company is required.';
  end if;

  if nullif(btrim(p_name), '') is null or char_length(btrim(p_name)) > 160 then
    raise exception using errcode = '22023', message = 'Project name must contain between 1 and 160 characters.';
  end if;

  if v_has_existing_client = v_has_new_client then
    raise exception using
      errcode = '22023',
      message = 'Provide exactly one client mode: p_client_company_id or new-client fields.';
  end if;

  if v_has_new_client then
    if v_email is null or v_client_name is null then
      raise exception using errcode = '22023', message = 'New client email and name are required.';
    end if;
    if char_length(v_email) > 320
       or v_email !~* '^[A-Z0-9.!#$%&''*+/=?^_`{|}~-]+@[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?(?:\.[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?)+$' then
      raise exception using errcode = '22023', message = 'Invalid new client email.';
    end if;
    if char_length(v_client_name) > 160 then
      raise exception using errcode = '22023', message = 'New client name is too long.';
    end if;
  else
    if not exists (
      select 1 from public.empresas e where e.id = p_client_company_id
    ) then
      raise exception using errcode = '23503', message = 'Client company does not exist.';
    end if;

    if p_client_company_id <> v_actor_company_id
       and not exists (
         select 1
         from public.usuarios u
         where u.empresa_id = p_client_company_id
           and u.ativo is true
           and u.is_admin_empresa is true
       ) then
      raise exception using
        errcode = '23514',
        message = 'Client company has no active administrator to receive the invitation.';
    end if;
  end if;

  if v_project_image_path is not null then
    if v_storage_origin is null
       or char_length(v_project_image_path) > 512
       or left(v_project_image_path, char_length(v_project_image_prefix)) <> v_project_image_prefix then
      raise exception using errcode = '22023', message = 'Project image must belong to the authenticated user project path.';
    end if;

    v_image_filename := substring(
      v_project_image_path
      from char_length(v_project_image_prefix) + 1
    );
    if v_image_filename !~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,254}$'
       or not exists (
         select 1
         from storage.objects o
         where o.bucket_id = 'projetos'
           and o.name = v_project_image_path
       ) then
      raise exception using errcode = '22023', message = 'Project image object does not exist in the authenticated user path.';
    end if;

    v_project_image_url :=
      v_storage_origin || '/storage/v1/object/public/projetos/' || v_project_image_path;
  end if;

  if v_client_image_path is not null then
    if v_storage_origin is null
       or char_length(v_client_image_path) > 512
       or left(v_client_image_path, char_length(v_client_image_prefix)) <> v_client_image_prefix then
      raise exception using errcode = '22023', message = 'Client image must belong to the authenticated user client path.';
    end if;

    v_image_filename := substring(
      v_client_image_path
      from char_length(v_client_image_prefix) + 1
    );
    if v_image_filename !~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,254}$'
       or not exists (
         select 1
         from storage.objects o
         where o.bucket_id = 'projetos'
           and o.name = v_client_image_path
       ) then
      raise exception using errcode = '22023', message = 'Client image object does not exist in the authenticated user path.';
    end if;

    v_client_image_url :=
      v_storage_origin || '/storage/v1/object/public/projetos/' || v_client_image_path;
  end if;

  if v_has_existing_client and p_client_company_id <> v_actor_company_id then
    insert into public.empresa_clientes (gestora_id, cliente_id, status_vinculo)
    values (v_actor_company_id, p_client_company_id, 'pendente')
    on conflict (gestora_id, cliente_id)
    do update set status_vinculo = excluded.status_vinculo;
  end if;

  insert into public.projetos (
    nome,
    empresa_gestora_id,
    empresa_cliente_id,
    status_vinculo_cliente,
    image_url,
    criado_por
  )
  values (
    btrim(p_name),
    v_actor_company_id,
    case when v_has_existing_client then p_client_company_id else null end,
    case
      when not v_has_existing_client then 'nao_vinculado'
      when p_client_company_id = v_actor_company_id then 'ativo'
      else 'pendente'
    end,
    v_project_image_url,
    v_actor_id
  )
  returning id into v_project_id;

  if v_has_existing_client and p_client_company_id <> v_actor_company_id then
    insert into public.notificacoes (
      usuario_id,
      titulo,
      mensagem,
      tipo,
      lida,
      dados_extras
    )
    select
      u.id,
      'Convite de Cliente',
      coalesce(v_actor_name, 'Um usuário') || ', da empresa ' ||
        coalesce(v_manager_company_name, 'gestora') ||
        ', convidou sua empresa para ser cliente do projeto ' || btrim(p_name) || '.',
      'convite_cliente',
      false,
      pg_catalog.jsonb_build_object(
        'projeto_id', v_project_id,
        'foto_url', v_project_image_url
      )
    from public.usuarios u
    where u.empresa_id = p_client_company_id
      and u.ativo is true
      and u.is_admin_empresa is true;
  end if;

  if v_has_new_client then
    insert into public.projeto_convites_cliente (
      projeto_id,
      email_convidado,
      empresa_nome_temp,
      criado_por,
      aceito,
      foto_url
    )
    values (
      v_project_id,
      v_email,
      v_client_name,
      v_actor_id,
      false,
      v_client_image_url
    );
  end if;

  insert into public.projeto_equipe_interna (
    projeto_id,
    usuario_id,
    empresa_id,
    ativo,
    is_gestor
  )
  values (
    v_project_id,
    v_actor_id,
    v_actor_company_id,
    true,
    true
  )
  on conflict (projeto_id, usuario_id)
  do update set
    empresa_id = excluded.empresa_id,
    ativo = true,
    is_gestor = true;

  return v_project_id;
end
$function$;

create or replace function public.update_project(
  p_project_id uuid,
  p_name text,
  p_description text,
  p_status_name text,
  p_priority_name text,
  p_image_url text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_status_id public.status_projeto.id%type;
  v_priority_id public.prioridade.id%type;
  v_storage_origin text := pg_catalog.regexp_replace(
    auth.jwt() ->> 'iss',
    '/auth/v1/?$',
    ''
  );
  v_project_image_prefix text := 'users/' || v_actor_id::text || '/capas/';
  v_project_image_path text := nullif(btrim(p_image_url), '');
  v_project_image_url text;
  v_image_filename text;
begin
  if v_actor_id is null then
    raise exception using errcode = '28000', message = 'Authentication required.';
  end if;

  if p_project_id is null then
    raise exception using errcode = '22023', message = 'Project id is required.';
  end if;

  perform 1
  from public.projetos p
  where p.id = p_project_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Project not found.';
  end if;

  -- Authorize only after locking the project so a concurrent management
  -- transfer cannot change the permission decision underneath this update.
  if not app_private.can_edit_project(p_project_id) then
    raise exception using errcode = '42501', message = 'User cannot edit this project.';
  end if;

  if nullif(btrim(p_name), '') is null or char_length(btrim(p_name)) > 160 then
    raise exception using errcode = '22023', message = 'Project name must contain between 1 and 160 characters.';
  end if;

  if (
    select count(*)
    from public.status_projeto s
    where lower(btrim(s.nome)) = lower(nullif(btrim(p_status_name), ''))
  ) <> 1 then
    raise exception using errcode = '22023', message = 'Project status must identify exactly one status.';
  end if;

  select s.id
    into v_status_id
  from public.status_projeto s
  where lower(btrim(s.nome)) = lower(btrim(p_status_name));

  if (
    select count(*)
    from public.prioridade pr
    where lower(btrim(pr.nome)) = lower(nullif(btrim(p_priority_name), ''))
  ) <> 1 then
    raise exception using errcode = '22023', message = 'Project priority must identify exactly one priority.';
  end if;

  select pr.id
    into v_priority_id
  from public.prioridade pr
  where lower(btrim(pr.nome)) = lower(btrim(p_priority_name));

  if v_project_image_path is not null then
    if v_storage_origin is null
       or char_length(v_project_image_path) > 512
       or left(v_project_image_path, char_length(v_project_image_prefix)) <> v_project_image_prefix then
      raise exception using errcode = '22023', message = 'Project image must belong to the authenticated user project path.';
    end if;

    v_image_filename := substring(
      v_project_image_path
      from char_length(v_project_image_prefix) + 1
    );
    if v_image_filename !~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,254}$'
       or not exists (
         select 1
         from storage.objects o
         where o.bucket_id = 'projetos'
           and o.name = v_project_image_path
       ) then
      raise exception using errcode = '22023', message = 'Project image object does not exist in the authenticated user path.';
    end if;

    v_project_image_url :=
      v_storage_origin || '/storage/v1/object/public/projetos/' || v_project_image_path;
  end if;

  update public.projetos p
  set nome = btrim(p_name),
      descricao = coalesce(btrim(p_description), ''),
      status_id = v_status_id,
      prioridade_id = v_priority_id,
      image_url = coalesce(v_project_image_url, p.image_url)
  where p.id = p_project_id;

  return p_project_id;
end
$function$;

create or replace function public.invite_project_company(
  p_project_id uuid,
  p_invited_company_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_actor_company_id uuid;
  v_manager_company_id uuid;
  v_project_name text;
  v_project_image text;
  v_actor_name text;
  v_invitation_id uuid;
  v_old_status text;
begin
  if v_actor_id is null then
    raise exception using errcode = '28000', message = 'Authentication required.';
  end if;

  select u.empresa_id, nullif(btrim(concat_ws(' ', u.nome, u.sobrenome)), '')
    into v_actor_company_id, v_actor_name
  from public.usuarios u
  where u.id = v_actor_id
    and u.ativo is true;

  select p.empresa_gestora_id, p.nome, p.image_url
    into v_manager_company_id, v_project_name, v_project_image
  from public.projetos p
  where p.id = p_project_id
  for update;

  if v_manager_company_id is null then
    raise exception using errcode = 'P0002', message = 'Project not found.';
  end if;

  -- Check permission after taking the row lock so a concurrent management
  -- transfer cannot leave a stale authorization decision.
  if not app_private.can_manage_project(p_project_id) then
    raise exception using errcode = '42501', message = 'Only a project manager may invite companies.';
  end if;

  if p_invited_company_id is null or p_invited_company_id = v_manager_company_id then
    raise exception using errcode = '22023', message = 'The invited company must differ from the managing company.';
  end if;

  if not exists (select 1 from public.empresas e where e.id = p_invited_company_id) then
    raise exception using errcode = '23503', message = 'Invited company does not exist.';
  end if;

  if not exists (
    select 1
    from public.usuarios u
    where u.empresa_id = p_invited_company_id
      and u.ativo is true
      and u.is_admin_empresa is true
  ) then
    raise exception using
      errcode = '23514',
      message = 'Invited company has no active administrator to receive the invitation.';
  end if;

  -- Serialize retries for the same project/company pair before reading its state.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_project_id::text || ':' || p_invited_company_id::text, 0)
  );

  select pec.id, pec.status
    into v_invitation_id, v_old_status
  from public.projeto_empresas_colaboradoras pec
  where pec.projeto_id = p_project_id
    and pec.empresa_id = p_invited_company_id
  for update;

  if found then
    if v_old_status = 'aceito' then
      raise exception using errcode = '23505', message = 'Company is already an active project collaborator.';
    end if;
    if v_old_status <> 'pendente' then
      update public.projeto_empresas_colaboradoras
      set status = 'pendente', criado_por = v_actor_id
      where id = v_invitation_id;
    end if;
  else
    insert into public.projeto_empresas_colaboradoras (
      projeto_id,
      empresa_id,
      criado_por,
      status
    )
    values (
      p_project_id,
      p_invited_company_id,
      v_actor_id,
      'pendente'
    )
    returning id into v_invitation_id;
  end if;

  insert into public.notificacoes (
    usuario_id,
    titulo,
    mensagem,
    tipo,
    lida,
    dados_extras
  )
  select
    u.id,
    'Novo Convite de Colaboracao',
    coalesce(v_actor_name, 'Um gestor') || ' convidou sua empresa para o projeto ' || v_project_name || '.',
    'convite_projeto',
    false,
    pg_catalog.jsonb_build_object(
      'projeto_id', p_project_id,
      'convite_id', v_invitation_id,
      'foto_url', v_project_image
    )
  from public.usuarios u
  where u.empresa_id = p_invited_company_id
    and u.ativo is true
    and u.is_admin_empresa is true
    and not exists (
      select 1
      from public.notificacoes n
      where n.usuario_id = u.id
        and n.tipo = 'convite_projeto'
        and n.lida is false
        and n.dados_extras ->> 'convite_id' = v_invitation_id::text
    );

  return v_invitation_id;
end
$function$;

create or replace function public.respond_to_project_company_invite(
  p_invitation_id uuid,
  p_notification_id uuid,
  p_accept boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_actor_company_id uuid;
  v_project_id uuid;
  v_locked_project_id uuid;
  v_invited_company_id uuid;
  v_status text;
begin
  if v_actor_id is null then
    raise exception using errcode = '28000', message = 'Authentication required.';
  end if;
  if p_accept is null then
    raise exception using errcode = '22023', message = 'p_accept is required.';
  end if;

  select pec.projeto_id
    into v_project_id
  from public.projeto_empresas_colaboradoras pec
  where pec.id = p_invitation_id;

  if v_project_id is null then
    raise exception using errcode = 'P0002', message = 'Invitation not found.';
  end if;

  select p.id
    into v_locked_project_id
  from public.projetos p
  where p.id = v_project_id
  for update;

  if v_locked_project_id is null then
    raise exception using errcode = 'P0002', message = 'Project not found.';
  end if;

  select u.empresa_id
    into v_actor_company_id
  from public.usuarios u
  where u.id = v_actor_id
    and u.ativo is true
    and u.is_admin_empresa is true;

  if v_actor_company_id is null then
    raise exception using errcode = '42501', message = 'Only an active company administrator may answer this invitation.';
  end if;

  select pec.projeto_id, pec.empresa_id, pec.status
    into v_project_id, v_invited_company_id, v_status
  from public.projeto_empresas_colaboradoras pec
  where pec.id = p_invitation_id
    and pec.projeto_id = v_locked_project_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Invitation not found.';
  end if;
  if v_invited_company_id <> v_actor_company_id then
    raise exception using errcode = '42501', message = 'Invitation belongs to another company.';
  end if;
  if v_status <> 'pendente' then
    raise exception using errcode = '23514', message = 'Invitation is no longer pending.';
  end if;

  if not exists (
    select 1
    from public.notificacoes n
    where n.id = p_notification_id
      and n.usuario_id = v_actor_id
      and n.tipo = 'convite_projeto'
      and n.dados_extras ->> 'projeto_id' = v_project_id::text
      and n.dados_extras ->> 'convite_id' = p_invitation_id::text
  ) then
    raise exception using errcode = '42501', message = 'Notification does not match this invitation and user.';
  end if;

  update public.projeto_empresas_colaboradoras
  set status = case when p_accept then 'aceito' else 'recusado' end
  where id = p_invitation_id;

  if p_accept then
    insert into public.projeto_equipe_interna (
      projeto_id,
      usuario_id,
      empresa_id,
      ativo,
      is_gestor
    )
    values (
      v_project_id,
      v_actor_id,
      v_actor_company_id,
      true,
      true
    )
    on conflict (projeto_id, usuario_id)
    do update set
      empresa_id = excluded.empresa_id,
      ativo = true,
      is_gestor = true;
  end if;

  update public.notificacoes n
  set lida = true
  where n.usuario_id in (
      select u.id
      from public.usuarios u
      where u.empresa_id = v_actor_company_id
        and u.ativo is true
        and u.is_admin_empresa is true
    )
    and n.dados_extras ->> 'convite_id' = p_invitation_id::text;

  return v_project_id;
end
$function$;

create or replace function public.transfer_project_management(
  p_project_id uuid,
  p_new_manager_company_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_old_manager_company_id uuid;
begin
  if v_actor_id is null then
    raise exception using errcode = '28000', message = 'Authentication required.';
  end if;

  select p.empresa_gestora_id
    into v_old_manager_company_id
  from public.projetos p
  where p.id = p_project_id
  for update;

  if v_old_manager_company_id is null then
    raise exception using errcode = 'P0002', message = 'Project not found.';
  end if;

  -- Authorize against the locked/current project state.
  if not app_private.can_manage_project(p_project_id) then
    raise exception using errcode = '42501', message = 'Only a project manager may transfer management.';
  end if;
  if p_new_manager_company_id is null then
    raise exception using errcode = '22023', message = 'New managing company is required.';
  end if;
  if p_new_manager_company_id = v_old_manager_company_id then
    return p_project_id;
  end if;

  perform 1
    from public.projeto_empresas_colaboradoras pec
    where pec.projeto_id = p_project_id
      and pec.empresa_id = p_new_manager_company_id
      and pec.status = 'aceito'
    for update;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'New managing company must already be an accepted collaborator.';
  end if;

  -- The previous manager remains an accepted collaborator after the transfer.
  insert into public.projeto_empresas_colaboradoras (
    projeto_id,
    empresa_id,
    criado_por,
    status
  )
  values (
    p_project_id,
    v_old_manager_company_id,
    v_actor_id,
    'aceito'
  )
  on conflict (projeto_id, empresa_id)
  do update set status = 'aceito';

  -- The new manager is represented by projetos.empresa_gestora_id, not twice.
  delete from public.projeto_empresas_colaboradoras
  where projeto_id = p_project_id
    and empresa_id = p_new_manager_company_id;

  update public.projetos
  set empresa_gestora_id = p_new_manager_company_id
  where id = p_project_id;

  return p_project_id;
end
$function$;

create or replace function public.invite_project_client(
  p_project_id uuid,
  p_client_company_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_actor_company_id uuid;
  v_actor_name text;
  v_manager_company_id uuid;
  v_manager_company_name text;
  v_project_name text;
  v_project_image_url text;
  v_previous_client_company_id uuid;
  v_previous_client_status text;
begin
  if v_actor_id is null then
    raise exception using errcode = '28000', message = 'Authentication required.';
  end if;
  if p_client_company_id is null then
    raise exception using errcode = '22023', message = 'Client company is required.';
  end if;

  select
    u.empresa_id,
    nullif(btrim(pg_catalog.concat_ws(' ', u.nome, u.sobrenome)), '')
    into v_actor_company_id, v_actor_name
  from public.usuarios u
  where u.id = v_actor_id
    and u.ativo is true;

  if v_actor_company_id is null then
    raise exception using errcode = '42501', message = 'Active user with a company is required.';
  end if;

  select
    p.empresa_gestora_id,
    p.empresa_cliente_id,
    p.status_vinculo_cliente,
    p.nome,
    p.image_url
    into
      v_manager_company_id,
      v_previous_client_company_id,
      v_previous_client_status,
      v_project_name,
      v_project_image_url
  from public.projetos p
  where p.id = p_project_id
  for update;

  if v_manager_company_id is null then
    raise exception using errcode = 'P0002', message = 'Project not found.';
  end if;
  if not app_private.can_manage_project(p_project_id) then
    raise exception using errcode = '42501', message = 'Only a project manager may invite a client.';
  end if;
  if not exists (
    select 1 from public.empresas e where e.id = p_client_company_id
  ) then
    raise exception using errcode = '23503', message = 'Client company does not exist.';
  end if;
  if v_previous_client_company_id = p_client_company_id then
    if v_previous_client_status = 'ativo' then
      raise exception using errcode = '23514', message = 'This company is already the active project client.';
    elsif v_previous_client_status = 'pendente' then
      raise exception using errcode = '23514', message = 'A client invitation is already pending for this company.';
    end if;
  end if;

  if p_client_company_id <> v_manager_company_id
     and not exists (
       select 1
       from public.usuarios u
       where u.empresa_id = p_client_company_id
         and u.ativo is true
         and u.is_admin_empresa is true
     ) then
    raise exception using
      errcode = '23514',
      message = 'Client company has no active administrator to receive the invitation.';
  end if;

  select e.nome
    into v_manager_company_name
  from public.empresas e
  where e.id = v_manager_company_id;

  -- Close stale client invitations before changing the project relationship.
  update public.notificacoes n
  set lida = true
  where n.tipo = 'convite_cliente'
    and n.dados_extras ->> 'projeto_id' = p_project_id::text;

  if v_previous_client_company_id is not null
     and v_previous_client_company_id <> v_manager_company_id
     and v_previous_client_company_id <> p_client_company_id then
    update public.empresa_clientes ec
    set status_vinculo = 'removida'
    where ec.gestora_id = v_manager_company_id
      and ec.cliente_id = v_previous_client_company_id;
  end if;

  if p_client_company_id = v_manager_company_id then
    update public.projetos
    set empresa_cliente_id = p_client_company_id,
        status_vinculo_cliente = 'ativo'
    where id = p_project_id;
    return p_project_id;
  end if;

  insert into public.empresa_clientes (gestora_id, cliente_id, status_vinculo)
  values (v_manager_company_id, p_client_company_id, 'pendente')
  on conflict (gestora_id, cliente_id)
  do update set status_vinculo = excluded.status_vinculo;

  update public.projetos
  set empresa_cliente_id = p_client_company_id,
      status_vinculo_cliente = 'pendente'
  where id = p_project_id;

  insert into public.notificacoes (
    usuario_id,
    titulo,
    mensagem,
    tipo,
    lida,
    dados_extras
  )
  select
    u.id,
    'Convite de Cliente',
    coalesce(v_actor_name, 'Um usuário') || ', da empresa ' ||
      coalesce(v_manager_company_name, 'gestora') ||
      ', convidou sua empresa para ser cliente do projeto ' ||
      coalesce(v_project_name, 'sem nome') || '.',
    'convite_cliente',
    false,
    pg_catalog.jsonb_build_object(
      'projeto_id', p_project_id,
      'foto_url', v_project_image_url
    )
  from public.usuarios u
  where u.empresa_id = p_client_company_id
    and u.ativo is true
    and u.is_admin_empresa is true;

  return p_project_id;
end
$function$;

create or replace function public.respond_to_project_client_invite(
  p_project_id uuid,
  p_notification_id uuid,
  p_accept boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_actor_company_id uuid;
  v_manager_company_id uuid;
  v_client_company_id uuid;
  v_client_status text;
begin
  if v_actor_id is null then
    raise exception using errcode = '28000', message = 'Authentication required.';
  end if;

  select u.empresa_id
    into v_actor_company_id
  from public.usuarios u
  where u.id = v_actor_id
    and u.ativo is true
    and u.is_admin_empresa is true;

  if v_actor_company_id is null then
    raise exception using errcode = '42501', message = 'Only an active company administrator may answer a client invitation.';
  end if;

  select
    p.empresa_gestora_id,
    p.empresa_cliente_id,
    p.status_vinculo_cliente
    into v_manager_company_id, v_client_company_id, v_client_status
  from public.projetos p
  where p.id = p_project_id
  for update;

  if v_manager_company_id is null then
    raise exception using errcode = 'P0002', message = 'Project not found.';
  end if;
  if v_client_company_id <> v_actor_company_id or v_client_status <> 'pendente' then
    raise exception using errcode = '42501', message = 'This client invitation is no longer valid for your company.';
  end if;
  if not exists (
    select 1
    from public.notificacoes n
    where n.id = p_notification_id
      and n.usuario_id = v_actor_id
      and n.tipo = 'convite_cliente'
      and n.dados_extras ->> 'projeto_id' = p_project_id::text
  ) then
    raise exception using errcode = '42501', message = 'Notification does not match this client invitation and user.';
  end if;

  if p_accept then
    update public.projetos
    set status_vinculo_cliente = 'ativo'
    where id = p_project_id;

    insert into public.empresa_clientes (gestora_id, cliente_id, status_vinculo)
    values (v_manager_company_id, v_actor_company_id, 'ativo')
    on conflict (gestora_id, cliente_id)
    do update set status_vinculo = excluded.status_vinculo;
  else
    update public.projetos
    set empresa_cliente_id = null,
        status_vinculo_cliente = 'nao_vinculado'
    where id = p_project_id;

    insert into public.empresa_clientes (gestora_id, cliente_id, status_vinculo)
    values (v_manager_company_id, v_actor_company_id, 'recusado')
    on conflict (gestora_id, cliente_id)
    do update set status_vinculo = excluded.status_vinculo;
  end if;

  update public.notificacoes n
  set lida = true
  where n.tipo = 'convite_cliente'
    and n.dados_extras ->> 'projeto_id' = p_project_id::text
    and n.usuario_id in (
      select u.id
      from public.usuarios u
      where u.empresa_id = v_actor_company_id
        and u.ativo is true
        and u.is_admin_empresa is true
    );

  return p_project_id;
end
$function$;

create or replace function public.remove_project_client(p_project_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_manager_company_id uuid;
  v_client_company_id uuid;
begin
  if auth.uid() is null then
    raise exception using errcode = '28000', message = 'Authentication required.';
  end if;

  select p.empresa_gestora_id, p.empresa_cliente_id
    into v_manager_company_id, v_client_company_id
  from public.projetos p
  where p.id = p_project_id
  for update;

  if v_manager_company_id is null then
    raise exception using errcode = 'P0002', message = 'Project not found.';
  end if;
  if not app_private.can_manage_project(p_project_id) then
    raise exception using errcode = '42501', message = 'Only a project manager may remove the client.';
  end if;

  update public.projetos
  set empresa_cliente_id = null,
      status_vinculo_cliente = 'nao_vinculado'
  where id = p_project_id;

  if v_client_company_id is not null
     and v_client_company_id <> v_manager_company_id then
    update public.empresa_clientes ec
    set status_vinculo = 'removida'
    where ec.gestora_id = v_manager_company_id
      and ec.cliente_id = v_client_company_id;
  end if;

  update public.notificacoes n
  set lida = true
  where n.tipo = 'convite_cliente'
    and n.dados_extras ->> 'projeto_id' = p_project_id::text;

  return p_project_id;
end
$function$;

create or replace function public.delete_project(p_project_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_actor_company_id uuid;
  v_is_company_admin boolean;
  v_manager_company_id uuid;
begin
  if v_actor_id is null then
    raise exception using errcode = '28000', message = 'Authentication required.';
  end if;

  select u.empresa_id, u.is_admin_empresa
    into v_actor_company_id, v_is_company_admin
  from public.usuarios u
  where u.id = v_actor_id
    and u.ativo is true;

  select p.empresa_gestora_id
    into v_manager_company_id
  from public.projetos p
  where p.id = p_project_id
  for update;

  if v_manager_company_id is null then
    raise exception using errcode = 'P0002', message = 'Project not found.';
  end if;
  if v_actor_company_id <> v_manager_company_id
     or v_is_company_admin is not true then
    raise exception using errcode = '42501', message = 'Only an administrator of the managing company may delete the project.';
  end if;

  delete from public.projetos p where p.id = p_project_id;
  return p_project_id;
end
$function$;

-- Revoke every overload first. Old signatures are kept for dependency safety, but
-- none of them may remain callable through PostgREST by accident.
do $revoke_project_rpc_overloads$
declare
  v_function record;
begin
  for v_function in
    select p.oid
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and p.proname in (
        'create_project',
        'update_project',
        'invite_project_company',
        'respond_to_project_company_invite',
        'transfer_project_management',
        'invite_project_client',
        'respond_to_project_client_invite',
        'remove_project_client',
        'delete_project'
      )
  loop
    execute pg_catalog.format(
      'revoke all on function %s from public, anon, authenticated',
      v_function.oid::pg_catalog.regprocedure
    );
  end loop;
end
$revoke_project_rpc_overloads$;

grant execute on function public.create_project(text, uuid, text, text, text, text) to authenticated;
grant execute on function public.update_project(uuid, text, text, text, text, text) to authenticated;
grant execute on function public.invite_project_company(uuid, uuid) to authenticated;
grant execute on function public.respond_to_project_company_invite(uuid, uuid, boolean) to authenticated;
grant execute on function public.transfer_project_management(uuid, uuid) to authenticated;
grant execute on function public.invite_project_client(uuid, uuid) to authenticated;
grant execute on function public.respond_to_project_client_invite(uuid, uuid, boolean) to authenticated;
grant execute on function public.remove_project_client(uuid) to authenticated;
grant execute on function public.delete_project(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 4. Table RLS and least-privilege grants.
-- -----------------------------------------------------------------------------

alter table public.projetos enable row level security;
alter table public.projeto_equipe_interna enable row level security;
alter table public.projeto_empresas_colaboradoras enable row level security;
alter table public.projeto_convites_cliente enable row level security;
alter table public.empresa_clientes enable row level security;
alter table public.notificacoes enable row level security;

revoke all on table public.projetos from public, anon, authenticated;
revoke all on table public.projeto_equipe_interna from public, anon, authenticated;
revoke all on table public.projeto_empresas_colaboradoras from public, anon, authenticated;
revoke all on table public.projeto_convites_cliente from public, anon, authenticated;
revoke all on table public.empresa_clientes from public, anon, authenticated;
revoke all on table public.notificacoes from public, anon, authenticated;

grant select on table public.projetos to authenticated;
grant select on table public.projeto_equipe_interna to authenticated;
grant select on table public.projeto_empresas_colaboradoras to authenticated;
grant select on table public.projeto_convites_cliente to authenticated;
grant select on table public.empresa_clientes to authenticated;
grant select on table public.notificacoes to authenticated;

-- Remove table-level mutation grants for RPC-only operations.
revoke insert, update, delete on table public.projetos from public, authenticated;
revoke insert, update, delete on table public.projeto_equipe_interna from public, authenticated;
revoke insert, update, delete on table public.projeto_empresas_colaboradoras from public, authenticated;
revoke insert, update, delete on table public.projeto_convites_cliente from public, authenticated;
revoke insert, update, delete on table public.empresa_clientes from public, authenticated;
revoke insert, update, delete on table public.notificacoes from public, authenticated;

-- Rebuild column-level UPDATE grants used by the Flutter repositories. This also
-- removes an old column grant that could otherwise bypass a table-level revoke.
do $column_grants$
declare
  v_column record;
begin
  for v_column in
    select c.table_schema, c.table_name, c.column_name
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name in (
        'projetos',
        'projeto_equipe_interna',
        'projeto_empresas_colaboradoras',
        'projeto_convites_cliente',
        'empresa_clientes',
        'notificacoes'
      )
  loop
    execute format(
      'revoke all privileges (%I) on table %I.%I from public, anon, authenticated',
      v_column.column_name,
      v_column.table_schema,
      v_column.table_name
    );
  end loop;
end
$column_grants$;

revoke update on table public.projetos from public, authenticated;
revoke update on table public.projeto_equipe_interna from public, authenticated;
revoke update on table public.notificacoes from public, authenticated;

grant insert on table public.projeto_equipe_interna to authenticated;
grant update (ativo, is_gestor)
  on table public.projeto_equipe_interna to authenticated;
grant update (lida)
  on table public.notificacoes to authenticated;

-- projetos --------------------------------------------------------------------

drop policy if exists dv_projects_select_allow on public.projetos;
drop policy if exists dv_projects_select_guard on public.projetos;
drop policy if exists dv_projects_insert_guard on public.projetos;
drop policy if exists dv_projects_update_allow on public.projetos;
drop policy if exists dv_projects_update_guard on public.projetos;
drop policy if exists dv_projects_delete_guard on public.projetos;

create policy dv_projects_select_allow
on public.projetos as permissive
for select to authenticated
using (app_private.has_project_access(id));

create policy dv_projects_select_guard
on public.projetos as restrictive
for select to authenticated
using (app_private.has_project_access(id));

create policy dv_projects_insert_guard
on public.projetos as restrictive
for insert to authenticated
with check (false);

create policy dv_projects_update_guard
on public.projetos as restrictive
for update to authenticated
using (false)
with check (false);

create policy dv_projects_delete_guard
on public.projetos as restrictive
for delete to authenticated
using (false);

-- projeto_equipe_interna -------------------------------------------------------

drop policy if exists dv_project_team_select_allow on public.projeto_equipe_interna;
drop policy if exists dv_project_team_select_guard on public.projeto_equipe_interna;
drop policy if exists dv_project_team_insert_allow on public.projeto_equipe_interna;
drop policy if exists dv_project_team_insert_guard on public.projeto_equipe_interna;
drop policy if exists dv_project_team_update_allow on public.projeto_equipe_interna;
drop policy if exists dv_project_team_update_guard on public.projeto_equipe_interna;
drop policy if exists dv_project_team_delete_guard on public.projeto_equipe_interna;

create policy dv_project_team_select_allow
on public.projeto_equipe_interna as permissive
for select to authenticated
using (app_private.has_project_access(projeto_id));

create policy dv_project_team_select_guard
on public.projeto_equipe_interna as restrictive
for select to authenticated
using (app_private.has_project_access(projeto_id));

create policy dv_project_team_insert_allow
on public.projeto_equipe_interna as permissive
for insert to authenticated
with check (
  app_private.can_manage_company_team(projeto_id, empresa_id)
  and app_private.is_valid_team_member(usuario_id, empresa_id)
  and usuario_id <> auth.uid()
);

create policy dv_project_team_insert_guard
on public.projeto_equipe_interna as restrictive
for insert to authenticated
with check (
  app_private.can_manage_company_team(projeto_id, empresa_id)
  and app_private.is_valid_team_member(usuario_id, empresa_id)
  and usuario_id <> auth.uid()
);

create policy dv_project_team_update_allow
on public.projeto_equipe_interna as permissive
for update to authenticated
using (
  app_private.can_manage_company_team(projeto_id, empresa_id)
  and usuario_id <> auth.uid()
  and not app_private.is_company_admin_user(usuario_id)
)
with check (
  app_private.can_manage_company_team(projeto_id, empresa_id)
  and app_private.is_valid_team_member(usuario_id, empresa_id)
  and usuario_id <> auth.uid()
  and not app_private.is_company_admin_user(usuario_id)
);

create policy dv_project_team_update_guard
on public.projeto_equipe_interna as restrictive
for update to authenticated
using (
  app_private.can_manage_company_team(projeto_id, empresa_id)
  and usuario_id <> auth.uid()
  and not app_private.is_company_admin_user(usuario_id)
)
with check (
  app_private.can_manage_company_team(projeto_id, empresa_id)
  and app_private.is_valid_team_member(usuario_id, empresa_id)
  and usuario_id <> auth.uid()
  and not app_private.is_company_admin_user(usuario_id)
);

create policy dv_project_team_delete_guard
on public.projeto_equipe_interna as restrictive
for delete to authenticated
using (false);

-- projeto_empresas_colaboradoras ---------------------------------------------

drop policy if exists dv_project_companies_select_allow on public.projeto_empresas_colaboradoras;
drop policy if exists dv_project_companies_select_guard on public.projeto_empresas_colaboradoras;
drop policy if exists dv_project_companies_insert_guard on public.projeto_empresas_colaboradoras;
drop policy if exists dv_project_companies_update_guard on public.projeto_empresas_colaboradoras;
drop policy if exists dv_project_companies_delete_guard on public.projeto_empresas_colaboradoras;

create policy dv_project_companies_select_allow
on public.projeto_empresas_colaboradoras as permissive
for select to authenticated
using (
  app_private.has_project_access(projeto_id)
  or (
    empresa_id = app_private.current_company_id()
    and app_private.is_company_admin(empresa_id)
  )
);

create policy dv_project_companies_select_guard
on public.projeto_empresas_colaboradoras as restrictive
for select to authenticated
using (
  app_private.has_project_access(projeto_id)
  or (
    empresa_id = app_private.current_company_id()
    and app_private.is_company_admin(empresa_id)
  )
);

create policy dv_project_companies_insert_guard
on public.projeto_empresas_colaboradoras as restrictive
for insert to authenticated
with check (false);

create policy dv_project_companies_update_guard
on public.projeto_empresas_colaboradoras as restrictive
for update to authenticated
using (false)
with check (false);

create policy dv_project_companies_delete_guard
on public.projeto_empresas_colaboradoras as restrictive
for delete to authenticated
using (false);

-- projeto_convites_cliente ----------------------------------------------------

drop policy if exists dv_client_invites_select_allow on public.projeto_convites_cliente;
drop policy if exists dv_client_invites_select_guard on public.projeto_convites_cliente;
drop policy if exists dv_client_invites_insert_guard on public.projeto_convites_cliente;
drop policy if exists dv_client_invites_update_guard on public.projeto_convites_cliente;
drop policy if exists dv_client_invites_delete_guard on public.projeto_convites_cliente;

create policy dv_client_invites_select_allow
on public.projeto_convites_cliente as permissive
for select to authenticated
using (app_private.has_project_access(projeto_id));

create policy dv_client_invites_select_guard
on public.projeto_convites_cliente as restrictive
for select to authenticated
using (app_private.has_project_access(projeto_id));

create policy dv_client_invites_insert_guard
on public.projeto_convites_cliente as restrictive
for insert to authenticated
with check (false);

create policy dv_client_invites_update_guard
on public.projeto_convites_cliente as restrictive
for update to authenticated
using (false)
with check (false);

create policy dv_client_invites_delete_guard
on public.projeto_convites_cliente as restrictive
for delete to authenticated
using (false);

-- empresa_clientes ------------------------------------------------------------

drop policy if exists dv_company_clients_select_allow on public.empresa_clientes;
drop policy if exists dv_company_clients_select_guard on public.empresa_clientes;
drop policy if exists dv_company_clients_insert_guard on public.empresa_clientes;
drop policy if exists dv_company_clients_update_guard on public.empresa_clientes;
drop policy if exists dv_company_clients_delete_guard on public.empresa_clientes;

create policy dv_company_clients_select_allow
on public.empresa_clientes as permissive
for select to authenticated
using (
  gestora_id = app_private.current_company_id()
  or cliente_id = app_private.current_company_id()
);

create policy dv_company_clients_select_guard
on public.empresa_clientes as restrictive
for select to authenticated
using (
  gestora_id = app_private.current_company_id()
  or cliente_id = app_private.current_company_id()
);

create policy dv_company_clients_insert_guard
on public.empresa_clientes as restrictive
for insert to authenticated
with check (false);

create policy dv_company_clients_update_guard
on public.empresa_clientes as restrictive
for update to authenticated
using (false)
with check (false);

create policy dv_company_clients_delete_guard
on public.empresa_clientes as restrictive
for delete to authenticated
using (false);

-- notificacoes ----------------------------------------------------------------

drop policy if exists dv_notifications_select_allow on public.notificacoes;
drop policy if exists dv_notifications_select_guard on public.notificacoes;
drop policy if exists dv_notifications_insert_guard on public.notificacoes;
drop policy if exists dv_notifications_update_allow on public.notificacoes;
drop policy if exists dv_notifications_update_guard on public.notificacoes;
drop policy if exists dv_notifications_delete_guard on public.notificacoes;

create policy dv_notifications_select_allow
on public.notificacoes as permissive
for select to authenticated
using (usuario_id = auth.uid());

create policy dv_notifications_select_guard
on public.notificacoes as restrictive
for select to authenticated
using (usuario_id = auth.uid());

create policy dv_notifications_insert_guard
on public.notificacoes as restrictive
for insert to authenticated
with check (false);

create policy dv_notifications_update_allow
on public.notificacoes as permissive
for update to authenticated
using (usuario_id = auth.uid())
with check (usuario_id = auth.uid());

create policy dv_notifications_update_guard
on public.notificacoes as restrictive
for update to authenticated
using (usuario_id = auth.uid())
with check (usuario_id = auth.uid());

create policy dv_notifications_delete_guard
on public.notificacoes as restrictive
for delete to authenticated
using (false);

-- -----------------------------------------------------------------------------
-- 5. Storage: project covers/client photos are readable by authenticated users,
--    but only the owner of users/<uid>/{capas|clientes}/... may write there.
--    Other paths in this shared bucket keep relying on their existing policies.
--    The restrictive guards below therefore constrain only this new namespace.
-- -----------------------------------------------------------------------------

alter table storage.objects enable row level security;

drop policy if exists dv_project_storage_select_allow on storage.objects;
drop policy if exists dv_project_storage_insert_allow on storage.objects;
drop policy if exists dv_project_storage_insert_guard on storage.objects;
drop policy if exists dv_project_storage_update_allow on storage.objects;
drop policy if exists dv_project_storage_update_guard on storage.objects;
drop policy if exists dv_project_storage_delete_allow on storage.objects;
drop policy if exists dv_project_storage_delete_guard on storage.objects;
drop policy if exists dv_project_storage_anon_insert_guard on storage.objects;
drop policy if exists dv_project_storage_anon_update_guard on storage.objects;
drop policy if exists dv_project_storage_anon_delete_guard on storage.objects;

create policy dv_project_storage_select_allow
on storage.objects as permissive
for select to authenticated
using (bucket_id = 'projetos');

create policy dv_project_storage_insert_allow
on storage.objects as permissive
for insert to authenticated
with check (
  bucket_id = 'projetos'
  and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = auth.uid()::text
  and (storage.foldername(name))[3] in ('capas', 'clientes')
  and (storage.foldername(name))[4] is null
);

create policy dv_project_storage_insert_guard
on storage.objects as restrictive
for insert to authenticated
with check (
  bucket_id <> 'projetos'
  or coalesce((storage.foldername(name))[1], '') <> 'users'
  or coalesce((storage.foldername(name))[3], '') not in ('capas', 'clientes')
  or (
    (storage.foldername(name))[1] = 'users'
    and (storage.foldername(name))[2] = auth.uid()::text
    and (storage.foldername(name))[3] in ('capas', 'clientes')
    and (storage.foldername(name))[4] is null
  )
);

create policy dv_project_storage_update_allow
on storage.objects as permissive
for update to authenticated
using (
  bucket_id = 'projetos'
  and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = auth.uid()::text
  and (storage.foldername(name))[3] in ('capas', 'clientes')
  and (storage.foldername(name))[4] is null
)
with check (
  bucket_id = 'projetos'
  and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = auth.uid()::text
  and (storage.foldername(name))[3] in ('capas', 'clientes')
  and (storage.foldername(name))[4] is null
);

create policy dv_project_storage_update_guard
on storage.objects as restrictive
for update to authenticated
using (
  bucket_id <> 'projetos'
  or coalesce((storage.foldername(name))[1], '') <> 'users'
  or coalesce((storage.foldername(name))[3], '') not in ('capas', 'clientes')
  or (
    (storage.foldername(name))[1] = 'users'
    and (storage.foldername(name))[2] = auth.uid()::text
    and (storage.foldername(name))[3] in ('capas', 'clientes')
    and (storage.foldername(name))[4] is null
  )
)
with check (
  bucket_id <> 'projetos'
  or coalesce((storage.foldername(name))[1], '') <> 'users'
  or coalesce((storage.foldername(name))[3], '') not in ('capas', 'clientes')
  or (
    (storage.foldername(name))[1] = 'users'
    and (storage.foldername(name))[2] = auth.uid()::text
    and (storage.foldername(name))[3] in ('capas', 'clientes')
    and (storage.foldername(name))[4] is null
  )
);

create policy dv_project_storage_delete_allow
on storage.objects as permissive
for delete to authenticated
using (
  bucket_id = 'projetos'
  and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = auth.uid()::text
  and (storage.foldername(name))[3] in ('capas', 'clientes')
  and (storage.foldername(name))[4] is null
);

create policy dv_project_storage_delete_guard
on storage.objects as restrictive
for delete to authenticated
using (
  bucket_id <> 'projetos'
  or coalesce((storage.foldername(name))[1], '') <> 'users'
  or coalesce((storage.foldername(name))[3], '') not in ('capas', 'clientes')
  or (
    (storage.foldername(name))[1] = 'users'
    and (storage.foldername(name))[2] = auth.uid()::text
    and (storage.foldername(name))[3] in ('capas', 'clientes')
    and (storage.foldername(name))[4] is null
  )
);

-- Existing PUBLIC policies also apply to anon. These guards prevent anonymous
-- writes to this bucket without affecting any other storage bucket.
create policy dv_project_storage_anon_insert_guard
on storage.objects as restrictive
for insert to anon
with check (bucket_id <> 'projetos');

create policy dv_project_storage_anon_update_guard
on storage.objects as restrictive
for update to anon
using (bucket_id <> 'projetos')
with check (bucket_id <> 'projetos');

create policy dv_project_storage_anon_delete_guard
on storage.objects as restrictive
for delete to anon
using (bucket_id <> 'projetos');

notify pgrst, 'reload schema';

commit;
