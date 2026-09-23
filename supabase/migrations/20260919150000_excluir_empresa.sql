-- PENDENTE: para a equipe revisar e aplicar. Ainda NÃO está no Supabase.
--
-- Exclusão completa de uma empresa. Apaga os usuários, a empresa e tudo o
-- que é deles. Usada em dois lugares, sempre pela edge function
-- `auth-operations` (service role), nunca direto pelo app:
--   * action `delete_own_company`: o administrador principal apaga a própria
--     empresa (painel da empresa › Excluir conta da empresa);
--   * action `platform_delete_company`: o administrador principal da DIAVICON
--     apaga outra empresa (painel da DIAVICON › Empresas cadastradas).
-- A DIAVICON (96b9a6b9-32d0-453e-9f69-74a2691ac5cc) nunca pode ser apagada:
-- a função recusa, e a edge function também confere.
--
-- Ordem:
--   1. projetos em que a empresa é a gestora (e tudo abaixo deles);
--   2. estruturas geridas pela empresa;
--   3. usuários da empresa (e o que cada um criou);
--   4. a própria empresa (e o que sobrou ligado a ela).
--
-- Tudo que depende de uma linha apagada é tratado pelas chaves estrangeiras
-- lidas do catálogo na hora (private.apagar_em_cascata):
--   * chave OBRIGATÓRIA (NOT NULL), ex. pontos_ensaios_geral.empresa_autora_id:
--     a linha é da empresa apagada e é apagada também;
--     O mesmo vale para colunas chamadas empresa_id ou usuario_id, mesmo
--     quando aceitam nulo, porque indicam o dono da linha;
--   * chave OPCIONAL, ex. projetos.empresa_cliente_id ou elementos.criado_por:
--     só a ligação é limpa (fica nula) e o dado da outra empresa continua.
-- Assim, um projeto de outra empresa em que esta era só cliente continua
-- existindo. Mas os pontos de ensaio que esta empresa fez no projeto de outra
-- empresa são apagados, porque são dela.
--
-- Os arquivos no Storage (fotos, PDFs) não são apagados pelo SQL. A função
-- devolve a lista de arquivos enviados pelos usuários da empresa, e a edge
-- function remove cada um pela API de Storage. Depois apaga as contas de login
-- (auth.users).
--
-- ATENÇÃO para a revisão: rodar primeiro num branch/cópia do banco com uma
-- empresa de teste e conferir o resultado:
--   select public.excluir_empresa_completa('<empresa de teste>');
-- Tudo roda numa transação. Se qualquer passo falhar, nada é apagado.

begin;

-- ---------------------------------------------------------------------------
-- Apaga linhas e, antes, tudo que aponta para elas (cascata manual)
-- ---------------------------------------------------------------------------
create or replace function private.apagar_em_cascata(
  p_tabela regclass,
  p_ids text[],
  p_profundidade integer default 0
)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  fk record;
  v_filhos text[];
  v_tem_id boolean;
begin
  if p_ids is null or cardinality(p_ids) = 0 then
    return;
  end if;
  if p_profundidade > 25 then
    raise exception 'Cascata de exclusão profunda demais em % (verificar ciclo de chaves).', p_tabela;
  end if;

  -- Chaves estrangeiras de uma coluna que apontam para p_tabela.id
  for fk in
    select
      c.conrelid::regclass as tabela_filha,
      a.attname as coluna,
      a.attnotnull as obrigatoria,
      c.confdeltype as ao_apagar
    from pg_constraint c
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
    join pg_attribute ref on ref.attrelid = c.confrelid and ref.attnum = c.confkey[1]
    where c.contype = 'f'
      and c.confrelid = p_tabela
      and cardinality(c.conkey) = 1
      and ref.attname = 'id'
  loop
    -- SET NULL / SET DEFAULT: o próprio banco resolve ao apagar.
    continue when fk.ao_apagar in ('n', 'd');

    -- Colunas chamadas empresa_id / usuario_id indicam DONO da linha (gastos,
    -- categorias, posts do feed, participação em equipe...), mesmo quando o
    -- banco as aceita nulas: essas linhas vão junto.
    if not fk.obrigatoria and fk.ao_apagar <> 'c'
       and fk.coluna not in ('empresa_id', 'usuario_id') then
      -- Ligação opcional: solta a ligação e mantém a linha (dado de terceiros).
      execute format('update %s set %I = null where %I::text = any($1)', fk.tabela_filha, fk.coluna, fk.coluna)
        using p_ids;
    else
      select exists (
        select 1 from pg_attribute
        where attrelid = fk.tabela_filha and attname = 'id' and not attisdropped
      ) into v_tem_id;

      if v_tem_id then
        execute format('select array_agg(id::text) from %s where %I::text = any($1)', fk.tabela_filha, fk.coluna)
          into v_filhos using p_ids;
        -- Autorreferência (ex.: comentário respondendo comentário): evita
        -- voltar para as mesmas linhas.
        if fk.tabela_filha = p_tabela then
          v_filhos := array(select unnest(v_filhos) except select unnest(p_ids));
        end if;
        perform private.apagar_em_cascata(fk.tabela_filha, v_filhos, p_profundidade + 1);
      else
        execute format('delete from %s where %I::text = any($1)', fk.tabela_filha, fk.coluna)
          using p_ids;
      end if;
    end if;
  end loop;

  execute format('delete from %s where id::text = any($1)', p_tabela) using p_ids;
