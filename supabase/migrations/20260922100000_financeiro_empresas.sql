-- PENDENTE: para a equipe revisar e aplicar. Ainda NÃO está no Supabase.
--
-- Controle financeiro das empresas clientes (painel da DIAVICON ›
-- Empresas cadastradas › Financeiro).
--
--   empresa_contratos   um contrato ATIVO por empresa: plano, valor mensal,
--                       dia de vencimento, vigência e especificidades.
--   empresa_cobrancas   uma linha por mês (ou cobrança avulsa): valor,
--                       vencimento, status, boleto e nota fiscal.
--   bucket financeiro   PDFs/XML de boleto e nota fiscal (PRIVADO).
--
-- Quem faz o quê:
--   * Administrador principal da DIAVICON (is_admin_empresa na empresa
--     DIAVICON): lê e grava tudo, de todas as empresas.
--   * Gestor da empresa cliente (is_admin_empresa da própria empresa): só LÊ
--     o contrato e as cobranças da própria empresa e baixa boleto/NF
--     (tela Meu Plano). Admin comum e colaboradores não veem nada.
--
-- Status da cobrança gravado: pendente, pago ou cancelado. "Atrasado" não é
-- gravado: o app mostra quando está pendente e o vencimento já passou.
--
-- Salvar um contrato ATIVO:
--   * troca empresas.plano_id pelo plano do contrato (limites e módulos
--     passam a valer na hora, lidos da tabela planos);
--   * marca como 'ativado' o pedido pendente de troca para o mesmo plano
--     (empresa_plano_solicitacao);
--   * desativa o contrato ativo anterior da empresa (fica no histórico).
--
-- Retenção fiscal: as colunas se chamam cliente_empresa_id (e não
-- empresa_id) e aceitam nulo de propósito. Ao excluir uma empresa,
-- private.apagar_em_cascata só LIMPA essa ligação, e o histórico financeiro
-- continua guardado com o nome e o CNPJ copiados na linha. Os arquivos do
-- bucket financeiro também não são apagados na exclusão da empresa (notas
-- fiscais precisam ser guardadas por 5 anos).
--
-- Obs.: os arquivos enviados pela DIAVICON entram na cota de armazenamento
-- da própria DIAVICON (gatilho registrar_arquivo_empresa).
--
-- Pode rodar mais de uma vez sem erro.

begin;

-- ---------------------------------------------------------------------------
-- 1. Quem é quem
-- ---------------------------------------------------------------------------
create or replace function private.eh_admin_diavicon()
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select private.is_primary_company_admin((select auth.uid()), '96b9a6b9-32d0-453e-9f69-74a2691ac5cc'::uuid)
$$;

