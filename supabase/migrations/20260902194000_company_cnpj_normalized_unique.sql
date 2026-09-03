-- CNPJ uniqueness must be enforced on its normalized digits, not on display
-- punctuation. Existing duplicate normalized values were checked before this
-- migration was applied and none were present.
create unique index if not exists empresas_cnpj_digits_unique_idx
  on public.empresas ((regexp_replace(cnpj, '[^0-9]', '', 'g')))
  where cnpj is not null;
