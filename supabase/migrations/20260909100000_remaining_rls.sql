-- RLS hardening for 56 application tables in this migration.
--
-- This migration deliberately leaves the five structural tables without RLS:
-- estruturas, estruturas_locais, estruturas_plantas, elementos_estruturais and
-- projeto_estruturas. public.projetos is the 57th table in the overall rollout,
-- but its RLS and grants are already owned by
-- 20260903120000_harden_home_projects_rls.sql and are preserved here. Other
-- existing RLS tables outside the explicit target arrays are left untouched.
-- After this migration, 74 public tables are protected and the five structural
-- tables remain intentionally pending structural-policy work.
-- The project access helper already used by the team policies is preserved;
-- the helpers below add the individual active-member check needed by these
-- tables.

begin;

create schema if not exists private;

-- The existing column is not sufficient to scope a region.  Populate rows
-- that have exactly one project through the current plant/project links and
-- leave ambiguous or orphaned historical rows NULL (fail closed in policy).
alter table public.regioes_ensaio
  add column if not exists projeto_id uuid;

update public.regioes_ensaio r
set projeto_id = mapped.projeto_id
from (
  select r0.id, (array_agg(distinct pe.projeto_id))[1] as projeto_id
  from public.regioes_ensaio r0
  join public.estruturas_plantas ep on ep.id = r0.planta_id
  join public.projeto_estruturas pe on pe.estrutura_id = ep.estrutura_id
  where r0.projeto_id is null
  group by r0.id
  having count(distinct pe.projeto_id) = 1
) mapped
where r.id = mapped.id;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'regioes_ensaio_projeto_id_fkey'
      and conrelid = 'public.regioes_ensaio'::regclass
  ) then
    alter table public.regioes_ensaio
      add constraint regioes_ensaio_projeto_id_fkey
      foreign key (projeto_id) references public.projetos(id)
      on delete cascade;
  end if;
end;
$$;

-- UUID defaults are valid for primary keys only. A generated foreign key,
-- tenant or author id can silently create an incoherent payload.
do $$
declare v record;
begin
  for v in
    select c.table_name, c.column_name
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = any (array[
        'anomalias','condicoes_local','conjuntos_estruturais','empresa_clientes','empresa_plano_assinatura','empresa_plano_consumo','ensaio_elementos','ensaio_resultados','ensaios','ensaios_contratados','feed_comentarios','feed_fotos','feed_likes','feed_posts','galeria_ponto_ensaio_carb','galeria_ponto_ensaio_resistividade','galeria_pontos_ensaios_geral','midias','midias_ensaios','papeis','permissoes','ponto_ensaio_arrancamento','ponto_ensaio_arrancamento_leitura','ponto_ensaio_arrancamento_ruptura','ponto_ensaio_carb','ponto_ensaio_carb_frentes','ponto_ensaio_esclerometria','ponto_ensaio_esclerometria_leituras','ponto_ensaio_potencial','ponto_ensaio_potencial_leitura','ponto_ensaio_prova_carga','ponto_ensaio_prova_carga_ponto_leitura','ponto_ensaio_prova_carga_ponto_medicao','ponto_ensaio_resistividade_leitura','ponto_ensaio_ultrassom','ponto_ensaio_ultrassom_direto_leitura','ponto_ensaio_ultrassom_direto_medicao','ponto_ensaio_ultrassom_indireto_leitura','ponto_ensaio_ultrassom_indireto_medicao','ponto_inspecao_regiao','ponto_inspecao_visual','ponto_inspecao_visual_anomalia','ponto_inspecao_visual_galeria','ponto_inspecao_visual_geral','pontos_ensaios_geral','prioridade','projeto_convites_cliente','regioes_ensaio','relatorio_ensaio','relatorios','revestimentos_elemento','setores','sistemas_habitacionais','status_projeto','tipologias_elemento','tipologias_estrutura'
      ])
      and c.column_name <> 'id'
      and (c.column_name like '%_id' or c.column_name in ('criado_por', 'usuario_id', 'empresa_id', 'post_id'))
      and c.column_default like '%gen_random_uuid%'
  loop
    execute format('alter table public.%I alter column %I drop default', v.table_name, v.column_name);
  end loop;
end;
$$;

create index if not exists regioes_ensaio_projeto_id_idx
  on public.regioes_ensaio (projeto_id);

create unique index if not exists ensaios_contratados_regiao_tipo_unique
  on public.ensaios_contratados (regiao_id, tipo_ensaio_id)
  where regiao_id is not null and tipo_ensaio_id is not null;

-- Server-owned author company. Existing rows are backfilled only where the
-- creator still resolves to a user; unresolved history aborts this migration
-- rather than receiving guessed ownership.
alter table public.pontos_ensaios_geral
  add column if not exists empresa_autora_id uuid;

update public.pontos_ensaios_geral p
set empresa_autora_id = u.empresa_id
from public.usuarios u
where p.empresa_autora_id is null
  and p.criado_por = u.id::text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'pontos_ensaios_geral_empresa_autora_id_fkey'
      and conrelid = 'public.pontos_ensaios_geral'::regclass
  ) then
    alter table public.pontos_ensaios_geral
      add constraint pontos_ensaios_geral_empresa_autora_id_fkey
      foreign key (empresa_autora_id) references public.empresas(id)
      on delete restrict;
  end if;
end;
$$;

create index if not exists pontos_ensaios_geral_empresa_autora_id_idx
  on public.pontos_ensaios_geral (empresa_autora_id);

do $$
begin
  if exists (select 1 from public.pontos_ensaios_geral where empresa_autora_id is null) then
    raise exception using errcode = '23514', message = 'Há pontos de ensaio sem empresa autora resolvida; corrija o histórico antes de ativar RLS.';
  end if;
  alter table public.pontos_ensaios_geral alter column empresa_autora_id set not null;
end;
$$;

alter table public.relatorio_ensaio
  add column if not exists empresa_autora_id uuid;

update public.relatorio_ensaio r
set empresa_autora_id = u.empresa_id
from public.usuarios u
where r.empresa_autora_id is null
  and r.criado_por = u.id::text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'relatorio_ensaio_empresa_autora_id_fkey'
      and conrelid = 'public.relatorio_ensaio'::regclass
  ) then
    alter table public.relatorio_ensaio
      add constraint relatorio_ensaio_empresa_autora_id_fkey
      foreign key (empresa_autora_id) references public.empresas(id)
      on delete restrict;
  end if;
end;
$$;

create index if not exists relatorio_ensaio_empresa_autora_id_idx
  on public.relatorio_ensaio (empresa_autora_id);

alter table public.relatorio_ensaio
  alter column projeto_id drop default,
  alter column estrutura_id drop default,
  alter column tipo_ensaio_id drop default,
  alter column projeto_id set not null,
  alter column estrutura_id set not null,
  alter column tipo_ensaio_id set not null;

do $$
begin
  if exists (select 1 from public.relatorio_ensaio where empresa_autora_id is null) then
    raise exception using errcode = '23514', message = 'Há relatórios sem empresa autora resolvida; corrija o histórico antes de ativar RLS.';
  end if;
  alter table public.relatorio_ensaio alter column empresa_autora_id set not null;
end;
$$;

-- Ownership helpers.  All functions are fixed-search-path SECURITY DEFINER
-- functions and are callable only by authenticated requests and service_role.
create or replace function private.is_active_actor()
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.usuarios u
    where u.id = (select auth.uid())
      and u.ativo is true
  )
$$;

create or replace function private.is_active_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.usuarios u
    where u.id = (select auth.uid())
      and u.ativo is true
      and u.is_admin is true
  )
$$;

create or replace function private.can_project_company(
  p_projeto_id uuid,
  p_empresa_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.projetos p
    where p.id = p_projeto_id
      and (
        p.empresa_gestora_id = p_empresa_id
        or (
          p.empresa_cliente_id = p_empresa_id
          and p.status_vinculo_cliente = 'ativo'
        )
        or exists (
          select 1
          from public.projeto_empresas_colaboradoras c
          where c.projeto_id = p.id
            and c.empresa_id = p_empresa_id
            and c.status = 'aceito'
        )
      )
  )
$$;

-- Keep private.can_access_project unchanged. This version adds the required
-- individual team/admin check on top of its company-level relationship check.
create or replace function private.can_access_project_member(p_projeto_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.projetos p
    join public.usuarios u
      on u.id = (select auth.uid())
     and u.ativo is true
    where p.id = p_projeto_id
      and (
        p.empresa_gestora_id = u.empresa_id
        or (
          p.empresa_cliente_id = u.empresa_id
          and p.status_vinculo_cliente = 'ativo'
        )
        or exists (
          select 1
          from public.projeto_empresas_colaboradoras c
          where c.projeto_id = p.id
            and c.empresa_id = u.empresa_id
            and c.status = 'aceito'
        )
      )
      and (
        u.is_admin_empresa is true
        or u.is_admin is true
        or exists (
          select 1
          from public.projeto_equipe_interna e
          where e.projeto_id = p.id
            and e.usuario_id = u.id
            and e.empresa_id = u.empresa_id
            and e.ativo is true
        )
      )
  )
$$;

create or replace function private.can_manage_project_member(p_projeto_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.projetos p
    join public.usuarios u
      on u.id = (select auth.uid())
     and u.ativo is true
     and u.empresa_id = p.empresa_gestora_id
    where p.id = p_projeto_id
      and (
        u.is_admin_empresa is true
        or u.is_admin is true
        or exists (
          select 1
          from public.projeto_equipe_interna e
          where e.projeto_id = p.id
            and e.usuario_id = u.id
            and e.empresa_id = u.empresa_id
            and e.ativo is true
            and e.is_gestor is true
        )
      )
  )
$$;

create or replace function private.can_access_point(p_ponto_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.pontos_ensaios_geral p
    where p.id = p_ponto_id
      and private.can_access_project_member(p.projeto_id)
  )
$$;

create or replace function private.can_edit_point(p_ponto_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.pontos_ensaios_geral p
    join public.usuarios u on u.id = (select auth.uid()) and u.ativo is true
    where p.id = p_ponto_id
      and private.can_access_project_member(p.projeto_id)
      and p.empresa_autora_id = u.empresa_id
  )
$$;

create or replace function private.can_delete_point(p_ponto_id uuid)
returns boolean language sql stable security definer set search_path = public, pg_catalog as $$
  select private.can_edit_point(p_ponto_id)
    or exists (select 1 from public.pontos_ensaios_geral p where p.id = p_ponto_id and private.can_manage_project_member(p.projeto_id))
$$;

create or replace function private.can_access_point_in_project(
  p_ponto_id uuid,
  p_projeto_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.pontos_ensaios_geral p
    where p.id = p_ponto_id
      and p.projeto_id = p_projeto_id
      and private.can_access_project_member(p.projeto_id)
  )
$$;

create or replace function private.can_edit_point_in_project(
  p_ponto_id uuid,
  p_projeto_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.pontos_ensaios_geral p
    where p.id = p_ponto_id
      and p.projeto_id = p_projeto_id
      and private.can_edit_point(p.id)
  )
$$;

create or replace function private.can_access_report(p_report_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1 from public.relatorio_ensaio r
    where r.id = p_report_id
      and private.can_access_project_member(r.projeto_id)
  )
$$;

