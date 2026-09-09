begin;

drop policy if exists project_team_insert
  on public.projeto_equipe_interna;

create policy project_team_insert
on public.projeto_equipe_interna
for insert to authenticated
with check (
  private.active_actor_company_id() = empresa_id
  and usuario_id = (select auth.uid())
  and private.is_active_user_in_company(usuario_id, empresa_id)
  and ativo is true
  and is_gestor is true
  and exists (
    select 1
    from public.projetos p
    where p.id = projeto_id
      and p.empresa_gestora_id = empresa_id
      and p.criado_por = (select auth.uid())
  )
);

commit;
