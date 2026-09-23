-- The `avatars` and `empresas` storage buckets have zero RLS policies
-- anywhere in this repo's migration history (only the `projetos` bucket got
-- policies, in migrations_manual/20260903120000_harden_home_projects_rls.sql,
-- which also flipped `storage.objects` RLS on for every bucket). With RLS on
-- and no matching policy, every insert/update/delete against these two
-- buckets is denied for every user — this is the "bucket doesn't recognize
-- the logged-in user as part of the company" symptom: it isn't a broken
-- membership check, it's the absence of any policy at all.
--
-- Paths actually used by the client (see lib/features/empresa/repositories/
-- empresa_repository.dart, lib/features/empresa/screens/
-- empresa_informacoes_screen.dart, lib/features/auth/repositories/
-- auth_repository.dart, lib/features/auth/screens/completar_cadastro_screen.dart):
--   avatars/usuarios/<uid>_<timestamp>.<ext>   (user avatar)
--   avatars/perfis/<uid>-<timestamp>.<ext>     (user avatar, alt flow)
--   avatars/empresas/<timestamp>.<ext>         (company logo at signup time —
--                                                no empresa_id in the path;
--                                                legacy/unscoped by design)
--   empresas/<empresa_id>/capa_<timestamp>.<ext>
--   empresas/<empresa_id>/logo_<timestamp>.<ext>

begin;

-- RLS on storage.objects is already enabled project-wide (see
-- migrations_manual/20260903120000_harden_home_projects_rls.sql). Toggling
-- it again requires table OWNERSHIP, which the pooled `postgres` role used
-- to apply this migration does not have (CREATE POLICY below only needs a
-- grant, which it does have) — so this migration does not re-run that ALTER
-- TABLE. If you're bootstrapping a fresh project where RLS was never
-- enabled on storage.objects, run that first, separately, as the table
-- owner (e.g. via the Supabase SQL Editor, which runs as a privileged role).

drop policy if exists dv_avatars_select_allow on storage.objects;
drop policy if exists dv_avatars_insert_own on storage.objects;
drop policy if exists dv_avatars_update_own on storage.objects;
drop policy if exists dv_avatars_delete_own on storage.objects;
drop policy if exists dv_empresas_bucket_select_allow on storage.objects;
drop policy if exists dv_empresas_bucket_write_admin on storage.objects;
drop policy if exists dv_empresas_bucket_update_admin on storage.objects;
drop policy if exists dv_empresas_bucket_delete_admin on storage.objects;

-- ---------------------------------------------------------------------------
-- `avatars` bucket — read is open to any authenticated user (same posture as
-- the existing `projetos` bucket policy); writes are scoped to the owner's
-- own uid embedded in the filename for `usuarios/` and `perfis/`, and left
-- open (but authenticated-only) for the unscoped legacy `empresas/` subpath.
-- ---------------------------------------------------------------------------

create policy dv_avatars_select_allow
on storage.objects as permissive
for select to authenticated
using (bucket_id = 'avatars');

create policy dv_avatars_insert_own
on storage.objects as permissive
for insert to authenticated
with check (
  bucket_id = 'avatars'
  and (
    (
      (storage.foldername(name))[1] in ('usuarios', 'perfis')
      and split_part((regexp_replace(name, '^[^/]+/', '')), '_', 1) = auth.uid()::text
    )
    or (
      (storage.foldername(name))[1] in ('usuarios', 'perfis')
      and split_part((regexp_replace(name, '^[^/]+/', '')), '-', 1) = auth.uid()::text
    )
    or (storage.foldername(name))[1] = 'empresas'
    or (storage.foldername(name))[1] = 'feed'
  )
);

create policy dv_avatars_update_own
on storage.objects as permissive
for update to authenticated
using (
  bucket_id = 'avatars'
  and (
    (
      (storage.foldername(name))[1] in ('usuarios', 'perfis')
      and (
        split_part((regexp_replace(name, '^[^/]+/', '')), '_', 1) = auth.uid()::text
        or split_part((regexp_replace(name, '^[^/]+/', '')), '-', 1) = auth.uid()::text
      )
    )
    or (storage.foldername(name))[1] = 'empresas'
    or (storage.foldername(name))[1] = 'feed'
  )
)
with check (
  bucket_id = 'avatars'
  and (
    (
      (storage.foldername(name))[1] in ('usuarios', 'perfis')
      and (
        split_part((regexp_replace(name, '^[^/]+/', '')), '_', 1) = auth.uid()::text
        or split_part((regexp_replace(name, '^[^/]+/', '')), '-', 1) = auth.uid()::text
      )
    )
    or (storage.foldername(name))[1] = 'empresas'
    or (storage.foldername(name))[1] = 'feed'
  )
);

create policy dv_avatars_delete_own
on storage.objects as permissive
for delete to authenticated
using (
  bucket_id = 'avatars'
  and (
    (
      (storage.foldername(name))[1] in ('usuarios', 'perfis')
      and (
        split_part((regexp_replace(name, '^[^/]+/', '')), '_', 1) = auth.uid()::text
        or split_part((regexp_replace(name, '^[^/]+/', '')), '-', 1) = auth.uid()::text
      )
    )
    or (storage.foldername(name))[1] = 'empresas'
    or (storage.foldername(name))[1] = 'feed'
  )
);

-- ---------------------------------------------------------------------------
-- `empresas` bucket — path is always `<empresa_id>/...`. Read is open to any
-- authenticated user (company photos aren't sensitive); writes require the
-- caller to be an ACTIVE user whose own `usuarios.empresa_id` matches the
-- folder AND who is an admin of that company (primary or secondary) —
-- mirroring the `auth_companies_update_admin` policy on `public.empresas`
-- itself as widened by 20260917110000_company_update_any_admin.sql, so
-- bucket write access follows the exact same rule as editing the company row.
-- ---------------------------------------------------------------------------

create policy dv_empresas_bucket_select_allow
on storage.objects as permissive
for select to authenticated
using (bucket_id = 'empresas');

create policy dv_empresas_bucket_write_admin
on storage.objects as permissive
for insert to authenticated
with check (
  bucket_id = 'empresas'
  and exists (
    select 1
    from public.usuarios u
    where u.id = auth.uid()
      and u.ativo = true
      and (u.is_admin_empresa = true or u.is_admin = true)
      and u.empresa_id::text = (storage.foldername(name))[1]
  )
);

create policy dv_empresas_bucket_update_admin
on storage.objects as permissive
for update to authenticated
using (
  bucket_id = 'empresas'
  and exists (
    select 1
    from public.usuarios u
    where u.id = auth.uid()
      and u.ativo = true
      and (u.is_admin_empresa = true or u.is_admin = true)
      and u.empresa_id::text = (storage.foldername(name))[1]
  )
)
with check (
  bucket_id = 'empresas'
  and exists (
    select 1
    from public.usuarios u
    where u.id = auth.uid()
      and u.ativo = true
      and (u.is_admin_empresa = true or u.is_admin = true)
      and u.empresa_id::text = (storage.foldername(name))[1]
  )
);

create policy dv_empresas_bucket_delete_admin
on storage.objects as permissive
for delete to authenticated
using (
  bucket_id = 'empresas'
  and exists (
    select 1
    from public.usuarios u
    where u.id = auth.uid()
      and u.ativo = true
      and (u.is_admin_empresa = true or u.is_admin = true)
      and u.empresa_id::text = (storage.foldername(name))[1]
  )
);

notify pgrst, 'reload schema';

commit;