create or replace function private.can_edit_report(p_report_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1
    from public.relatorio_ensaio r
    join public.usuarios u on u.id = (select auth.uid()) and u.ativo is true
    where r.id = p_report_id
      and private.can_access_project_member(r.projeto_id)
      and r.empresa_autora_id = u.empresa_id
  )
$$;

create or replace function private.can_delete_report(p_report_id uuid)
returns boolean language sql stable security definer set search_path = public, pg_catalog as $$
  select private.can_edit_report(p_report_id)
    or exists (select 1 from public.relatorio_ensaio r where r.id = p_report_id and private.can_manage_project_member(r.projeto_id))
$$;

create or replace function private.can_manage_feed_post(p_post_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1 from public.feed_posts p
    where p.id = p_post_id
      and p.usuario_id = (select auth.uid())
      and private.is_active_actor()
  )
$$;

-- Convert only an object owned by the current user into the canonical public
-- URL stored by project/client rows. RPC callers pass an object path, never an
-- arbitrary URL.
create or replace function private.canonical_project_image_url(
  p_object_path text,
  p_actor_id uuid,
  p_directory text
)
returns text
language plpgsql
stable
security definer
set search_path = public, pg_catalog
as $$
declare
  v_path text := nullif(btrim(p_object_path), '');
  v_prefix text;
  v_filename text;
  v_storage_origin text := pg_catalog.regexp_replace(
    auth.jwt() ->> 'iss',
    '/auth/v1/?$',
    ''
  );
begin
  if v_path is null then
    return null;
  end if;
  if p_actor_id is null or p_directory not in ('capas', 'clientes') then
    raise exception using errcode = '22023', message = 'Caminho de imagem inválido.';
  end if;

  v_prefix := 'users/' || p_actor_id::text || '/' || p_directory || '/';
  v_filename := substring(v_path from char_length(v_prefix) + 1);
  if v_storage_origin is null
     or char_length(v_path) > 512
     or left(v_path, char_length(v_prefix)) <> v_prefix
     or v_filename !~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,254}$'
     or not exists (
       select 1
       from storage.objects o
       where o.bucket_id = 'projetos'
         and o.name = v_path
     ) then
    raise exception using errcode = '22023', message = 'A imagem precisa existir no caminho privado do usuário autenticado.';
  end if;

  return v_storage_origin || '/storage/v1/object/public/projetos/' || v_path;
end;
$$;

create or replace function private.set_point_actor_company()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if tg_op = 'INSERT' and (select auth.uid()) is not null then
    new.criado_por := (select auth.uid())::text;
    new.empresa_autora_id := private.active_actor_company_id();
  end if;
  if tg_op = 'INSERT' and (new.projeto_id is null or new.estrutura_id is null or new.tipo_ensaio_id is null) then
    raise exception using errcode = '23514', message = 'Novos pontos exigem projeto, estrutura e tipo de ensaio.';
  end if;
  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id
       or new.projeto_id is distinct from old.projeto_id
       or new.criado_por is distinct from old.criado_por
       or new.empresa_autora_id is distinct from old.empresa_autora_id then
      raise exception using errcode = '42501', message = 'A identidade, projeto e autoria do ponto não podem ser alterados.';
    end if;
  end if;
  if new.estrutura_id is not null and not exists (
    select 1 from public.projeto_estruturas pe
    where pe.projeto_id = new.projeto_id and pe.estrutura_id = new.estrutura_id
  ) then
    raise exception using errcode = '23514', message = 'A estrutura do ponto não pertence ao projeto.';
  end if;
  if new.elemento_estrutural_id is not null and not exists (
    select 1 from public.elementos_estruturais e
    where e.id = new.elemento_estrutural_id
      and (new.estrutura_id is null or e.estrutura_id = new.estrutura_id)
      and exists (select 1 from public.projeto_estruturas pe where pe.projeto_id = new.projeto_id and pe.estrutura_id = e.estrutura_id)
  ) then
    raise exception using errcode = '23514', message = 'O elemento do ponto não pertence à estrutura e projeto informados.';
  end if;
  return new;
end;
$$;

create or replace function private.set_report_actor_company()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if tg_op = 'INSERT' and (select auth.uid()) is not null then
    new.criado_por := (select auth.uid())::text;
    new.empresa_autora_id := private.active_actor_company_id();
  end if;
  if tg_op = 'INSERT' and (new.projeto_id is null or new.estrutura_id is null or new.tipo_ensaio_id is null) then
    raise exception using errcode = '23514', message = 'Novos relatórios exigem projeto, estrutura e tipo de ensaio.';
  end if;
  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id
       or new.projeto_id is distinct from old.projeto_id
       or new.criado_por is distinct from old.criado_por
       or new.empresa_autora_id is distinct from old.empresa_autora_id then
      raise exception using errcode = '42501', message = 'A identidade, projeto e autoria do relatório não podem ser alterados.';
    end if;
  end if;
  if new.estrutura_id is not null and not exists (
    select 1 from public.projeto_estruturas pe
    where pe.projeto_id = new.projeto_id and pe.estrutura_id = new.estrutura_id
  ) then
    raise exception using errcode = '23514', message = 'A estrutura do relatório não pertence ao projeto.';
  end if;
  return new;
end;
$$;

create or replace function private.enforce_region_update()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if (select auth.uid()) is not null and tg_op = 'INSERT' then
    new.criado_por := (select auth.uid());
  end if;
  if tg_op = 'UPDATE' and (
    new.id is distinct from old.id
    or new.projeto_id is distinct from old.projeto_id
    or new.planta_id is distinct from old.planta_id
    or new.empresa_id is distinct from old.empresa_id
    or new.criado_por is distinct from old.criado_por
  ) then
    raise exception using errcode = '42501', message = 'O projeto, planta, empresa e autor da região não podem ser alterados.';
  end if;
  if not exists (
    select 1
    from public.estruturas_plantas ep
    join public.projeto_estruturas pe on pe.estrutura_id = ep.estrutura_id
    join public.elementos_estruturais e on e.id = new.elemento_id and e.estrutura_id = ep.estrutura_id
    where ep.id = new.planta_id and pe.projeto_id = new.projeto_id
  ) then
    raise exception using errcode = '23514', message = 'A planta e o elemento da região devem pertencer à estrutura vinculada ao projeto.';
  end if;
  return new;
end;
$$;

create or replace function private.enforce_contract_update()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if tg_op = 'INSERT' and (new.projeto_id is null or new.estrutura_id is null or new.empresa_id is null or new.tipo_ensaio_id is null or new.regiao_id is null) then
    raise exception using errcode = '23514', message = 'Novos contratos exigem projeto, estrutura, empresa, tipo de ensaio e região.';
  end if;
  if tg_op = 'UPDATE' and (
    new.id is distinct from old.id
    or new.projeto_id is distinct from old.projeto_id
    or new.estrutura_id is distinct from old.estrutura_id
    or new.empresa_id is distinct from old.empresa_id
    or new.tipo_ensaio_id is distinct from old.tipo_ensaio_id
    or new.regiao_id is distinct from old.regiao_id
  ) then
    raise exception using errcode = '42501', message = 'O escopo do ensaio contratado não pode ser alterado.';
  end if;
  if not exists (select 1 from public.projeto_estruturas pe where pe.projeto_id = new.projeto_id and pe.estrutura_id = new.estrutura_id)
     or not private.can_project_company(new.projeto_id, new.empresa_id)
     or (new.regiao_id is not null and not exists (
       select 1 from public.regioes_ensaio r
       join public.estruturas_plantas ep on ep.id = r.planta_id
       where r.id = new.regiao_id and r.projeto_id = new.projeto_id and ep.estrutura_id = new.estrutura_id
     )) then
    raise exception using errcode = '23514', message = 'O contrato deve usar empresa, estrutura e região vinculadas ao mesmo projeto.';
  end if;
  return new;
end;
$$;

create or replace function private.enforce_catalog_tenant_update()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_catalog
as $$
begin
  if new.empresa_id is distinct from old.empresa_id then
    raise exception using errcode = '42501', message = 'A empresa do catálogo não pode ser alterada.';
  end if;
  return new;
end;
$$;

drop trigger if exists pontos_ensaios_geral_actor_company on public.pontos_ensaios_geral;
create trigger pontos_ensaios_geral_actor_company
before insert or update on public.pontos_ensaios_geral
for each row execute function private.set_point_actor_company();

drop trigger if exists relatorio_ensaio_actor_company on public.relatorio_ensaio;
create trigger relatorio_ensaio_actor_company
before insert or update on public.relatorio_ensaio
for each row execute function private.set_report_actor_company();

drop trigger if exists regioes_ensaio_immutable_scope on public.regioes_ensaio;
create trigger regioes_ensaio_immutable_scope
before insert or update on public.regioes_ensaio
for each row execute function private.enforce_region_update();

drop trigger if exists ensaios_contratados_immutable_scope on public.ensaios_contratados;
create trigger ensaios_contratados_immutable_scope
before insert or update on public.ensaios_contratados
for each row execute function private.enforce_contract_update();

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'anomalias', 'condicoes_local', 'conjuntos_estruturais',
    'revestimentos_elemento', 'sistemas_habitacionais',
    'tipologias_elemento', 'tipologias_estrutura'
  ] loop
    execute format('drop trigger if exists %I on public.%I',
      v_table || '_immutable_tenant', v_table);
    execute format(
      'create trigger %I before update on public.%I for each row execute function private.enforce_catalog_tenant_update()',
      v_table || '_immutable_tenant', v_table
    );
  end loop;
end;
$$;

-- Remove stale disabled policies only from this migration's target set. No
-- existing policy on an RLS-protected table is touched.
do $$
declare
  v_policy record;
begin
  for v_policy in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = any (array[
        'anomalias','condicoes_local','conjuntos_estruturais',
        'empresa_clientes','empresa_plano_assinatura','empresa_plano_consumo',
        'ensaio_elementos','ensaio_resultados','ensaios','ensaios_contratados',
        'feed_comentarios','feed_fotos','feed_likes','feed_posts',
        'galeria_ponto_ensaio_carb','galeria_ponto_ensaio_resistividade',
        'galeria_pontos_ensaios_geral','midias','midias_ensaios','papeis',
        'permissoes','ponto_ensaio_arrancamento','ponto_ensaio_arrancamento_leitura',
        'ponto_ensaio_arrancamento_ruptura','ponto_ensaio_carb',
        'ponto_ensaio_carb_frentes','ponto_ensaio_esclerometria',
        'ponto_ensaio_esclerometria_leituras','ponto_ensaio_potencial',
        'ponto_ensaio_potencial_leitura','ponto_ensaio_prova_carga',
        'ponto_ensaio_prova_carga_ponto_leitura',
        'ponto_ensaio_prova_carga_ponto_medicao','ponto_ensaio_resistividade_leitura',
        'ponto_ensaio_ultrassom','ponto_ensaio_ultrassom_direto_leitura',
        'ponto_ensaio_ultrassom_direto_medicao',
        'ponto_ensaio_ultrassom_indireto_leitura',
        'ponto_ensaio_ultrassom_indireto_medicao','ponto_inspecao_regiao',
        'ponto_inspecao_visual','ponto_inspecao_visual_anomalia',
        'ponto_inspecao_visual_galeria','ponto_inspecao_visual_geral',
        'pontos_ensaios_geral','prioridade','projeto_convites_cliente',
        'regioes_ensaio','relatorio_ensaio',
        'relatorios','revestimentos_elemento','setores','sistemas_habitacionais',
        'status_projeto','tipologias_elemento','tipologias_estrutura'
      ])
  loop
    execute format('drop policy if exists %I on public.%I',
      v_policy.policyname, v_policy.tablename);
  end loop;
