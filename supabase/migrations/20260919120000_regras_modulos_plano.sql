-- APLICADA no Supabase de produção em 21/09/2026 (SQL Editor).
--
-- Regras de plano × módulo aplicadas no servidor. O app já confere as mesmas
-- regras (lib/features/planos/acesso_plano.dart), mas só para explicar o
-- bloqueio. Quem chama a API direto (ou digita a URL no web app) passa por
-- aqui.
--
-- Tudo é lido da tabela `planos` na hora. Mudar um plano no painel do
-- Supabase vale imediatamente, sem publicar app nem nova migration.
--
--   Módulo                     Coluna em `planos`   O que é bloqueado
--   -------------------------  -------------------  ---------------------------------------
--   Monitorar estruturas       monitor +            marcar estrutura como monitorada
--                              tokens_estrutura     (até tokens_estrutura estruturas)
--   Relatórios                 gerar_relatorio      criar relatorio_ensaio, relatorio_rdo e
--                                                   modelos_relatorios
--   RDO e gastos               rdo_gastos           criar rdo_realizado, gastos e
--                                                   modelo_relatorio_rdo
--   Serviços                   servicos             criar/editar empresa_servicos
--   Publicar no feed           publicar_feed_edu    criar feed_posts
--   Patrocinar publicações     tokens_publicidade   marcar feed_posts.patrocinado
--                                                   (até tokens_publicidade posts ao mesmo tempo)
--   Anúncios / offline         ads / offline        só no app (não há dado a proteger)
--
-- Leitura não é bloqueada. Quem baixa de plano continua vendo o que já criou;
-- só não cria coisa nova no módulo.
--
-- Gravações sem usuário logado (service role, edge functions, SQL no painel)
-- não passam pela regra. A equipe continua podendo corrigir dados.
--
-- Tokens nulos contam como ZERO. Na tabela atual, os planos pagos estão com
-- tokens_publicidade = null: ninguém patrocina até a equipe definir um número.
--
-- Também cria a solicitação de plano. O plano escolhido no cadastro (ou na
-- tela "Meu Plano") vira um pedido pendente; a empresa segue no plano padrão
-- até a equipe ativar. Enquanto não houver cobrança online, isso é manual:
--   update public.empresas set plano_id = '<plano>' where id = '<empresa>';
--   update public.empresa_plano_solicitacao set status = 'ativado', resolvido_em = now()
--     where id = '<solicitação>';
--
-- Pode rodar mais de uma vez sem erro.

begin;

-- ---------------------------------------------------------------------------
-- Plano da empresa
-- ---------------------------------------------------------------------------
create or replace function private.plano_da_empresa(p_empresa_id uuid)
returns public.planos
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select p.*
  from public.empresas e
  join public.planos p on p.id = e.plano_id
  where e.id = p_empresa_id
$$;

-- Levanta o erro padrão quando o plano da empresa não libera o módulo.
-- A mensagem é a mesma que o app mostra (planos_mensagens.dart).
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
    when 'tokens_publicidade' then 'patrocinar publicações no feed'
    else 'este recurso'
  end;

  raise exception using errcode = 'P0001',
    message = format('Seu plano atual não inclui %s. Para aumentar o seu plano, entre em contato com o time de vendas da Diavicon.', v_nome);
end;
$$;

