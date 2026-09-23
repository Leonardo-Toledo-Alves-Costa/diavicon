-- Move project-team reads and writes behind tenant-scoped database functions.

begin;

create or replace function public.list_project_team_candidates(
  p_projeto_id uuid
)
returns table (
  usuario_id uuid,
  nome text,
  sobrenome text,
  cargo text,
  foto_url text,
  ativo boolean,
  is_gestor boolean,
  membro_obrigatorio boolean
)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_actor_id uuid;
  v_empresa_id uuid;
  v_is_company_admin boolean;
begin
  v_actor_id := (select auth.uid());
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'Autenticação obrigatória.';
  end if;
  if p_projeto_id is null then
    raise exception using errcode = '22023', message = 'Projeto inválido.';
  end if;

  select u.empresa_id,
         (u.is_admin_empresa is true or u.is_admin is true)
  into v_empresa_id, v_is_company_admin
  from public.usuarios u
  where u.id = v_actor_id
    and u.ativo is true
    and u.empresa_id is not null;

  if not found then
    raise exception using errcode = '42501', message = 'Usuário ativo e vinculado à empresa é obrigatório.';
  end if;

  if not exists (
    select 1
    from public.projetos p
    where p.id = p_projeto_id
      and (
        p.empresa_gestora_id = v_empresa_id
        or (
          p.empresa_cliente_id = v_empresa_id
          and p.status_vinculo_cliente = 'ativo'
        )
        or exists (
          select 1
          from public.projeto_empresas_colaboradoras c
          where c.projeto_id = p.id
            and c.empresa_id = v_empresa_id
            and c.status = 'aceito'
        )
      )
  ) then
    raise exception using errcode = 'P0002', message = 'Projeto não encontrado.';
  end if;

  if coalesce(v_is_company_admin, false) is not true
     and not exists (
       select 1
       from public.projeto_equipe_interna e
       where e.projeto_id = p_projeto_id
         and e.usuario_id = v_actor_id
         and e.empresa_id = v_empresa_id
         and e.ativo is true
         and e.is_gestor is true
     ) then
    raise exception using errcode = '42501', message = 'Apenas administradores ou gestores ativos podem consultar a equipe.';
  end if;

  return query
  select u.id,
         u.nome,
         u.sobrenome,
         u.cargo,
         u.foto_url,
         case
           when u.is_admin_empresa is true then true
           else coalesce(e.ativo, false)
         end,
         case
           when u.is_admin_empresa is true then true
           else coalesce(e.is_gestor, false)
         end,
         (u.is_admin_empresa is true)
  from public.usuarios u
  left join public.projeto_equipe_interna e
    on e.projeto_id = p_projeto_id
   and e.usuario_id = u.id
   and e.empresa_id = v_empresa_id
  where u.empresa_id = v_empresa_id
    and u.ativo is true
    and u.id <> v_actor_id
  order by (u.is_admin_empresa is true) desc,
           u.nome asc nulls last,
           u.sobrenome asc nulls last,
           u.id asc;
end;
$$;

create or replace function public.list_project_team_visible(
  p_projeto_id uuid
)
returns table (
  usuario_id uuid,
  nome text,
  sobrenome text,
  cargo text,
  foto_url text
)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_actor_id uuid;
  v_empresa_id uuid;
  v_is_company_admin boolean;
