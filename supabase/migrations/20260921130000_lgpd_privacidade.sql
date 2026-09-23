-- APLICADA no Supabase de produção em 21/09/2026 (SQL Editor).
-- LGPD: consentimento, preferências de privacidade, exportação dos dados,
-- auditoria, retenção e correção de permissões de escrita.
--
-- Pode rodar mais de uma vez sem erro.
--
-- O QUE ENTRA
--   1. CORREÇÃO DE SEGURANÇA (urgente, independe da LGPD): `authenticated`
--      tinha UPDATE em TODAS as colunas de `usuarios` e `empresas`.
--        • usuarios: a política deixa cada um editar a própria linha, então
--          qualquer usuário conseguia trocar o próprio empresa_id,
--          is_admin_empresa, is_admin e ativo pela API — entrar como
--          administrador em qualquer empresa.
--        • empresas: qualquer administrador conseguia trocar o plano_id da
--          própria empresa (plano pago de graça, furando os bloqueios).
--      Agora o UPDATE direto vale só para as colunas de perfil que as telas
--      editam. O resto continua pelas funções/edge functions de sempre.
--   2. Colunas de privacidade em usuarios (permite_uso_ia, perfil_visivel)
--      e a data de desativação (desativado_em), mantida por gatilho.
--   3. Tabela `consentimentos` (aceite dos Termos e da Política, com versão,
--      data e plataforma) e as funções de aceite.
--   4. Visibilidade do perfil aplicada nas funções públicas (feed e página
--      pública da empresa).
--   5. `exportar_meus_dados()` — portabilidade (LGPD art. 18, V).
--   6. Auditoria: private.auditoria + gatilhos + registrar_evento_auditoria()
--      para a edge function.
--   7. Retenção: private.aplicar_retencao() — contas desativadas há mais de
--      12 meses são apagadas; auditoria com mais de 5 anos também. O
--      agendamento (pg_cron) fica no fim, protegido: se a extensão não
--      estiver ligada, só avisa.

begin;

-- ---------------------------------------------------------------------------
-- 1. Permissões de escrita por coluna
-- ---------------------------------------------------------------------------
revoke update on public.usuarios from authenticated;
revoke truncate, trigger, references on public.usuarios from authenticated, anon;
grant update (nome, sobrenome, celular, cargo, setor_id, titulo_principal, escolaridade,
              foto_url, linkedin, instagram, endereco_id)
  on public.usuarios to authenticated;

revoke update on public.empresas from authenticated;
revoke truncate, trigger, references on public.empresas from authenticated, anon;
grant update (nome, tipo, ramo_atuacao, descricao, sobre, site, email_contato, whatsapp, linkedin,
              instagram, youtube, foto_capa, foto_url, endereco_id, cor_tema, tamanho)
  on public.empresas to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Colunas de privacidade e data de desativação
-- ---------------------------------------------------------------------------
alter table public.usuarios add column if not exists permite_uso_ia boolean not null default false;
alter table public.usuarios add column if not exists perfil_visivel boolean not null default true;
alter table public.usuarios add column if not exists desativado_em timestamptz;

-- Quem já está desativado começa a contar a partir de hoje (não sabemos a
-- data real, e apagar na hora seria injusto com quem ainda pode voltar).
update public.usuarios set desativado_em = now()
where ativo is false and desativado_em is null;

create or replace function private.trg_usuario_desativado_em()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $$
begin
  if new.ativo is false and (tg_op = 'INSERT' or old.ativo is distinct from false) then
    new.desativado_em := coalesce(new.desativado_em, now());
  elsif new.ativo is true then
    new.desativado_em := null;
  end if;
  return new;
end;
$$;

drop trigger if exists usuario_desativado_em on public.usuarios;
create trigger usuario_desativado_em
before insert or update of ativo on public.usuarios
for each row execute function private.trg_usuario_desativado_em();

