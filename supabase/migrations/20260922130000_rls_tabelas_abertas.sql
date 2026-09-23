-- PENDENTE: para a equipe revisar e aplicar. Ainda NÃO está no Supabase.
--
-- RLS nas tabelas que ainda respondem à chave pública (anon).
--
-- POR QUE
--   Um teste com a chave anon (sem login) em 22/09/2026 leu com HTTP 200 as
--   tabelas abaixo, e PATCH/DELETE passaram na checagem de GRANT (204). As
--   cinco estruturais ficaram de fora de 20260909100000_remaining_rls.sql de
--   propósito ("structural-policy work" pendente) e as demais foram criadas
--   pelo painel (que dá GRANT total para anon/authenticated) ou por
--   migrations cujo trecho de RLS não chegou ao banco. Resultado: qualquer
--   pessoa com a chave do app (que é pública) lê e altera estruturas,
--   elementos, RDOs, modelos etc. de TODAS as empresas.
--
-- O QUE FAZ (para cada tabela)
--   * enable row level security;
--   * revoke all de public/anon/authenticated e grant só do necessário para
--     authenticated (planos continua com SELECT para anon: é a tabela de
--     preços);
--   * APAGA todas as policies que já existirem nessas tabelas (inclusive as
--     criadas pelo painel, tipo "Enable read access for all users" com
--     using (true), que anulariam qualquer regra nova porque policies
--     permissivas se somam com OU) e cria o conjunto novo abaixo.
--     Rode a consulta "ANTES DE APLICAR" para guardar as policies atuais.
--
-- NÃO MEXE EM
--   * prova_carga_dinamica, _sensor, _arquivo, _canal, _estagio, _resultado:
--     a RLS delas está em 20260919210000_prova_carga_dinamica_ajuste.sql
--     (pendente) — aplique aquele arquivo.
--   * ultrassom_importacao e ultrassom_importacao_resultado: a RLS está em
--     20260919180000_ultrassom_importacao_equipamento.sql (pendente). Aquele
--     arquivo não revoga o GRANT de anon, então aqui só há um
--     "revoke ... from anon" nessas duas (se existirem). Nada de policy.
--   * gastos / categoria_gastos: 20260918150000_gastos_rls.sql (pendente).
--
-- PRÉ-REQUISITOS (já aplicados em produção)
--   * 20260908010000_project_team_rls_hardening.sql — private.active_actor_company_id,
--     can_access_project, is_active_company_admin, grant usage no schema private.
--   * 20260909100000_remaining_rls.sql — private.is_active_actor,
--     can_access_point, can_edit_point, can_delete_point (RLS dos pontos).
--   * 20260919120000_regras_modulos_plano.sql — os gatilhos de plano
--     (plano_exige_*, plano_limite_monitoradas) continuam como estão; são
--     SECURITY DEFINER e não dependem de RLS.
--   O bloco "PREFLIGHT" aborta sem alterar nada se faltar função, tabela ou
--   coluna esperada (ou se alguma coluna usada nas regras não for uuid).
--
-- ORDEM SUGERIDA
--   1. 20260918150000_gastos_rls.sql            (independente; qualquer ordem)
--   2. 20260919180000_ultrassom_importacao_equipamento.sql
--   3. 20260919210000_prova_carga_dinamica_ajuste.sql
--   4. este arquivo (20260922130000_rls_tabelas_abertas.sql)
--   Este arquivo não depende dos três acima; só não fecha as tabelas deles.
--   Se preferir aplicar este primeiro, tudo bem — mas as tabelas de PCD e de
--   ultrassom_importacao continuam abertas até aqueles arquivos entrarem.
--
-- ACESSO RESULTANTE (resumo — detalhes em cada bloco)
--   Estrutura "visível" = a empresa do usuário é empresa_gestora_id ou
--   proprietaria_id da estrutura, OU a estrutura está vinculada
--   (projeto_estruturas) a um projeto que a empresa acessa
--   (private.can_access_project: gestora, cliente ativo, colaboradora aceita).
--   Estrutura "gerida" = empresa_gestora_id ou proprietaria_id da estrutura,
--   ou gestora de algum projeto ao qual ela está vinculada.
--
-- Pode rodar mais de uma vez sem erro.
--
-- ANTES DE APLICAR (guarde o resultado, serve de rollback):
--   select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
--   from pg_policies
--   where schemaname = 'public'
--     and tablename in ('estruturas','elementos_estruturais','estruturas_locais',
--       'estruturas_plantas','projeto_estruturas','rdo_realizado','rdo_galeria',
--       'relatorio_rdo','modelo_relatorio_rdo','dashboard_modelos','simulacao_bi',
--       'variavel_bi','tipologias_local','tipos_ensaio','planos','notificacoes',
--       'modelos_relatorios','empresa_timestamp_fotos_padrao',
--       'ponto_ensaio_extracao_local','ponto_ensaio_extracao_leituras',
--       'ponto_ensaio_monitoramento_fissura','ponto_ensaio_monitoramento_fissura_leitura',
--       'ponto_ensaio_tracao','ponto_ensaio_tracao_leitura',
--       'ponto_ensaio_ultrassom_mapeamento','ponto_ensaio_ultrassom_mapeamento_leitura',
--       'ponto_ensaio_liquido_penetrante')
--   order by tablename, policyname;

begin;

-- ===========================================================================
-- PREFLIGHT: confere funções, tabelas e colunas antes de mudar qualquer coisa.
-- ===========================================================================
do $$
declare
  v_faltando text[] := '{}';
  v_item text;
  v_tab text;
  v_col text;
  v_tipo text;