begin
  v_actor_id := (select auth.uid());
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'Autenticação obrigatória.';
  end if;
  if p_projeto_id is null then
    raise exception using errcode = '22023', message = 'Projeto inválido.';
  end if;

  select u.empresa_id,
         (u.is_admin_empresa is true or u.is_admin is true)
  into v_empresa_id, v_is_company_admin
  from public.usuarios u
  where u.id = v_actor_id
    and u.ativo is true
    and u.empresa_id is not null;

  if not found then
    raise exception using errcode = '42501', message = 'Usuário ativo e vinculado à empresa é obrigatório.';
  end if;

  if not exists (
    select 1
    from public.projetos p
    where p.id = p_projeto_id
      and (
        p.empresa_gestora_id = v_empresa_id
        or (
          p.empresa_cliente_id = v_empresa_id
          and p.status_vinculo_cliente = 'ativo'
        )
        or exists (
          select 1
          from public.projeto_empresas_colaboradoras c
          where c.projeto_id = p.id
            and c.empresa_id = v_empresa_id
            and c.status = 'aceito'
        )
      )
  ) then
    raise exception using errcode = 'P0002', message = 'Projeto não encontrado.';
  end if;

  if coalesce(v_is_company_admin, false) is not true
     and not exists (
       select 1
       from public.projeto_equipe_interna e
       where e.projeto_id = p_projeto_id
         and e.usuario_id = v_actor_id
         and e.empresa_id = v_empresa_id
         and e.ativo is true
     ) then
    raise exception using errcode = '42501', message = 'Usuário não tem acesso à equipe deste projeto.';
  end if;

  return query
  select u.id,
         u.nome,
         u.sobrenome,
         u.cargo,
         u.foto_url
  from public.usuarios u
  left join public.projeto_equipe_interna e
    on e.projeto_id = p_projeto_id
   and e.usuario_id = u.id
   and e.empresa_id = v_empresa_id
  where (e.ativo is true or u.is_admin_empresa is true)
    and u.empresa_id = v_empresa_id
    and u.ativo is true
  order by u.nome asc nulls last,
           u.sobrenome asc nulls last,
           u.id asc;
end;
$$;

