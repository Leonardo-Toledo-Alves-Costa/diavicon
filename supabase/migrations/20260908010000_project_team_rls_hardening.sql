create schema if not exists private;

create or replace function private.active_actor_company_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select u.empresa_id
  from public.usuarios u
  where u.id = (select auth.uid())
    and u.ativo is true
    and u.empresa_id is not null
  limit 1
$$;

create or replace function private.is_active_company_admin(p_empresa_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.usuarios u
    where u.id = (select auth.uid())
      and u.empresa_id = p_empresa_id
      and u.ativo is true
      and (u.is_admin_empresa is true or u.is_admin is true)
  )
$$;

create or replace function private.is_active_user_in_company(
  p_usuario_id uuid,
  p_empresa_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.usuarios u
    where u.id = p_usuario_id
      and u.empresa_id = p_empresa_id
      and u.ativo is true
  )
$$;

create or replace function private.is_primary_company_admin(
  p_usuario_id uuid,
  p_empresa_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.usuarios u
    where u.id = p_usuario_id
      and u.empresa_id = p_empresa_id
      and u.ativo is true
      and u.is_admin_empresa is true
  )
$$;

create or replace function private.can_access_project(p_projeto_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.projetos p
    where p.id = p_projeto_id
      and (
        p.empresa_gestora_id = private.active_actor_company_id()
        or (
          p.empresa_cliente_id = private.active_actor_company_id()
          and p.status_vinculo_cliente = 'ativo'
        )
        or exists (
          select 1
          from public.projeto_empresas_colaboradoras c
          where c.projeto_id = p.id
            and c.empresa_id = private.active_actor_company_id()
            and c.status = 'aceito'
        )
      )
  )
$$;