begin
  foreach v_item in array array[
    'private.active_actor_company_id()',
    'private.is_active_actor()',
    'private.is_active_company_admin(uuid)',
    'private.can_access_project(uuid)',
    'private.can_access_point(uuid)',
    'private.can_edit_point(uuid)',
    'private.can_delete_point(uuid)'
  ] loop
    if to_regprocedure(v_item) is null then
      v_faltando := v_faltando || v_item;
    end if;
  end loop;

  -- tabela.coluna usada nas regras; todas precisam existir e ser uuid.
  foreach v_item in array array[
    'estruturas.id', 'estruturas.empresa_gestora_id', 'estruturas.proprietaria_id',
    'elementos_estruturais.estrutura_id', 'elementos_estruturais.criado_por',
    'estruturas_locais.estrutura_id',
    'estruturas_plantas.estrutura_id',
    'projeto_estruturas.projeto_id', 'projeto_estruturas.estrutura_id',
    'projetos.id', 'projetos.empresa_gestora_id', 'projetos.empresa_cliente_id',
    'rdo_realizado.id', 'rdo_realizado.projeto_id', 'rdo_realizado.empresa_id',
    'rdo_galeria.rdo_id',
    'relatorio_rdo.projeto_id', 'relatorio_rdo.empresa_autora_id',
    'modelo_relatorio_rdo.empresa_id',
    'dashboard_modelos.empresa_id',
    'simulacao_bi.empresa_id',
    'variavel_bi.empresa_id',
    'tipologias_local.empresa_id',
    'modelos_relatorios.empresa_id',
    'empresa_timestamp_fotos_padrao.empresa_id',
    'notificacoes.usuario_id',
    'ponto_ensaio_ultrassom.id', 'ponto_ensaio_ultrassom.ponto_ensaio_id',
    'ponto_ensaio_extracao_local.id', 'ponto_ensaio_extracao_local.ponto_id',
    'ponto_ensaio_extracao_leituras.ponto_local_id',
    'ponto_ensaio_monitoramento_fissura.id', 'ponto_ensaio_monitoramento_fissura.ponto_ensaio_id',
    'ponto_ensaio_monitoramento_fissura_leitura.ponto_id',
    'ponto_ensaio_tracao.id', 'ponto_ensaio_tracao.ponto_id',
    'ponto_ensaio_tracao_leitura.ponto_id',
    'ponto_ensaio_ultrassom_mapeamento.id', 'ponto_ensaio_ultrassom_mapeamento.ponto_id',
    'ponto_ensaio_ultrassom_mapeamento_leitura.ponto_id',
    'ponto_ensaio_liquido_penetrante.ponto_id'
  ] loop
    v_tab := split_part(v_item, '.', 1);
    v_col := split_part(v_item, '.', 2);
    select c.data_type into v_tipo
    from information_schema.columns c
    where c.table_schema = 'public' and c.table_name = v_tab and c.column_name = v_col;
    if v_tipo is null then
      v_faltando := v_faltando || (v_item || ' (não existe)');
    elsif v_tipo <> 'uuid' then
      v_faltando := v_faltando || (v_item || ' (é ' || v_tipo || ', esperado uuid)');
    end if;
    v_tipo := null;
  end loop;

  foreach v_item in array array['tipos_ensaio', 'planos', 'notificacoes'] loop
    if to_regclass('public.' || v_item) is null then
      v_faltando := v_faltando || ('public.' || v_item || ' (não existe)');
    end if;
  end loop;

  if array_length(v_faltando, 1) > 0 then
    raise exception using
      errcode = '42P01',
      message = 'Preflight de 20260922130000_rls_tabelas_abertas falhou; nada foi alterado.',
      detail = array_to_string(v_faltando, E'\n');
  end if;
end;
$$;

-- ===========================================================================
-- HELPERS NOVOS (schema private, SECURITY DEFINER, só para authenticated)
-- ===========================================================================

-- A estrutura está vinculada a algum projeto que a empresa do usuário acessa
-- (gestora, cliente ativo ou colaboradora aceita).
create or replace function private.estrutura_em_projeto_acessivel(p_estrutura_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.projeto_estruturas pe
    where pe.estrutura_id = p_estrutura_id
      and private.can_access_project(pe.projeto_id)
  )
$$;

-- A estrutura está vinculada a algum projeto cuja GESTORA é a empresa do
-- usuário (mesma regra do app: canEdit = projeto.empresaGestoraId == empresa).
create or replace function private.estrutura_em_projeto_gerido(p_estrutura_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.projeto_estruturas pe
    join public.projetos p on p.id = pe.projeto_id
    where pe.estrutura_id = p_estrutura_id
      and p.empresa_gestora_id = private.active_actor_company_id()
  )
$$;

create or replace function private.pode_ver_estrutura(p_estrutura_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.estruturas e
    where e.id = p_estrutura_id
      and private.active_actor_company_id() is not null
      and (
        e.empresa_gestora_id = private.active_actor_company_id()
        or e.proprietaria_id = private.active_actor_company_id()
        or private.estrutura_em_projeto_acessivel(e.id)
      )
  )
$$;

create or replace function private.pode_gerir_estrutura(p_estrutura_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.estruturas e
    where e.id = p_estrutura_id
      and private.active_actor_company_id() is not null
      and (
        e.empresa_gestora_id = private.active_actor_company_id()
        or e.proprietaria_id = private.active_actor_company_id()
        or private.estrutura_em_projeto_gerido(e.id)
      )
  )