create or replace function public.set_project_member_status(
  p_projeto_id uuid,
  p_usuario_id uuid,
  p_ativo boolean
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_actor_id uuid;
  v_locked_projeto_id uuid;
  v_empresa_id uuid;
  v_is_company_admin boolean;
  v_target_is_primary boolean;
begin
  if p_projeto_id is null or p_usuario_id is null or p_ativo is null then
    raise exception using errcode = '22023', message = 'Dados da participação inválidos.';
  end if;

  select p.id
  into v_locked_projeto_id
  from public.projetos p
  where p.id = p_projeto_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Projeto não encontrado.';
  end if;

  v_actor_id := (select auth.uid());
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'Autenticação obrigatória.';
  end if;
  if p_usuario_id = v_actor_id then
    raise exception using errcode = '42501', message = 'Você não pode alterar a própria participação.';
  end if;

  select u.empresa_id,
         (u.is_admin_empresa is true or u.is_admin is true)
  into v_empresa_id, v_is_company_admin
  from public.usuarios u
  where u.id = v_actor_id
    and u.ativo is true
    and u.empresa_id is not null
  for update;

  if not found then
    raise exception using errcode = '42501', message = 'Usuário ativo e vinculado à empresa é obrigatório.';
  end if;

  if not exists (
    select 1
    from public.projetos p
    where p.id = p_projeto_id
      and (
        p.empresa_gestora_id = v_empresa_id
        or (
          p.empresa_cliente_id = v_empresa_id
          and p.status_vinculo_cliente = 'ativo'
        )
        or exists (
          select 1
          from public.projeto_empresas_colaboradoras c
          where c.projeto_id = p.id
            and c.empresa_id = v_empresa_id
            and c.status = 'aceito'
        )
      )
  ) then
    raise exception using errcode = 'P0002', message = 'Projeto não encontrado.';
  end if;

  if coalesce(v_is_company_admin, false) is not true
     and not exists (
       select 1
       from public.projeto_equipe_interna e
       where e.projeto_id = p_projeto_id
         and e.usuario_id = v_actor_id
         and e.empresa_id = v_empresa_id
         and e.ativo is true
         and e.is_gestor is true
     ) then
    raise exception using errcode = '42501', message = 'Apenas administradores ou gestores ativos podem editar a equipe.';
  end if;

  select u.is_admin_empresa
  into v_target_is_primary
  from public.usuarios u
  where u.id = p_usuario_id
    and u.empresa_id = v_empresa_id
    and u.ativo is true
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Colaborador ativo não encontrado na empresa.';
  end if;

  if v_target_is_primary is true and p_ativo is false then
    raise exception using errcode = '42501', message = 'O administrador principal é membro obrigatório do projeto.';
  end if;

  insert into public.projeto_equipe_interna as current_team (
    projeto_id, usuario_id, empresa_id, ativo, is_gestor
  ) values (
    p_projeto_id,
    p_usuario_id,
    v_empresa_id,
    case when v_target_is_primary is true then true else p_ativo end,
    (v_target_is_primary is true)
  )
  on conflict (projeto_id, usuario_id) do update
  set empresa_id = excluded.empresa_id,
      ativo = excluded.ativo,
      is_gestor = case
        when excluded.ativo is true then current_team.is_gestor
        else false
      end;

  return true;
end;
$$;

create or replace function public.set_project_member_manager(
  p_projeto_id uuid,
  p_usuario_id uuid,
  p_is_gestor boolean
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_actor_id uuid;
  v_locked_projeto_id uuid;
  v_empresa_id uuid;
  v_is_company_admin boolean;
  v_target_is_primary boolean;
begin
  if p_projeto_id is null or p_usuario_id is null or p_is_gestor is null then
    raise exception using errcode = '22023', message = 'Dados da gestão inválidos.';
  end if;

  select p.id
  into v_locked_projeto_id
  from public.projetos p
  where p.id = p_projeto_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Projeto não encontrado.';
  end if;

  v_actor_id := (select auth.uid());
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'Autenticação obrigatória.';
  end if;
  if p_usuario_id = v_actor_id then
    raise exception using errcode = '42501', message = 'Você não pode alterar a própria gestão.';
  end if;

  select u.empresa_id,
         (u.is_admin_empresa is true or u.is_admin is true)
  into v_empresa_id, v_is_company_admin
  from public.usuarios u
  where u.id = v_actor_id
    and u.ativo is true
    and u.empresa_id is not null
  for update;

  if not found then
    raise exception using errcode = '42501', message = 'Usuário ativo e vinculado à empresa é obrigatório.';
  end if;

  if not exists (
    select 1
    from public.projetos p
    where p.id = p_projeto_id
      and (
        p.empresa_gestora_id = v_empresa_id
        or (
          p.empresa_cliente_id = v_empresa_id
          and p.status_vinculo_cliente = 'ativo'
        )
        or exists (
          select 1
          from public.projeto_empresas_colaboradoras c
          where c.projeto_id = p.id
            and c.empresa_id = v_empresa_id
            and c.status = 'aceito'
        )
      )
  ) then
    raise exception using errcode = 'P0002', message = 'Projeto não encontrado.';
  end if;

  if coalesce(v_is_company_admin, false) is not true
     and not exists (
       select 1
       from public.projeto_equipe_interna e
       where e.projeto_id = p_projeto_id
         and e.usuario_id = v_actor_id
         and e.empresa_id = v_empresa_id
         and e.ativo is true
         and e.is_gestor is true
     ) then
    raise exception using errcode = '42501', message = 'Apenas administradores ou gestores ativos podem editar a equipe.';
  end if;

  select u.is_admin_empresa
  into v_target_is_primary
  from public.usuarios u
  where u.id = p_usuario_id
    and u.empresa_id = v_empresa_id
    and u.ativo is true
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Colaborador ativo não encontrado na empresa.';
  end if;

  if v_target_is_primary is true and p_is_gestor is false then
    raise exception using errcode = '42501', message = 'O administrador principal é gestor obrigatório do projeto.';
  end if;

  if p_is_gestor is true then
    insert into public.projeto_equipe_interna (
      projeto_id, usuario_id, empresa_id, ativo, is_gestor
    ) values (
      p_projeto_id, p_usuario_id, v_empresa_id, true, true
    )
    on conflict (projeto_id, usuario_id) do update
    set empresa_id = excluded.empresa_id,
        ativo = true,
        is_gestor = true;
  else
    update public.projeto_equipe_interna
    set is_gestor = false
    where projeto_id = p_projeto_id
      and usuario_id = p_usuario_id
      and empresa_id = v_empresa_id;
  end if;

  return true;
end;
$$;

revoke all on function public.list_project_team_candidates(uuid) from public, anon, authenticated;
revoke all on function public.list_project_team_visible(uuid) from public, anon, authenticated;
revoke all on function public.set_project_member_status(uuid, uuid, boolean) from public, anon, authenticated;
revoke all on function public.set_project_member_manager(uuid, uuid, boolean) from public, anon, authenticated;

grant execute on function public.list_project_team_candidates(uuid) to authenticated;
grant execute on function public.list_project_team_visible(uuid) to authenticated;
grant execute on function public.set_project_member_status(uuid, uuid, boolean) to authenticated;
grant execute on function public.set_project_member_manager(uuid, uuid, boolean) to authenticated;

commit;
