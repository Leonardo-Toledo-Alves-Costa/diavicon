-- APLICADA no Supabase de produção em 21/09/2026 (SQL Editor).
-- Cota de armazenamento por plano + coluna `dashboard` em `planos`.
--
-- Depende de 20260919120000_regras_modulos_plano.sql (usa as mesmas funções
-- private.* de empresa ativa e o mesmo padrão de mensagem).
--
-- COMO O USO É MEDIDO (híbrido)
--   Arquivos  → bytes REAIS, somando storage.objects.metadata->>'size' de todos
--               os arquivos enviados por usuários da empresa (dono = quem subiu).
--               Vale para o que já existe e para o que vier, sem mudar os pontos
--               de upload do app. PDFs contam como "relatórios", o resto como
--               "fotos".
--   Dados     → ESTIMATIVA: 2 KB por projeto, estrutura, elemento e ponto de
--               ensaio (a mesma conta que o app já fazia).
--   Arquivos enviados sem usuário (service role, painel) não entram na conta.
--
-- O QUE ACONTECE QUANDO ENCHE
--   • Uploads no Storage são recusados (política restritiva de INSERT).
--   • Toda criação de conteúdo é recusada (gatilho por comando, antes do
--     INSERT) nas tabelas listadas no bloco "Tabelas de conteúdo".
--   • Ler, editar e APAGAR continuam liberados — apagar é como a pessoa libera
--     espaço. Pedido de troca de plano, cadastro, convite, curtida e
--     comentário também continuam liberados.
--
-- Gravações sem usuário logado (service role, edge functions, SQL no painel)
-- não passam pela regra.
--
-- Pode rodar mais de uma vez sem erro.

begin;

-- ---------------------------------------------------------------------------
-- Coluna do módulo Dashboard (plano Avançado em diante)
-- ---------------------------------------------------------------------------
alter table public.planos add column if not exists dashboard boolean not null default false;

-- Módulo dashboard no bloqueio genérico (mesma mensagem padrão).
create or replace function private.exigir_modulo_plano(p_empresa_id uuid, p_modulo text)
returns void
language plpgsql
stable
security definer
set search_path = public, pg_catalog
as $$
declare
  v_plano public.planos;
  v_liberado boolean;
  v_nome text;
begin
  if p_empresa_id is null then
    raise exception using errcode = 'P0001',
      message = 'Seu usuário não está vinculado a uma empresa.';
  end if;

  v_plano := private.plano_da_empresa(p_empresa_id);

  v_liberado := case p_modulo
    when 'monitor' then coalesce(v_plano.monitor, false)
    when 'gerar_relatorio' then coalesce(v_plano.gerar_relatorio, false)
    when 'rdo_gastos' then coalesce(v_plano.rdo_gastos, false)
    when 'servicos' then coalesce(v_plano.servicos, false)
    when 'publicar_feed_edu' then coalesce(v_plano.publicar_feed_edu, false)
    when 'dashboard' then coalesce(v_plano.dashboard, false)
    when 'tokens_publicidade' then coalesce(v_plano.tokens_publicidade, 0) > 0
    else false
  end;

  if v_liberado then
    return;
  end if;

  v_nome := case p_modulo
    when 'monitor' then 'o monitoramento de estruturas'
    when 'gerar_relatorio' then 'a geração de relatórios'
    when 'rdo_gastos' then 'o RDO e o controle de gastos'
    when 'servicos' then 'o cadastro de serviços'
    when 'publicar_feed_edu' then 'publicar no feed'
    when 'dashboard' then 'o dashboard'
    when 'tokens_publicidade' then 'patrocinar publicações no feed'
    else 'este recurso'
  end;

  raise exception using errcode = 'P0001',
    message = format('Seu plano atual não inclui %s. Para aumentar o seu plano, entre em contato com o time de vendas da Diavicon.', v_nome);
end;
$$;