end;
$$;

-- Enable RLS and remove the broad Data API grants from all 56 targets.
do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'anomalias','condicoes_local','conjuntos_estruturais','empresa_clientes',
    'empresa_plano_assinatura','empresa_plano_consumo','ensaio_elementos',
    'ensaio_resultados','ensaios','ensaios_contratados','feed_comentarios',
    'feed_fotos','feed_likes','feed_posts','galeria_ponto_ensaio_carb',
    'galeria_ponto_ensaio_resistividade','galeria_pontos_ensaios_geral','midias',
    'midias_ensaios','papeis','permissoes','ponto_ensaio_arrancamento',
    'ponto_ensaio_arrancamento_leitura','ponto_ensaio_arrancamento_ruptura',
    'ponto_ensaio_carb','ponto_ensaio_carb_frentes','ponto_ensaio_esclerometria',
    'ponto_ensaio_esclerometria_leituras','ponto_ensaio_potencial',
    'ponto_ensaio_potencial_leitura','ponto_ensaio_prova_carga',
    'ponto_ensaio_prova_carga_ponto_leitura',
    'ponto_ensaio_prova_carga_ponto_medicao','ponto_ensaio_resistividade_leitura',
    'ponto_ensaio_ultrassom','ponto_ensaio_ultrassom_direto_leitura',
    'ponto_ensaio_ultrassom_direto_medicao',
    'ponto_ensaio_ultrassom_indireto_leitura',
    'ponto_ensaio_ultrassom_indireto_medicao','ponto_inspecao_regiao',
    'ponto_inspecao_visual','ponto_inspecao_visual_anomalia',
    'ponto_inspecao_visual_galeria','ponto_inspecao_visual_geral',
    'pontos_ensaios_geral','prioridade','projeto_convites_cliente',
    'regioes_ensaio','relatorio_ensaio',
    'relatorios','revestimentos_elemento','setores','sistemas_habitacionais',
    'status_projeto','tipologias_elemento','tipologias_estrutura'
  ] loop
    execute format('alter table public.%I enable row level security', v_table);
    execute format('revoke all on table public.%I from public, anon, authenticated', v_table);
  end loop;
end;
$$;

-- Catalogues with tenant rows and optional Diavicon global rows.
do $$
declare
  v_table text;
  v_select_scope text;
  v_insert_scope text;
begin
  foreach v_table in array array[
    'anomalias','condicoes_local','conjuntos_estruturais',
    'revestimentos_elemento','sistemas_habitacionais',
    'tipologias_elemento','tipologias_estrutura'
  ] loop
    v_select_scope := case
      when v_table = 'tipologias_estrutura'
        then '(empresa_id is null or empresa_id = private.active_actor_company_id())'
      else 'empresa_id = private.active_actor_company_id()'
    end;
    v_insert_scope := case
      when v_table = 'tipologias_estrutura'
        then '((private.is_active_platform_admin() and empresa_id is null) or (private.is_active_company_admin(private.active_actor_company_id()) and empresa_id = private.active_actor_company_id()))'
      else '(private.is_active_company_admin(private.active_actor_company_id()) and empresa_id = private.active_actor_company_id())'
    end;
    execute format('grant select, insert, update, delete on table public.%I to authenticated', v_table);
    execute format(
      'create policy %I on public.%I for select to authenticated using (private.is_active_actor() and %s)',
      'remaining_' || v_table || '_select', v_table, v_select_scope
    );
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (%s)',
      'remaining_' || v_table || '_insert', v_table, v_insert_scope
    );
    execute format(
      'create policy %I on public.%I for update to authenticated using (private.is_active_platform_admin() or (private.is_active_company_admin(empresa_id) and empresa_id = private.active_actor_company_id())) with check (private.is_active_platform_admin() or (private.is_active_company_admin(empresa_id) and empresa_id = private.active_actor_company_id()))',
      'remaining_' || v_table || '_update', v_table
    );
    execute format(
      'create policy %I on public.%I for delete to authenticated using (private.is_active_platform_admin() or (private.is_active_company_admin(empresa_id) and empresa_id = private.active_actor_company_id()))',
      'remaining_' || v_table || '_delete', v_table
    );
  end loop;
end;
$$;

-- The anomalous legacy random default could manufacture a tenant id that the
-- current user does not own. Require the policy/trigger to supply it.
alter table public.anomalias alter column empresa_id drop default;

-- Global reference tables are readable by active users and writable only by
-- service_role/platform administration outside the app.
grant select on table public.papeis, public.permissoes, public.prioridade, public.status_projeto to authenticated;
create policy remaining_papeis_select on public.papeis for select to authenticated using (private.is_active_actor());
create policy remaining_permissoes_select on public.permissoes for select to authenticated using (private.is_active_actor());
create policy remaining_prioridade_select on public.prioridade for select to authenticated using (private.is_active_actor());
create policy remaining_status_projeto_select on public.status_projeto for select to authenticated using (private.is_active_actor());

-- setores is legacy and has no application consumer. It remains RLS-enabled
-- with no authenticated grant or policy, so it is closed to the Data API.

-- Subscription and consumption are server-owned.
grant select on table public.empresa_plano_assinatura, public.empresa_plano_consumo to authenticated;
create policy remaining_plan_subscription_select on public.empresa_plano_assinatura
for select to authenticated using (private.is_active_actor() and empresa_id = private.active_actor_company_id());
create policy remaining_plan_consumption_select on public.empresa_plano_consumo
for select to authenticated using (private.is_active_actor() and empresa_id = private.active_actor_company_id());

-- Feed: active users can read visible posts and their children. Only the
-- author can mutate a post, its photos and comments; likes are self-owned.
grant select, insert, update, delete on table public.feed_posts, public.feed_fotos,
  public.feed_comentarios, public.feed_likes to authenticated;
create policy remaining_feed_posts_select on public.feed_posts for select to authenticated
using (private.is_active_actor());
create policy remaining_feed_posts_insert on public.feed_posts for insert to authenticated
with check (private.is_active_actor() and usuario_id = (select auth.uid()));
create policy remaining_feed_posts_update on public.feed_posts for update to authenticated
using (private.can_manage_feed_post(id))
with check (private.is_active_actor() and usuario_id = (select auth.uid()));
create policy remaining_feed_posts_delete on public.feed_posts for delete to authenticated
using (private.can_manage_feed_post(id));

create policy remaining_feed_fotos_select on public.feed_fotos for select to authenticated
using (private.is_active_actor() and exists (select 1 from public.feed_posts p where p.id = post_id));
create policy remaining_feed_fotos_insert on public.feed_fotos for insert to authenticated
with check (private.can_manage_feed_post(post_id));
create policy remaining_feed_fotos_update on public.feed_fotos for update to authenticated
using (private.can_manage_feed_post(post_id))
with check (private.can_manage_feed_post(post_id));
create policy remaining_feed_fotos_delete on public.feed_fotos for delete to authenticated
using (private.can_manage_feed_post(post_id));

create policy remaining_feed_comments_select on public.feed_comentarios for select to authenticated
using (private.is_active_actor() and exists (select 1 from public.feed_posts p where p.id = post_id and private.is_active_actor()));
create policy remaining_feed_comments_insert on public.feed_comentarios for insert to authenticated
with check (private.is_active_actor() and usuario_id = (select auth.uid()) and exists (select 1 from public.feed_posts p where p.id = post_id and private.is_active_actor()));
create policy remaining_feed_comments_update on public.feed_comentarios for update to authenticated
using (private.is_active_actor() and usuario_id = (select auth.uid()))
with check (private.is_active_actor() and usuario_id = (select auth.uid()));
create policy remaining_feed_comments_delete on public.feed_comentarios for delete to authenticated
using (private.is_active_actor() and usuario_id = (select auth.uid()));

create policy remaining_feed_likes_select on public.feed_likes for select to authenticated
using (private.is_active_actor() and exists (select 1 from public.feed_posts p where p.id = post_id and private.is_active_actor()));
create policy remaining_feed_likes_insert on public.feed_likes for insert to authenticated
with check (private.is_active_actor() and usuario_id = (select auth.uid()) and exists (select 1 from public.feed_posts p where p.id = post_id and private.is_active_actor()));
create policy remaining_feed_likes_delete on public.feed_likes for delete to authenticated
using (private.is_active_actor() and usuario_id = (select auth.uid()));

-- Project RLS, grants and policies are owned by
-- 20260903120000_harden_home_projects_rls.sql. Keep that permissive+restrictive
-- policy pair intact; the transaction RPCs below remain SECURITY DEFINER.
grant select on table public.projetos to authenticated;

grant select on table public.empresa_clientes to authenticated;
create policy remaining_company_clients_select on public.empresa_clientes for select to authenticated
using (private.is_active_actor() and (gestora_id = private.active_actor_company_id() or cliente_id = private.active_actor_company_id()));

grant select on table public.projeto_convites_cliente to authenticated;
create policy remaining_client_invites_select on public.projeto_convites_cliente for select to authenticated
using (
  private.can_manage_project_member(projeto_id)
  or criado_por = (select auth.uid())
  or (
    private.is_active_actor()
    and lower(email_convidado) = lower(coalesce((select auth.jwt() ->> 'email'), ''))
  )
);

-- Project-level contracts and regions. The company on a contract/region must
-- itself be attached to the project, while only the project manager mutates.
grant select, insert, update, delete on table public.ensaios_contratados to authenticated;
create policy remaining_contracts_select on public.ensaios_contratados for select to authenticated
using (private.can_access_project_member(projeto_id));
create policy remaining_contracts_insert on public.ensaios_contratados for insert to authenticated
with check (private.can_manage_project_member(projeto_id) and private.can_project_company(projeto_id, empresa_id));
create policy remaining_contracts_update on public.ensaios_contratados for update to authenticated
using (private.can_manage_project_member(projeto_id))
with check (private.can_manage_project_member(projeto_id) and private.can_project_company(projeto_id, empresa_id));
create policy remaining_contracts_delete on public.ensaios_contratados for delete to authenticated
using (private.can_manage_project_member(projeto_id));

grant select, insert, update, delete on table public.regioes_ensaio to authenticated;
create policy remaining_regions_select on public.regioes_ensaio for select to authenticated
using (projeto_id is not null and private.can_access_project_member(projeto_id));
create policy remaining_regions_insert on public.regioes_ensaio for insert to authenticated
with check (projeto_id is not null and private.can_manage_project_member(projeto_id) and private.can_project_company(projeto_id, empresa_id));
create policy remaining_regions_update on public.regioes_ensaio for update to authenticated
using (projeto_id is not null and private.can_manage_project_member(projeto_id))
with check (projeto_id is not null and private.can_manage_project_member(projeto_id) and private.can_project_company(projeto_id, empresa_id));
create policy remaining_regions_delete on public.regioes_ensaio for delete to authenticated
using (projeto_id is not null and private.can_manage_project_member(projeto_id));