create or replace function private.has_accepted_company_invite(
  p_projeto_id uuid,
  p_empresa_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select private.active_actor_company_id() = p_empresa_id
     and exists (
       select 1
       from public.projeto_empresas_colaboradoras c
       where c.projeto_id = p_projeto_id
         and c.empresa_id = p_empresa_id
         and c.status = 'aceito'
     )
$$;

create or replace function private.is_active_project_member(
  p_projeto_id uuid,
  p_empresa_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.projeto_equipe_interna e
    join public.usuarios u on u.id = e.usuario_id
    where e.projeto_id = p_projeto_id
      and e.usuario_id = (select auth.uid())
      and e.empresa_id = p_empresa_id
      and e.ativo is true
      and u.ativo is true
      and u.empresa_id = p_empresa_id
  )
$$;

create or replace function private.can_manage_project(p_projeto_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select private.can_access_project(p_projeto_id)
     and exists (
       select 1
       from public.usuarios u
       where u.id = (select auth.uid())
         and u.ativo is true
         and u.empresa_id is not null
         and (
           u.is_admin_empresa is true
           or u.is_admin is true
           or exists (
             select 1
             from public.projeto_equipe_interna e
             where e.projeto_id = p_projeto_id
               and e.usuario_id = u.id
               and e.empresa_id = u.empresa_id
               and e.ativo is true
               and e.is_gestor is true
           )
         )
     )
$$;

create or replace function private.can_manage_gestora_project(p_projeto_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.projetos p
    join public.usuarios u
      on u.id = (select auth.uid())
     and u.empresa_id = p.empresa_gestora_id
    where p.id = p_projeto_id
      and u.ativo is true
      and (
        u.is_admin_empresa is true
        or u.is_admin is true
        or exists (
          select 1
          from public.projeto_equipe_interna e
          where e.projeto_id = p.id
            and e.usuario_id = u.id
            and e.empresa_id = p.empresa_gestora_id
            and e.ativo is true
            and e.is_gestor is true
        )
      )
  )
$$;

create or replace function private.can_create_company_invite(p_projeto_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select private.can_manage_gestora_project(p_projeto_id)
$$;

create or replace function public.set_project_company_invite_status(
  p_convite_id uuid,
  p_status text
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_projeto_id uuid;
  v_empresa_id uuid;
  v_old_status text;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'Autenticação obrigatória.';
  end if;
  if p_convite_id is null or p_status is null
     or p_status not in ('pendente', 'aceito', 'recusado') then
    raise exception using errcode = '22023', message = 'Status de convite inválido.';
  end if;

  select c.projeto_id, c.empresa_id, c.status
  into v_projeto_id, v_empresa_id, v_old_status
  from public.projeto_empresas_colaboradoras c
  where c.id = p_convite_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Convite não encontrado.';
  end if;

  if p_status = 'aceito' then
    if v_old_status <> 'pendente'
       or not private.is_active_company_admin(v_empresa_id) then
      raise exception using errcode = '42501', message = 'Somente o administrador ativo da empresa destinatária pode aceitar o convite pendente.';
    end if;
  elsif p_status = 'recusado' then
    if v_old_status = 'pendente'
       and not (
         private.is_active_company_admin(v_empresa_id)
         or private.can_manage_gestora_project(v_projeto_id)
       ) then
      raise exception using errcode = '42501', message = 'Usuário sem permissão para recusar ou cancelar o convite.';
    elsif v_old_status = 'aceito'
       and not private.can_manage_gestora_project(v_projeto_id) then
      raise exception using errcode = '42501', message = 'Somente a gestora pode remover este vínculo.';
    elsif v_old_status not in ('pendente', 'aceito') then
      raise exception using errcode = '42501', message = 'Transição de convite inválida.';
    end if;
  elsif p_status = 'pendente' then
    if v_old_status <> 'recusado'
       or not private.can_manage_gestora_project(v_projeto_id) then
      raise exception using errcode = '42501', message = 'Somente a gestora pode reconvidar este vínculo.';
    end if;
  end if;

  update public.projeto_empresas_colaboradoras
  set status = p_status
  where id = p_convite_id;

  return true;
end;
$$;

create or replace function private.enforce_project_company_invite_update()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $$
begin
  if (select auth.uid()) is null then
    return new;
  end if;

  if new.id is distinct from old.id
     or new.projeto_id is distinct from old.projeto_id
     or new.empresa_id is distinct from old.empresa_id
     or new.criado_por is distinct from old.criado_por
     or new.criado_em is distinct from old.criado_em then
    raise exception using errcode = '42501', message = 'Os identificadores e o autor do convite não podem ser alterados.';
  end if;

  if new.status is null or new.status not in ('pendente', 'aceito', 'recusado') then
    raise exception using errcode = '22023', message = 'Status de convite inválido.';
  end if;

  if new.status is not distinct from old.status then
    return new;
  end if;

  if old.status = 'pendente' then
    if new.status = 'aceito'
       and not private.is_active_company_admin(old.empresa_id) then
      raise exception using errcode = '42501', message = 'Somente o administrador ativo da empresa destinatária pode aceitar o convite.';
    elsif new.status = 'recusado'
       and not (
         private.is_active_company_admin(old.empresa_id)
         or private.can_manage_gestora_project(old.projeto_id)
       ) then
      raise exception using errcode = '42501', message = 'Usuário sem permissão para recusar ou cancelar o convite.';
    end if;
  elsif old.status = 'recusado' then
    if new.status <> 'pendente'
       or not private.can_manage_gestora_project(old.projeto_id) then
      raise exception using errcode = '42501', message = 'Somente a gestora pode reconvidar este vínculo.';
    end if;
  elsif old.status = 'aceito' then
    if new.status <> 'recusado'
       or not private.can_manage_gestora_project(old.projeto_id) then
      raise exception using errcode = '42501', message = 'Somente a gestora pode remover este vínculo.';
    end if;
  else
    raise exception using errcode = '22023', message = 'Status anterior de convite inválido.';
  end if;

  return new;
end;
$$;

create or replace function private.enforce_project_team_update()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $$
begin
  if (select auth.uid()) is null then
    return new;
  end if;

  if new.projeto_id is distinct from old.projeto_id
     or new.usuario_id is distinct from old.usuario_id
     or new.empresa_id is distinct from old.empresa_id then
    raise exception using errcode = '42501', message = 'Os identificadores e a empresa do membro não podem ser alterados.';
  end if;

  if new.usuario_id = (select auth.uid()) then
    if new.is_gestor is distinct from old.is_gestor then
      raise exception using errcode = '42501', message = 'Você não pode alterar a própria gestão.';
    end if;
    if new.ativo is distinct from old.ativo
       and not (
         old.ativo is false
         and new.ativo is true
         and private.has_accepted_company_invite(new.projeto_id, new.empresa_id)
       ) then
      raise exception using errcode = '42501', message = 'Você não pode alterar a própria participação.';
    end if;
  end if;

  if private.is_primary_company_admin(new.usuario_id, new.empresa_id)
     and (new.ativo is not true or new.is_gestor is not true) then
    raise exception using errcode = '42501', message = 'O administrador principal é membro e gestor obrigatório do projeto.';
  end if;

  return new;
end;
$$;

drop trigger if exists project_company_invites_immutable_update on public.projeto_empresas_colaboradoras;
create trigger project_company_invites_immutable_update
before update on public.projeto_empresas_colaboradoras
for each row execute function private.enforce_project_company_invite_update();

drop trigger if exists project_team_immutable_update on public.projeto_equipe_interna;
create trigger project_team_immutable_update
before update on public.projeto_equipe_interna
for each row execute function private.enforce_project_team_update();

alter table public.usuario_papeis enable row level security;
alter table public.projeto_empresas_colaboradoras enable row level security;
alter table public.projeto_equipe_interna enable row level security;

drop policy if exists "Liberar atualizacao de convites" on public.projeto_empresas_colaboradoras;
drop policy if exists "Liberar insercao de convites" on public.projeto_empresas_colaboradoras;
drop policy if exists "Liberar leitura de convites para usuários logados" on public.projeto_empresas_colaboradoras;
drop policy if exists project_company_invites_select on public.projeto_empresas_colaboradoras;
drop policy if exists project_company_invites_insert on public.projeto_empresas_colaboradoras;
drop policy if exists project_company_invites_update on public.projeto_empresas_colaboradoras;
drop policy if exists project_team_select on public.projeto_equipe_interna;
drop policy if exists project_team_insert on public.projeto_equipe_interna;
drop policy if exists project_team_update on public.projeto_equipe_interna;
drop policy if exists auth_user_roles_select_own on public.usuario_papeis;

create policy auth_user_roles_select_own
on public.usuario_papeis
for select to authenticated
using (
  usuario_id = (select auth.uid())
  and exists (
    select 1
    from public.usuarios u
    where u.id = (select auth.uid())
      and u.ativo is true
  )
);

create policy project_company_invites_select
on public.projeto_empresas_colaboradoras
for select to authenticated
using (
  private.active_actor_company_id() is not null
  and (
    (
      private.is_active_company_admin(private.active_actor_company_id())
      and private.can_access_project(projeto_id)
    )
    or private.is_active_project_member(projeto_id, private.active_actor_company_id())
    or (
      status in ('pendente', 'aceito', 'recusado')
      and private.is_active_company_admin(empresa_id)
    )
  )
);

create policy project_company_invites_insert
on public.projeto_empresas_colaboradoras
for insert to authenticated
with check (
  status = 'pendente'
  and criado_por = (select auth.uid())
  and private.can_create_company_invite(projeto_id)
);

create policy project_company_invites_update
on public.projeto_empresas_colaboradoras
for update to authenticated
using (
  private.can_manage_gestora_project(projeto_id)
  or (
    status = 'pendente'
    and private.is_active_company_admin(empresa_id)
  )
)
with check (
  status in ('pendente', 'aceito', 'recusado')
  and (
    private.can_manage_gestora_project(projeto_id)
    or private.is_active_company_admin(empresa_id)
  )
);

create policy project_team_select
on public.projeto_equipe_interna
for select to authenticated
using (
  private.active_actor_company_id() = empresa_id
  and private.can_access_project(projeto_id)
  and (
    private.is_active_company_admin(empresa_id)
    or private.is_active_project_member(projeto_id, empresa_id)
  )
);

create policy project_team_insert
on public.projeto_equipe_interna
for insert to authenticated
with check (
  private.active_actor_company_id() = empresa_id
  and usuario_id = (select auth.uid())
  and private.is_active_user_in_company(usuario_id, empresa_id)
  and private.is_active_company_admin(empresa_id)
  and (
    (
      ativo is true
      and is_gestor is true
      and exists (
        select 1
        from public.projetos p
        where p.id = projeto_id
          and p.empresa_gestora_id = empresa_id
      )
    )
    or (
      ativo is true
      and is_gestor is false
      and private.has_accepted_company_invite(projeto_id, empresa_id)
    )
  )
);

create policy project_team_update
on public.projeto_equipe_interna
for update to authenticated
using (
  private.active_actor_company_id() = empresa_id
  and private.can_access_project(projeto_id)
  and (
    (
      private.can_manage_project(projeto_id)
      and usuario_id <> (select auth.uid())
    )
    or (
      usuario_id = (select auth.uid())
      and private.is_active_company_admin(empresa_id)
      and private.has_accepted_company_invite(projeto_id, empresa_id)
    )
  )
)
with check (
  private.active_actor_company_id() = empresa_id
  and private.can_access_project(projeto_id)
  and private.is_active_user_in_company(usuario_id, empresa_id)
  and (
    (
      private.can_manage_project(projeto_id)
      and usuario_id <> (select auth.uid())
      and not (
        private.is_primary_company_admin(usuario_id, empresa_id)
        and (ativo is not true or is_gestor is not true)
      )
    )
    or (
      usuario_id = (select auth.uid())
      and private.is_active_company_admin(empresa_id)
      and private.has_accepted_company_invite(projeto_id, empresa_id)
    )
  )
);

revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated, service_role;

revoke all on function private.active_actor_company_id() from public, anon, authenticated;
revoke all on function private.is_active_company_admin(uuid) from public, anon, authenticated;
revoke all on function private.is_active_user_in_company(uuid, uuid) from public, anon, authenticated;
revoke all on function private.is_primary_company_admin(uuid, uuid) from public, anon, authenticated;
revoke all on function private.can_access_project(uuid) from public, anon, authenticated;
revoke all on function private.has_accepted_company_invite(uuid, uuid) from public, anon, authenticated;
revoke all on function private.is_active_project_member(uuid, uuid) from public, anon, authenticated;
revoke all on function private.can_manage_project(uuid) from public, anon, authenticated;
revoke all on function private.can_manage_gestora_project(uuid) from public, anon, authenticated;
revoke all on function private.can_create_company_invite(uuid) from public, anon, authenticated;

grant execute on function private.active_actor_company_id() to authenticated, service_role;
grant execute on function private.is_active_company_admin(uuid) to authenticated, service_role;
grant execute on function private.is_active_user_in_company(uuid, uuid) to authenticated, service_role;
grant execute on function private.is_primary_company_admin(uuid, uuid) to authenticated, service_role;
grant execute on function private.can_access_project(uuid) to authenticated, service_role;
grant execute on function private.has_accepted_company_invite(uuid, uuid) to authenticated, service_role;
grant execute on function private.is_active_project_member(uuid, uuid) to authenticated, service_role;
grant execute on function private.can_manage_project(uuid) to authenticated, service_role;
grant execute on function private.can_manage_gestora_project(uuid) to authenticated, service_role;
grant execute on function private.can_create_company_invite(uuid) to authenticated, service_role;

revoke all on function public.set_project_company_invite_status(uuid, text) from public, anon, authenticated;
grant execute on function public.set_project_company_invite_status(uuid, text) to authenticated, service_role;

revoke all on table public.usuario_papeis from public, anon, authenticated;
grant select on table public.usuario_papeis to authenticated;

revoke all on table public.projeto_empresas_colaboradoras from public, anon, authenticated;
grant select on table public.projeto_empresas_colaboradoras to authenticated;
grant insert (projeto_id, empresa_id, status, criado_por)
  on table public.projeto_empresas_colaboradoras to authenticated;
grant update (status)
  on table public.projeto_empresas_colaboradoras to authenticated;

revoke all on table public.projeto_equipe_interna from public, anon, authenticated;
grant select on table public.projeto_equipe_interna to authenticated;
grant insert (projeto_id, usuario_id, empresa_id, ativo, is_gestor)
  on table public.projeto_equipe_interna to authenticated;
grant update (ativo, is_gestor)
  on table public.projeto_equipe_interna to authenticated;
