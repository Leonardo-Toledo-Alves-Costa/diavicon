-- Ajuste das tabelas da Prova de Carga Dinâmica criadas pelo painel.
-- Para rodar no SQL Editor do Supabase. Não apaga tabelas nem dados e pode
-- rodar mais de uma vez sem erro.
--
-- Projeto, estrutura, empresa autora e autor NÃO se repetem aqui: vêm de
-- pontos_ensaios_geral pelo ponto_id, e as permissões usam as funções que já
-- existem (can_access_point, can_edit_point, can_delete_point), como nas
-- outras famílias de ensaio.
--
-- Corrige:
--   * colunas de ligação (FK) com padrão gen_random_uuid(): um insert sem
--     local/planta/elemento geraria um id aleatório e falharia;
--   * ligações sem "on delete": apagar um ponto travaria por causa da prova;
--   * números gravados como texto;
--   * colunas que faltam (código do sensor, arquivo do canal, vibração e
--     deslocamento no resultado…);
--   * nomes com erro de digitação (tamano, medida_removida, exitacao);
--   * chaves únicas (reanalisar sobrescreve em vez de duplicar);
-- e cria o que as tabelas pelo painel não trazem: tipo de ensaio, gatilhos,
-- permissões (RLS) e o bucket privado dos arquivos.

begin;

-- Converte uma coluna para outro tipo só se ainda não estiver nele.
create or replace function pg_temp.pcd_tipo(p_tabela text, p_coluna text, p_tipo text, p_using text)
returns void
language plpgsql
as $$
declare
  v_atual text;
begin
  select format_type(a.atttypid, a.atttypmod) into v_atual
  from pg_attribute a
  where a.attrelid = ('public.' || p_tabela)::regclass and a.attname = p_coluna and not a.attisdropped;
  if v_atual is not null and v_atual <> p_tipo then
    execute format('alter table public.%I alter column %I type %s using %s', p_tabela, p_coluna, p_tipo, p_using);
  end if;
end;
$$;

-- Renomeia uma coluna se o nome antigo existir e o novo não.
create or replace function pg_temp.pcd_renomear(p_tabela text, p_de text, p_para text)
returns void
language plpgsql
as $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = p_tabela and column_name = p_de)
     and not exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = p_tabela and column_name = p_para) then
    execute format('alter table public.%I rename column %I to %I', p_tabela, p_de, p_para);
  end if;
end;
$$;

-- ===========================================================================
-- prova_carga_dinamica
-- ===========================================================================
select pg_temp.pcd_renomear('prova_carga_dinamica', 'taxa_amostragem', 'taxa_amostragem_hz');

alter table public.prova_carga_dinamica
  add column if not exists atualizado_em timestamptz not null default now(),
  add column if not exists uso_estrutura text,
  add column if not exists taxa_amostragem_hz numeric;

