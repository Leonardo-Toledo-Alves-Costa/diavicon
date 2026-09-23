-- PENDENTE: para a equipe revisar e aplicar. Ainda NÃO está no Supabase.
--
-- Importação de leituras de ultrassom direto do equipamento (web app):
-- Proceq Pundit PL-200, pulsos diretos transversais e longitudinais.
--
-- O web app lê o CSV do PL-Link, trata as ondas (chegada da onda P e da S),
-- agrupa as leituras em conjuntos (elemento + posição + onda) e grava:
--   * as velocidades nas tabelas que já existem (pontos_ensaios_geral →
--     ponto_ensaio_ultrassom modo 'direto' → _direto_medicao → _direto_leitura),
--     então análise global, relatórios e dashboards funcionam sem mudança;
--   * esta importação (arquivo, parâmetros da análise e vínculos), para
--     reabrir a análise do CSV depois;
--   * o resultado por elemento (Vp, Vs, Poisson, módulo, fck estimado e
--     característico).
-- Reabrir a análise e mudar algo sobrescreve os pontos e o resultado daquela
-- importação com os valores atuais.
--
-- O CSV fica num bucket PRIVADO (ensaios-importacoes), aberto só por link
-- assinado. O app de celular não mostra o arquivo.
--
-- Sem esta migration o web app ainda importa e grava as velocidades nos
-- pontos, mas não guarda o CSV nem o histórico (avisa na hora de salvar).
--
-- Pode rodar mais de uma vez sem erro.

begin;

create table if not exists public.ultrassom_importacao (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  projeto_id uuid not null references public.projetos (id) on delete cascade,
  estrutura_id uuid references public.estruturas (id) on delete cascade,
  tipo_ensaio_id uuid,
  empresa_id uuid references public.empresas (id) on delete cascade,
  criado_por uuid references public.usuarios (id) on delete set null,
  equipamento text not null,
  nome_arquivo text,
  arquivo_bucket text,
  arquivo_caminho text,
  -- Nome, série e versões do aparelho lidos do cabeçalho do CSV.
  dispositivo jsonb not null default '{}'::jsonb,
  -- Vínculos código → elemento, densidade/αE, ajustes por conjunto,
  -- leituras incluídas/excluídas à mão e os pontos gerados.
  parametros jsonb not null default '{}'::jsonb,
  -- Totais para a lista de importações (leituras, elementos, período).
  resumo jsonb not null default '{}'::jsonb
);

create index if not exists ultrassom_importacao_projeto_idx
  on public.ultrassom_importacao (projeto_id, estrutura_id, criado_em desc);

create table if not exists public.ultrassom_importacao_resultado (
  id uuid primary key default gen_random_uuid(),
  importacao_id uuid not null references public.ultrassom_importacao (id) on delete cascade,
  elemento_id uuid not null references public.elementos_estruturais (id) on delete cascade,
  codigo text not null,
  ponto_longitudinal_id uuid references public.pontos_ensaios_geral (id) on delete set null,
  ponto_transversal_id uuid references public.pontos_ensaios_geral (id) on delete set null,
  densidade numeric,
  alfa_e numeric,
  velocidade_longitudinal numeric,
  velocidade_transversal numeric,
  poisson numeric,
  modulo_elasticidade_gpa numeric,
  fck_estimado numeric,
  fck_caracteristico numeric,
  qualidade text,
  n_posicoes integer,
  -- Resultado por posição (P1, P2…) para o detalhamento no relatório.
  posicoes jsonb not null default '[]'::jsonb,
  atualizado_em timestamptz not null default now(),
  unique (importacao_id, elemento_id)
);

create index if not exists ultrassom_importacao_resultado_elemento_idx
  on public.ultrassom_importacao_resultado (elemento_id);

-- Liga o ponto de ultrassom à importação que o gerou (null = coleta manual).
alter table public.ponto_ensaio_ultrassom
  add column if not exists importacao_id uuid references public.ultrassom_importacao (id) on delete set null;