-- Root points and reports.
grant select, insert, update, delete on table public.pontos_ensaios_geral to authenticated;
create policy remaining_points_select on public.pontos_ensaios_geral for select to authenticated
using (private.can_access_project_member(projeto_id));
create policy remaining_points_insert on public.pontos_ensaios_geral for insert to authenticated
with check (private.can_access_project_member(projeto_id) and empresa_autora_id = private.active_actor_company_id() and criado_por = (select auth.uid())::text);
create policy remaining_points_update on public.pontos_ensaios_geral for update to authenticated
using (private.can_edit_point(id))
with check (private.can_access_project_member(projeto_id) and empresa_autora_id is not null);
create policy remaining_points_delete on public.pontos_ensaios_geral for delete to authenticated
using (private.can_delete_point(id));

-- The report follows the same project and author-company rules.
grant select, insert, update, delete on table public.relatorio_ensaio to authenticated;
create policy remaining_reports_select on public.relatorio_ensaio for select to authenticated
using (private.can_access_project_member(projeto_id));
create policy remaining_reports_insert on public.relatorio_ensaio for insert to authenticated
with check (private.can_access_project_member(projeto_id) and empresa_autora_id = private.active_actor_company_id() and criado_por = (select auth.uid())::text);
create policy remaining_reports_update on public.relatorio_ensaio for update to authenticated
using (private.can_edit_report(id))
with check (private.can_access_project_member(projeto_id));
create policy remaining_reports_delete on public.relatorio_ensaio for delete to authenticated
using (private.can_delete_report(id));

-- Point children are writable only by the root author company. Project
-- managers may still delete a root point; its dependent rows are removed by
-- the database cascade in that same deletion transaction.
grant select, insert, update, delete on table
  public.galeria_pontos_ensaios_geral,
  public.galeria_ponto_ensaio_carb,
  public.galeria_ponto_ensaio_resistividade,
  public.ponto_ensaio_arrancamento,
  public.ponto_ensaio_arrancamento_leitura,
  public.ponto_ensaio_arrancamento_ruptura,
  public.ponto_ensaio_carb,
  public.ponto_ensaio_carb_frentes,
  public.ponto_ensaio_esclerometria,
  public.ponto_ensaio_esclerometria_leituras,
  public.ponto_ensaio_potencial,
  public.ponto_ensaio_potencial_leitura,
  public.ponto_ensaio_resistividade_leitura,
  public.ponto_ensaio_prova_carga,
  public.ponto_ensaio_prova_carga_ponto_medicao,
  public.ponto_ensaio_prova_carga_ponto_leitura,
  public.ponto_ensaio_ultrassom,
  public.ponto_ensaio_ultrassom_direto_medicao,
  public.ponto_ensaio_ultrassom_direto_leitura,
  public.ponto_ensaio_ultrassom_indireto_medicao,
  public.ponto_ensaio_ultrassom_indireto_leitura,
  public.ponto_inspecao_visual_geral,
  public.ponto_inspecao_visual,
  public.ponto_inspecao_regiao,
  public.ponto_inspecao_visual_anomalia,
  public.ponto_inspecao_visual_galeria to authenticated;

-- Root-linked child tables.
create policy remaining_general_gallery_select on public.galeria_pontos_ensaios_geral for select to authenticated using (private.can_access_point(ponto_ensaio_id));
create policy remaining_general_gallery_insert on public.galeria_pontos_ensaios_geral for insert to authenticated with check (private.can_edit_point(ponto_ensaio_id));
create policy remaining_general_gallery_update on public.galeria_pontos_ensaios_geral for update to authenticated using (private.can_edit_point(ponto_ensaio_id)) with check (private.can_edit_point(ponto_ensaio_id));
create policy remaining_general_gallery_delete on public.galeria_pontos_ensaios_geral for delete to authenticated using (private.can_delete_point(ponto_ensaio_id));

create policy remaining_res_gallery_select on public.galeria_ponto_ensaio_resistividade for select to authenticated using (private.can_access_point(ponto_ensaio_id));
create policy remaining_res_gallery_insert on public.galeria_ponto_ensaio_resistividade for insert to authenticated with check (private.can_edit_point(ponto_ensaio_id));
create policy remaining_res_gallery_update on public.galeria_ponto_ensaio_resistividade for update to authenticated using (private.can_edit_point(ponto_ensaio_id)) with check (private.can_edit_point(ponto_ensaio_id));
create policy remaining_res_gallery_delete on public.galeria_ponto_ensaio_resistividade for delete to authenticated using (private.can_delete_point(ponto_ensaio_id));

create policy remaining_arrancamento_select on public.ponto_ensaio_arrancamento for select to authenticated using (private.can_access_point(ponto_ensaio_id));
create policy remaining_arrancamento_insert on public.ponto_ensaio_arrancamento for insert to authenticated with check (private.can_edit_point(ponto_ensaio_id));
create policy remaining_arrancamento_update on public.ponto_ensaio_arrancamento for update to authenticated using (private.can_edit_point(ponto_ensaio_id)) with check (private.can_edit_point(ponto_ensaio_id));
create policy remaining_arrancamento_delete on public.ponto_ensaio_arrancamento for delete to authenticated using (private.can_delete_point(ponto_ensaio_id));

create policy remaining_carb_select on public.ponto_ensaio_carb for select to authenticated using (private.can_access_point(ponto_ensaio_id));
create policy remaining_carb_insert on public.ponto_ensaio_carb for insert to authenticated with check (private.can_edit_point(ponto_ensaio_id) and exists (select 1 from public.pontos_ensaios_geral p where p.id = ponto_ensaio_carb.ponto_ensaio_id and p.projeto_id = ponto_ensaio_carb.projeto_id));
create policy remaining_carb_update on public.ponto_ensaio_carb for update to authenticated using (private.can_edit_point(ponto_ensaio_id)) with check (private.can_edit_point(ponto_ensaio_id) and exists (select 1 from public.pontos_ensaios_geral p where p.id = ponto_ensaio_carb.ponto_ensaio_id and p.projeto_id = ponto_ensaio_carb.projeto_id));
create policy remaining_carb_delete on public.ponto_ensaio_carb for delete to authenticated using (private.can_delete_point(ponto_ensaio_id));

create policy remaining_potencial_select on public.ponto_ensaio_potencial for select to authenticated using (private.can_access_point(ponto_ensaio_id));
create policy remaining_potencial_insert on public.ponto_ensaio_potencial for insert to authenticated with check (private.can_edit_point(ponto_ensaio_id));
create policy remaining_potencial_update on public.ponto_ensaio_potencial for update to authenticated using (private.can_edit_point(ponto_ensaio_id)) with check (private.can_edit_point(ponto_ensaio_id));
create policy remaining_potencial_delete on public.ponto_ensaio_potencial for delete to authenticated using (private.can_delete_point(ponto_ensaio_id));

create policy remaining_ultrassom_select on public.ponto_ensaio_ultrassom for select to authenticated using (private.can_access_point(ponto_ensaio_id));
create policy remaining_ultrassom_insert on public.ponto_ensaio_ultrassom for insert to authenticated with check (private.can_edit_point(ponto_ensaio_id));
create policy remaining_ultrassom_update on public.ponto_ensaio_ultrassom for update to authenticated using (private.can_edit_point(ponto_ensaio_id)) with check (private.can_edit_point(ponto_ensaio_id));
create policy remaining_ultrassom_delete on public.ponto_ensaio_ultrassom for delete to authenticated using (private.can_delete_point(ponto_ensaio_id));

create policy remaining_esclerometria_select on public.ponto_ensaio_esclerometria for select to authenticated using (private.can_access_point(ponto_geral_id));
create policy remaining_esclerometria_insert on public.ponto_ensaio_esclerometria for insert to authenticated with check (private.can_edit_point(ponto_geral_id));
create policy remaining_esclerometria_update on public.ponto_ensaio_esclerometria for update to authenticated using (private.can_edit_point(ponto_geral_id)) with check (private.can_edit_point(ponto_geral_id));
create policy remaining_esclerometria_delete on public.ponto_ensaio_esclerometria for delete to authenticated using (private.can_delete_point(ponto_geral_id));

create policy remaining_res_readings_select on public.ponto_ensaio_resistividade_leitura for select to authenticated using (private.can_access_point(id_ponto_geral));
create policy remaining_res_readings_insert on public.ponto_ensaio_resistividade_leitura for insert to authenticated with check (private.can_edit_point(id_ponto_geral));
create policy remaining_res_readings_update on public.ponto_ensaio_resistividade_leitura for update to authenticated using (private.can_edit_point(id_ponto_geral)) with check (private.can_edit_point(id_ponto_geral));
create policy remaining_res_readings_delete on public.ponto_ensaio_resistividade_leitura for delete to authenticated using (private.can_delete_point(id_ponto_geral));

-- Multi-level child policies use scalar parent lookups. The SECURITY DEFINER
-- helpers avoid recursively evaluating the parent table's RLS.
create policy remaining_arr_readings_select on public.ponto_ensaio_arrancamento_leitura for select to authenticated using (private.can_access_point((select a.ponto_ensaio_id from public.ponto_ensaio_arrancamento a where a.id = id_ponto_arrancamento)));
create policy remaining_arr_readings_insert on public.ponto_ensaio_arrancamento_leitura for insert to authenticated with check (private.can_edit_point((select a.ponto_ensaio_id from public.ponto_ensaio_arrancamento a where a.id = id_ponto_arrancamento)));
create policy remaining_arr_readings_update on public.ponto_ensaio_arrancamento_leitura for update to authenticated using (private.can_edit_point((select a.ponto_ensaio_id from public.ponto_ensaio_arrancamento a where a.id = id_ponto_arrancamento))) with check (private.can_edit_point((select a.ponto_ensaio_id from public.ponto_ensaio_arrancamento a where a.id = id_ponto_arrancamento)));
create policy remaining_arr_readings_delete on public.ponto_ensaio_arrancamento_leitura for delete to authenticated using (private.can_edit_point((select a.ponto_ensaio_id from public.ponto_ensaio_arrancamento a where a.id = id_ponto_arrancamento)));

create policy remaining_arr_failures_select on public.ponto_ensaio_arrancamento_ruptura for select to authenticated using (private.can_access_point((select a.ponto_ensaio_id from public.ponto_ensaio_arrancamento a join public.ponto_ensaio_arrancamento_leitura l on l.id_ponto_arrancamento = a.id where l.id = id_ponto_leitura)));
create policy remaining_arr_failures_insert on public.ponto_ensaio_arrancamento_ruptura for insert to authenticated with check (private.can_edit_point((select a.ponto_ensaio_id from public.ponto_ensaio_arrancamento a join public.ponto_ensaio_arrancamento_leitura l on l.id_ponto_arrancamento = a.id where l.id = id_ponto_leitura)));
create policy remaining_arr_failures_update on public.ponto_ensaio_arrancamento_ruptura for update to authenticated using (private.can_edit_point((select a.ponto_ensaio_id from public.ponto_ensaio_arrancamento a join public.ponto_ensaio_arrancamento_leitura l on l.id_ponto_arrancamento = a.id where l.id = id_ponto_leitura))) with check (private.can_edit_point((select a.ponto_ensaio_id from public.ponto_ensaio_arrancamento a join public.ponto_ensaio_arrancamento_leitura l on l.id_ponto_arrancamento = a.id where l.id = id_ponto_leitura)));
create policy remaining_arr_failures_delete on public.ponto_ensaio_arrancamento_ruptura for delete to authenticated using (private.can_edit_point((select a.ponto_ensaio_id from public.ponto_ensaio_arrancamento a join public.ponto_ensaio_arrancamento_leitura l on l.id_ponto_arrancamento = a.id where l.id = id_ponto_leitura)));