$$;

-- Papéis da empresa do usuário no projeto (espelha PapelEmpresaProjeto em
-- lib/features/projetos/rdo/models/rdo_realizado_model.dart).
create or replace function private.eh_gestora_do_projeto(p_projeto_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1 from public.projetos p
    where p.id = p_projeto_id
      and p.empresa_gestora_id = private.active_actor_company_id()
  )
$$;

create or replace function private.eh_cliente_ativo_do_projeto(p_projeto_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1 from public.projetos p
    where p.id = p_projeto_id
      and p.empresa_cliente_id = private.active_actor_company_id()
      and p.status_vinculo_cliente = 'ativo'
  )
$$;

-- RDO: gestora e cliente ativo veem os RDOs de todas as empresas do projeto;
-- qualquer empresa vê os próprios.
create or replace function private.rdo_pode_ver(p_rdo_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1 from public.rdo_realizado r
    where r.id = p_rdo_id
      and private.active_actor_company_id() is not null
      and (
        r.empresa_id = private.active_actor_company_id()
        or private.eh_gestora_do_projeto(r.projeto_id)
        or private.eh_cliente_ativo_do_projeto(r.projeto_id)
      )
  )
$$;

-- RDO: edita (fotos da galeria) quem é dono do RDO ou gestora do projeto.
create or replace function private.rdo_pode_editar(p_rdo_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1 from public.rdo_realizado r
    where r.id = p_rdo_id
      and private.active_actor_company_id() is not null
      and (
        r.empresa_id = private.active_actor_company_id()
        or private.eh_gestora_do_projeto(r.projeto_id)
      )
  )
$$;

do $$
declare v_sig text;
begin
  foreach v_sig in array array[
    'estrutura_em_projeto_acessivel(uuid)', 'estrutura_em_projeto_gerido(uuid)',
    'pode_ver_estrutura(uuid)', 'pode_gerir_estrutura(uuid)',
    'eh_gestora_do_projeto(uuid)', 'eh_cliente_ativo_do_projeto(uuid)',
    'rdo_pode_ver(uuid)', 'rdo_pode_editar(uuid)'
  ] loop
    execute 'revoke all on function private.' || v_sig || ' from public, anon';
    execute 'grant execute on function private.' || v_sig || ' to authenticated, service_role';
  end loop;
end;
$$;

-- ===========================================================================
-- LIMPEZA: RLS ligada, grants zerados e policies antigas removidas.
-- ===========================================================================
do $$
declare
  v_table text;
  v_policy record;
begin
  foreach v_table in array array[
    'estruturas','elementos_estruturais','estruturas_locais','estruturas_plantas',
    'projeto_estruturas',
    'rdo_realizado','rdo_galeria','relatorio_rdo','modelo_relatorio_rdo',
    'dashboard_modelos','simulacao_bi','variavel_bi',
    'tipologias_local','tipos_ensaio','planos',
    'notificacoes','modelos_relatorios','empresa_timestamp_fotos_padrao',
    'ponto_ensaio_extracao_local','ponto_ensaio_extracao_leituras',
    'ponto_ensaio_monitoramento_fissura','ponto_ensaio_monitoramento_fissura_leitura',
    'ponto_ensaio_tracao','ponto_ensaio_tracao_leitura',
    'ponto_ensaio_ultrassom_mapeamento','ponto_ensaio_ultrassom_mapeamento_leitura',
    'ponto_ensaio_liquido_penetrante'
  ] loop
    execute format('alter table public.%I enable row level security', v_table);
    execute format('revoke all on table public.%I from public, anon, authenticated', v_table);
    for v_policy in
      select policyname from pg_policies
      where schemaname = 'public' and tablename = v_table
    loop
      execute format('drop policy if exists %I on public.%I', v_policy.policyname, v_table);
    end loop;
  end loop;

  -- Só fecha o anon; a RLS dessas duas vem de 20260919180000 (pendente).
  foreach v_table in array array['ultrassom_importacao', 'ultrassom_importacao_resultado'] loop
    if to_regclass('public.' || v_table) is not null then
      execute format('revoke all on table public.%I from public, anon', v_table);
    end if;
  end loop;
end;
$$;

-- ===========================================================================
-- 1. ESTRUTURAS
-- ===========================================================================
-- Leitura (lib/features/estrutura/providers/estrutura_provider.dart):
--   * aba Estruturas: empresa_gestora_id = minha empresa;
--   * "incluir estrutura existente": proprietaria_id/empresa_gestora_id;
--   * dentro do projeto: embed via projeto_estruturas → estruturas(...).
-- Criação: nova_estrutura_body.dart grava empresa_gestora_id = empresa do
--   usuário e proprietaria_id = cliente ativo do projeto (ou a própria).
-- Edição: gestora do projeto (canEdit); transferência de propriedade: a
--   proprietária atual (proprietario_vinculo_section.dart).
-- Exclusão: admin da empresa gestora (estrutura_informacao_screen.dart e
--   project_info_screen.dart, que exclui DEPOIS de apagar o projeto — por
--   isso vale também empresa_gestora_id sem vínculo).
grant select, insert, update, delete on public.estruturas to authenticated;

create policy estruturas_select on public.estruturas
for select to authenticated
using (
  private.is_active_actor()
  and (
    empresa_gestora_id = private.active_actor_company_id()
    or proprietaria_id = private.active_actor_company_id()
    or private.estrutura_em_projeto_acessivel(id)
  )
);

