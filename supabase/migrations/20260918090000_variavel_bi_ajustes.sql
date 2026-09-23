-- Ajustes em `variavel_bi` (tabela criada manualmente no Supabase).
--
-- O CREATE TABLE original tinha alguns pontos que quebram em uso real. O
-- mais grave:
--
--   criado_por  uuid DEFAULT gen_random_uuid()
--   empresa_id  uuid DEFAULT gen_random_uuid()
--
-- São chaves estrangeiras com default aleatório — artefato do editor de
-- tabelas do Supabase, que replica o default da PK nas demais colunas uuid.
-- Qualquer insert que omita essas colunas gera um uuid que não existe em
-- `usuarios`/`empresas` e falha na hora com violação de FK. Não é um risco
-- teórico: é a primeira coisa que acontece ao salvar sem informar o autor.
--
-- Os demais ajustes seguem convenções já estabelecidas no schema.

begin;

-- ── 1. Defaults aleatórios em FK ───────────────────────────────────────────
alter table public.variavel_bi alter column criado_por drop default;
alter table public.variavel_bi alter column empresa_id drop default;

-- ── 2. Dono é obrigatório ──────────────────────────────────────────────────
-- Todo o mecanismo de "padrão DIAVICON vs. variável da empresa" é decidido
-- por empresa_id (mesmo padrão de dashboard_modelos, que filtra com
-- `empresa_id.eq.<empresa>,empresa_id.eq.<DIAVICON>`). Uma linha com
-- empresa_id nulo não pertence a ninguém e fica invisível pra esse filtro.
alter table public.variavel_bi alter column empresa_id set not null;

-- ── 3. Conteúdo mínimo pra variável ser utilizável ─────────────────────────
-- Sem nome, expressão ou entradas a variável não pode ser avaliada, e o app
-- teria que se defender disso em todo ponto de leitura.
alter table public.variavel_bi alter column nome set not null;
alter table public.variavel_bi alter column expressao set not null;
alter table public.variavel_bi alter column entradas set not null;

-- ── 4. Excluir colaborador não pode travar na FK ───────────────────────────
-- Mesma razão de 20260917220000: a autoria é histórico, não é "dado do
-- usuário" — desvincula em vez de bloquear a exclusão.
alter table public.variavel_bi
  drop constraint if exists variavel_bi_criado_por_fkey;
alter table public.variavel_bi
  add constraint variavel_bi_criado_por_fkey
    foreign key (criado_por) references public.usuarios(id) on delete set null;

-- ── 5. Estrutura em jsonb, não text ────────────────────────────────────────
-- `entradas` é uma lista de {alias, fonte, campo, estatistica} e `parametros`
-- um mapa de coeficientes. Em jsonb dá pra responder "quais variáveis usam
-- ultrassom?" numa query em vez de carregar tudo e filtrar no app — que é
-- exatamente o que a tela de dashboard precisa pra saber se a variável é
-- calculável no contexto atual.
alter table public.variavel_bi
  alter column entradas type jsonb using entradas::jsonb,
  alter column parametros type jsonb using parametros::jsonb;

-- ── 6. Faixa esperada ──────────────────────────────────────────────────────
-- Validação que pega o erro real de campo: coeficiente na ordem errada ou
-- unidade trocada (km/s em vez de m/s) produz um número que roda sem erro
-- nenhum. Comparar com a faixa plausível é o que denuncia. Nulo = sem
-- verificação.
alter table public.variavel_bi add column if not exists valor_min double precision;
alter table public.variavel_bi add column if not exists valor_max double precision;

-- ── 7. Linhagem da duplicação ──────────────────────────────────────────────
-- Espelha `modelo_origem_id` de dashboard_modelos: quando a empresa duplica
-- uma variável padrão DIAVICON pra recalibrar os coeficientes, fica
-- registrado de onde ela saiu.
alter table public.variavel_bi add column if not exists variavel_origem_id uuid;
alter table public.variavel_bi
  drop constraint if exists variavel_bi_variavel_origem_id_fkey;
alter table public.variavel_bi
  add constraint variavel_bi_variavel_origem_id_fkey
    foreign key (variavel_origem_id) references public.variavel_bi(id) on delete set null;

create index if not exists variavel_bi_empresa_id_idx on public.variavel_bi (empresa_id);

commit;