create or replace function private.eh_gestor_da_empresa(p_empresa_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select p_empresa_id is not null
     and private.is_primary_company_admin((select auth.uid()), p_empresa_id)
$$;

revoke all on function private.eh_admin_diavicon() from public, anon;
revoke all on function private.eh_gestor_da_empresa(uuid) from public, anon;
grant execute on function private.eh_admin_diavicon() to authenticated, service_role;
grant execute on function private.eh_gestor_da_empresa(uuid) to authenticated, service_role;

create or replace function private.trg_financeiro_atualizado_em()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $$
begin
  new.atualizado_em := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Contratos
-- ---------------------------------------------------------------------------
create table if not exists public.empresa_contratos (
  id uuid primary key default gen_random_uuid(),
  cliente_empresa_id uuid references public.empresas (id) on delete set null,
  cliente_nome text not null,
  cliente_cnpj text,
  plano_id uuid not null references public.planos (id),
  valor_mensal numeric(12, 2) not null check (valor_mensal >= 0),
  dia_vencimento smallint not null check (dia_vencimento between 1 and 28),
  inicio date not null,
  fim date check (fim is null or fim >= inicio),
  especificidades text,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  criado_por uuid references public.usuarios (id) on delete set null
);

create index if not exists empresa_contratos_cliente_idx on public.empresa_contratos (cliente_empresa_id);
create unique index if not exists empresa_contratos_um_ativo_idx
  on public.empresa_contratos (cliente_empresa_id) where ativo;

-- Antes de gravar: copia nome/CNPJ da empresa e desativa o contrato ativo
-- anterior (o índice acima só aceita um ativo por empresa).
create or replace function private.trg_contrato_antes()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if new.cliente_empresa_id is not null then
    select e.nome, e.cnpj into new.cliente_nome, new.cliente_cnpj
    from public.empresas e where e.id = new.cliente_empresa_id;
    if new.cliente_nome is null then
      raise exception using errcode = 'P0001', message = 'Empresa não encontrada.';
    end if;
  end if;
  if tg_op = 'INSERT' then
    new.criado_por := coalesce(new.criado_por, (select auth.uid()));
  end if;
  if new.ativo and new.cliente_empresa_id is not null then
    update public.empresa_contratos
    set ativo = false
    where cliente_empresa_id = new.cliente_empresa_id and ativo and id <> new.id;
  end if;
  return new;
end;
$$;

-- Depois de gravar um contrato ativo: aplica o plano na empresa.
create or replace function private.trg_contrato_aplica_plano()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if new.ativo and new.cliente_empresa_id is not null
     and (tg_op = 'INSERT' or old.plano_id is distinct from new.plano_id or old.ativo is distinct from new.ativo) then
    update public.empresas set plano_id = new.plano_id where id = new.cliente_empresa_id;
    update public.empresa_plano_solicitacao
    set status = 'ativado', resolvido_em = now()
    where empresa_id = new.cliente_empresa_id and plano_id = new.plano_id and status = 'pendente';
  end if;
  return null;
end;
$$;

revoke all on function private.trg_contrato_antes() from public, anon, authenticated;
revoke all on function private.trg_contrato_aplica_plano() from public, anon, authenticated;

drop trigger if exists contrato_antes on public.empresa_contratos;
create trigger contrato_antes
before insert or update on public.empresa_contratos
for each row execute function private.trg_contrato_antes();

drop trigger if exists contrato_aplica_plano on public.empresa_contratos;
create trigger contrato_aplica_plano
after insert or update on public.empresa_contratos
for each row execute function private.trg_contrato_aplica_plano();

drop trigger if exists contrato_atualizado_em on public.empresa_contratos;
create trigger contrato_atualizado_em
before update on public.empresa_contratos
for each row execute function private.trg_financeiro_atualizado_em();

alter table public.empresa_contratos enable row level security;

drop policy if exists empresa_contratos_ler on public.empresa_contratos;
create policy empresa_contratos_ler on public.empresa_contratos
for select to authenticated
using (private.eh_admin_diavicon() or private.eh_gestor_da_empresa(cliente_empresa_id));

drop policy if exists empresa_contratos_gravar on public.empresa_contratos;
create policy empresa_contratos_gravar on public.empresa_contratos
for all to authenticated
using (private.eh_admin_diavicon())
with check (private.eh_admin_diavicon());

revoke all on public.empresa_contratos from anon;
grant select, insert, update, delete on public.empresa_contratos to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Cobranças
-- ---------------------------------------------------------------------------
create table if not exists public.empresa_cobrancas (
  id uuid primary key default gen_random_uuid(),
  cliente_empresa_id uuid references public.empresas (id) on delete set null,
  cliente_nome text not null,
  cliente_cnpj text,
  contrato_id uuid references public.empresa_contratos (id) on delete set null,
  competencia date not null check (extract(day from competencia) = 1),
  descricao text,
  valor numeric(12, 2) not null check (valor >= 0),
  vencimento date not null,
  status text not null default 'pendente' check (status in ('pendente', 'pago', 'cancelado')),
  pago_em date,
  boleto_path text,
  nota_fiscal_path text,
  observacao text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create index if not exists empresa_cobrancas_cliente_idx
  on public.empresa_cobrancas (cliente_empresa_id, competencia desc);
-- Uma mensalidade por mês de cada contrato (as avulsas não têm contrato).
create unique index if not exists empresa_cobrancas_mes_contrato_idx
  on public.empresa_cobrancas (contrato_id, competencia) where contrato_id is not null;

create or replace function private.trg_cobranca_antes()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if new.cliente_empresa_id is not null
     and (tg_op = 'INSERT' or new.cliente_empresa_id is distinct from old.cliente_empresa_id) then
    select e.nome, e.cnpj into new.cliente_nome, new.cliente_cnpj
    from public.empresas e where e.id = new.cliente_empresa_id;
    if new.cliente_nome is null then
      raise exception using errcode = 'P0001', message = 'Empresa não encontrada.';
    end if;
  end if;
  new.competencia := date_trunc('month', new.competencia)::date;
  if new.status = 'pago' and new.pago_em is null then
    new.pago_em := current_date;
  elsif new.status <> 'pago' then
    new.pago_em := null;
  end if;
  return new;
end;
$$;
revoke all on function private.trg_cobranca_antes() from public, anon, authenticated;

drop trigger if exists cobranca_antes on public.empresa_cobrancas;
create trigger cobranca_antes
before insert or update on public.empresa_cobrancas
for each row execute function private.trg_cobranca_antes();

drop trigger if exists cobranca_atualizado_em on public.empresa_cobrancas;
create trigger cobranca_atualizado_em
before update on public.empresa_cobrancas
for each row execute function private.trg_financeiro_atualizado_em();

alter table public.empresa_cobrancas enable row level security;

drop policy if exists empresa_cobrancas_ler on public.empresa_cobrancas;
create policy empresa_cobrancas_ler on public.empresa_cobrancas
for select to authenticated
using (private.eh_admin_diavicon() or private.eh_gestor_da_empresa(cliente_empresa_id));

drop policy if exists empresa_cobrancas_gravar on public.empresa_cobrancas;
create policy empresa_cobrancas_gravar on public.empresa_cobrancas
for all to authenticated
using (private.eh_admin_diavicon())
with check (private.eh_admin_diavicon());

revoke all on public.empresa_cobrancas from anon;
grant select, insert, update, delete on public.empresa_cobrancas to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Gerar mensalidades a partir do contrato
-- ---------------------------------------------------------------------------
-- Cria uma cobrança 'pendente' para cada mês da vigência que ainda não tem.
-- Até: o fim do contrato; se não tiver fim, até o mês que vem. Devolve
-- quantas foram criadas. Meses já lançados não são tocados.
create or replace function public.plataforma_gerar_cobrancas(p_contrato_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_c public.empresa_contratos;
  v_mes date;
  v_ate date;
  v_criadas integer := 0;
  v_linhas integer;
begin
  if not private.eh_admin_diavicon() then
    raise exception using errcode = '42501', message = 'Acesso restrito à administração da DIAVICON.';
  end if;

  select * into v_c from public.empresa_contratos where id = p_contrato_id;
  if v_c.id is null then
    raise exception using errcode = 'P0001', message = 'Contrato não encontrado.';
  end if;
  if v_c.cliente_empresa_id is null then
    raise exception using errcode = 'P0001', message = 'A empresa deste contrato foi excluída.';
  end if;

  v_mes := date_trunc('month', v_c.inicio)::date;
  v_ate := date_trunc('month', coalesce(v_c.fim, (current_date + interval '1 month')::date))::date;
  -- Trava de segurança: no máximo 36 meses por vez (uma data digitada
  -- errada, ex. início em 1926, não pode criar milhares de linhas).
  if v_ate > (v_mes + interval '35 months')::date then
    raise exception using errcode = 'P0001',
      message = 'Período longo demais: gere no máximo 36 mensalidades por vez (ajuste o início ou o fim do contrato).';
  end if;

  while v_mes <= v_ate loop
    insert into public.empresa_cobrancas (
      cliente_empresa_id, cliente_nome, cliente_cnpj, contrato_id,
      competencia, descricao, valor, vencimento
    )
    values (
      v_c.cliente_empresa_id, v_c.cliente_nome, v_c.cliente_cnpj, v_c.id,
      v_mes, 'Mensalidade', v_c.valor_mensal,
      make_date(extract(year from v_mes)::int, extract(month from v_mes)::int, v_c.dia_vencimento)
    )
    on conflict (contrato_id, competencia) where contrato_id is not null do nothing;
    get diagnostics v_linhas = row_count;
    v_criadas := v_criadas + v_linhas;
    v_mes := (v_mes + interval '1 month')::date;
  end loop;

  return v_criadas;
end;
$$;

revoke all on function public.plataforma_gerar_cobrancas(uuid) from public, anon;
grant execute on function public.plataforma_gerar_cobrancas(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Arquivos: bucket privado financeiro
-- ---------------------------------------------------------------------------
-- Caminho: <cliente_empresa_id>/<cobranca_id>/<boleto|nota-fiscal>-<data>.<ext>
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'financeiro', 'financeiro', false, 10485760,
  array['application/pdf', 'image/png', 'image/jpeg', 'application/xml', 'text/xml']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- A primeira pasta do caminho é a empresa. Texto que não é uuid → sem acesso.
create or replace function private.pode_ler_financeiro(p_nome text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_catalog
as $$
declare
  v_empresa uuid;
begin
  if private.eh_admin_diavicon() then
    return true;
  end if;
  begin
    v_empresa := split_part(p_nome, '/', 1)::uuid;
  exception when others then
    return false;
  end;
  return private.eh_gestor_da_empresa(v_empresa);
end;
$$;
revoke all on function private.pode_ler_financeiro(text) from public, anon;
grant execute on function private.pode_ler_financeiro(text) to authenticated, service_role;

drop policy if exists financeiro_ler on storage.objects;
create policy financeiro_ler on storage.objects
for select to authenticated
using (bucket_id = 'financeiro' and private.pode_ler_financeiro(name));

drop policy if exists financeiro_enviar on storage.objects;
create policy financeiro_enviar on storage.objects
for insert to authenticated
with check (bucket_id = 'financeiro' and private.eh_admin_diavicon());

drop policy if exists financeiro_alterar on storage.objects;
create policy financeiro_alterar on storage.objects
for update to authenticated
using (bucket_id = 'financeiro' and private.eh_admin_diavicon())
with check (bucket_id = 'financeiro' and private.eh_admin_diavicon());

drop policy if exists financeiro_apagar on storage.objects;
create policy financeiro_apagar on storage.objects
for delete to authenticated
using (bucket_id = 'financeiro' and private.eh_admin_diavicon());

commit;

-- ---------------------------------------------------------------------------
-- Conferência depois de aplicar
-- ---------------------------------------------------------------------------
-- 1. Nenhuma política de storage.objects SEM filtro de bucket pode deixar
--    outros usuários gravarem no bucket financeiro. Deve voltar vazio:
--      select policyname, cmd, qual, with_check from pg_policies
--      where schemaname = 'storage' and tablename = 'objects'
--        and coalesce(qual, '') || coalesce(with_check, '') not like '%bucket_id%';
-- 2. Bucket privado:
--      select id, public from storage.buckets where id = 'financeiro';