create policy estruturas_insert on public.estruturas
for insert to authenticated
with check (
  private.is_active_actor()
  and empresa_gestora_id = private.active_actor_company_id()
);

-- No WITH CHECK, pode_gerir_estrutura(id) lê a linha ANTERIOR (o snapshot do
-- comando ainda não tem a versão nova): é o que permite à proprietária
-- transferir a propriedade para outra empresa.
create policy estruturas_update on public.estruturas
for update to authenticated
using (
  private.is_active_actor()
  and (
    empresa_gestora_id = private.active_actor_company_id()
    or proprietaria_id = private.active_actor_company_id()
    or private.estrutura_em_projeto_gerido(id)
  )
)
with check (
  private.is_active_actor()
  and (
    empresa_gestora_id = private.active_actor_company_id()
    or proprietaria_id = private.active_actor_company_id()
    or private.pode_gerir_estrutura(id)
  )
);

create policy estruturas_delete on public.estruturas
for delete to authenticated
using (
  private.is_active_company_admin(private.active_actor_company_id())
  and (
    empresa_gestora_id = private.active_actor_company_id()
    or private.estrutura_em_projeto_gerido(id)
  )
);

-- ===========================================================================
-- 2. PROJETO_ESTRUTURAS (vínculo projeto × estrutura)
-- ===========================================================================
-- Lida por todas as empresas do projeto (stream em projetoEstruturasProvider)
-- e pela aba Estruturas (contagem de projetos da estrutura). Inserida ao
-- criar/incluir estrutura; removida ao desvincular. Não há UPDATE no app.
grant select, insert, delete on public.projeto_estruturas to authenticated;

create policy projeto_estruturas_select on public.projeto_estruturas
for select to authenticated
using (
  private.can_access_project(projeto_id)
  or private.pode_gerir_estrutura(estrutura_id)
);

create policy projeto_estruturas_insert on public.projeto_estruturas
for insert to authenticated
with check (
  private.can_access_project(projeto_id)
  and private.pode_gerir_estrutura(estrutura_id)
);

create policy projeto_estruturas_delete on public.projeto_estruturas
for delete to authenticated
using (
  private.eh_gestora_do_projeto(projeto_id)
  or (
    private.can_access_project(projeto_id)
    and private.pode_gerir_estrutura(estrutura_id)
  )
);

-- ===========================================================================
-- 3. ELEMENTOS, LOCAIS E PLANTAS (filhas da estrutura)
-- ===========================================================================
-- ATENÇÃO (revisar): o app cria elementos e locais também pela inspeção
-- visual (registro_inspecao_screen.dart, novo_local_modal.dart), que pode ser
-- feita por colaboradora; a tela de edição de elemento só libera a gestora
-- do projeto, mas atualizações de marcação/inclusão acontecem no
-- planejamento. Para não quebrar nada, criar/editar fica liberado para toda
-- empresa que VÊ a estrutura (inclui o cliente ativo). Excluir fica com quem
-- GERE a estrutura (e, no elemento, também com o próprio autor: o app apaga o
-- elemento recém-criado se o passo seguinte falhar — novo_elem_estrutural_screen.dart).
-- As exclusões em cascata (apagar estrutura/projeto) não passam por RLS.
grant select, insert, update, delete on public.elementos_estruturais to authenticated;

create policy elementos_estruturais_select on public.elementos_estruturais
for select to authenticated
using (private.pode_ver_estrutura(estrutura_id));

create policy elementos_estruturais_insert on public.elementos_estruturais
for insert to authenticated
with check (private.pode_ver_estrutura(estrutura_id));

create policy elementos_estruturais_update on public.elementos_estruturais
for update to authenticated
using (private.pode_ver_estrutura(estrutura_id))
with check (private.pode_ver_estrutura(estrutura_id));

create policy elementos_estruturais_delete on public.elementos_estruturais
for delete to authenticated
using (
  private.pode_gerir_estrutura(estrutura_id)
  or (private.is_active_actor() and criado_por = (select auth.uid()))
);

grant select, insert, update, delete on public.estruturas_locais to authenticated;

create policy estruturas_locais_select on public.estruturas_locais
for select to authenticated
using (private.pode_ver_estrutura(estrutura_id));

create policy estruturas_locais_insert on public.estruturas_locais
for insert to authenticated
with check (private.pode_ver_estrutura(estrutura_id));

create policy estruturas_locais_update on public.estruturas_locais
for update to authenticated
using (private.pode_ver_estrutura(estrutura_id))
with check (private.pode_ver_estrutura(estrutura_id));

create policy estruturas_locais_delete on public.estruturas_locais
for delete to authenticated
using (private.pode_gerir_estrutura(estrutura_id));

grant select, insert, update, delete on public.estruturas_plantas to authenticated;

create policy estruturas_plantas_select on public.estruturas_plantas
for select to authenticated
using (private.pode_ver_estrutura(estrutura_id));

create policy estruturas_plantas_insert on public.estruturas_plantas
for insert to authenticated
with check (private.pode_ver_estrutura(estrutura_id));

create policy estruturas_plantas_update on public.estruturas_plantas
for update to authenticated
using (private.pode_ver_estrutura(estrutura_id))
with check (private.pode_ver_estrutura(estrutura_id));

create policy estruturas_plantas_delete on public.estruturas_plantas
for delete to authenticated
using (private.pode_gerir_estrutura(estrutura_id));

