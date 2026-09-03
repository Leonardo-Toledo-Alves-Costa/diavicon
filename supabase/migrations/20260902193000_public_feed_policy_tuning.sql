-- Keep gallery SELECT isolated from admin write policies and index its FK.
-- Public gallery reads continue to go through list_public_service_gallery().
drop policy if exists empresa_service_gallery_write_admin
  on public.empresa_servicos_galeria;

create policy empresa_service_gallery_insert_admin
  on public.empresa_servicos_galeria
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.empresa_servicos s
      join public.usuarios u on u.empresa_id = s.empresa_id
      where s.id = empresa_servicos_galeria.servico_id
        and u.id = (select auth.uid())
        and u.ativo = true
        and (u.is_admin_empresa = true or u.is_admin = true)
    )
  );

create policy empresa_service_gallery_update_admin
  on public.empresa_servicos_galeria
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.empresa_servicos s
      join public.usuarios u on u.empresa_id = s.empresa_id
      where s.id = empresa_servicos_galeria.servico_id
        and u.id = (select auth.uid())
        and u.ativo = true
        and (u.is_admin_empresa = true or u.is_admin = true)
    )
  )
  with check (
    exists (
      select 1
      from public.empresa_servicos s
      join public.usuarios u on u.empresa_id = s.empresa_id
      where s.id = empresa_servicos_galeria.servico_id
        and u.id = (select auth.uid())
        and u.ativo = true
        and (u.is_admin_empresa = true or u.is_admin = true)
    )
  );

create policy empresa_service_gallery_delete_admin
  on public.empresa_servicos_galeria
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.empresa_servicos s
      join public.usuarios u on u.empresa_id = s.empresa_id
      where s.id = empresa_servicos_galeria.servico_id
        and u.id = (select auth.uid())
        and u.ativo = true
        and (u.is_admin_empresa = true or u.is_admin = true)
    )
  );

create index if not exists empresa_servicos_galeria_servico_idx
  on public.empresa_servicos_galeria (servico_id);
