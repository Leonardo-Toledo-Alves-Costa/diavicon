-- Dados mínimos de autoria para exibição (logo da empresa + avatar do autor).
--
-- Por que uma função em vez de select direto em `usuarios`: a policy
-- auth_users_select_own (20260902190000) deixa cada usuário ler apenas a
-- própria linha, de propósito — `usuarios` guarda email, celular,
-- escolaridade e redes sociais, que não podem vazar pra montar um avatar.
--
-- Isso tem um efeito colateral que já existe hoje: o card de ponto de ensaio
-- busca o logo com um select direto em `usuarios` filtrando pelos autores, e
-- sob essa policy ele só retorna a linha do próprio usuário. Na prática o
-- logo da empresa só aparece nos pontos criados pelo próprio observador; nos
-- dos colegas cai no placeholder. Esta função corrige isso.
--
-- A regra de visibilidade fica no banco, não na tela: nome e foto do autor
-- só saem quando quem chama pertence à mesma empresa. Se ficasse só no
-- Flutter, bastaria ler a API pra ver a foto de qualquer um. O logo da
-- empresa é visível a qualquer autenticado — é a informação de "de qual
-- empresa veio este registro", que o card de ponto já pretendia mostrar.

begin;

create or replace function public.autores_para_exibicao(p_ids uuid[])
returns table (
  autor_id uuid,
  autor_empresa_id uuid,
  empresa_nome text,
  empresa_logo_url text,
  autor_nome text,
  autor_foto_url text
)
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  -- Os ::text são obrigatórios, não cosméticos: se alguma dessas colunas for
  -- `character varying` no schema, o RETURNS TABLE declarado como `text`
  -- falha em tempo de execução com "structure of query does not match
  -- function result type".
  select
    u.id,
    u.empresa_id,
    e.nome::text,
    e.foto_url::text,
    -- active_actor_company_id() é null pra quem ainda não tem empresa ativa;
    -- o teste explícito de "is not null" evita que dois usuários sem empresa
    -- sejam tratados como colegas.
    case
      when private.active_actor_company_id() is not null
       and u.empresa_id = private.active_actor_company_id()
      then nullif(btrim(coalesce(u.nome, '') || ' ' || coalesce(u.sobrenome, '')), '')::text
    end,
    case
      when private.active_actor_company_id() is not null
       and u.empresa_id = private.active_actor_company_id()
      then u.foto_url::text
    end
  from public.usuarios u
  left join public.empresas e on e.id = u.empresa_id
  where u.id = any(p_ids)
    and (select auth.uid()) is not null;
$$;

revoke all on function public.autores_para_exibicao(uuid[]) from public, anon;
grant execute on function public.autores_para_exibicao(uuid[]) to authenticated;

commit;
