begin;

-- Keep team invite visibility tied to a project relationship that is still active.
drop policy if exists project_company_invites_select
  on public.projeto_empresas_colaboradoras;

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
    or (
      private.can_access_project(projeto_id)
      and private.is_active_project_member(
        projeto_id,
        private.active_actor_company_id()
      )
    )
    or (
      status in ('pendente', 'aceito', 'recusado')
      and private.is_active_company_admin(empresa_id)
    )
  )
);

-- The project creator is allowed to create their own initial manager row.
-- The accepted-invite path preserves the primary-admin manager invariant.
drop policy if exists project_team_insert on public.projeto_equipe_interna;

create policy project_team_insert
on public.projeto_equipe_interna
for insert to authenticated
with check (
  private.active_actor_company_id() = empresa_id
  and usuario_id = (select auth.uid())
  and private.is_active_user_in_company(usuario_id, empresa_id)
  and (
    (
      ativo is true
      and is_gestor is true
      and exists (
        select 1
        from public.projetos p
        where p.id = projeto_id
          and p.empresa_gestora_id = empresa_id
          and p.criado_por = (select auth.uid())
      )
    )
    or (
      ativo is true
      and is_gestor = private.is_primary_company_admin(usuario_id, empresa_id)
      and private.has_accepted_company_invite(projeto_id, empresa_id)
    )
  )
);

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
  v_actor_id uuid;
  v_projeto_id uuid;
  v_empresa_id uuid;
  v_old_status text;
  v_actor_is_primary boolean;
begin
  v_actor_id := (select auth.uid());

  if v_actor_id is null then
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
       or not private.is_active_company_admin(v_empresa_id)
       or not private.is_active_user_in_company(v_actor_id, v_empresa_id) then
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

  if p_status = 'aceito' then
    v_actor_is_primary := private.is_primary_company_admin(v_actor_id, v_empresa_id);

    insert into public.projeto_equipe_interna as current_team (
      projeto_id,
      usuario_id,
      empresa_id,
      ativo,
      is_gestor
    ) values (
      v_projeto_id,
      v_actor_id,
      v_empresa_id,
      true,
      v_actor_is_primary
    )
    on conflict (projeto_id, usuario_id) do update
      set empresa_id = excluded.empresa_id,
          ativo = true,
          is_gestor = case
            when excluded.is_gestor is true then true
            else current_team.is_gestor
          end;
  end if;

  return true;
end;
$$;

revoke all on function public.set_project_company_invite_status(uuid, text)
  from public, anon, authenticated;
grant execute on function public.set_project_company_invite_status(uuid, text)
  to authenticated, service_role;

commit;