end;
$$;

revoke all on function private.apagar_em_cascata(regclass, text[], integer) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Exclusão da empresa
-- ---------------------------------------------------------------------------
create or replace function public.excluir_empresa_completa(p_empresa_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  c_diavicon constant uuid := '96b9a6b9-32d0-453e-9f69-74a2691ac5cc';
  v_usuarios uuid[];
  v_arquivos jsonb;
  v_ids text[];
begin
  if p_empresa_id is null then
    raise exception using errcode = 'P0001', message = 'Empresa não informada.';
  end if;
  if p_empresa_id = c_diavicon then
    raise exception using errcode = '42501', message = 'A empresa DIAVICON não pode ser excluída.';
  end if;
  if not exists (select 1 from public.empresas where id = p_empresa_id) then
    raise exception using errcode = 'P0002', message = 'Empresa não encontrada.';
  end if;

  select coalesce(array_agg(id), '{}') into v_usuarios
  from public.usuarios where empresa_id = p_empresa_id;

  -- Arquivos enviados pelos usuários da empresa (removidos depois pela
  -- edge function via API de Storage).
  select coalesce(jsonb_agg(jsonb_build_object('bucket', o.bucket_id, 'nome', o.name)), '[]'::jsonb)
  into v_arquivos
  from storage.objects o
  where o.owner = any(v_usuarios);

  -- 1. Projetos geridos pela empresa
  select array_agg(id::text) into v_ids from public.projetos where empresa_gestora_id = p_empresa_id;
  perform private.apagar_em_cascata('public.projetos'::regclass, v_ids);

  -- 2. Estruturas geridas pela empresa
  select array_agg(id::text) into v_ids from public.estruturas where empresa_gestora_id = p_empresa_id;
  perform private.apagar_em_cascata('public.estruturas'::regclass, v_ids);

  -- 3. Usuários da empresa
  perform private.apagar_em_cascata('public.usuarios'::regclass, array(select unnest(v_usuarios)::text));

  -- 4. A empresa
  perform private.apagar_em_cascata('public.empresas'::regclass, array[p_empresa_id::text]);

  return jsonb_build_object(
    'empresa_id', p_empresa_id,
    'usuarios', to_jsonb(v_usuarios),
    'arquivos', v_arquivos
  );
end;
$$;

revoke all on function public.excluir_empresa_completa(uuid) from public, anon, authenticated;
grant execute on function public.excluir_empresa_completa(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- Resumo das empresas cadastradas (painel da DIAVICON)
-- ---------------------------------------------------------------------------
create or replace function public.plataforma_resumo_empresas()
returns table (
  id uuid,
  nome text,
  cnpj text,
  foto_url text,
  criado_em timestamptz,
  plano text,
  qtd_usuarios bigint,
  qtd_projetos bigint,
  qtd_estruturas bigint,
  qtd_pontos_ensaio bigint
)
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select
    e.id,
    e.nome::text,
    e.cnpj::text,
    e.foto_url::text,
    e.criado_em::timestamptz,
    p.nome::text,
    (select count(*) from public.usuarios u where u.empresa_id = e.id),
    (select count(*) from public.projetos pr where pr.empresa_gestora_id = e.id),
    (select count(*) from public.estruturas s where s.empresa_gestora_id = e.id),
    (select count(*) from public.pontos_ensaios_geral pt where pt.empresa_autora_id = e.id)
  from public.empresas e
  left join public.planos p on p.id = e.plano_id
  order by e.criado_em desc nulls last, e.nome
$$;

revoke all on function public.plataforma_resumo_empresas() from public, anon, authenticated;
grant execute on function public.plataforma_resumo_empresas() to service_role;

commit;
