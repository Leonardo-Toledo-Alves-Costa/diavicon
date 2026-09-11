-- Apply only after the preflight query reports no unresolved regions.
-- The first remaining-RLS migration deliberately leaves ambiguous historical
-- rows with projeto_id NULL, which makes them inaccessible through the API.
-- This migration refuses to guess a project and reports every row that still
-- needs an explicit business decision before making the column mandatory.

begin;

do $$
declare
  v_ids text;
begin
  select string_agg(r.id::text, ', ' order by r.id::text)
    into v_ids
  from public.regioes_ensaio r
  where r.projeto_id is null;

  if v_ids is not null then
    raise exception using
      errcode = 'check_violation',
      message = 'Saneamento obrigatório: regioes_ensaio sem projeto_id: ' || v_ids;
  end if;
end;
$$;

alter table public.regioes_ensaio
  alter column projeto_id set not null;

commit;
