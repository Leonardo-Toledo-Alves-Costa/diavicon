-- "permission denied for table empresas" on every attempt to edit company
-- info, for every admin, regardless of the RLS policy fixed in
-- 20260917110000_company_update_any_admin.sql — confirmed live (simulated
-- the exact UPDATE as a real is_admin_empresa=true user, reproduced the
-- error) that `public.empresas` was simply never GRANTed UPDATE for the
-- `authenticated` role (information_schema.role_table_grants showed only
-- DELETE/REFERENCES/SELECT/TRIGGER/TRUNCATE — no UPDATE, no INSERT). A
-- missing table-level GRANT is checked before RLS ever runs, so no policy
-- fix alone could have unblocked this.
--
-- empresa_informacoes_screen.dart only ever calls
-- `supabase.from('empresas').update(...)` directly (company creation goes
-- through the complete_self_registration RPC, which runs as a privileged
-- definer and doesn't need this grant) — so UPDATE is the only privilege
-- actually missing for the app's real usage.

begin;

grant update on public.empresas to authenticated;

notify pgrst, 'reload schema';

commit;
