-- Corrige o erro "column reference \"id\" is ambiguous" ao abrir a galeria de
-- um serviço.
--
-- Causa: `list_public_service_gallery` devolve uma tabela cuja primeira coluna
-- se chama `id` (`returns table (id uuid, ...)`). Em PL/pgSQL esse nome de
-- saída vira uma variável visível dentro do corpo da função. A checagem de
-- usuário no começo fazia
--
--     select 1 from public.usuarios where id = v_actor_id and ativo is true
--
-- com `id` SEM qualificar — e aí o Postgres não sabe se `id` é a coluna de
-- `usuarios` ou a coluna de saída da função, e recusa a chamada inteira.
--
-- A correção é só qualificar a referência (`u.id`). As outras duas funções do
-- mesmo arquivo têm a mesma checagem sem qualificar; elas não quebram hoje
-- porque nenhuma delas tem uma coluna de saída chamada `id`, mas ficam
-- qualificadas também para não repetir o problema quando alguém mudar o
-- retorno.
--
-- Nada além do corpo das funções muda: mesma assinatura, mesmas permissões.

begin;

create or replace function public.list_public_service_gallery(p_servico_id uuid)
returns table (id uuid, servico_id uuid, foto_url text)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_actor_id uuid := (select auth.uid());
begin
  if v_actor_id is null or not exists (
    select 1 from public.usuarios u where u.id = v_actor_id and u.ativo is true
  ) then
    raise exception using errcode = '42501', message = 'Usuário ativo é obrigatório.';
  end if;
  return query
  select g.id, g.servico_id, g.foto_url
  from public.empresa_servicos_galeria g
  join public.empresa_servicos s on s.id = g.servico_id
  join public.empresas e on e.id = s.empresa_id and e.ativo is true
  where g.servico_id = p_servico_id
  order by g.criado_em asc, g.id;
end;
$$;

create or replace function public.get_public_company(p_empresa_id uuid)
returns table (
  empresa_id uuid,
  nome text,
  cnpj text,
  descricao text,
  sobre text,
  foto_url text,
  foto_capa text,
  cidade text,
  estado text,
  linkedin text,
  instagram text,
  youtube text,
  site text,
  email_contato text,
  whatsapp text,
  ramo_atuacao text,
  qtd_servicos bigint
)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_actor_id uuid := (select auth.uid());
begin
  if v_actor_id is null or not exists (
    select 1 from public.usuarios u where u.id = v_actor_id and u.ativo is true
  ) then
    raise exception using errcode = '42501', message = 'Usuário ativo é obrigatório.';
  end if;
  return query
  select e.id, e.nome, e.cnpj, e.descricao, e.sobre, e.foto_url, e.foto_capa,
         a.cidade, a.estado, e.linkedin, e.instagram, e.youtube, e.site,
         e.email_contato, e.whatsapp, e.ramo_atuacao, count(s.id)::bigint
  from public.empresas e
  left join public.enderecos a on a.id = e.endereco_id
  left join public.empresa_servicos s on s.empresa_id = e.id
  where e.id = p_empresa_id and e.ativo is true
  group by e.id, e.nome, e.cnpj, e.descricao, e.sobre, e.foto_url, e.foto_capa,
           a.cidade, a.estado, e.linkedin, e.instagram, e.youtube, e.site,
           e.email_contato, e.whatsapp, e.ramo_atuacao;
end;
$$;

create or replace function public.list_public_company_services(
  p_empresa_id uuid default null,
  p_search text default null,
  p_categoria text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  servico_id uuid,
  empresa_id uuid,
  nome text,
  objetivo text,
  foto_principal text,
  categoria text,
  link_anexo text,
  nome_anexo text,
  descricao text,
  empresa_nome text,
  empresa_foto_url text,
  cidade text,
  estado text
)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_actor_id uuid := (select auth.uid());
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_search text := nullif(btrim(p_search), '');
  v_categoria text := nullif(btrim(p_categoria), '');
begin
  if v_actor_id is null or not exists (
    select 1 from public.usuarios u where u.id = v_actor_id and u.ativo is true
  ) then
    raise exception using errcode = '42501', message = 'Usuário ativo é obrigatório.';
  end if;
  return query
  select s.id, s.empresa_id, s.nome, s.objetivo, s.foto_principal, s.categoria,
         s.link_anexo, s.nome_anexo, s.descricao, e.nome, e.foto_url,
         a.cidade, a.estado
  from public.empresa_servicos s
  join public.empresas e on e.id = s.empresa_id and e.ativo is true
  left join public.enderecos a on a.id = e.endereco_id
  where (p_empresa_id is null or s.empresa_id = p_empresa_id)
    and (v_search is null or s.nome ilike '%' || v_search || '%')
    and (v_categoria is null or v_categoria = 'Todos' or s.categoria = v_categoria)
  order by lower(coalesce(s.nome, '')), s.id
  limit v_limit offset v_offset;
end;
$$;

commit;
