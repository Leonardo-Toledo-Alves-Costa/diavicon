-- Same root cause as 20260917130000_grant_empresas_update.sql:
-- "permission denied for table usuarios" when a user edits their own
-- profile. `AuthRepository.salvarPerfil` (lib/features/auth/repositories/
-- auth_repository.dart:132-137) calls `supabase.from('usuarios').update(...)`
-- directly with the regular authenticated client — and `public.usuarios`
-- was never GRANTed UPDATE for the `authenticated` role (confirmed live via
-- information_schema.role_table_grants: only DELETE/REFERENCES/SELECT/
-- TRIGGER/TRUNCATE). The RLS policy itself (`auth_users_update_own`,
-- supabase/migrations/20260902110000_auth_rls_active_state.sql) already
-- correctly scopes this to the caller's own row — it just never had a
-- chance to run, since the missing table-level GRANT is checked first.
--
-- Other writes to `usuarios` (registration, invites, admin actions) go
-- through SECURITY DEFINER RPCs / the service-role Edge Function, which
-- don't need this grant — so UPDATE is the only privilege missing for the
-- app's actual direct-client usage.

begin;

grant update on public.usuarios to authenticated;

notify pgrst, 'reload schema';

commit;