select pg_temp.pcd_tipo('prova_carga_dinamica', 'taxa_amostragem_hz', 'numeric', 'nullif(trim(taxa_amostragem_hz::text), '''')::numeric');
select pg_temp.pcd_tipo('prova_carga_dinamica', 'freq_critica_hz', 'numeric', 'nullif(trim(freq_critica_hz::text), '''')::numeric');
select pg_temp.pcd_tipo('prova_carga_dinamica', 'vibracao_max_db', 'numeric', 'nullif(trim(vibracao_max_db::text), '''')::numeric');
select pg_temp.pcd_tipo('prova_carga_dinamica', 'freq_natural_min_hz', 'numeric', 'nullif(trim(freq_natural_min_hz::text), '''')::numeric');
select pg_temp.pcd_tipo('prova_carga_dinamica', 'desloc_max_mm', 'numeric', 'nullif(trim(desloc_max_mm::text), '''')::numeric');

alter table public.prova_carga_dinamica
  alter column ponto_id drop default,
  alter column local_id drop default,
  alter column planta_id drop default,
  alter column taxa_amostragem_hz set default 400,
  alter column unidade set default 'g',
  alter column parametros set default '{}'::jsonb,
  alter column geometria set default '{}'::jsonb,
  alter column status set default 'rascunho';

update public.prova_carga_dinamica set parametros = '{}'::jsonb where parametros is null;
update public.prova_carga_dinamica set geometria = '{}'::jsonb where geometria is null;
update public.prova_carga_dinamica set status = 'rascunho' where status is null;

alter table public.prova_carga_dinamica
  drop constraint if exists prova_carga_dinamica_ponto_id_fkey,
  drop constraint if exists prova_carga_dinamica_local_id_fkey,
  drop constraint if exists prova_carga_dinamica_planta_id_fkey,
  drop constraint if exists prova_carga_dinamica_ponto_id_key,
  drop constraint if exists prova_carga_dinamica_status_check;

alter table public.prova_carga_dinamica
  add constraint prova_carga_dinamica_ponto_id_fkey foreign key (ponto_id) references public.pontos_ensaios_geral (id) on delete cascade,
  add constraint prova_carga_dinamica_local_id_fkey foreign key (local_id) references public.estruturas_locais (id) on delete set null,
  add constraint prova_carga_dinamica_planta_id_fkey foreign key (planta_id) references public.estruturas_plantas (id) on delete set null,
  add constraint prova_carga_dinamica_ponto_id_key unique (ponto_id),
  add constraint prova_carga_dinamica_status_check check (status in ('rascunho', 'em_analise', 'concluido'));

alter table public.prova_carga_dinamica
  alter column ponto_id set not null,
  alter column status set not null;

-- ===========================================================================
-- prova_carga_dinamica_sensor
-- ===========================================================================
alter table public.prova_carga_dinamica_sensor
  add column if not exists codigo text;

update public.prova_carga_dinamica_sensor set codigo = coalesce(nome, id::text) where codigo is null;
update public.prova_carga_dinamica_sensor set tipo = 'medicao' where tipo is null;

alter table public.prova_carga_dinamica_sensor
  alter column prova_id drop default,
  alter column elemento_id drop default,
  alter column tipo set default 'medicao',
  alter column ordem set default 0;

alter table public.prova_carga_dinamica_sensor
  drop constraint if exists prova_carga_dinamica_sensor_prova_id_fkey,
  drop constraint if exists prova_carga_dinamica_sensor_elemento_id_fkey,
  drop constraint if exists prova_carga_dinamica_sensor_prova_codigo_key,
  drop constraint if exists prova_carga_dinamica_sensor_tipo_check;

alter table public.prova_carga_dinamica_sensor
  add constraint prova_carga_dinamica_sensor_prova_id_fkey foreign key (prova_id) references public.prova_carga_dinamica (id) on delete cascade,
  add constraint prova_carga_dinamica_sensor_elemento_id_fkey foreign key (elemento_id) references public.elementos_estruturais (id) on delete set null,
  add constraint prova_carga_dinamica_sensor_prova_codigo_key unique (prova_id, codigo),
  add constraint prova_carga_dinamica_sensor_tipo_check check (tipo in ('medicao', 'apoio', 'virtual'));

alter table public.prova_carga_dinamica_sensor
  alter column prova_id set not null,
  alter column codigo set not null,
  alter column tipo set not null;

-- ===========================================================================
-- prova_carga_dinamica_arquivo
-- ===========================================================================
select pg_temp.pcd_renomear('prova_carga_dinamica_arquivo', 'tamano_original_bytes', 'tamanho_original_bytes');

update public.prova_carga_dinamica_arquivo set inicio_s = 0 where inicio_s is null;
update public.prova_carga_dinamica_arquivo set cabecalho = '{}'::jsonb where cabecalho is null;

alter table public.prova_carga_dinamica_arquivo
  alter column prova_id drop default,
  alter column inicio_s set default 0,
  alter column cabecalho set default '{}'::jsonb,
  alter column formato_serie set default 'f32le_gzip',
  alter column amostras_por_bloco set default 240000;

alter table public.prova_carga_dinamica_arquivo
  drop constraint if exists prova_carga_dinamica_arquivo_prova_id_fkey,
  drop constraint if exists prova_carga_dinamica_arquivo_prova_sha_key;

alter table public.prova_carga_dinamica_arquivo
  add constraint prova_carga_dinamica_arquivo_prova_id_fkey foreign key (prova_id) references public.prova_carga_dinamica (id) on delete cascade,
  add constraint prova_carga_dinamica_arquivo_prova_sha_key unique (prova_id, sha256);

alter table public.prova_carga_dinamica_arquivo
  alter column prova_id set not null,
  alter column inicio_s set not null;

-- ===========================================================================
-- prova_carga_dinamica_canal
-- ===========================================================================
select pg_temp.pcd_renomear('prova_carga_dinamica_canal', 'medida_removida', 'media_removida');

alter table public.prova_carga_dinamica_canal
  add column if not exists arquivo_id uuid,
  add column if not exists media_removida numeric;

select pg_temp.pcd_tipo('prova_carga_dinamica_canal', 'n_saturadas', 'integer', 'coalesce(n_saturadas, 0)::integer');
select pg_temp.pcd_tipo('prova_carga_dinamica_canal', 'n_invalidas', 'integer', 'coalesce(n_invalidas, 0)::integer');

update public.prova_carga_dinamica_canal set n_saturadas = 0 where n_saturadas is null;
update public.prova_carga_dinamica_canal set n_invalidas = 0 where n_invalidas is null;
update public.prova_carga_dinamica_canal set ativo = true where ativo is null;
update public.prova_carga_dinamica_canal set fator_escala = 1 where fator_escala is null;

alter table public.prova_carga_dinamica_canal
  alter column prova_id drop default,
  alter column sensor_id drop default,
  alter column unidade set default 'g',
  alter column fator_escala set default 1,
  alter column n_saturadas set default 0,
  alter column n_invalidas set default 0,
  alter column ativo set default true;

alter table public.prova_carga_dinamica_canal
  drop constraint if exists prova_carga_dinamica_canal_prova_id_fkey,
  drop constraint if exists prova_carga_dinamica_canal_sensor_id_fkey,
  drop constraint if exists prova_carga_dinamica_canal_arquivo_id_fkey,
  drop constraint if exists prova_carga_dinamica_canal_arquivo_coluna_key,
  drop constraint if exists prova_carga_dinamica_canal_eixo_check;

alter table public.prova_carga_dinamica_canal
  add constraint prova_carga_dinamica_canal_prova_id_fkey foreign key (prova_id) references public.prova_carga_dinamica (id) on delete cascade,
  add constraint prova_carga_dinamica_canal_sensor_id_fkey foreign key (sensor_id) references public.prova_carga_dinamica_sensor (id) on delete set null,
  add constraint prova_carga_dinamica_canal_arquivo_id_fkey foreign key (arquivo_id) references public.prova_carga_dinamica_arquivo (id) on delete cascade,
  add constraint prova_carga_dinamica_canal_arquivo_coluna_key unique (arquivo_id, coluna),
  add constraint prova_carga_dinamica_canal_eixo_check check (eixo in ('X', 'Y', 'Z'));

alter table public.prova_carga_dinamica_canal
  alter column prova_id set not null,
  alter column arquivo_id set not null,
  alter column coluna set not null,
  alter column fator_escala set not null,
  alter column n_saturadas set not null,
  alter column n_invalidas set not null,
  alter column ativo set not null;

create index if not exists prova_carga_dinamica_canal_prova_idx
  on public.prova_carga_dinamica_canal (prova_id);

-- ===========================================================================
-- prova_carga_dinamica_estagio
-- ===========================================================================
select pg_temp.pcd_renomear('prova_carga_dinamica_estagio', 'freq_exitacao_hz', 'freq_excitacao_hz');

update public.prova_carga_dinamica_estagio set ativo = true where ativo is null;
update public.prova_carga_dinamica_estagio set ordem = 0 where ordem is null;
update public.prova_carga_dinamica_estagio set atualizado_em = now() where atualizado_em is null;

alter table public.prova_carga_dinamica_estagio
  alter column prova_id drop default,
  alter column atualizado_em set default now(),
  alter column ordem set default 0,
  alter column ativo set default true;

alter table public.prova_carga_dinamica_estagio
  drop constraint if exists prova_carga_dinamica_estagio_prova_id_fkey,
  drop constraint if exists prova_carga_dinamica_estagio_tempo_check;

alter table public.prova_carga_dinamica_estagio
  add constraint prova_carga_dinamica_estagio_prova_id_fkey foreign key (prova_id) references public.prova_carga_dinamica (id) on delete cascade,
  add constraint prova_carga_dinamica_estagio_tempo_check check (t_fim_s > t_inicio_s);

alter table public.prova_carga_dinamica_estagio
  alter column prova_id set not null,
  alter column nome set not null,
  alter column t_inicio_s set not null,
  alter column t_fim_s set not null,
  alter column ativo set not null;

create index if not exists prova_carga_dinamica_estagio_prova_idx
  on public.prova_carga_dinamica_estagio (prova_id, ordem);

-- ===========================================================================
-- prova_carga_dinamica_resultado
-- ===========================================================================
-- Os 3 maiores picos, em colunas separadas (sem lista).
select pg_temp.pcd_renomear('prova_carga_dinamica_resultado', 'picos_hz', 'pico_1_hz');

alter table public.prova_carga_dinamica_resultado
  add column if not exists pico_1_hz numeric,
  add column if not exists pico_2_hz numeric,
  add column if not exists pico_3_hz numeric,
  add column if not exists busca_min_hz numeric,
  add column if not exists busca_max_hz numeric,
  add column if not exists amplitude_desloc_mm numeric,
  add column if not exists vibracao_db numeric,
  add column if not exists faixa_vibracao text,
  add column if not exists espectro jsonb,
  add column if not exists desloc_passa_alta_hz numeric,
  add column if not exists desloc_max_mm numeric,
  add column if not exists desloc_min_mm numeric,
  add column if not exists desloc_pp_mm numeric,
  add column if not exists desloc_rms_mm numeric,
  add column if not exists desloc_taxa_hz numeric,
  add column if not exists desloc_serie_caminho text;

alter table public.prova_carga_dinamica_resultado
  drop column if exists atualizado_por;

update public.prova_carga_dinamica_resultado set pico_escolhido = 1 where pico_escolhido is null;
update public.prova_carga_dinamica_resultado set ajuste_manual = false where ajuste_manual is null;
update public.prova_carga_dinamica_resultado set atualizado_em = now() where atualizado_em is null;

alter table public.prova_carga_dinamica_resultado
  alter column prova_id drop default,
  alter column estagio_id drop default,
  alter column canal_id drop default,
  alter column atualizado_em set default now(),
  alter column pico_escolhido set default 1,
  alter column ajuste_manual set default false;

alter table public.prova_carga_dinamica_resultado
  drop constraint if exists prova_carga_dinamica_resultado_prova_id_fkey,
  drop constraint if exists prova_carga_dinamica_resultado_estagio_id_fkey,
  drop constraint if exists prova_carga_dinamica_resultado_canal_id_fkey,
  drop constraint if exists prova_carga_dinamica_resultado_atualizado_por_fkey,
  drop constraint if exists prova_carga_dinamica_resultado_estagio_canal_key,
  drop constraint if exists prova_carga_dinamica_resultado_pico_check,
  drop constraint if exists prova_carga_dinamica_resultado_faixa_check;

alter table public.prova_carga_dinamica_resultado
  add constraint prova_carga_dinamica_resultado_prova_id_fkey foreign key (prova_id) references public.prova_carga_dinamica (id) on delete cascade,
  add constraint prova_carga_dinamica_resultado_estagio_id_fkey foreign key (estagio_id) references public.prova_carga_dinamica_estagio (id) on delete cascade,
  add constraint prova_carga_dinamica_resultado_canal_id_fkey foreign key (canal_id) references public.prova_carga_dinamica_canal (id) on delete cascade,
  add constraint prova_carga_dinamica_resultado_estagio_canal_key unique (estagio_id, canal_id),
  add constraint prova_carga_dinamica_resultado_pico_check check (pico_escolhido between 1 and 3),
  add constraint prova_carga_dinamica_resultado_faixa_check
    check (faixa_vibracao in ('sem_dano', 'danos_leves', 'danos_severos', 'colapso'));

alter table public.prova_carga_dinamica_resultado
  alter column prova_id set not null,
  alter column estagio_id set not null,
  alter column canal_id set not null,
  alter column atualizado_em set not null,
  alter column pico_escolhido set not null,
  alter column ajuste_manual set not null;

create index if not exists prova_carga_dinamica_resultado_prova_idx
  on public.prova_carga_dinamica_resultado (prova_id);
create index if not exists prova_carga_dinamica_resultado_canal_idx
  on public.prova_carga_dinamica_resultado (canal_id);

-- ===========================================================================
-- Tipo de ensaio (mesma área e ícone da prova de carga estática).
-- ===========================================================================
insert into public.tipos_ensaio (id, nome, icone_path, area)
select gen_random_uuid(), 'Prova de carga dinâmica', t.icone_path, t.area
from public.tipos_ensaio t
where t.nome ilike 'prova de carga est%'
  and not exists (
    select 1 from public.tipos_ensaio x
    where x.nome ilike '%din_mic%' or x.nome ilike '%acelerometr%'
  )
limit 1;

-- ===========================================================================
-- Gatilhos: o vínculo com o ponto e com a prova vem do servidor, não do app.
-- ===========================================================================
create or replace function private.trg_pcd_prova()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if tg_op = 'UPDATE' then
    new.ponto_id := old.ponto_id;   -- o ensaio não troca de ponto
  end if;
  new.atualizado_em := now();
  return new;
end;
$$;

create or replace function private.trg_pcd_filho()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if tg_table_name = 'prova_carga_dinamica_canal' then
    select a.prova_id into new.prova_id
    from public.prova_carga_dinamica_arquivo a where a.id = new.arquivo_id;
  elsif tg_table_name = 'prova_carga_dinamica_resultado' then
    select e.prova_id into new.prova_id
    from public.prova_carga_dinamica_estagio e where e.id = new.estagio_id;
    if not exists (
      select 1 from public.prova_carga_dinamica_canal c
      where c.id = new.canal_id and c.prova_id = new.prova_id
    ) then
      raise exception 'Canal e estágio pertencem a provas diferentes.';
    end if;
    new.atualizado_em := now();
  elsif tg_table_name = 'prova_carga_dinamica_estagio' then
    new.atualizado_em := now();
  end if;
  return new;
end;
$$;

revoke all on function private.trg_pcd_prova() from public, anon, authenticated;
revoke all on function private.trg_pcd_filho() from public, anon, authenticated;

drop trigger if exists pcd_prova on public.prova_carga_dinamica;
create trigger pcd_prova
  before insert or update on public.prova_carga_dinamica
  for each row execute function private.trg_pcd_prova();

drop trigger if exists pcd_arquivo on public.prova_carga_dinamica_arquivo;

drop trigger if exists pcd_canal on public.prova_carga_dinamica_canal;
create trigger pcd_canal
  before insert or update on public.prova_carga_dinamica_canal
  for each row execute function private.trg_pcd_filho();

drop trigger if exists pcd_estagio on public.prova_carga_dinamica_estagio;
create trigger pcd_estagio
  before insert or update on public.prova_carga_dinamica_estagio
  for each row execute function private.trg_pcd_filho();

drop trigger if exists pcd_resultado on public.prova_carga_dinamica_resultado;
create trigger pcd_resultado
  before insert or update on public.prova_carga_dinamica_resultado
  for each row execute function private.trg_pcd_filho();

-- ===========================================================================
-- RLS: as mesmas regras do ponto do ensaio.
-- ===========================================================================
create or replace function private.pcd_pode_ver(p_prova_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1 from public.prova_carga_dinamica p
    where p.id = p_prova_id and private.can_access_point(p.ponto_id)
  );
$$;

create or replace function private.pcd_pode_editar(p_prova_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1 from public.prova_carga_dinamica p
    where p.id = p_prova_id and private.can_edit_point(p.ponto_id)
  );
$$;

revoke all on function private.pcd_pode_ver(uuid) from public, anon;
revoke all on function private.pcd_pode_editar(uuid) from public, anon;
grant execute on function private.pcd_pode_ver(uuid) to authenticated, service_role;
grant execute on function private.pcd_pode_editar(uuid) to authenticated, service_role;

alter table public.prova_carga_dinamica enable row level security;
alter table public.prova_carga_dinamica_sensor enable row level security;
alter table public.prova_carga_dinamica_arquivo enable row level security;
alter table public.prova_carga_dinamica_canal enable row level security;
alter table public.prova_carga_dinamica_estagio enable row level security;
alter table public.prova_carga_dinamica_resultado enable row level security;

-- Sem acesso anônimo; só usuários logados, filtrados pelas políticas.
revoke all on public.prova_carga_dinamica from anon;
revoke all on public.prova_carga_dinamica_sensor from anon;
revoke all on public.prova_carga_dinamica_arquivo from anon;
revoke all on public.prova_carga_dinamica_canal from anon;
revoke all on public.prova_carga_dinamica_estagio from anon;
revoke all on public.prova_carga_dinamica_resultado from anon;

grant select, insert, update, delete on public.prova_carga_dinamica to authenticated;
grant select, insert, update, delete on public.prova_carga_dinamica_sensor to authenticated;
grant select, insert, update, delete on public.prova_carga_dinamica_arquivo to authenticated;
grant select, insert, update, delete on public.prova_carga_dinamica_canal to authenticated;
grant select, insert, update, delete on public.prova_carga_dinamica_estagio to authenticated;
grant select, insert, update, delete on public.prova_carga_dinamica_resultado to authenticated;

drop policy if exists pcd_select on public.prova_carga_dinamica;
create policy pcd_select on public.prova_carga_dinamica
for select to authenticated
using (private.can_access_point(ponto_id));

drop policy if exists pcd_insert on public.prova_carga_dinamica;
create policy pcd_insert on public.prova_carga_dinamica
for insert to authenticated
with check (private.can_edit_point(ponto_id));

drop policy if exists pcd_update on public.prova_carga_dinamica;
create policy pcd_update on public.prova_carga_dinamica
for update to authenticated
using (private.can_edit_point(ponto_id))
with check (private.can_edit_point(ponto_id));

drop policy if exists pcd_delete on public.prova_carga_dinamica;
create policy pcd_delete on public.prova_carga_dinamica
for delete to authenticated
using (private.can_delete_point(ponto_id));

do $$
declare
  t text;
begin
  foreach t in array array[
    'prova_carga_dinamica_sensor',
    'prova_carga_dinamica_arquivo',
    'prova_carga_dinamica_canal',
    'prova_carga_dinamica_estagio',
    'prova_carga_dinamica_resultado'
  ] loop
    execute format('drop policy if exists %I on public.%I', t || '_select', t);
    execute format(
      'create policy %I on public.%I for select to authenticated using (private.pcd_pode_ver(prova_id))',
      t || '_select', t);
    execute format('drop policy if exists %I on public.%I', t || '_escrita', t);
    execute format(
      'create policy %I on public.%I for all to authenticated '
      'using (private.pcd_pode_editar(prova_id)) with check (private.pcd_pode_editar(prova_id))',
      t || '_escrita', t);
  end loop;
end;
$$;

-- ===========================================================================
-- Bucket privado (o mesmo da importação do ultrassom).
-- Caminho: <projeto_id>/pcd/<prova_id>/…
-- ===========================================================================
insert into storage.buckets (id, name, public)
values ('ensaios-importacoes', 'ensaios-importacoes', false)
on conflict (id) do nothing;

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

-- Regravar (reanálise) e apagar arquivos: quem pode editar o ensaio.
drop policy if exists ensaios_importacoes_pcd_update on storage.objects;
create policy ensaios_importacoes_pcd_update on storage.objects
for update to authenticated
using (
  bucket_id = 'ensaios-importacoes'
  and (storage.foldername(name))[2] = 'pcd'
  and private.pcd_pode_editar(case when (storage.foldername(name))[2] = 'pcd'
                                   then ((storage.foldername(name))[3])::uuid end)
);

drop policy if exists ensaios_importacoes_pcd_delete on storage.objects;
create policy ensaios_importacoes_pcd_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'ensaios-importacoes'
  and (storage.foldername(name))[2] = 'pcd'
  and private.pcd_pode_editar(case when (storage.foldername(name))[2] = 'pcd'
                                   then ((storage.foldername(name))[3])::uuid end)
);

commit;
