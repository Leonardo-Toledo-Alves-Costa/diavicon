-- Preventive audit (requested after the empresas/usuarios grant bugs): a
-- scan of every `.from(table).insert/update/upsert/delete(...)` call in
-- lib/ against information_schema.role_table_grants for the `authenticated`
-- role found one more real grant gap:
--
-- `notificacoes` had SELECT but no UPDATE. "Marcar como lida"
-- (lib/features/notificacoes/repositories/notificacoes_repository.dart:41,
-- lib/features/projetos/repositories/empresas_projeto_repository.dart:208)
-- silently fails to persist (Postgrest just returns 0 rows updated, no
-- thrown error) every time.
--
-- The audit also flagged `plantas` as missing every grant, including
-- SELECT — but `public.plantas` doesn't exist at all; the real table is
-- `estruturas_plantas` (confirmed live: right columns, full grants, RLS not
-- even enabled). That's a client-side wrong-table-name bug, not a DB
-- permissions issue — fixed in lib/features/elementos/screens/
-- planejamento_screen.dart instead, no migration needed for it.

begin;

grant update on public.notificacoes to authenticated;

notify pgrst, 'reload schema';

commit;