create policy remaining_carb_fronts_select on public.ponto_ensaio_carb_frentes for select to authenticated using (private.can_access_point((select c.ponto_ensaio_id from public.ponto_ensaio_carb c where c.id = ponto_ensaio_id)));
create policy remaining_carb_fronts_insert on public.ponto_ensaio_carb_frentes for insert to authenticated with check (private.can_edit_point((select c.ponto_ensaio_id from public.ponto_ensaio_carb c where c.id = ponto_ensaio_id)));
create policy remaining_carb_fronts_update on public.ponto_ensaio_carb_frentes for update to authenticated using (private.can_edit_point((select c.ponto_ensaio_id from public.ponto_ensaio_carb c where c.id = ponto_ensaio_id))) with check (private.can_edit_point((select c.ponto_ensaio_id from public.ponto_ensaio_carb c where c.id = ponto_ensaio_id)));
create policy remaining_carb_fronts_delete on public.ponto_ensaio_carb_frentes for delete to authenticated using (private.can_edit_point((select c.ponto_ensaio_id from public.ponto_ensaio_carb c where c.id = ponto_ensaio_id)));

create policy remaining_carb_gallery_select on public.galeria_ponto_ensaio_carb for select to authenticated using (private.can_access_point((select c.ponto_ensaio_id from public.ponto_ensaio_carb c where c.id = ponto_ensaio_id)));
create policy remaining_carb_gallery_insert on public.galeria_ponto_ensaio_carb for insert to authenticated with check (private.can_edit_point((select c.ponto_ensaio_id from public.ponto_ensaio_carb c where c.id = ponto_ensaio_id)));
create policy remaining_carb_gallery_update on public.galeria_ponto_ensaio_carb for update to authenticated using (private.can_edit_point((select c.ponto_ensaio_id from public.ponto_ensaio_carb c where c.id = ponto_ensaio_id))) with check (private.can_edit_point((select c.ponto_ensaio_id from public.ponto_ensaio_carb c where c.id = ponto_ensaio_id)));
create policy remaining_carb_gallery_delete on public.galeria_ponto_ensaio_carb for delete to authenticated using (private.can_edit_point((select c.ponto_ensaio_id from public.ponto_ensaio_carb c where c.id = ponto_ensaio_id)));

create policy remaining_esclerometria_readings_select on public.ponto_ensaio_esclerometria_leituras for select to authenticated using (private.can_access_point((select e.ponto_geral_id from public.ponto_ensaio_esclerometria e where e.id = ponto_ensaio_esclerometria_leituras.ponto_id)));
create policy remaining_esclerometria_readings_insert on public.ponto_ensaio_esclerometria_leituras for insert to authenticated with check (private.can_edit_point((select e.ponto_geral_id from public.ponto_ensaio_esclerometria e where e.id = ponto_ensaio_esclerometria_leituras.ponto_id)));
create policy remaining_esclerometria_readings_update on public.ponto_ensaio_esclerometria_leituras for update to authenticated using (private.can_edit_point((select e.ponto_geral_id from public.ponto_ensaio_esclerometria e where e.id = ponto_ensaio_esclerometria_leituras.ponto_id))) with check (private.can_edit_point((select e.ponto_geral_id from public.ponto_ensaio_esclerometria e where e.id = ponto_ensaio_esclerometria_leituras.ponto_id)));
create policy remaining_esclerometria_readings_delete on public.ponto_ensaio_esclerometria_leituras for delete to authenticated using (private.can_edit_point((select e.ponto_geral_id from public.ponto_ensaio_esclerometria e where e.id = ponto_ensaio_esclerometria_leituras.ponto_id)));

create policy remaining_potencial_readings_select on public.ponto_ensaio_potencial_leitura for select to authenticated using (private.can_access_point((select p.ponto_ensaio_id from public.ponto_ensaio_potencial p where p.id = ponto_potencial_id)));
create policy remaining_potencial_readings_insert on public.ponto_ensaio_potencial_leitura for insert to authenticated with check (private.can_edit_point((select p.ponto_ensaio_id from public.ponto_ensaio_potencial p where p.id = ponto_potencial_id)));
create policy remaining_potencial_readings_update on public.ponto_ensaio_potencial_leitura for update to authenticated using (private.can_edit_point((select p.ponto_ensaio_id from public.ponto_ensaio_potencial p where p.id = ponto_potencial_id))) with check (private.can_edit_point((select p.ponto_ensaio_id from public.ponto_ensaio_potencial p where p.id = ponto_potencial_id)));
create policy remaining_potencial_readings_delete on public.ponto_ensaio_potencial_leitura for delete to authenticated using (private.can_edit_point((select p.ponto_ensaio_id from public.ponto_ensaio_potencial p where p.id = ponto_potencial_id)));

create policy remaining_prova_carga_select on public.ponto_ensaio_prova_carga for select to authenticated using (private.can_access_point(ponto_geral_id));
create policy remaining_prova_carga_insert on public.ponto_ensaio_prova_carga for insert to authenticated with check (private.can_edit_point(ponto_geral_id));
create policy remaining_prova_carga_update on public.ponto_ensaio_prova_carga for update to authenticated using (private.can_edit_point(ponto_geral_id)) with check (private.can_edit_point(ponto_geral_id));
create policy remaining_prova_carga_delete on public.ponto_ensaio_prova_carga for delete to authenticated using (private.can_edit_point(ponto_geral_id));

create policy remaining_prova_medicao_select on public.ponto_ensaio_prova_carga_ponto_medicao for select to authenticated using (private.can_access_point((select c.ponto_geral_id from public.ponto_ensaio_prova_carga c where c.id = ponto_carga_id)));
create policy remaining_prova_medicao_insert on public.ponto_ensaio_prova_carga_ponto_medicao for insert to authenticated with check (private.can_edit_point((select c.ponto_geral_id from public.ponto_ensaio_prova_carga c where c.id = ponto_carga_id)));
create policy remaining_prova_medicao_update on public.ponto_ensaio_prova_carga_ponto_medicao for update to authenticated using (private.can_edit_point((select c.ponto_geral_id from public.ponto_ensaio_prova_carga c where c.id = ponto_carga_id))) with check (private.can_edit_point((select c.ponto_geral_id from public.ponto_ensaio_prova_carga c where c.id = ponto_carga_id)));
create policy remaining_prova_medicao_delete on public.ponto_ensaio_prova_carga_ponto_medicao for delete to authenticated using (private.can_edit_point((select c.ponto_geral_id from public.ponto_ensaio_prova_carga c where c.id = ponto_carga_id)));

create policy remaining_prova_reading_select on public.ponto_ensaio_prova_carga_ponto_leitura for select to authenticated using (private.can_access_point((select c.ponto_geral_id from public.ponto_ensaio_prova_carga c join public.ponto_ensaio_prova_carga_ponto_medicao m on m.ponto_carga_id = c.id where m.id = ponto_medicao_id)));
create policy remaining_prova_reading_insert on public.ponto_ensaio_prova_carga_ponto_leitura for insert to authenticated with check (private.can_edit_point((select c.ponto_geral_id from public.ponto_ensaio_prova_carga c join public.ponto_ensaio_prova_carga_ponto_medicao m on m.ponto_carga_id = c.id where m.id = ponto_medicao_id)));
create policy remaining_prova_reading_update on public.ponto_ensaio_prova_carga_ponto_leitura for update to authenticated using (private.can_edit_point((select c.ponto_geral_id from public.ponto_ensaio_prova_carga c join public.ponto_ensaio_prova_carga_ponto_medicao m on m.ponto_carga_id = c.id where m.id = ponto_medicao_id))) with check (private.can_edit_point((select c.ponto_geral_id from public.ponto_ensaio_prova_carga c join public.ponto_ensaio_prova_carga_ponto_medicao m on m.ponto_carga_id = c.id where m.id = ponto_medicao_id)));
create policy remaining_prova_reading_delete on public.ponto_ensaio_prova_carga_ponto_leitura for delete to authenticated using (private.can_edit_point((select c.ponto_geral_id from public.ponto_ensaio_prova_carga c join public.ponto_ensaio_prova_carga_ponto_medicao m on m.ponto_carga_id = c.id where m.id = ponto_medicao_id)));

create policy remaining_ultrassom_direct_select on public.ponto_ensaio_ultrassom_direto_medicao for select to authenticated using (private.can_access_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u where u.id = ponto_ensaio_ultrassom_direto_medicao.ponto_id)));
create policy remaining_ultrassom_direct_insert on public.ponto_ensaio_ultrassom_direto_medicao for insert to authenticated with check (private.can_edit_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u where u.id = ponto_ensaio_ultrassom_direto_medicao.ponto_id)));
create policy remaining_ultrassom_direct_update on public.ponto_ensaio_ultrassom_direto_medicao for update to authenticated using (private.can_edit_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u where u.id = ponto_ensaio_ultrassom_direto_medicao.ponto_id))) with check (private.can_edit_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom_direto_medicao d join public.ponto_ensaio_ultrassom u on u.id = d.ponto_id where d.id = ponto_ensaio_ultrassom_direto_medicao.id)));
create policy remaining_ultrassom_direct_delete on public.ponto_ensaio_ultrassom_direto_medicao for delete to authenticated using (private.can_edit_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u where u.id = ponto_ensaio_ultrassom_direto_medicao.ponto_id)));

create policy remaining_ultrassom_direct_read_select on public.ponto_ensaio_ultrassom_direto_leitura for select to authenticated using (private.can_access_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u join public.ponto_ensaio_ultrassom_direto_medicao m on m.ponto_id = u.id where m.id = ponto_ensaio_ultrassom_direto_leitura.ponto_id)));
create policy remaining_ultrassom_direct_read_insert on public.ponto_ensaio_ultrassom_direto_leitura for insert to authenticated with check (private.can_edit_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u join public.ponto_ensaio_ultrassom_direto_medicao m on m.ponto_id = u.id where m.id = ponto_ensaio_ultrassom_direto_leitura.ponto_id)));
create policy remaining_ultrassom_direct_read_update on public.ponto_ensaio_ultrassom_direto_leitura for update to authenticated using (private.can_edit_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u join public.ponto_ensaio_ultrassom_direto_medicao m on m.ponto_id = u.id where m.id = ponto_ensaio_ultrassom_direto_leitura.ponto_id))) with check (private.can_edit_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u join public.ponto_ensaio_ultrassom_direto_medicao m on m.ponto_id = u.id where m.id = ponto_ensaio_ultrassom_direto_leitura.ponto_id)));
create policy remaining_ultrassom_direct_read_delete on public.ponto_ensaio_ultrassom_direto_leitura for delete to authenticated using (private.can_edit_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u join public.ponto_ensaio_ultrassom_direto_medicao m on m.ponto_id = u.id where m.id = ponto_ensaio_ultrassom_direto_leitura.ponto_id)));