revoke all on function private.plano_da_empresa(uuid) from public, anon, authenticated;
revoke all on function private.exigir_modulo_plano(uuid, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Gatilho genérico: o módulo vem como argumento do trigger e a empresa é a
-- do usuário logado. Não depende da coluna de empresa da linha, que em
-- algumas tabelas é preenchida por outro trigger.
-- ---------------------------------------------------------------------------
create or replace function private.trg_exigir_modulo_plano()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if (select auth.uid()) is null then
    return new;
  end if;
  perform private.exigir_modulo_plano(private.active_actor_company_id(), tg_argv[0]);
  return new;
end;
$$;

revoke all on function private.trg_exigir_modulo_plano() from public, anon, authenticated;

-- Relatórios
drop trigger if exists plano_exige_relatorio on public.relatorio_ensaio;
create trigger plano_exige_relatorio
  before insert on public.relatorio_ensaio
  for each row execute function private.trg_exigir_modulo_plano('gerar_relatorio');

drop trigger if exists plano_exige_relatorio on public.relatorio_rdo;
create trigger plano_exige_relatorio
  before insert on public.relatorio_rdo
  for each row execute function private.trg_exigir_modulo_plano('gerar_relatorio');

drop trigger if exists plano_exige_relatorio on public.modelos_relatorios;
create trigger plano_exige_relatorio
  before insert on public.modelos_relatorios
  for each row execute function private.trg_exigir_modulo_plano('gerar_relatorio');

-- RDO e gastos
drop trigger if exists plano_exige_rdo_gastos on public.rdo_realizado;
create trigger plano_exige_rdo_gastos
  before insert on public.rdo_realizado
  for each row execute function private.trg_exigir_modulo_plano('rdo_gastos');

drop trigger if exists plano_exige_rdo_gastos on public.gastos;
create trigger plano_exige_rdo_gastos
  before insert on public.gastos
  for each row execute function private.trg_exigir_modulo_plano('rdo_gastos');

drop trigger if exists plano_exige_rdo_gastos on public.modelo_relatorio_rdo;
create trigger plano_exige_rdo_gastos
  before insert on public.modelo_relatorio_rdo
  for each row execute function private.trg_exigir_modulo_plano('rdo_gastos');

-- Serviços (criar e editar)
drop trigger if exists plano_exige_servicos on public.empresa_servicos;
create trigger plano_exige_servicos
  before insert or update on public.empresa_servicos
  for each row execute function private.trg_exigir_modulo_plano('servicos');

-- Feed (só criar; editar post antigo continua liberado)
drop trigger if exists plano_exige_publicar_feed on public.feed_posts;
create trigger plano_exige_publicar_feed
  before insert on public.feed_posts
  for each row execute function private.trg_exigir_modulo_plano('publicar_feed_edu');

-- ---------------------------------------------------------------------------
-- Patrocínio no feed: até tokens_publicidade posts patrocinados ao mesmo
-- tempo, somando todos os usuários da empresa.
-- ---------------------------------------------------------------------------
create or replace function private.trg_limite_patrocinio_feed()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_empresa uuid;
  v_limite integer;
  v_em_uso integer;
begin
  if (select auth.uid()) is null or new.patrocinado is not true then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.patrocinado is true then
    return new;
  end if;

  v_empresa := private.active_actor_company_id();
  perform private.exigir_modulo_plano(v_empresa, 'tokens_publicidade');

  v_limite := coalesce((private.plano_da_empresa(v_empresa)).tokens_publicidade, 0);
  select count(*) into v_em_uso
  from public.feed_posts f
  join public.usuarios u on u.id = f.usuario_id
  where u.empresa_id = v_empresa
    and f.patrocinado is true
    and f.id is distinct from new.id;

  if v_em_uso >= v_limite then
    raise exception using errcode = 'P0001',
      message = format('Sua empresa já usa as %s publicações patrocinadas do plano. Tire o patrocínio de outra publicação ou fale com o time de vendas da Diavicon.', v_limite);
  end if;
  return new;
end;
$$;

revoke all on function private.trg_limite_patrocinio_feed() from public, anon, authenticated;

drop trigger if exists plano_limite_patrocinio on public.feed_posts;
create trigger plano_limite_patrocinio
  before insert or update of patrocinado on public.feed_posts
  for each row execute function private.trg_limite_patrocinio_feed();

-- ---------------------------------------------------------------------------
-- Estruturas monitoradas: plano com `monitor` e no máximo tokens_estrutura
-- estruturas monitoradas por empresa gestora. Uma assinatura ativa com
-- tokens próprios (empresa_plano_assinatura) vale mais que o plano base, como
-- no app (tokens_estrutura_provider.dart).
-- ---------------------------------------------------------------------------
create or replace function private.trg_limite_estruturas_monitoradas()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_empresa uuid;
  v_limite integer;
  v_em_uso integer;
begin
  if (select auth.uid()) is null or new.monitorada is not true then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.monitorada is true
     and old.empresa_gestora_id is not distinct from new.empresa_gestora_id then
    return new;
  end if;

  v_empresa := coalesce(new.empresa_gestora_id, private.active_actor_company_id());
  perform private.exigir_modulo_plano(v_empresa, 'monitor');

  select a.tokens_estrutura into v_limite
  from public.empresa_plano_assinatura a
  where a.empresa_id = v_empresa
    and a.status = 'ativo'
    and a.tokens_estrutura is not null
  order by a.criado_em desc
  limit 1;
  v_limite := coalesce(v_limite, (private.plano_da_empresa(v_empresa)).tokens_estrutura, 0);

  select count(*) into v_em_uso
  from public.estruturas s
  where s.empresa_gestora_id = v_empresa
    and s.monitorada is true
    and s.id is distinct from new.id;

  if v_em_uso >= v_limite then
    raise exception using errcode = 'P0001',
      message = format('Sua empresa já monitora %s estrutura(s), o limite do plano. Desmarque outra estrutura ou fale com o time de vendas da Diavicon.', v_limite);
  end if;
  return new;
end;
$$;

revoke all on function private.trg_limite_estruturas_monitoradas() from public, anon, authenticated;

drop trigger if exists plano_limite_monitoradas on public.estruturas;
create trigger plano_limite_monitoradas
  before insert or update of monitorada, empresa_gestora_id on public.estruturas
  for each row execute function private.trg_limite_estruturas_monitoradas();

-- ---------------------------------------------------------------------------
-- Solicitação de plano (enquanto não há cobrança online)
-- ---------------------------------------------------------------------------
create table if not exists public.empresa_plano_solicitacao (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  plano_id uuid not null references public.planos (id),
  solicitado_por uuid references public.usuarios (id) on delete set null,
  status text not null default 'pendente'
    check (status in ('pendente', 'ativado', 'recusado', 'cancelado')),
  criado_em timestamptz not null default now(),
  resolvido_em timestamptz
);

create index if not exists empresa_plano_solicitacao_empresa_idx
  on public.empresa_plano_solicitacao (empresa_id, status);

-- No máximo um pedido pendente por empresa (um novo substitui o anterior).
create unique index if not exists empresa_plano_solicitacao_uma_pendente_uidx
  on public.empresa_plano_solicitacao (empresa_id)
  where status = 'pendente';

alter table public.empresa_plano_solicitacao enable row level security;
revoke all on table public.empresa_plano_solicitacao from anon, authenticated;
grant select on table public.empresa_plano_solicitacao to authenticated;

drop policy if exists plano_solicitacao_select on public.empresa_plano_solicitacao;
create policy plano_solicitacao_select on public.empresa_plano_solicitacao
for select to authenticated
using (private.is_active_actor() and empresa_id = private.active_actor_company_id());

-- Só o admin da empresa pede troca de plano. Não muda empresas.plano_id.
create or replace function public.solicitar_plano(p_plano_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_empresa uuid := private.active_actor_company_id();
  v_plano public.planos;
  v_id uuid;
begin
  if v_empresa is null or not private.is_active_company_admin(v_empresa) then
    raise exception using errcode = '42501',
      message = 'Só o administrador da empresa pode solicitar a troca de plano.';
  end if;

  select * into v_plano from public.planos where id = p_plano_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'Plano não encontrado.';
  end if;

  update public.empresa_plano_solicitacao
  set status = 'cancelado', resolvido_em = now()
  where empresa_id = v_empresa and status = 'pendente';

  -- Pedir o plano que a empresa já tem só cancela o pedido anterior.
  if exists (select 1 from public.empresas where id = v_empresa and plano_id = p_plano_id) then
    return null;
  end if;

  insert into public.empresa_plano_solicitacao (empresa_id, plano_id, solicitado_por)
  values (v_empresa, p_plano_id, (select auth.uid()))
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.solicitar_plano(uuid) from public, anon;
grant execute on function public.solicitar_plano(uuid) to authenticated;

commit;