-- ===========================================================================
-- 4. RDO (mesmas regras de 20260914120000/20260916090000/20260917090000/
--    20260916100000, que estavam no papel mas não no banco)
-- ===========================================================================
-- PapelEmpresaProjeto: gestora e cliente ativo veem tudo do projeto;
-- colaboradora vê só o próprio RDO; cliente não cria RDO, só muda o status;
-- excluir: dono do RDO ou gestora.
grant select, insert, update, delete on public.rdo_realizado to authenticated;

create policy rdo_realizado_select on public.rdo_realizado
for select to authenticated
using (
  private.is_active_actor()
  and (
    empresa_id = private.active_actor_company_id()
    or private.eh_gestora_do_projeto(projeto_id)
    or private.eh_cliente_ativo_do_projeto(projeto_id)
  )
);

create policy rdo_realizado_insert on public.rdo_realizado
for insert to authenticated
with check (
  private.is_active_actor()
  and empresa_id = private.active_actor_company_id()
  and private.can_access_project(projeto_id)
  and not private.eh_cliente_ativo_do_projeto(projeto_id)
);

-- Cliente ativo só troca o status pelo app; a RLS não restringe coluna a
-- coluna (mesma granularidade da migration original).
create policy rdo_realizado_update on public.rdo_realizado
for update to authenticated
using (
  private.is_active_actor()
  and (
    empresa_id = private.active_actor_company_id()
    or private.eh_gestora_do_projeto(projeto_id)
    or private.eh_cliente_ativo_do_projeto(projeto_id)
  )
)
with check (
  private.is_active_actor()
  and (
    empresa_id = private.active_actor_company_id()
    or private.eh_gestora_do_projeto(projeto_id)
    or private.eh_cliente_ativo_do_projeto(projeto_id)
  )
);

create policy rdo_realizado_delete on public.rdo_realizado
for delete to authenticated
using (
  private.is_active_actor()
  and (
    empresa_id = private.active_actor_company_id()
    or private.eh_gestora_do_projeto(projeto_id)
  )
);

grant select, insert, update, delete on public.rdo_galeria to authenticated;

create policy rdo_galeria_select on public.rdo_galeria
for select to authenticated
using (private.rdo_pode_ver(rdo_id));

create policy rdo_galeria_insert on public.rdo_galeria
for insert to authenticated
with check (private.rdo_pode_editar(rdo_id));

create policy rdo_galeria_update on public.rdo_galeria
for update to authenticated
using (private.rdo_pode_editar(rdo_id))
with check (private.rdo_pode_editar(rdo_id));

create policy rdo_galeria_delete on public.rdo_galeria
for delete to authenticated
using (private.rdo_pode_editar(rdo_id));

-- Relatórios de RDO: gestora/cliente ativo veem todos do projeto; cada
-- empresa vê, atualiza (status "Gerando" → pronto) e apaga os que gerou.
grant select, insert, update, delete on public.relatorio_rdo to authenticated;

create policy relatorio_rdo_select on public.relatorio_rdo
for select to authenticated
using (
  private.is_active_actor()
  and (
    empresa_autora_id = private.active_actor_company_id()
    or private.eh_gestora_do_projeto(projeto_id)
    or private.eh_cliente_ativo_do_projeto(projeto_id)
  )
);

create policy relatorio_rdo_insert on public.relatorio_rdo
for insert to authenticated
with check (
  private.is_active_actor()
  and empresa_autora_id = private.active_actor_company_id()
  and private.can_access_project(projeto_id)
);

create policy relatorio_rdo_update on public.relatorio_rdo
for update to authenticated
using (private.is_active_actor() and empresa_autora_id = private.active_actor_company_id())
with check (private.is_active_actor() and empresa_autora_id = private.active_actor_company_id());

create policy relatorio_rdo_delete on public.relatorio_rdo
for delete to authenticated
using (private.is_active_actor() and empresa_autora_id = private.active_actor_company_id());

-- ===========================================================================
-- 5. MODELOS POR EMPRESA COM PADRÃO DIAVICON
--    (modelo_relatorio_rdo, modelos_relatorios, dashboard_modelos,
--     variavel_bi, simulacao_bi)
-- ===========================================================================
-- O app lista `empresa_id = minha OR empresa_id = DIAVICON` e grava sempre
-- com empresa_id = empresa do usuário (duplicar = copiar para a minha).
-- Os padrões DIAVICON são editados pelos próprios usuários da DIAVICON
-- (empresa_id deles = DIAVICON), então a regra "própria empresa" já cobre.
-- ATENÇÃO (revisar): qualquer usuário ativo da empresa cria/edita/apaga
-- modelos (é o que o app faz hoje); se isso tiver que ser só do admin,
-- troque o predicado de escrita por private.is_active_company_admin(empresa_id).
do $$
declare
  v_table text;
  v_leitura text;
begin
  foreach v_table in array array[
    'modelo_relatorio_rdo', 'modelos_relatorios', 'dashboard_modelos',
    'variavel_bi', 'simulacao_bi'
  ] loop
    -- dashboard_modelos: aceita também linhas globais (empresa_id nulo), se houver.
    v_leitura := case when v_table = 'dashboard_modelos'
      then 'or empresa_id is null' else '' end;

    execute format('grant select, insert, update, delete on public.%I to authenticated', v_table);

    execute format(
      'create policy %I on public.%I for select to authenticated using ('
      || 'private.is_active_actor() and ('
      || 'empresa_id = private.active_actor_company_id() '
      || 'or empresa_id = %L::uuid %s))',
      v_table || '_select', v_table, '96b9a6b9-32d0-453e-9f69-74a2691ac5cc', v_leitura
    );
    execute format(
      'create policy %I on public.%I for insert to authenticated with check ('
      || 'private.is_active_actor() and empresa_id = private.active_actor_company_id())',
      v_table || '_insert', v_table
    );
    execute format(
      'create policy %I on public.%I for update to authenticated '
      || 'using (private.is_active_actor() and empresa_id = private.active_actor_company_id()) '
      || 'with check (private.is_active_actor() and empresa_id = private.active_actor_company_id())',
      v_table || '_update', v_table
    );
    execute format(
      'create policy %I on public.%I for delete to authenticated '
      || 'using (private.is_active_actor() and empresa_id = private.active_actor_company_id())',
      v_table || '_delete', v_table
    );
  end loop;