-- Empresa e autor preenchidos pelo servidor, não pelo app.
create or replace function private.trg_ultrassom_importacao_autor()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if tg_op = 'INSERT' then
    new.empresa_id := coalesce(private.active_actor_company_id(), new.empresa_id);
    new.criado_por := coalesce((select auth.uid()), new.criado_por);
  end if;
  new.atualizado_em := now();
  return new;
end;
$$;

revoke all on function private.trg_ultrassom_importacao_autor() from public, anon, authenticated;

drop trigger if exists ultrassom_importacao_autor on public.ultrassom_importacao;
create trigger ultrassom_importacao_autor
  before insert or update on public.ultrassom_importacao
  for each row execute function private.trg_ultrassom_importacao_autor();

-- ---------------------------------------------------------------------------
-- RLS: vê quem acessa o projeto; altera só a empresa que importou.
-- ---------------------------------------------------------------------------
alter table public.ultrassom_importacao enable row level security;
alter table public.ultrassom_importacao_resultado enable row level security;

grant select, insert, update, delete on public.ultrassom_importacao to authenticated;
grant select, insert, update, delete on public.ultrassom_importacao_resultado to authenticated;

drop policy if exists ultrassom_importacao_select on public.ultrassom_importacao;
create policy ultrassom_importacao_select on public.ultrassom_importacao
for select to authenticated
using (private.is_active_actor() and private.can_access_project(projeto_id));

drop policy if exists ultrassom_importacao_insert on public.ultrassom_importacao;
create policy ultrassom_importacao_insert on public.ultrassom_importacao
for insert to authenticated
with check (private.is_active_actor() and private.can_access_project(projeto_id));

drop policy if exists ultrassom_importacao_update on public.ultrassom_importacao;
create policy ultrassom_importacao_update on public.ultrassom_importacao
for update to authenticated
using (private.is_active_actor() and empresa_id = private.active_actor_company_id())
with check (private.is_active_actor() and empresa_id = private.active_actor_company_id());

drop policy if exists ultrassom_importacao_delete on public.ultrassom_importacao;
create policy ultrassom_importacao_delete on public.ultrassom_importacao
for delete to authenticated
using (private.is_active_actor() and empresa_id = private.active_actor_company_id());

drop policy if exists ultrassom_importacao_resultado_select on public.ultrassom_importacao_resultado;
create policy ultrassom_importacao_resultado_select on public.ultrassom_importacao_resultado
for select to authenticated
using (exists (
  select 1 from public.ultrassom_importacao i
  where i.id = importacao_id and private.is_active_actor() and private.can_access_project(i.projeto_id)
));

drop policy if exists ultrassom_importacao_resultado_escrita on public.ultrassom_importacao_resultado;
create policy ultrassom_importacao_resultado_escrita on public.ultrassom_importacao_resultado
for all to authenticated
using (exists (
  select 1 from public.ultrassom_importacao i
  where i.id = importacao_id and private.is_active_actor() and i.empresa_id = private.active_actor_company_id()
))
with check (exists (
  select 1 from public.ultrassom_importacao i
  where i.id = importacao_id and private.is_active_actor() and i.empresa_id = private.active_actor_company_id()
));

-- ---------------------------------------------------------------------------
-- Bucket privado do CSV original. Caminho: <projeto_id>/<arquivo>.csv
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('ensaios-importacoes', 'ensaios-importacoes', false)
on conflict (id) do update set public = false;

drop policy if exists ensaios_importacoes_select on storage.objects;
create policy ensaios_importacoes_select on storage.objects
for select to authenticated
using (
  bucket_id = 'ensaios-importacoes'
  and private.is_active_actor()
  and private.can_access_project(((storage.foldername(name))[1])::uuid)
);

drop policy if exists ensaios_importacoes_insert on storage.objects;
create policy ensaios_importacoes_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'ensaios-importacoes'
  and private.is_active_actor()
  and private.can_access_project(((storage.foldername(name))[1])::uuid)
);

commit;
