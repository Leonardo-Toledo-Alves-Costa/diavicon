-- DIAVICON - Project CRUD/invite RPCs the Flutter app already calls
-- (create_project, update_project, delete_project, invite_project_company,
-- respond_to_project_company_invite, transfer_project_management,
-- invite_project_client, respond_to_project_client_invite,
-- remove_project_client) but that were never created in this database.
--
-- These were originally drafted in supabase/migrations_manual/
-- 20260903120000_harden_home_projects_rls.sql under a separate app_private
-- helper schema, but that draft predates the private.* helper schema and
-- RLS work already applied on 2026-09-08 (project_team_rls_followup,
-- project_team_insert_creator_only, project_company_invite_update_revoke).
-- This migration only adds the missing RPCs, reusing the private.* helpers
-- that already exist and are already relied on by live RLS policies. It
-- intentionally does NOT touch table grants or RLS on projetos and friends
-- (RLS is currently disabled there; that is a separate, larger change to be
-- handled on its own).

begin;

create unique index if not exists dv_projeto_empresa_project_company_uidx
  on public.projeto_empresas_colaboradoras (projeto_id, empresa_id);

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
  v_gestora_id uuid;
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

  select p.empresa_gestora_id
    into v_gestora_id
  from public.projetos p
  where p.id = p_project_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Project not found.';
  end if;

  -- Authorize only after locking the project so a concurrent management
  -- transfer cannot change the permission decision underneath this update.
  -- Any active team member of the managing company may edit (not only
  -- managers) mirroring private.can_manage_gestora_project's admin escape
  -- hatch plus private.is_active_project_member for regular members.
  if v_gestora_id is null
     or v_gestora_id is distinct from private.active_actor_company_id()
     or not (
       private.is_active_company_admin(v_gestora_id)
       or private.is_active_project_member(p_project_id, v_gestora_id)
     ) then
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
  v_actor_name text;
  v_manager_company_id uuid;
  v_project_name text;
  v_project_image text;
  v_invitation_id uuid;
  v_old_status text;
begin
  if v_actor_id is null then
    raise exception using errcode = '28000', message = 'Authentication required.';
  end if;

  select nullif(btrim(pg_catalog.concat_ws(' ', u.nome, u.sobrenome)), '')
    into v_actor_name
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
  if not private.can_manage_gestora_project(p_project_id) then
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
  v_invited_company_id uuid;
  v_status text;
begin
  if v_actor_id is null then
    raise exception using errcode = '28000', message = 'Authentication required.';
  end if;
  if p_accept is null then
    raise exception using errcode = '22023', message = 'p_accept is required.';
  end if;

  select u.empresa_id
    into v_actor_company_id
  from public.usuarios u
  where u.id = v_actor_id
    and u.ativo is true;

  if v_actor_company_id is null or not private.is_active_company_admin(v_actor_company_id) then
    raise exception using errcode = '42501', message = 'Only an active company administrator may answer this invitation.';
  end if;

  select pec.projeto_id, pec.empresa_id, pec.status
    into v_project_id, v_invited_company_id, v_status
  from public.projeto_empresas_colaboradoras pec
  where pec.id = p_invitation_id
  for update;

  if v_project_id is null then
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
  if not private.can_manage_gestora_project(p_project_id) then
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
    nullif(btrim(pg_catalog.concat_ws(' ', u.nome, u.sobrenome)), '')
    into v_actor_name
  from public.usuarios u
  where u.id = v_actor_id
    and u.ativo is true;

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
  if not private.can_manage_gestora_project(p_project_id) then
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
    and u.ativo is true;

  if v_actor_company_id is null or not private.is_active_company_admin(v_actor_company_id) then
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
  if not private.can_manage_gestora_project(p_project_id) then
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
  v_manager_company_id uuid;
begin
  if v_actor_id is null then
    raise exception using errcode = '28000', message = 'Authentication required.';
  end if;

  select p.empresa_gestora_id
    into v_manager_company_id
  from public.projetos p
  where p.id = p_project_id
  for update;

  if v_manager_company_id is null then
    raise exception using errcode = 'P0002', message = 'Project not found.';
  end if;
  if not private.is_active_company_admin(v_manager_company_id) then
    raise exception using errcode = '42501', message = 'Only an administrator of the managing company may delete the project.';
  end if;

  delete from public.projetos p where p.id = p_project_id;
  return p_project_id;
end
$function$;

-- Revoke every overload first. None of these functions may remain callable
-- through PostgREST by accident under a different signature.
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

commit;
