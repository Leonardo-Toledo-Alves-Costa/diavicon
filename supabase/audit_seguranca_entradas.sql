-- Auditoria de segurança (SOMENTE LEITURA — não altera nada).
-- Rodar no SQL Editor do Supabase de produção. Complementa
-- SEGURANCA_LOGIN_E_ENTRADAS.md.
--
-- As migrations do repositório não têm SQL dinâmico, mas o banco de
-- produção tem funções criadas antes delas. Estas consultas procuram, no
-- banco real, os pontos onde um texto vindo do app PODERIA virar SQL.

-- 1) Funções com SQL dinâmico (EXECUTE). Revise cada uma: valores devem
--    entrar por `EXECUTE ... USING $1` ou `format('%L')`/`format('%I')`,
--    nunca concatenados com || ou format('%s').
select n.nspname as schema, p.proname as funcao,
       pg_get_function_identity_arguments(p.oid) as argumentos,
       p.prosecdef as security_definer
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private')
  and p.prokind = 'f'
  and p.prosrc ~* '\mexecute\M'
order by 1, 2;

-- 2) Das anteriores, as que concatenam texto na hora de montar o SQL
--    (sinal forte de injeção). Resultado esperado: nenhuma linha.
select n.nspname as schema, p.proname as funcao
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private')
  and p.prokind = 'f'
  and p.prosrc ~* '\mexecute\M'
  and (p.prosrc ~* 'execute\s+[^;]*\|\|' or p.prosrc ~* 'format\s*\([^)]*%s')
order by 1, 2;

-- 3) Funções SECURITY DEFINER sem search_path fixo (podem ser sequestradas
--    por um objeto com o mesmo nome em outro schema). Esperado: nenhuma.
select n.nspname as schema, p.proname as funcao
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private')
  and p.prosecdef
  and not exists (
    select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%'
  )
order by 1, 2;

-- 4) Funções que qualquer usuário logado (ou anônimo) pode chamar pela API.
--    Confira se cada uma deveria mesmo ser pública.
select n.nspname as schema, p.proname as funcao,
       has_function_privilege('anon', p.oid, 'execute') as anon,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.prokind = 'f'
  and (has_function_privilege('anon', p.oid, 'execute')
       or has_function_privilege('authenticated', p.oid, 'execute'))
order by anon desc, 2;

-- 5) Tabelas do schema public sem RLS (acessíveis pela API sem regra).
--    Esperado: nenhuma linha.
select c.relname as tabela
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
order by 1;