revoke all on function private.exigir_modulo_plano(uuid, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Uso de armazenamento (bytes)
-- storage.objects tem `owner` (uuid) e, nas versões novas, `owner_id` (text).
-- A função é criada conforme as colunas que existirem neste projeto.
-- ---------------------------------------------------------------------------
do $do$
declare
  v_dono text;
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'storage' and table_name = 'objects' and column_name = 'owner_id'
  ) then
    v_dono := 'coalesce(o.owner_id, o.owner::text)';
  else
    v_dono := 'o.owner::text';
  end if;

  execute format($f$
    create or replace function private.uso_armazenamento_bytes(p_empresa uuid)
    returns table (dados_bytes bigint, fotos_bytes bigint, relatorios_bytes bigint)
    language sql
    stable
    security definer
    set search_path = public, pg_catalog
    as $body$
      with membros as (
        select u.id::text as id from public.usuarios u where u.empresa_id = p_empresa
      ),
      arquivos as (
        select
          coalesce(sum((o.metadata->>'size')::bigint) filter (
            where coalesce(o.metadata->>'mimetype', '') <> 'application/pdf'
              and o.name not ilike '%%.pdf'), 0)::bigint as fotos,
          coalesce(sum((o.metadata->>'size')::bigint) filter (
            where o.metadata->>'mimetype' = 'application/pdf'
               or o.name ilike '%%.pdf'), 0)::bigint as relatorios
        from storage.objects o
        where %s in (select id from membros)
      ),
      estr as (
        select s.id from public.estruturas s
        where s.empresa_gestora_id = p_empresa or s.proprietaria_id = p_empresa
      ),
      linhas as (
        select
          (select count(*) from estr)
          + (select count(*) from public.elementos_estruturais e where e.estrutura_id in (select id from estr))
          + (select count(*) from public.pontos_ensaios_geral p where p.estrutura_id in (select id from estr))
          + (select count(*) from public.projetos pr
             where pr.empresa_gestora_id = p_empresa or pr.empresa_cliente_id = p_empresa) as n
      )
      select (linhas.n * 2048)::bigint, arquivos.fotos, arquivos.relatorios
      from linhas, arquivos
    $body$;
  $f$, v_dono);
end;
$do$;

revoke all on function private.uso_armazenamento_bytes(uuid) from public, anon, authenticated;

-- Limite do plano em bytes (null = sem plano ou sem limite definido).
create or replace function private.limite_armazenamento_bytes(p_empresa uuid)
returns bigint
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select case when p.armazenamento_mb is null or p.armazenamento_mb <= 0 then null
              else p.armazenamento_mb::bigint * 1024 * 1024 end
  from public.empresas e
  join public.planos p on p.id = e.plano_id
  where e.id = p_empresa
$$;

revoke all on function private.limite_armazenamento_bytes(uuid) from public, anon, authenticated;

-- true quando a empresa do usuário logado já atingiu o limite.
-- Sem usuário, sem empresa ou sem limite definido: não bloqueia.
create or replace function private.armazenamento_esgotado_ator()
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_catalog
as $$
declare
  v_empresa uuid;
  v_limite bigint;
  v_uso record;
begin
  if (select auth.uid()) is null then
    return false;
  end if;
  v_empresa := private.active_actor_company_id();
  if v_empresa is null then
    return false;
  end if;
  v_limite := private.limite_armazenamento_bytes(v_empresa);
  if v_limite is null then
    return false;
  end if;
  select * into v_uso from private.uso_armazenamento_bytes(v_empresa);
  return (v_uso.dados_bytes + v_uso.fotos_bytes + v_uso.relatorios_bytes) >= v_limite;
end;
$$;

revoke all on function private.armazenamento_esgotado_ator() from public, anon;
-- Precisa ser executável por `authenticated` porque é chamada dentro da
-- política do Storage, que roda com o papel de quem faz o upload.
grant execute on function private.armazenamento_esgotado_ator() to authenticated;