end;
$$;

-- ===========================================================================
-- 6. EMPRESA_TIMESTAMP_FOTOS_PADRAO (padrão da marca d'água das fotos)
-- ===========================================================================
-- Só a própria empresa lê e grava (timestamp_foto_padrao_repository.dart
-- filtra por empresa_id; salvar faz insert/update/delete de duplicatas).
-- ATENÇÃO (revisar): liberado para qualquer usuário ativo da empresa, como
-- o app faz hoje; restrinja ao admin se a tela for só de administrador.
grant select, insert, update, delete on public.empresa_timestamp_fotos_padrao to authenticated;

create policy empresa_timestamp_fotos_padrao_select on public.empresa_timestamp_fotos_padrao
for select to authenticated
using (private.is_active_actor() and empresa_id = private.active_actor_company_id());

create policy empresa_timestamp_fotos_padrao_insert on public.empresa_timestamp_fotos_padrao
for insert to authenticated
with check (private.is_active_actor() and empresa_id = private.active_actor_company_id());

create policy empresa_timestamp_fotos_padrao_update on public.empresa_timestamp_fotos_padrao
for update to authenticated
using (private.is_active_actor() and empresa_id = private.active_actor_company_id())
with check (private.is_active_actor() and empresa_id = private.active_actor_company_id());

create policy empresa_timestamp_fotos_padrao_delete on public.empresa_timestamp_fotos_padrao
for delete to authenticated
using (private.is_active_actor() and empresa_id = private.active_actor_company_id());

-- ===========================================================================
-- 7. CATÁLOGOS
-- ===========================================================================
-- tipologias_local: mesmas 4 regras de 20260917120000 (lê as da empresa e as
-- da DIAVICON; grava só as da empresa), agora com os helpers.
-- ATENÇÃO (revisar): os catálogos irmãos (condicoes_local, anomalias...) só
-- aceitam escrita do admin (20260909100000). Aqui mantive "qualquer usuário
-- ativo da empresa" porque o app cria tipologia no campo
-- (local_repository.dart, novo_local_modal.dart) e isso já era permitido.
grant select, insert, update, delete on public.tipologias_local to authenticated;

create policy tipologias_local_select on public.tipologias_local
for select to authenticated
using (
  private.is_active_actor()
  and (
    empresa_id = private.active_actor_company_id()
    or empresa_id = '96b9a6b9-32d0-453e-9f69-74a2691ac5cc'::uuid
  )
);

create policy tipologias_local_insert on public.tipologias_local
for insert to authenticated
with check (private.is_active_actor() and empresa_id = private.active_actor_company_id());

create policy tipologias_local_update on public.tipologias_local
for update to authenticated
using (private.is_active_actor() and empresa_id = private.active_actor_company_id())
with check (private.is_active_actor() and empresa_id = private.active_actor_company_id());

create policy tipologias_local_delete on public.tipologias_local
for delete to authenticated
using (private.is_active_actor() and empresa_id = private.active_actor_company_id());

-- tipos_ensaio: catálogo global. O app só lê. Escrita só por service_role /
-- SQL Editor (ex.: 20260919210000 insere o tipo da prova de carga dinâmica).
-- Leitura sem exigir usuário ativo para não travar o cadastro/onboarding.
grant select on public.tipos_ensaio to authenticated;

create policy tipos_ensaio_select on public.tipos_ensaio
for select to authenticated
using (true);

-- planos: tabela de preços pública (anon + authenticated só leem). Mesmas
-- policies de 20260902050000; escrita só por service_role/SQL Editor.
grant select on public.planos to anon, authenticated;

create policy planos_catalog_select_anon on public.planos
for select to anon
using (true);

create policy planos_catalog_select_authenticated on public.planos
for select to authenticated
using (true);

-- ===========================================================================
-- 8. NOTIFICAÇÕES
-- ===========================================================================
-- O app só lê as do próprio usuário (stream por usuario_id) e marca como
-- lida. Quem cria notificação são as RPCs SECURITY DEFINER (convites etc.),
-- que não dependem destes grants. UPDATE só na coluna `lida`.
grant select on public.notificacoes to authenticated;
grant update (lida) on public.notificacoes to authenticated;

create policy notificacoes_select on public.notificacoes
for select to authenticated
using (private.is_active_actor() and usuario_id = (select auth.uid()));

create policy notificacoes_update on public.notificacoes
for update to authenticated
using (private.is_active_actor() and usuario_id = (select auth.uid()))
with check (private.is_active_actor() and usuario_id = (select auth.uid()));

-- ===========================================================================
-- 9. PONTOS DE ENSAIO QUE FICARAM SEM RLS
-- ===========================================================================
-- Mesmo padrão de 20260909100000 para as outras famílias:
--   ver     → private.can_access_point(ponto geral)
--   gravar  → private.can_edit_point(ponto geral)   (empresa autora do ponto)
--   apagar  → private.can_delete_point(ponto geral) (autora ou gestor do projeto)
-- Diferença proposital: nas tabelas de leitura (2º/3º nível) o DELETE também
-- usa can_delete_point, porque o app apaga as leituras antes do ponto
-- (ex.: chumbador_repository.dart) e o gestor do projeto precisa conseguir.
grant select, insert, update, delete on
  public.ponto_ensaio_extracao_local,
  public.ponto_ensaio_extracao_leituras,
  public.ponto_ensaio_monitoramento_fissura,
  public.ponto_ensaio_monitoramento_fissura_leitura,
  public.ponto_ensaio_tracao,
  public.ponto_ensaio_tracao_leitura,
  public.ponto_ensaio_ultrassom_mapeamento,
  public.ponto_ensaio_ultrassom_mapeamento_leitura,
  public.ponto_ensaio_liquido_penetrante
to authenticated;

-- 1º nível: ligadas direto a pontos_ensaios_geral.
-- extracao_local.ponto_id, tracao.ponto_id, liquido_penetrante.ponto_id,
-- monitoramento_fissura.ponto_ensaio_id → pontos_ensaios_geral.id
do $$
declare
  v_table text;
  v_col text;
begin
  for v_table, v_col in
    select * from (values
      ('ponto_ensaio_extracao_local', 'ponto_id'),
      ('ponto_ensaio_tracao', 'ponto_id'),
      ('ponto_ensaio_liquido_penetrante', 'ponto_id'),
      ('ponto_ensaio_monitoramento_fissura', 'ponto_ensaio_id')
    ) as t(tabela, coluna)
  loop
    execute format('create policy %I on public.%I for select to authenticated using (private.can_access_point(%I))',
      v_table || '_select', v_table, v_col);
    execute format('create policy %I on public.%I for insert to authenticated with check (private.can_edit_point(%I))',
      v_table || '_insert', v_table, v_col);
    execute format('create policy %I on public.%I for update to authenticated using (private.can_edit_point(%I)) with check (private.can_edit_point(%I))',
      v_table || '_update', v_table, v_col, v_col);
    execute format('create policy %I on public.%I for delete to authenticated using (private.can_delete_point(%I))',
      v_table || '_delete', v_table, v_col);
  end loop;
end;
$$;

-- 2º/3º nível: o ponto geral vem por subconsulta no pai.
--   extracao_leituras.ponto_local_id            → extracao_local.id → .ponto_id
--   monitoramento_fissura_leitura.ponto_id       → monitoramento_fissura.id → .ponto_ensaio_id
--   tracao_leitura.ponto_id                      → tracao.id → .ponto_id
--   ultrassom_mapeamento.ponto_id                → ponto_ensaio_ultrassom.id → .ponto_ensaio_id
--   ultrassom_mapeamento_leitura.ponto_id        → ultrassom_mapeamento.id → ultrassom → .ponto_ensaio_id
do $$
declare
  v_table text;
  v_ponto text;
begin
  for v_table, v_ponto in
    select * from (values
      ('ponto_ensaio_extracao_leituras',
       '(select l.ponto_id from public.ponto_ensaio_extracao_local l where l.id = ponto_ensaio_extracao_leituras.ponto_local_id)'),
      ('ponto_ensaio_monitoramento_fissura_leitura',
       '(select f.ponto_ensaio_id from public.ponto_ensaio_monitoramento_fissura f where f.id = ponto_ensaio_monitoramento_fissura_leitura.ponto_id)'),
      ('ponto_ensaio_tracao_leitura',
       '(select t.ponto_id from public.ponto_ensaio_tracao t where t.id = ponto_ensaio_tracao_leitura.ponto_id)'),
      ('ponto_ensaio_ultrassom_mapeamento',
       '(select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u where u.id = ponto_ensaio_ultrassom_mapeamento.ponto_id)'),
      ('ponto_ensaio_ultrassom_mapeamento_leitura',
       '(select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u join public.ponto_ensaio_ultrassom_mapeamento m on m.ponto_id = u.id where m.id = ponto_ensaio_ultrassom_mapeamento_leitura.ponto_id)')
    ) as t(tabela, ponto)
  loop
    execute format('create policy %I on public.%I for select to authenticated using (private.can_access_point(%s))',
      v_table || '_select', v_table, v_ponto);
    execute format('create policy %I on public.%I for insert to authenticated with check (private.can_edit_point(%s))',
      v_table || '_insert', v_table, v_ponto);
    execute format('create policy %I on public.%I for update to authenticated using (private.can_edit_point(%s)) with check (private.can_edit_point(%s))',
      v_table || '_update', v_table, v_ponto, v_ponto);
    execute format('create policy %I on public.%I for delete to authenticated using (private.can_delete_point(%s))',
      v_table || '_delete', v_table, v_ponto);
  end loop;
end;
$$;

notify pgrst, 'reload schema';

commit;

-- ===========================================================================
-- VERIFICAÇÃO (rodar no SQL Editor depois de aplicar)
-- ===========================================================================
-- 1) Tabelas do schema public que AINDA estão sem RLS (esperado: só as que a
--    equipe decidiu deixar assim; gastos/categoria_gastos/PCD/ultrassom_importacao
--    somem desta lista quando os arquivos pendentes forem aplicados):
--
--   select c.relname
--   from pg_class c join pg_namespace n on n.oid = c.relnamespace
--   where n.nspname = 'public' and c.relkind in ('r', 'p')
--     and not c.relrowsecurity
--   order by 1;
--
-- 2) Grants que sobraram para anon (esperado: SELECT em planos e as tabelas
--    que são públicas de propósito — feed/serviços/empresas conforme as
--    migrations de cadastro; nada de INSERT/UPDATE/DELETE):
--
--   select table_name, string_agg(privilege_type, ', ' order by privilege_type) as privilegios
--   from information_schema.role_table_grants
--   where grantee = 'anon' and table_schema = 'public'
--   group by table_name
--   order by 1;
--
-- 3) Tabelas com RLS ligada mas SEM nenhuma policy (ficam fechadas para o app;
--    confira se é intencional):
--
--   select c.relname
--   from pg_class c join pg_namespace n on n.oid = c.relnamespace
--   where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity
--     and not exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = c.relname)
--   order by 1;
--
-- 4) Policies criadas por este arquivo:
--
--   select tablename, policyname, cmd, roles
--   from pg_policies
--   where schemaname = 'public'
--     and (tablename like 'estrutura%' or tablename in ('elementos_estruturais','projeto_estruturas',
--          'rdo_realizado','rdo_galeria','relatorio_rdo','modelo_relatorio_rdo','dashboard_modelos',
--          'simulacao_bi','variavel_bi','tipologias_local','tipos_ensaio','planos','notificacoes',
--          'modelos_relatorios','empresa_timestamp_fotos_padrao')
--          or tablename like 'ponto_ensaio_extracao%' or tablename like 'ponto_ensaio_monitoramento%'
--          or tablename like 'ponto_ensaio_tracao%' or tablename like 'ponto_ensaio_ultrassom_mapeamento%'
--          or tablename = 'ponto_ensaio_liquido_penetrante')
--   order by 1, 2;
--
-- 5) Teste rápido fingindo ser um usuário (troque o uuid; não grava nada):
--
--   begin;
--   set local role authenticated;
--   select set_config('request.jwt.claims', '{"sub":"<uuid do usuario>","role":"authenticated"}', true);
--   select count(*) from public.estruturas;          -- só as da empresa/projetos dele
--   select count(*) from public.rdo_realizado;
--   rollback;
--
-- 6) Pela chave anon (fora do banco): GET /rest/v1/estruturas?select=id&limit=1
--    deve responder 401/permission denied (sem grant), e planos continua 200.
--
-- ===========================================================================
-- CHECKLIST DE TESTE NO APP (web e celular), com usuários de empresas
-- diferentes: admin da gestora, funcionário da gestora fora da equipe do
-- projeto, admin do cliente ativo, colaboradora aceita e uma 4ª empresa sem
-- vínculo (esta não pode ver nada do projeto).
-- ===========================================================================
--  [ ] Home › abrir projeto: lista de estruturas aparece (gestora, cliente,
--      colaboradora); a 4ª empresa não vê.
--  [ ] Criar estrutura dentro do projeto (gestora) e ser levado à tela dela.
--  [ ] Incluir estrutura existente no projeto (modal "minhas estruturas") e
--      desvincular.
--  [ ] Editar informações da estrutura (gestora do projeto) e transferir a
--      propriedade (proprietária); marcar/desmarcar "monitorada" (limite do
--      plano continua funcionando).
--  [ ] Aba Estruturas (monitor) e navegação por Conjunto Estrutural: aparecem
--      as estruturas geridas pela empresa, com contagem de elementos/ensaios/
--      projetos.
--  [ ] Criar elemento, editar, marcar na planta (planejamento), remover
--      marcação, incluir/excluir do escopo, excluir elemento (admin gestora).
--  [ ] Criar local e tipologia de local (também pela inspeção visual, com a
--      colaboradora); subir planta e mudar preferência de nomes na planta.
--  [ ] Registrar pontos de extração de testemunho, monitoramento de fissura,
--      chumbador (tração), ultrassom mapeamento e líquido penetrante; editar
--      leituras; excluir o ponto (autora e gestor do projeto).
--  [ ] Análise global / relatórios de cada ensaio acima (embeds de
--      elementos_estruturais!inner e estruturas não podem sumir).
--  [ ] RDO: colaboradora cria RDO e anexa fotos; gestora vê RDO de todas as
--      empresas e exclui; cliente vê todos, muda status, NÃO consegue criar;
--      colaboradora não vê RDO das outras. "Meus RDOs" no menu lateral.
--  [ ] Gerar relatório de RDO (modelo próprio e modelo padrão DIAVICON) e
--      abrir em "Meus relatórios"; modelos de RDO: criar, duplicar, editar,
--      excluir.
--  [ ] Modelos de relatório de ensaio: listar (próprios + DIAVICON), criar,
--      duplicar, editar schema, excluir.
--  [ ] Dashboards BI: listar modelos, criar/duplicar/editar/excluir modelo,
--      abrir dashboard de projeto/estrutura/elemento; variáveis e simulações
--      (listar, duplicar padrão DIAVICON, editar, excluir).
--  [ ] Padrões da empresa › carimbo de data das fotos: abrir e salvar; tirar
--      foto em ensaio e conferir a marca d'água (lê estrutura/elemento).
--  [ ] Notificações: badge de não lidas, lista, marcar como lida, aceitar
--      convite de empresa pela notificação.
--  [ ] Planos: página de planos abre logado e deslogado (landing/preços).
--  [ ] Excluir projeto como admin da gestora e aceitar "excluir estrutura
--      também".
