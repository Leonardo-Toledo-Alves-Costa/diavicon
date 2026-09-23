-- "Campos personalizáveis" (lib/features/empresa/providers/campos_personalizaveis_provider.dart)
-- is generic client code: every category queries `empresa_id = own OR
-- empresa_id = DIAVICON_EMPRESA_ID` the exact same way. Only `tipos_estrutura`
-- and `tipos_elemento` actually showed Diavicon's default rows to other
-- companies — confirmed live (pg_policies + row counts) that every other
-- category DOES have rows with `empresa_id = '96b9a6b9-...'` (Diavicon), but
-- their SELECT policy never checked for that literal id — only the caller's
-- own company (and, for a couple of tables, NULL). Those rows were invisible
-- to every company except Diavicon itself.
--
-- This migration widens ONLY the SELECT policies (visibility), copying the
-- exact pattern already working on `tipos_estrutura`/`tipos_elemento`. It
-- intentionally does NOT touch INSERT/UPDATE/DELETE — another company must
-- never be able to write to Diavicon's own default rows, only read them.

begin;

-- ---------------------------------------------------------------------------
-- "remaining_*" convention: condicoes_local, revestimentos_elemento,
-- sistemas_habitacionais, tipologias_elemento, anomalias — SELECT only
-- allowed the caller's own company, no Diavicon/global carve-out at all.
-- ---------------------------------------------------------------------------

alter policy remaining_condicoes_local_select
on public.condicoes_local
using (
  private.is_active_actor()
  and (
    empresa_id = private.active_actor_company_id()
    or empresa_id = '96b9a6b9-32d0-453e-9f69-74a2691ac5cc'::uuid
  )
);

alter policy remaining_revestimentos_elemento_select
on public.revestimentos_elemento
using (
  private.is_active_actor()
  and (
    empresa_id = private.active_actor_company_id()
    or empresa_id = '96b9a6b9-32d0-453e-9f69-74a2691ac5cc'::uuid
  )
);

alter policy remaining_sistemas_habitacionais_select
on public.sistemas_habitacionais
using (
  private.is_active_actor()
  and (
    empresa_id = private.active_actor_company_id()
    or empresa_id = '96b9a6b9-32d0-453e-9f69-74a2691ac5cc'::uuid
  )
);

alter policy remaining_tipologias_elemento_select
on public.tipologias_elemento
using (
  private.is_active_actor()
  and (
    empresa_id = private.active_actor_company_id()
    or empresa_id = '96b9a6b9-32d0-453e-9f69-74a2691ac5cc'::uuid
  )
);

alter policy remaining_anomalias_select
on public.anomalias
using (
  private.is_active_actor()
  and (
    empresa_id = private.active_actor_company_id()
    or empresa_id = '96b9a6b9-32d0-453e-9f69-74a2691ac5cc'::uuid
  )
);

-- ---------------------------------------------------------------------------
-- tipologias_estrutura — already treats NULL as global, but Diavicon's rows
-- here use the literal company id, not NULL, so they still weren't visible.
-- ---------------------------------------------------------------------------

alter policy remaining_tipologias_estrutura_select
on public.tipologias_estrutura
using (
  private.is_active_actor()
  and (
    empresa_id is null
    or empresa_id = private.active_actor_company_id()
    or empresa_id = '96b9a6b9-32d0-453e-9f69-74a2691ac5cc'::uuid
  )
);

-- ---------------------------------------------------------------------------
-- utilizacoes_estrutura — older policy style (no `private.*` helpers), same
-- NULL-only gap as tipologias_estrutura.
-- ---------------------------------------------------------------------------

alter policy "Ver globais e da propria empresa"
on public.utilizacoes_estrutura
using (
  empresa_id is null
  or empresa_id = (select usuarios.empresa_id from public.usuarios where usuarios.id = auth.uid())
  or empresa_id = '96b9a6b9-32d0-453e-9f69-74a2691ac5cc'::uuid
);

-- ---------------------------------------------------------------------------
-- tipologias_local — single ALL-commands policy covering select AND write
-- with the exact same "own company only" rule. Can't just widen it in place
-- (that would also let every company INSERT/UPDATE/DELETE Diavicon's own
-- default rows) — split it into the same 4-policy shape every other table
-- here uses, widening only SELECT.
-- ---------------------------------------------------------------------------

drop policy if exists "Isolamento por Empresa" on public.tipologias_local;

create policy tipologias_local_select
on public.tipologias_local
for select
to authenticated
using (
  empresa_id = (select usuarios.empresa_id from public.usuarios where usuarios.id = auth.uid())
  or empresa_id = '96b9a6b9-32d0-453e-9f69-74a2691ac5cc'::uuid
);

create policy tipologias_local_insert
on public.tipologias_local
for insert
to authenticated
with check (
  empresa_id = (select usuarios.empresa_id from public.usuarios where usuarios.id = auth.uid())
);

create policy tipologias_local_update
on public.tipologias_local
for update
to authenticated
using (
  empresa_id = (select usuarios.empresa_id from public.usuarios where usuarios.id = auth.uid())
)
with check (
  empresa_id = (select usuarios.empresa_id from public.usuarios where usuarios.id = auth.uid())
);

create policy tipologias_local_delete
on public.tipologias_local
for delete
to authenticated
using (
  empresa_id = (select usuarios.empresa_id from public.usuarios where usuarios.id = auth.uid())
);

notify pgrst, 'reload schema';

commit;