create policy remaining_ultrassom_indirect_select on public.ponto_ensaio_ultrassom_indireto_medicao for select to authenticated using (private.can_access_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u where u.id = ponto_ensaio_ultrassom_indireto_medicao.ponto_id)));
create policy remaining_ultrassom_indirect_insert on public.ponto_ensaio_ultrassom_indireto_medicao for insert to authenticated with check (private.can_edit_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u where u.id = ponto_ensaio_ultrassom_indireto_medicao.ponto_id)));
create policy remaining_ultrassom_indirect_update on public.ponto_ensaio_ultrassom_indireto_medicao for update to authenticated using (private.can_edit_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u where u.id = ponto_ensaio_ultrassom_indireto_medicao.ponto_id))) with check (private.can_edit_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom_indireto_medicao d join public.ponto_ensaio_ultrassom u on u.id = d.ponto_id where d.id = ponto_ensaio_ultrassom_indireto_medicao.id)));
create policy remaining_ultrassom_indirect_delete on public.ponto_ensaio_ultrassom_indireto_medicao for delete to authenticated using (private.can_edit_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u where u.id = ponto_ensaio_ultrassom_indireto_medicao.ponto_id)));

create policy remaining_ultrassom_indirect_read_select on public.ponto_ensaio_ultrassom_indireto_leitura for select to authenticated using (private.can_access_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u join public.ponto_ensaio_ultrassom_indireto_medicao m on m.ponto_id = u.id where m.id = ponto_ensaio_ultrassom_indireto_leitura.ponto_id)));
create policy remaining_ultrassom_indirect_read_insert on public.ponto_ensaio_ultrassom_indireto_leitura for insert to authenticated with check (private.can_edit_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u join public.ponto_ensaio_ultrassom_indireto_medicao m on m.ponto_id = u.id where m.id = ponto_ensaio_ultrassom_indireto_leitura.ponto_id)));
create policy remaining_ultrassom_indirect_read_update on public.ponto_ensaio_ultrassom_indireto_leitura for update to authenticated using (private.can_edit_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u join public.ponto_ensaio_ultrassom_indireto_medicao m on m.ponto_id = u.id where m.id = ponto_ensaio_ultrassom_indireto_leitura.ponto_id))) with check (private.can_edit_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u join public.ponto_ensaio_ultrassom_indireto_medicao m on m.ponto_id = u.id where m.id = ponto_ensaio_ultrassom_indireto_leitura.ponto_id)));
create policy remaining_ultrassom_indirect_read_delete on public.ponto_ensaio_ultrassom_indireto_leitura for delete to authenticated using (private.can_edit_point((select u.ponto_ensaio_id from public.ponto_ensaio_ultrassom u join public.ponto_ensaio_ultrassom_indireto_medicao m on m.ponto_id = u.id where m.id = ponto_ensaio_ultrassom_indireto_leitura.ponto_id)));

-- Visual inspection rows must follow the real chain:
-- visual.id_ponto_geral -> visual_general.id -> general_point.id_ponto_geral
-- -> pontos_ensaios_geral.id. The visual project must match the root point.
create policy remaining_visual_general_select on public.ponto_inspecao_visual_geral for select to authenticated using (private.can_access_point(id_ponto_geral));
create policy remaining_visual_general_insert on public.ponto_inspecao_visual_geral for insert to authenticated with check (private.can_edit_point(id_ponto_geral));
create policy remaining_visual_general_update on public.ponto_inspecao_visual_geral for update to authenticated using (private.can_edit_point(id_ponto_geral)) with check (private.can_edit_point(id_ponto_geral));
create policy remaining_visual_general_delete on public.ponto_inspecao_visual_geral for delete to authenticated using (private.can_edit_point(id_ponto_geral));

create policy remaining_visual_select on public.ponto_inspecao_visual for select to authenticated using (
  ponto_inspecao_visual.id_projeto is not null
  and private.can_access_point_in_project(
    (select vg.id_ponto_geral
     from public.ponto_inspecao_visual_geral vg
     where vg.id = ponto_inspecao_visual.id_ponto_geral),
    ponto_inspecao_visual.id_projeto
  )
);
create policy remaining_visual_insert on public.ponto_inspecao_visual for insert to authenticated with check (
  ponto_inspecao_visual.id_projeto is not null
  and private.can_edit_point_in_project(
    (select vg.id_ponto_geral
     from public.ponto_inspecao_visual_geral vg
     where vg.id = ponto_inspecao_visual.id_ponto_geral),
    ponto_inspecao_visual.id_projeto
  )
);
create policy remaining_visual_update on public.ponto_inspecao_visual for update to authenticated using (
  ponto_inspecao_visual.id_projeto is not null
  and private.can_edit_point_in_project(
    (select vg.id_ponto_geral
     from public.ponto_inspecao_visual_geral vg
     where vg.id = ponto_inspecao_visual.id_ponto_geral),
    ponto_inspecao_visual.id_projeto
  )
) with check (
  ponto_inspecao_visual.id_projeto is not null
  and private.can_edit_point_in_project(
    (select vg.id_ponto_geral
     from public.ponto_inspecao_visual_geral vg
     where vg.id = ponto_inspecao_visual.id_ponto_geral),
    ponto_inspecao_visual.id_projeto
  )
);
create policy remaining_visual_delete on public.ponto_inspecao_visual for delete to authenticated using (
  ponto_inspecao_visual.id_projeto is not null
  and private.can_edit_point_in_project(
    (select vg.id_ponto_geral
     from public.ponto_inspecao_visual_geral vg
     where vg.id = ponto_inspecao_visual.id_ponto_geral),
    ponto_inspecao_visual.id_projeto
  )
);

create policy remaining_visual_region_select on public.ponto_inspecao_regiao for select to authenticated using (
  exists (
    select 1
    from public.ponto_inspecao_visual v
    join public.ponto_inspecao_visual_geral vg on vg.id = v.id_ponto_geral
    join public.pontos_ensaios_geral p on p.id = vg.id_ponto_geral
    where v.id = ponto_inspecao_regiao.ponto_id
      and v.id_projeto = p.projeto_id
      and private.can_access_point_in_project(p.id, v.id_projeto)
  )
);
create policy remaining_visual_region_insert on public.ponto_inspecao_regiao for insert to authenticated with check (
  exists (
    select 1
    from public.ponto_inspecao_visual v
    join public.ponto_inspecao_visual_geral vg on vg.id = v.id_ponto_geral
    join public.pontos_ensaios_geral p on p.id = vg.id_ponto_geral
    where v.id = ponto_inspecao_regiao.ponto_id
      and v.id_projeto = p.projeto_id
      and private.can_edit_point_in_project(p.id, v.id_projeto)
  )
);
create policy remaining_visual_region_update on public.ponto_inspecao_regiao for update to authenticated using (
  exists (
    select 1
    from public.ponto_inspecao_visual v
    join public.ponto_inspecao_visual_geral vg on vg.id = v.id_ponto_geral
    join public.pontos_ensaios_geral p on p.id = vg.id_ponto_geral
    where v.id = ponto_inspecao_regiao.ponto_id
      and v.id_projeto = p.projeto_id
      and private.can_edit_point_in_project(p.id, v.id_projeto)
  )
) with check (
  exists (
    select 1
    from public.ponto_inspecao_visual v
    join public.ponto_inspecao_visual_geral vg on vg.id = v.id_ponto_geral
    join public.pontos_ensaios_geral p on p.id = vg.id_ponto_geral
    where v.id = ponto_inspecao_regiao.ponto_id
      and v.id_projeto = p.projeto_id
      and private.can_edit_point_in_project(p.id, v.id_projeto)
  )
);
create policy remaining_visual_region_delete on public.ponto_inspecao_regiao for delete to authenticated using (
  exists (
    select 1
    from public.ponto_inspecao_visual v
    join public.ponto_inspecao_visual_geral vg on vg.id = v.id_ponto_geral
    join public.pontos_ensaios_geral p on p.id = vg.id_ponto_geral
    where v.id = ponto_inspecao_regiao.ponto_id
      and v.id_projeto = p.projeto_id
      and private.can_edit_point_in_project(p.id, v.id_projeto)
  )
);

create policy remaining_visual_anomaly_select on public.ponto_inspecao_visual_anomalia for select to authenticated using (
  exists (
    select 1
    from public.ponto_inspecao_visual v
    join public.ponto_inspecao_visual_geral vg on vg.id = v.id_ponto_geral
    join public.pontos_ensaios_geral p on p.id = vg.id_ponto_geral
    where v.id = ponto_inspecao_visual_anomalia.id_inspecao
      and v.id_projeto = p.projeto_id
      and private.can_access_point_in_project(p.id, v.id_projeto)
  )
);
create policy remaining_visual_anomaly_insert on public.ponto_inspecao_visual_anomalia for insert to authenticated with check (
  exists (
    select 1
    from public.ponto_inspecao_visual v
    join public.ponto_inspecao_visual_geral vg on vg.id = v.id_ponto_geral
    join public.pontos_ensaios_geral p on p.id = vg.id_ponto_geral
    where v.id = ponto_inspecao_visual_anomalia.id_inspecao
      and v.id_projeto = p.projeto_id
      and private.can_edit_point_in_project(p.id, v.id_projeto)
  )
);
create policy remaining_visual_anomaly_update on public.ponto_inspecao_visual_anomalia for update to authenticated using (
  exists (
    select 1
    from public.ponto_inspecao_visual v
    join public.ponto_inspecao_visual_geral vg on vg.id = v.id_ponto_geral
    join public.pontos_ensaios_geral p on p.id = vg.id_ponto_geral
    where v.id = ponto_inspecao_visual_anomalia.id_inspecao
      and v.id_projeto = p.projeto_id
      and private.can_edit_point_in_project(p.id, v.id_projeto)
  )
) with check (
  exists (
    select 1
    from public.ponto_inspecao_visual v
    join public.ponto_inspecao_visual_geral vg on vg.id = v.id_ponto_geral
    join public.pontos_ensaios_geral p on p.id = vg.id_ponto_geral
    where v.id = ponto_inspecao_visual_anomalia.id_inspecao
      and v.id_projeto = p.projeto_id
      and private.can_edit_point_in_project(p.id, v.id_projeto)
  )
);
create policy remaining_visual_anomaly_delete on public.ponto_inspecao_visual_anomalia for delete to authenticated using (
  exists (
    select 1
    from public.ponto_inspecao_visual v
    join public.ponto_inspecao_visual_geral vg on vg.id = v.id_ponto_geral
    join public.pontos_ensaios_geral p on p.id = vg.id_ponto_geral
    where v.id = ponto_inspecao_visual_anomalia.id_inspecao
      and v.id_projeto = p.projeto_id
      and private.can_edit_point_in_project(p.id, v.id_projeto)
  )
);