-- ---------------------------------------------------------------------------
-- 3. Consentimentos
-- ---------------------------------------------------------------------------
create table if not exists public.consentimentos (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references auth.users(id) on delete cascade,
  documento text not null check (documento in ('termos', 'privacidade')),
  versao text not null,
  aceito_em timestamptz not null default now(),
  plataforma text
);
create index if not exists consentimentos_usuario_idx on public.consentimentos (usuario_id, documento, versao);

alter table public.consentimentos enable row level security;
revoke all on public.consentimentos from anon, authenticated;
grant select on public.consentimentos to authenticated;
drop policy if exists consentimentos_select_own on public.consentimentos;
create policy consentimentos_select_own on public.consentimentos
for select to authenticated using (usuario_id = (select auth.uid()));
-- Sem INSERT direto: só pela função abaixo, que grava a data do servidor.

create or replace function public.registrar_consentimento(
  p_versao_termos text,
  p_versao_privacidade text,
  p_plataforma text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception using errcode = '42501', message = 'Autenticação obrigatória.';
  end if;
  if coalesce(btrim(p_versao_termos), '') = '' or coalesce(btrim(p_versao_privacidade), '') = '' then
    raise exception using errcode = '22023', message = 'Versão do documento não informada.';
  end if;
  insert into public.consentimentos (usuario_id, documento, versao, plataforma)
  values (v_uid, 'termos', left(p_versao_termos, 40), left(p_plataforma, 20)),
         (v_uid, 'privacidade', left(p_versao_privacidade, 40), left(p_plataforma, 20));
end;
$$;

revoke all on function public.registrar_consentimento(text, text, text) from public, anon;
grant execute on function public.registrar_consentimento(text, text, text) to authenticated;

create or replace function public.consentimento_pendente(p_versao_termos text, p_versao_privacidade text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select (select auth.uid()) is not null and (
    not exists (select 1 from public.consentimentos c
                where c.usuario_id = (select auth.uid()) and c.documento = 'termos' and c.versao = p_versao_termos)
    or
    not exists (select 1 from public.consentimentos c
                where c.usuario_id = (select auth.uid()) and c.documento = 'privacidade' and c.versao = p_versao_privacidade)
  );
$$;

revoke all on function public.consentimento_pendente(text, text) from public, anon;
grant execute on function public.consentimento_pendente(text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Preferências de privacidade
-- ---------------------------------------------------------------------------
create or replace function public.minhas_preferencias_privacidade()
returns table (permite_uso_ia boolean, perfil_visivel boolean)
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select u.permite_uso_ia, u.perfil_visivel
  from public.usuarios u
  where u.id = (select auth.uid());
$$;

revoke all on function public.minhas_preferencias_privacidade() from public, anon;
grant execute on function public.minhas_preferencias_privacidade() to authenticated;

-- null = não mexe naquela preferência.
create or replace function public.atualizar_preferencias_privacidade(
  p_permite_uso_ia boolean default null,
  p_perfil_visivel boolean default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'Autenticação obrigatória.';
  end if;
  update public.usuarios
  set permite_uso_ia = coalesce(p_permite_uso_ia, permite_uso_ia),
      perfil_visivel = coalesce(p_perfil_visivel, perfil_visivel)
  where id = (select auth.uid());
end;
$$;

revoke all on function public.atualizar_preferencias_privacidade(boolean, boolean) from public, anon;
grant execute on function public.atualizar_preferencias_privacidade(boolean, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Visibilidade do perfil nas funções públicas
--    Colegas da mesma empresa sempre veem. Outras empresas só veem nome e
--    foto de quem deixou o perfil visível.
-- ---------------------------------------------------------------------------
create or replace function public.get_perfis_feed(p_usuario_ids uuid[])
returns table (
  usuario_id uuid,
  nome text,
  foto_url text,
  empresa_nome text,
  empresa_foto_url text
)
language sql
security definer
stable
set search_path = public, pg_catalog
as $$
  -- O nome do autor continua aparecendo (a publicação no feed é pública
  -- por escolha de quem publicou); a foto só com o perfil visível.
  select u.id, u.nome,
         case when u.perfil_visivel
                or u.id = (select auth.uid())
                or (private.active_actor_company_id() is not null and u.empresa_id = private.active_actor_company_id())
              then u.foto_url end,
         e.nome, e.foto_url
  from public.usuarios u
  left join public.empresas e on e.id = u.empresa_id
  where u.id = any(p_usuario_ids)
    and u.ativo is true;
$$;

revoke all on function public.get_perfis_feed(uuid[]) from public, anon;
grant execute on function public.get_perfis_feed(uuid[]) to authenticated;

create or replace function public.get_public_company_colaboradores(p_empresa_id uuid)
returns table (
  usuario_id uuid,
  nome text,
  sobrenome text,
  cargo text,
  foto_url text
)
language sql
security definer
stable
set search_path = public, pg_catalog
as $$
  select u.id, u.nome, u.sobrenome, u.cargo, u.foto_url
  from public.usuarios u
  where u.empresa_id = p_empresa_id
    and u.ativo is true
    and (u.perfil_visivel or p_empresa_id = private.active_actor_company_id())
    and exists (
      select 1 from public.usuarios me
      where me.id = (select auth.uid()) and me.ativo is true
    )
  order by u.nome;
$$;

revoke all on function public.get_public_company_colaboradores(uuid) from public, anon;
grant execute on function public.get_public_company_colaboradores(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Auditoria
-- ---------------------------------------------------------------------------
create table if not exists private.auditoria (
  id bigint generated always as identity primary key,
  ocorrido_em timestamptz not null default now(),
  ator_id uuid,             -- quem fez (null = sistema / service role)
  acao text not null,       -- ex.: usuario.desativado, conta.excluida
  alvo_tabela text,
  alvo_id text,
  empresa_id uuid,
  detalhes jsonb
);
create index if not exists auditoria_ocorrido_idx on private.auditoria (ocorrido_em);
create index if not exists auditoria_alvo_idx on private.auditoria (alvo_tabela, alvo_id);
revoke all on private.auditoria from public, anon, authenticated;

create or replace function private.auditar(
  p_acao text, p_tabela text, p_id text, p_empresa uuid, p_detalhes jsonb default null
)
returns void
language sql
security definer
set search_path = public, pg_catalog
as $$
  insert into private.auditoria (ator_id, acao, alvo_tabela, alvo_id, empresa_id, detalhes)
  values ((select auth.uid()), p_acao, p_tabela, p_id, p_empresa, p_detalhes);
$$;
revoke all on function private.auditar(text, text, text, uuid, jsonb) from public, anon, authenticated;

-- Para a edge function (service role) registrar exclusões de conta etc.
create or replace function public.registrar_evento_auditoria(
  p_ator uuid, p_acao text, p_tabela text, p_id text, p_empresa uuid, p_detalhes jsonb default null
)
returns void
language sql
security definer
set search_path = public, pg_catalog
as $$
  insert into private.auditoria (ator_id, acao, alvo_tabela, alvo_id, empresa_id, detalhes)
  values (p_ator, left(p_acao, 80), p_tabela, p_id, p_empresa, p_detalhes);
$$;
revoke all on function public.registrar_evento_auditoria(uuid, text, text, text, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.registrar_evento_auditoria(uuid, text, text, text, uuid, jsonb) to service_role;

-- usuarios: mudanças de acesso e exclusão (sem copiar dados pessoais para
-- o log além do necessário para identificar o evento).
create or replace function private.trg_auditar_usuarios()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_mud jsonb := '{}'::jsonb;
begin
  if tg_op = 'DELETE' then
    perform private.auditar('usuario.excluido', 'usuarios', old.id::text, old.empresa_id,
      jsonb_build_object('era_admin_empresa', old.is_admin_empresa, 'ativo', old.ativo));
    return old;
  end if;

  if new.ativo is distinct from old.ativo then
    v_mud := v_mud || jsonb_build_object('ativo', jsonb_build_array(old.ativo, new.ativo));
  end if;
  if new.empresa_id is distinct from old.empresa_id then
    v_mud := v_mud || jsonb_build_object('empresa_id', jsonb_build_array(old.empresa_id, new.empresa_id));
  end if;
  if new.is_admin_empresa is distinct from old.is_admin_empresa then
    v_mud := v_mud || jsonb_build_object('is_admin_empresa', jsonb_build_array(old.is_admin_empresa, new.is_admin_empresa));
  end if;
  if new.is_admin is distinct from old.is_admin then
    v_mud := v_mud || jsonb_build_object('is_admin', jsonb_build_array(old.is_admin, new.is_admin));
  end if;
  if new.pode_visualizar_empresa is distinct from old.pode_visualizar_empresa then
    v_mud := v_mud || jsonb_build_object('pode_visualizar_empresa', jsonb_build_array(old.pode_visualizar_empresa, new.pode_visualizar_empresa));
  end if;
  if new.permite_uso_ia is distinct from old.permite_uso_ia then
    v_mud := v_mud || jsonb_build_object('permite_uso_ia', jsonb_build_array(old.permite_uso_ia, new.permite_uso_ia));
  end if;
  if new.perfil_visivel is distinct from old.perfil_visivel then
    v_mud := v_mud || jsonb_build_object('perfil_visivel', jsonb_build_array(old.perfil_visivel, new.perfil_visivel));
  end if;
  if new.email is distinct from old.email then
    v_mud := v_mud || jsonb_build_object('email_alterado', true);
  end if;

  if v_mud <> '{}'::jsonb then
    perform private.auditar('usuario.alterado', 'usuarios', new.id::text, coalesce(new.empresa_id, old.empresa_id), v_mud);
  end if;
  return new;
end;
$$;

drop trigger if exists auditar_usuarios on public.usuarios;
create trigger auditar_usuarios
after update or delete on public.usuarios
for each row execute function private.trg_auditar_usuarios();

create or replace function private.trg_auditar_empresas()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if tg_op = 'DELETE' then
    perform private.auditar('empresa.excluida', 'empresas', old.id::text, old.id,
      jsonb_build_object('nome', old.nome));
    return old;
  end if;
  if new.plano_id is distinct from old.plano_id then
    perform private.auditar('empresa.plano_alterado', 'empresas', new.id::text, new.id,
      jsonb_build_object('plano_id', jsonb_build_array(old.plano_id, new.plano_id)));
  end if;
  return new;
end;
$$;

drop trigger if exists auditar_empresas on public.empresas;
create trigger auditar_empresas
after update of plano_id or delete on public.empresas
for each row execute function private.trg_auditar_empresas();

create or replace function private.trg_auditar_consentimento()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  perform private.auditar('consentimento.aceito', 'consentimentos', new.id::text, null,
    jsonb_build_object('documento', new.documento, 'versao', new.versao, 'plataforma', new.plataforma));
  return new;
end;
$$;

drop trigger if exists auditar_consentimento on public.consentimentos;
create trigger auditar_consentimento
after insert on public.consentimentos
for each row execute function private.trg_auditar_consentimento();

-- Exclusões de dados de trabalho mais relevantes (quem apagou e quando).
create or replace function private.trg_auditar_exclusao()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  perform private.auditar(tg_table_name || '.excluido', tg_table_name, old.id::text, private.active_actor_company_id(), null);
  return old;
end;
$$;

do $do$
declare
  v_tabela text;
begin
  foreach v_tabela in array array['projetos', 'estruturas', 'relatorio_ensaio', 'relatorio_rdo'] loop
    if to_regclass(format('public.%I', v_tabela)) is not null then
      execute format('drop trigger if exists auditar_exclusao on public.%I', v_tabela);
      execute format('create trigger auditar_exclusao after delete on public.%I '
                     'for each row execute function private.trg_auditar_exclusao()', v_tabela);
    end if;
  end loop;
end;
$do$;

-- Todas as funções de gatilho acima são internas.
revoke all on function private.trg_usuario_desativado_em() from public, anon, authenticated;
revoke all on function private.trg_auditar_usuarios() from public, anon, authenticated;
revoke all on function private.trg_auditar_empresas() from public, anon, authenticated;
revoke all on function private.trg_auditar_consentimento() from public, anon, authenticated;
revoke all on function private.trg_auditar_exclusao() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. Exportação dos dados do titular (portabilidade)
-- ---------------------------------------------------------------------------
create or replace function public.exportar_meus_dados()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_uid uuid := (select auth.uid());
  v_resultado jsonb;
  v_contagens jsonb := '{}'::jsonb;
  r record;
  v_n bigint;
begin
  if v_uid is null then
    raise exception using errcode = '42501', message = 'Autenticação obrigatória.';
  end if;

  -- Quantos registros de trabalho têm você como autor, tabela por tabela.
  -- (O conteúdo desses registros é da empresa; aqui vai o inventário.)
  for r in
    select c.conrelid::regclass as tabela, a.attname as coluna
    from pg_constraint c
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
    join pg_namespace n on n.oid = (select relnamespace from pg_class where oid = c.conrelid)
    where c.contype = 'f'
      and c.confrelid = 'public.usuarios'::regclass
      and n.nspname = 'public'
      and array_length(c.conkey, 1) = 1
  loop
    execute format('select count(*) from %s where %I = $1', r.tabela, r.coluna) into v_n using v_uid;
    if v_n > 0 then
      v_contagens := v_contagens || jsonb_build_object(r.tabela::text || '.' || r.coluna, v_n);
    end if;
  end loop;

  select jsonb_build_object(
    'gerado_em', now(),
    'controlador', 'DIAVICON LTDA — contato@diavicon.com',
    'titular_id', v_uid,
    'conta', (select jsonb_build_object(
                'email', au.email,
                'criada_em', au.created_at,
                'ultimo_login', au.last_sign_in_at,
                'provedores', au.raw_app_meta_data -> 'providers')
              from auth.users au where au.id = v_uid),
    'perfil', (select to_jsonb(u) - 'id' from public.usuarios u where u.id = v_uid),
    'empresa', (select jsonb_build_object('id', e.id, 'nome', e.nome)
                from public.usuarios u join public.empresas e on e.id = u.empresa_id where u.id = v_uid),
    'consentimentos', coalesce((select jsonb_agg(jsonb_build_object(
                         'documento', c.documento, 'versao', c.versao, 'aceito_em', c.aceito_em, 'plataforma', c.plataforma)
                         order by c.aceito_em)
                       from public.consentimentos c where c.usuario_id = v_uid), '[]'::jsonb),
    'feed', jsonb_build_object(
      'publicacoes', coalesce((select jsonb_agg(jsonb_build_object(
                        'id', p.id, 'criado_em', p.criado_em, 'texto', p.texto, 'tag', p.tag,
                        'anexo_nome', p.anexo_nome, 'anexo_url', p.anexo_url,
                        'fotos', coalesce((select jsonb_agg(f.foto_url) from public.feed_fotos f where f.post_id = p.id), '[]'::jsonb))
                        order by p.criado_em)
                      from public.feed_posts p where p.usuario_id = v_uid), '[]'::jsonb),
      'comentarios', coalesce((select jsonb_agg(jsonb_build_object('post_id', c.post_id, 'criado_em', c.criado_em, 'texto', c.texto)
                        order by c.criado_em)
                      from public.feed_comentarios c where c.usuario_id = v_uid), '[]'::jsonb),
      'curtidas', (select count(*) from public.feed_likes l where l.usuario_id = v_uid)
    ),
    'notificacoes', (select count(*) from public.notificacoes n where n.usuario_id = v_uid),
    'registros_criados_por_voce', v_contagens,
    'historico_de_acesso_e_permissoes', coalesce((select jsonb_agg(jsonb_build_object(
                        'quando', a.ocorrido_em, 'acao', a.acao, 'detalhes', a.detalhes) order by a.ocorrido_em)
                      from private.auditoria a
                      where a.alvo_tabela = 'usuarios' and a.alvo_id = v_uid::text), '[]'::jsonb)
  ) into v_resultado;

  perform private.auditar('dados.exportados', 'usuarios', v_uid::text, private.active_actor_company_id(), null);
  return v_resultado;
end;
$$;

revoke all on function public.exportar_meus_dados() from public, anon;
grant execute on function public.exportar_meus_dados() to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Retenção
-- ---------------------------------------------------------------------------
-- Fila de arquivos a apagar do Storage. SQL não consegue apagar o arquivo
-- em si (só a edge function, pela API do Storage); a função de retenção
-- anota aqui e a auth-operations esvazia a fila.
create table if not exists private.arquivos_para_apagar (
  bucket_id text not null,
  nome text not null,
  anotado_em timestamptz not null default now(),
  primary key (bucket_id, nome)
);
revoke all on private.arquivos_para_apagar from public, anon, authenticated;

create or replace function private.aplicar_retencao(p_meses_desativado int default 12, p_anos_auditoria int default 5)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_ids uuid[];
  v_arquivos int := 0;
  v_auditoria int := 0;
begin
  -- Contas desativadas há mais do prazo. O administrador principal nunca é
  -- apagado por aqui (a empresa ficaria sem dono); esse caso é comercial.
  select coalesce(array_agg(u.id), '{}') into v_ids
  from public.usuarios u
  where u.ativo is false
    and u.desativado_em < now() - make_interval(months => p_meses_desativado)
    and coalesce(u.is_admin_empresa, false) is false;

  if array_length(v_ids, 1) > 0 then
    -- Arquivos pessoais (foto de perfil e fotos do feed) vão para a fila.
    insert into private.arquivos_para_apagar (bucket_id, nome)
    select o.bucket_id, o.name
    from storage.objects o
    where o.bucket_id = 'avatars'
      and o.owner = any(v_ids)
      and split_part(o.name, '/', 1) in ('usuarios', 'perfis', 'feed')
    on conflict do nothing;
    get diagnostics v_arquivos = row_count;

    -- Publicações no feed são conteúdo pessoal: saem junto.
    delete from public.feed_posts where usuario_id = any(v_ids);

    perform private.auditar('retencao.contas_excluidas', 'usuarios', null, null,
      jsonb_build_object('quantidade', array_length(v_ids, 1), 'prazo_meses', p_meses_desativado));

    -- Apagar em auth.users apaga a linha de usuarios (on delete cascade) e
    -- os vínculos de autoria viram null (ver 20260917220000).
    delete from auth.users where id = any(v_ids);
  end if;

  delete from private.auditoria where ocorrido_em < now() - make_interval(years => p_anos_auditoria);
  get diagnostics v_auditoria = row_count;

  -- Vínculos arquivo→empresa de arquivos que já não existem (a função vem
  -- da migração 20260921130100; se ainda não existir, só pula).
  begin
    perform private.limpar_arquivo_empresa();
  exception when undefined_function then
    null;
  end;

  return jsonb_build_object(
    'contas_excluidas', coalesce(array_length(v_ids, 1), 0),
    'arquivos_na_fila', v_arquivos,
    'auditoria_expurgada', v_auditoria);
end;
$$;

revoke all on function private.aplicar_retencao(int, int) from public, anon, authenticated;

-- Fila de arquivos: a edge function (service role) lê e confirma.
create or replace function public.arquivos_para_apagar_pegar(p_limite int default 500)
returns table (bucket_id text, nome text)
language sql
security definer
set search_path = public, pg_catalog
as $$
  select a.bucket_id, a.nome from private.arquivos_para_apagar a order by a.anotado_em limit p_limite;
$$;
revoke all on function public.arquivos_para_apagar_pegar(int) from public, anon, authenticated;
grant execute on function public.arquivos_para_apagar_pegar(int) to service_role;

create or replace function public.arquivos_para_apagar_confirmar(p_bucket text, p_nomes text[])
returns void
language sql
security definer
set search_path = public, pg_catalog
as $$
  delete from private.arquivos_para_apagar a where a.bucket_id = p_bucket and a.nome = any(p_nomes);
$$;
revoke all on function public.arquivos_para_apagar_confirmar(text, text[]) from public, anon, authenticated;
grant execute on function public.arquivos_para_apagar_confirmar(text, text[]) to service_role;

-- Exclusão de conta (edge function), em duas etapas:
--   1. ANTES de apagar o login: apaga as publicações do feed (depois, a FK
--      vira null e não daria mais para achar de quem eram).
--   2. DEPOIS de apagar o login: põe na fila a foto de perfil e as fotos do
--      feed (o dono continua registrado em storage.objects). Se o login não
--      foi apagado, a etapa 2 não roda e nenhuma foto some.
-- Arquivos de trabalho (projetos, ensaios, relatórios) ficam com a empresa.
create or replace function public.preparar_exclusao_conta(p_usuario_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_posts int;
begin
  delete from public.feed_posts where usuario_id = p_usuario_id;
  get diagnostics v_posts = row_count;
  return jsonb_build_object('publicacoes_apagadas', v_posts);
end;
$$;
revoke all on function public.preparar_exclusao_conta(uuid) from public, anon, authenticated;
grant execute on function public.preparar_exclusao_conta(uuid) to service_role;

create or replace function public.enfileirar_arquivos_pessoais(p_usuario_id uuid)
returns int
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_arquivos int;
begin
  -- Só para contas que já não existem: nunca apaga foto de quem está ativo.
  if exists (select 1 from auth.users where id = p_usuario_id) then
    return 0;
  end if;
  insert into private.arquivos_para_apagar (bucket_id, nome)
  select o.bucket_id, o.name
  from storage.objects o
  where o.bucket_id = 'avatars'
    and o.owner = p_usuario_id
    and split_part(o.name, '/', 1) in ('usuarios', 'perfis', 'feed')
  on conflict do nothing;
  get diagnostics v_arquivos = row_count;
  return v_arquivos;
end;
$$;
revoke all on function public.enfileirar_arquivos_pessoais(uuid) from public, anon, authenticated;
grant execute on function public.enfileirar_arquivos_pessoais(uuid) to service_role;

commit;

-- ---------------------------------------------------------------------------
-- Agendamento mensal da retenção (dia 1, 03:00 de Brasília = 06:00 UTC).
-- Fora da transação: se pg_cron não estiver disponível, só avisa.
-- Para ligar a extensão: Database > Extensions > pg_cron (ou a linha abaixo).
-- ---------------------------------------------------------------------------
do $do$
begin
  begin
    create extension if not exists pg_cron;
  exception when others then
    raise notice 'pg_cron indisponível (%). Ligue em Database > Extensions e rode este bloco de novo.', sqlerrm;
    return;
  end;
  if exists (select 1 from cron.job where jobname = 'lgpd-retencao') then
    perform cron.unschedule('lgpd-retencao');
  end if;
  perform cron.schedule('lgpd-retencao', '0 6 1 * *', 'select private.aplicar_retencao()');
end;
$do$;