-- Uso da empresa do usuário logado, em MB, para a tela "Meu Plano".
create or replace function public.uso_armazenamento_empresa()
returns table (dados_mb numeric, fotos_mb numeric, relatorios_mb numeric, total_mb numeric, limite_mb integer)
language plpgsql
stable
security definer
set search_path = public, pg_catalog
as $$
declare
  v_empresa uuid := private.active_actor_company_id();
  v_uso record;
  v_limite integer;
begin
  if v_empresa is null then
    return;
  end if;
  select * into v_uso from private.uso_armazenamento_bytes(v_empresa);
  select p.armazenamento_mb into v_limite
  from public.empresas e join public.planos p on p.id = e.plano_id
  where e.id = v_empresa;

  dados_mb := round(v_uso.dados_bytes / 1048576.0, 2);
  fotos_mb := round(v_uso.fotos_bytes / 1048576.0, 2);
  relatorios_mb := round(v_uso.relatorios_bytes / 1048576.0, 2);
  total_mb := dados_mb + fotos_mb + relatorios_mb;
  limite_mb := coalesce(v_limite, 0);
  return next;
end;
$$;

revoke all on function public.uso_armazenamento_empresa() from public, anon;
grant execute on function public.uso_armazenamento_empresa() to authenticated;

-- ---------------------------------------------------------------------------
-- Bloqueio das criações
-- ---------------------------------------------------------------------------
create or replace function private.trg_exigir_armazenamento()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if private.armazenamento_esgotado_ator() then
    raise exception using errcode = 'P0001',
      message = 'O armazenamento do seu plano está cheio. Apague arquivos que não usa mais ou entre em contato com o time de vendas da Diavicon para aumentar o seu plano.';
  end if;
  return null;
end;
$$;

revoke all on function private.trg_exigir_armazenamento() from public, anon, authenticated;

-- Tabelas de conteúdo. Um gatilho POR COMANDO (não por linha): um lote de
-- leituras custa uma checagem só. Tabelas que não existirem são ignoradas.
do $do$
declare
  v_tabela text;
  v_lista text[] := array[
    'projetos', 'projeto_estruturas',
    'estruturas', 'estruturas_locais', 'estruturas_plantas',
    'elementos_estruturais', 'anomalias',
    'pontos_ensaios_geral', 'ensaios_contratados',
    'relatorio_ensaio', 'relatorio_rdo', 'modelos_relatorios', 'modelo_relatorio_rdo',
    'rdo_realizado', 'rdo_galeria', 'gastos',
    'empresa_servicos', 'empresa_servicos_galeria',
    'feed_posts', 'feed_fotos',
    'dashboard_modelos', 'variavel_bi', 'simulacao_bi'
  ];
begin
  -- Todas as tabelas de pontos, leituras, medições e galerias de ensaio.
  select v_lista || coalesce(array_agg(t.table_name::text order by t.table_name), '{}')
  into v_lista
  from information_schema.tables t
  where t.table_schema = 'public'
    and t.table_type = 'BASE TABLE'
    and (t.table_name like 'ponto\_ensaio\_%' or t.table_name like 'ponto\_inspecao\_%'
         or t.table_name like 'galeria\_%');

  foreach v_tabela in array v_lista loop
    if to_regclass(format('public.%I', v_tabela)) is not null then
      execute format('drop trigger if exists plano_exige_armazenamento on public.%I', v_tabela);
      execute format(
        'create trigger plano_exige_armazenamento before insert on public.%I '
        'for each statement execute function private.trg_exigir_armazenamento()',
        v_tabela);
    end if;
  end loop;
end;
$do$;

-- Uploads no Storage: política RESTRITIVA (soma-se às permissivas que já
-- existem; não libera nada novo, só recusa quando o espaço acabou).
drop policy if exists plano_armazenamento_upload on storage.objects;
create policy plano_armazenamento_upload on storage.objects
as restrictive
for insert to authenticated
with check (not private.armazenamento_esgotado_ator());

commit;