create policy remaining_visual_gallery_select on public.ponto_inspecao_visual_galeria for select to authenticated using (
  exists (
    select 1
    from public.ponto_inspecao_visual v
    join public.ponto_inspecao_visual_geral vg on vg.id = v.id_ponto_geral
    join public.pontos_ensaios_geral p on p.id = vg.id_ponto_geral
    where v.id = ponto_inspecao_visual_galeria.id_inspecao
      and v.id_projeto = p.projeto_id
      and private.can_access_point_in_project(p.id, v.id_projeto)
  )
);
create policy remaining_visual_gallery_insert on public.ponto_inspecao_visual_galeria for insert to authenticated with check (
  exists (
    select 1
    from public.ponto_inspecao_visual v
    join public.ponto_inspecao_visual_geral vg on vg.id = v.id_ponto_geral
    join public.pontos_ensaios_geral p on p.id = vg.id_ponto_geral
    where v.id = ponto_inspecao_visual_galeria.id_inspecao
      and v.id_projeto = p.projeto_id
      and private.can_edit_point_in_project(p.id, v.id_projeto)
  )
);
create policy remaining_visual_gallery_update on public.ponto_inspecao_visual_galeria for update to authenticated using (
  exists (
    select 1
    from public.ponto_inspecao_visual v
    join public.ponto_inspecao_visual_geral vg on vg.id = v.id_ponto_geral
    join public.pontos_ensaios_geral p on p.id = vg.id_ponto_geral
    where v.id = ponto_inspecao_visual_galeria.id_inspecao
      and v.id_projeto = p.projeto_id
      and private.can_edit_point_in_project(p.id, v.id_projeto)
  )
) with check (
  exists (
    select 1
    from public.ponto_inspecao_visual v
    join public.ponto_inspecao_visual_geral vg on vg.id = v.id_ponto_geral
    join public.pontos_ensaios_geral p on p.id = vg.id_ponto_geral
    where v.id = ponto_inspecao_visual_galeria.id_inspecao
      and v.id_projeto = p.projeto_id
      and private.can_edit_point_in_project(p.id, v.id_projeto)
  )
);
create policy remaining_visual_gallery_delete on public.ponto_inspecao_visual_galeria for delete to authenticated using (
  exists (
    select 1
    from public.ponto_inspecao_visual v
    join public.ponto_inspecao_visual_geral vg on vg.id = v.id_ponto_geral
    join public.pontos_ensaios_geral p on p.id = vg.id_ponto_geral
    where v.id = ponto_inspecao_visual_galeria.id_inspecao
      and v.id_projeto = p.projeto_id
      and private.can_edit_point_in_project(p.id, v.id_projeto)
  )
);

-- Tables with no identified application consumer are deny-by-default after RLS.
-- They intentionally receive no authenticated grant or policy.

-- Transactional project/client operations. These are intentionally narrow
-- public entrypoints; all table writes run as the function owner and are
-- checked against the current authenticated user.
create or replace function public.create_project(
  p_name text,
  p_client_company_id uuid default null,
  p_new_client_email text default null,
  p_new_client_name text default null,
  p_image_url text default null,
  p_new_client_image_url text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
  v_company uuid;
  v_project uuid;
  v_email text := lower(nullif(btrim(p_new_client_email), ''));
  v_client_name text := nullif(btrim(p_new_client_name), '');
  v_project_image_url text;
  v_client_image_url text;
begin
  select u.empresa_id into v_company from public.usuarios u
  where u.id = v_actor and u.ativo is true;
  if v_actor is null or v_company is null then
    raise exception using errcode = '42501', message = 'Usuário ativo com empresa é obrigatório.';
  end if;
  if nullif(btrim(p_name), '') is null or char_length(btrim(p_name)) > 160 then
    raise exception using errcode = '22023', message = 'Nome de projeto inválido.';
  end if;
  if p_client_company_id is not null and (v_email is not null or v_client_name is not null) then
    raise exception using errcode = '22023', message = 'Escolha apenas um tipo de cliente.';
  end if;
  if p_client_company_id is null and (v_email is null or v_client_name is null) then
    raise exception using errcode = '22023', message = 'Informe o cliente novo completo.';
  end if;
  if p_client_company_id is not null and not exists (select 1 from public.empresas e where e.id = p_client_company_id) then
    raise exception using errcode = '23503', message = 'Empresa cliente não encontrada.';
  end if;
  if p_client_company_id is not null and p_client_company_id <> v_company
     and not exists (select 1 from public.usuarios u where u.empresa_id = p_client_company_id and u.ativo is true and u.is_admin_empresa is true) then
    raise exception using errcode = '23514', message = 'A empresa cliente não tem administrador ativo.';
  end if;

  v_project_image_url := private.canonical_project_image_url(p_image_url, v_actor, 'capas');
  v_client_image_url := private.canonical_project_image_url(p_new_client_image_url, v_actor, 'clientes');

  insert into public.projetos (nome, empresa_gestora_id, empresa_cliente_id, status_vinculo_cliente, image_url, criado_por)
  values (
    btrim(p_name), v_company,
    case when p_client_company_id is not null then p_client_company_id else null end,
    case when p_client_company_id is null or p_client_company_id = v_company then case when p_client_company_id is null then 'nao_vinculado' else 'ativo' end else 'pendente' end,
    v_project_image_url, v_actor
  ) returning id into v_project;

  insert into public.projeto_equipe_interna (projeto_id, usuario_id, empresa_id, ativo, is_gestor)
  values (v_project, v_actor, v_company, true, true)
  on conflict (projeto_id, usuario_id) do update set ativo = true, is_gestor = true, empresa_id = excluded.empresa_id;

  if p_client_company_id is null then
    insert into public.projeto_convites_cliente (projeto_id, email_convidado, empresa_nome_temp, criado_por, aceito, foto_url)
    values (v_project, v_email, v_client_name, v_actor, false, v_client_image_url);
  elsif p_client_company_id <> v_company then
    insert into public.empresa_clientes (gestora_id, cliente_id, status_vinculo)
    values (v_company, p_client_company_id, 'pendente')
    on conflict (gestora_id, cliente_id) do update set status_vinculo = excluded.status_vinculo;
    insert into public.notificacoes (usuario_id, titulo, mensagem, tipo, lida, dados_extras)
    select u.id, 'Convite de Cliente', 'Sua empresa recebeu um convite para o projeto ' || btrim(p_name) || '.', 'convite_cliente', false,
      pg_catalog.jsonb_build_object('projeto_id', v_project, 'foto_url', v_project_image_url)
    from public.usuarios u
    where u.empresa_id = p_client_company_id and u.ativo is true and u.is_admin_empresa is true;
  end if;
  return v_project;
end;
$$;

create or replace function public.update_project(
  p_project_id uuid,
  p_name text,
  p_description text,
  p_status_name text,
  p_priority_name text,
  p_image_url text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_actor uuid := (select auth.uid());
  v_status uuid;
  v_priority uuid;
  v_project_image_url text;
begin
  perform 1 from public.projetos p where p.id = p_project_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Projeto não encontrado.';
  end if;
  if not private.can_manage_project_member(p_project_id) then
    raise exception using errcode = '42501', message = 'Usuário sem permissão para editar o projeto.';
  end if;
  select id into v_status from public.status_projeto where lower(btrim(nome)) = lower(btrim(p_status_name)) limit 1;
  select id into v_priority from public.prioridade where lower(btrim(nome)) = lower(btrim(p_priority_name)) limit 1;
  if v_status is null or v_priority is null then
    raise exception using errcode = '22023', message = 'Status ou prioridade inválidos.';
  end if;
  v_project_image_url := private.canonical_project_image_url(p_image_url, v_actor, 'capas');
  update public.projetos set nome = btrim(p_name), descricao = coalesce(btrim(p_description), ''), status_id = v_status, prioridade_id = v_priority,
    image_url = coalesce(v_project_image_url, image_url)
  where id = p_project_id;
  return p_project_id;
end;
$$;

create or replace function public.delete_project(p_project_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare v_manager uuid;
begin
  select p.empresa_gestora_id
    into v_manager
  from public.projetos p
  where p.id = p_project_id
  for update;
  if not found or v_manager is null then
    raise exception using errcode = 'P0002', message = 'Projeto não encontrado.';
  end if;
  if not private.is_active_company_admin(v_manager) then
    raise exception using errcode = '42501', message = 'Somente administrador ativo da empresa gestora pode excluir o projeto.';
  end if;
  delete from public.projetos where id = p_project_id;
  return p_project_id;
end;
$$;

-- Atomic region + contract replacement used by the planning screen. Triggers
-- remain the source of truth for author attribution and relationship checks.
create or replace function public.save_region_with_contracts(
  p_region_id uuid,
  p_region jsonb,
  p_contracts jsonb
) returns uuid
language plpgsql security definer set search_path = public, pg_catalog as $$
declare v_region_id uuid; v_project uuid := (p_region ->> 'projeto_id')::uuid;
begin
  if v_project is null then
    raise exception using errcode = '42501', message = 'Região, contratos ou permissão inválidos.';
  end if;
  perform 1 from public.projetos p where p.id = v_project for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Projeto não encontrado.';
  end if;
  if jsonb_typeof(p_contracts) <> 'array' or not private.can_manage_project_member(v_project) then
    raise exception using errcode = '42501', message = 'Região, contratos ou permissão inválidos.';
  end if;
  if not private.can_project_company(v_project, (p_region ->> 'empresa_id')::uuid)
     or not exists (
       select 1 from public.estruturas_plantas ep
       join public.projeto_estruturas pe on pe.estrutura_id = ep.estrutura_id
       join public.elementos_estruturais e on e.id = (p_region ->> 'elemento_id')::uuid and e.estrutura_id = ep.estrutura_id
       where ep.id = (p_region ->> 'planta_id')::uuid and pe.projeto_id = v_project
     ) then
    raise exception using errcode = '23514', message = 'Empresa, planta ou elemento da região não pertencem ao projeto.';
  end if;
  if exists (select 1 from jsonb_array_elements(p_contracts) x group by x ->> 'tipo_ensaio_id' having count(*) > 1)
     or exists (select 1 from jsonb_array_elements(p_contracts) x where coalesce((x ->> 'quantidade')::integer, 0) <= 0
       or (x ->> 'empresa_id')::uuid is distinct from (p_region ->> 'empresa_id')::uuid
       or not exists (select 1 from public.tipos_ensaio t where t.id = (x ->> 'tipo_ensaio_id')::uuid)) then
    raise exception using errcode = '23514', message = 'Contratos inválidos, duplicados ou com quantidade não positiva.';
  end if;
  if p_region_id is null then
    insert into public.regioes_ensaio (projeto_id, planta_id, empresa_id, elemento_id, numero, posicao_x, posicao_y, tipo_marcacao, marcacao_largura, marcacao_altura, marcacao_rotacao, tamanho_marcacao, cor_marcacao, descricao)
    values (v_project, (p_region ->> 'planta_id')::uuid, (p_region ->> 'empresa_id')::uuid, (p_region ->> 'elemento_id')::uuid,
      (p_region ->> 'numero')::integer, (p_region ->> 'posicao_x')::numeric, (p_region ->> 'posicao_y')::numeric,
      p_region ->> 'tipo_marcacao', (p_region ->> 'marcacao_largura')::numeric, (p_region ->> 'marcacao_altura')::numeric,
      (p_region ->> 'marcacao_rotacao')::numeric, (p_region ->> 'tamanho_marcacao')::numeric, p_region ->> 'cor_marcacao', p_region ->> 'descricao')
    returning id into v_region_id;
  else
    if not exists (select 1 from public.regioes_ensaio r where r.id = p_region_id and r.projeto_id = v_project
      and r.planta_id = (p_region ->> 'planta_id')::uuid and r.empresa_id = (p_region ->> 'empresa_id')::uuid
      and r.elemento_id = (p_region ->> 'elemento_id')::uuid) then
      raise exception using errcode = '42501', message = 'O escopo da região existente não pode ser alterado.';
    end if;
    update public.regioes_ensaio set numero = (p_region ->> 'numero')::integer, posicao_x = (p_region ->> 'posicao_x')::numeric,
      posicao_y = (p_region ->> 'posicao_y')::numeric, tipo_marcacao = p_region ->> 'tipo_marcacao',
      marcacao_largura = (p_region ->> 'marcacao_largura')::numeric, marcacao_altura = (p_region ->> 'marcacao_altura')::numeric,
      marcacao_rotacao = (p_region ->> 'marcacao_rotacao')::numeric, tamanho_marcacao = (p_region ->> 'tamanho_marcacao')::numeric,
      cor_marcacao = p_region ->> 'cor_marcacao', descricao = p_region ->> 'descricao'
    where id = p_region_id and projeto_id = v_project returning id into v_region_id;
    if v_region_id is null then raise exception using errcode = '42501', message = 'Região não encontrada no projeto.'; end if;
  end if;
  delete from public.ensaios_contratados where regiao_id = v_region_id;
  insert into public.ensaios_contratados (projeto_id, estrutura_id, empresa_id, tipo_ensaio_id, quantidade, regiao_id)
  select v_project, (x ->> 'estrutura_id')::uuid, (x ->> 'empresa_id')::uuid, (x ->> 'tipo_ensaio_id')::uuid,
    coalesce((x ->> 'quantidade')::integer, 1), v_region_id
  from jsonb_array_elements(p_contracts) x;
  return v_region_id;
end;
$$;

create or replace function public.invite_project_client(p_project_id uuid, p_client_company_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare v_manager uuid; v_old uuid; v_old_status text;
begin
  select empresa_gestora_id, empresa_cliente_id, status_vinculo_cliente
    into v_manager, v_old, v_old_status
  from public.projetos
  where id = p_project_id
  for update;
  if not found or v_manager is null then
    raise exception using errcode = 'P0002', message = 'Projeto não encontrado.';
  end if;
  if not private.can_manage_project_member(p_project_id) then
    raise exception using errcode = '42501', message = 'Somente o gestor pode convidar cliente.';
  end if;
  if not exists (select 1 from public.empresas e where e.id = p_client_company_id) then
    raise exception using errcode = 'P0002', message = 'Projeto ou empresa não encontrado.';
  end if;
  if v_old is not null and (v_old <> p_client_company_id or v_old_status in ('ativo', 'pendente')) then
    raise exception using errcode = '23505', message = 'O projeto já possui vínculo de cliente ativo ou pendente; remova-o antes de convidar outro cliente.';
  end if;
  if p_client_company_id <> v_manager and not exists (select 1 from public.usuarios u where u.empresa_id = p_client_company_id and u.ativo is true and u.is_admin_empresa is true) then
    raise exception using errcode = '23514', message = 'A empresa cliente não tem administrador ativo.';
  end if;
  if p_client_company_id = v_manager then
    update public.projetos set empresa_cliente_id = p_client_company_id, status_vinculo_cliente = 'ativo' where id = p_project_id;
  else
    insert into public.empresa_clientes (gestora_id, cliente_id, status_vinculo) values (v_manager, p_client_company_id, 'pendente')
      on conflict (gestora_id, cliente_id) do update set status_vinculo = excluded.status_vinculo;
    update public.projetos set empresa_cliente_id = p_client_company_id, status_vinculo_cliente = 'pendente' where id = p_project_id;
    insert into public.notificacoes (usuario_id, titulo, mensagem, tipo, lida, dados_extras)
      select u.id, 'Convite de Cliente', 'Sua empresa recebeu um convite para um projeto.', 'convite_cliente', false,
        pg_catalog.jsonb_build_object('projeto_id', p_project_id)
      from public.usuarios u where u.empresa_id = p_client_company_id and u.ativo is true and u.is_admin_empresa is true;
  end if;
  return p_project_id;
end;
$$;

create or replace function public.respond_to_project_client_invite(p_project_id uuid, p_notification_id uuid, p_accept boolean)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare v_actor uuid := (select auth.uid()); v_company uuid; v_manager uuid; v_client uuid; v_status text;
begin
  select empresa_gestora_id, empresa_cliente_id, status_vinculo_cliente into v_manager, v_client, v_status from public.projetos where id = p_project_id for update;
  if not found or v_manager is null then
    raise exception using errcode = 'P0002', message = 'Projeto não encontrado.';
  end if;
  select u.empresa_id into v_company from public.usuarios u where u.id = v_actor and u.ativo is true and u.is_admin_empresa is true;
  if v_company is null or v_client <> v_company or v_status <> 'pendente' then
    raise exception using errcode = '42501', message = 'Convite inválido ou usuário sem permissão.';
  end if;
  if p_notification_id is not null and not exists (
    select 1
    from public.notificacoes n
    where n.id = p_notification_id
      and n.usuario_id = v_actor
      and n.tipo = 'convite_cliente'
      and n.dados_extras ->> 'projeto_id' = p_project_id::text
  ) then
    raise exception using errcode = '42501', message = 'Notificação inválida.';
  end if;
  if p_accept then
    update public.projetos set status_vinculo_cliente = 'ativo' where id = p_project_id;
    insert into public.empresa_clientes (gestora_id, cliente_id, status_vinculo) values (v_manager, v_company, 'ativo')
      on conflict (gestora_id, cliente_id) do update set status_vinculo = excluded.status_vinculo;
  else
    update public.projetos set empresa_cliente_id = null, status_vinculo_cliente = 'nao_vinculado' where id = p_project_id;
    insert into public.empresa_clientes (gestora_id, cliente_id, status_vinculo) values (v_manager, v_company, 'recusado')
      on conflict (gestora_id, cliente_id) do update set status_vinculo = excluded.status_vinculo;
  end if;
  if p_notification_id is not null then update public.notificacoes set lida = true where id = p_notification_id and usuario_id = v_actor; end if;
  return p_project_id;
end;
$$;

create or replace function public.remove_project_client(p_project_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare v_manager uuid; v_client uuid;
begin
  select empresa_gestora_id, empresa_cliente_id
    into v_manager, v_client
  from public.projetos
  where id = p_project_id
  for update;
  if not found or v_manager is null then
    raise exception using errcode = 'P0002', message = 'Projeto não encontrado.';
  end if;
  if not private.can_manage_project_member(p_project_id) then
    raise exception using errcode = '42501', message = 'Somente o gestor pode remover o cliente.';
  end if;
  update public.projetos set empresa_cliente_id = null, status_vinculo_cliente = 'nao_vinculado' where id = p_project_id;
  if v_client is not null then update public.empresa_clientes set status_vinculo = 'removida' where gestora_id = v_manager and cliente_id = v_client; end if;
  return p_project_id;
end;
$$;

create or replace function public.transfer_project_management(
  p_project_id uuid,
  p_new_manager_company_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_current_manager uuid;
begin
  select p.empresa_gestora_id
    into v_current_manager
  from public.projetos p
  where p.id = p_project_id
  for update;

  if not found or v_current_manager is null then
    raise exception using errcode = 'P0002', message = 'Projeto não encontrado.';
  end if;

  if not private.is_active_company_admin(v_current_manager) then
    raise exception using errcode = '42501', message = 'Somente administrador ativo da empresa gestora pode transferir o projeto.';
  end if;
  if p_new_manager_company_id is null then
    raise exception using errcode = '22023', message = 'A nova empresa gestora é obrigatória.';
  end if;
  if p_new_manager_company_id = v_current_manager then
    return p_project_id;
  end if;

  perform 1
  from public.projeto_empresas_colaboradoras pec
  where pec.projeto_id = p_project_id
    and pec.empresa_id = p_new_manager_company_id
    and pec.status = 'aceito'
  for update;
  if not found then
    raise exception using errcode = '42501', message = 'A nova empresa gestora precisa ser uma colaboradora aceita.';
  end if;

  insert into public.projeto_empresas_colaboradoras (projeto_id, empresa_id, criado_por, status)
  values (p_project_id, v_current_manager, (select auth.uid()), 'aceito')
  on conflict (projeto_id, empresa_id)
  do update set status = 'aceito';

  delete from public.projeto_empresas_colaboradoras
  where projeto_id = p_project_id
    and empresa_id = p_new_manager_company_id;

  update public.projetos
  set empresa_gestora_id = p_new_manager_company_id
  where id = p_project_id;

  return p_project_id;
end;
$$;

create or replace function public.list_company_clients(p_manager_company_id uuid)
returns table (id uuid, nome text)
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select e.id, e.nome
  from public.empresa_clientes ec
  join public.empresas e on e.id = ec.cliente_id
  where ec.gestora_id = p_manager_company_id
    and ec.status_vinculo = 'ativo'
    and private.is_active_actor()
    and private.active_actor_company_id() = p_manager_company_id
$$;

-- RPC ACLs. The private helpers are never exposed to anon; public RPCs require
-- the authenticated role. service_role retains explicit execution for trusted
-- backend jobs.
do $$
declare v_sig text;
begin
  foreach v_sig in array array[
    'is_active_actor()','is_active_platform_admin()','can_project_company(uuid, uuid)',
    'can_access_project_member(uuid)','can_manage_project_member(uuid)',
    'can_access_point(uuid)','can_edit_point(uuid)','can_delete_point(uuid)','can_access_point_in_project(uuid, uuid)',
    'can_edit_point_in_project(uuid, uuid)','can_access_report(uuid)',
    'can_edit_report(uuid)','can_delete_report(uuid)','can_manage_feed_post(uuid)'
  ] loop
    execute 'revoke all on function private.' || v_sig || ' from public, anon';
    execute 'grant execute on function private.' || v_sig || ' to authenticated, service_role';
  end loop;
end;
$$;

revoke all on function private.canonical_project_image_url(text, uuid, text)
  from public, anon, authenticated;
grant execute on function private.canonical_project_image_url(text, uuid, text)
  to service_role;

revoke all on function public.create_project(text, uuid, text, text, text, text) from public, anon, authenticated;
revoke all on function public.update_project(uuid, text, text, text, text, text) from public, anon, authenticated;
revoke all on function public.delete_project(uuid) from public, anon, authenticated;
revoke all on function public.save_region_with_contracts(uuid, jsonb, jsonb) from public, anon, authenticated;
revoke all on function public.invite_project_client(uuid, uuid) from public, anon, authenticated;
revoke all on function public.respond_to_project_client_invite(uuid, uuid, boolean) from public, anon, authenticated;
revoke all on function public.remove_project_client(uuid) from public, anon, authenticated;
revoke all on function public.list_company_clients(uuid) from public, anon, authenticated;
revoke all on function public.transfer_project_management(uuid, uuid) from public, anon, authenticated;
grant execute on function public.create_project(text, uuid, text, text, text, text) to authenticated, service_role;
grant execute on function public.update_project(uuid, text, text, text, text, text) to authenticated, service_role;
grant execute on function public.delete_project(uuid) to authenticated, service_role;
grant execute on function public.save_region_with_contracts(uuid, jsonb, jsonb) to authenticated, service_role;
grant execute on function public.invite_project_client(uuid, uuid) to authenticated, service_role;
grant execute on function public.respond_to_project_client_invite(uuid, uuid, boolean) to authenticated, service_role;
grant execute on function public.remove_project_client(uuid) to authenticated, service_role;
grant execute on function public.list_company_clients(uuid) to authenticated, service_role;
grant execute on function public.transfer_project_management(uuid, uuid) to authenticated, service_role;

-- No Data API access is granted to legacy, unconsumed tables:
-- ensaios, ensaio_elementos, ensaio_resultados, midias, midias_ensaios,
-- relatorios. They remain available to service_role/administration.

commit;
