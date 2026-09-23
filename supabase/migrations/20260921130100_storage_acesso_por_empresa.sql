-- APLICADA no Supabase de produção em 21/09/2026 (SQL Editor).
-- Storage: leitura restrita por empresa e fim das políticas abertas.
--
-- ESTADO ENCONTRADO (21/09/2026)
--   • Os 7 buckets são públicos: qualquer um com o link baixa o arquivo.
--   • Políticas para o papel `public` (inclui quem NÃO está logado, usando só
--     a chave anon que vai dentro do app) permitiam LISTAR e BAIXAR tudo de
--     projetos, avatars, estruturas e elementos-fotos, e ENVIAR, ALTERAR e
--     APAGAR arquivos de estruturas e avatars.
--
-- O QUE ESTA MIGRAÇÃO FAZ
--   1. Registra, para cada arquivo, a empresa dona (private.arquivo_empresa),
--      preenchida por gatilho no upload e, para o que já existe, pela empresa
--      atual de quem enviou. O vínculo não muda se a pessoa sair da empresa
--      ou tiver a conta apagada — a foto continua da empresa.
--   2. Leitura:
--        projetos, estruturas, elementos-fotos, relatorios → a própria
--        empresa e as empresas que dividem projeto com ela (gestora,
--        cliente ou equipe do projeto). elementos-fotos mantém também a
--        regra por elemento que já existia.
--        avatars, empresas, educacao_midias → qualquer usuário logado (fotos
--        de perfil, feed, logos e serviços aparecem entre empresas).
--   3. Remove todas as políticas para `public`/anon e as recria só para
--      `authenticated`.
--   4. A cota de armazenamento passa a contar pelos arquivos da empresa
--      (antes contava por quem enviou, e arquivos de quem saiu sumiam da
--      conta).
--
-- ESTA MIGRAÇÃO NÃO TORNA OS BUCKETS PRIVADOS. Com o bucket público, o link
-- direto continua abrindo, então nada quebra nos apps já instalados. A troca
-- para privado está em 20260921130200_buckets_privados.sql e só pode rodar
-- depois que a versão nova dos apps (links temporários) estiver publicada.
--
-- Pode rodar mais de uma vez sem erro.

begin;

-- ---------------------------------------------------------------------------
-- 1. Arquivo → empresa
-- ---------------------------------------------------------------------------
create table if not exists private.arquivo_empresa (
  object_id uuid primary key,
  bucket_id text not null,
  empresa_id uuid not null,
  registrado_em timestamptz not null default now()
);
create index if not exists arquivo_empresa_empresa_idx on private.arquivo_empresa (empresa_id);
revoke all on private.arquivo_empresa from public, anon, authenticated;

-- Carga do que já existe: empresa atual de quem enviou.
insert into private.arquivo_empresa (object_id, bucket_id, empresa_id)
select o.id, o.bucket_id, u.empresa_id
from storage.objects o
join public.usuarios u on u.id = o.owner
where u.empresa_id is not null
on conflict (object_id) do nothing;

-- Logos e capas ficam em empresas/<empresa_id>/...: a pasta diz a empresa.
insert into private.arquivo_empresa (object_id, bucket_id, empresa_id)
select o.id, o.bucket_id, e.id
from storage.objects o
join public.empresas e on e.id::text = split_part(o.name, '/', 1)
where o.bucket_id = 'empresas'
on conflict (object_id) do nothing;

-- No upload: grava a empresa de quem está enviando. Nunca impede o upload.
create or replace function private.trg_registrar_arquivo_empresa()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_empresa uuid;
begin
  begin
    v_empresa := private.active_actor_company_id();
    if v_empresa is not null then
      insert into private.arquivo_empresa (object_id, bucket_id, empresa_id)
      values (new.id, new.bucket_id, v_empresa)
      on conflict (object_id) do nothing;
    end if;
  exception when others then
    raise warning 'arquivo_empresa: %', sqlerrm;
  end;
  return null;
end;
$$;
revoke all on function private.trg_registrar_arquivo_empresa() from public, anon, authenticated;

-- Sem DROP: apagar gatilho exige ser dono de storage.objects (o papel
-- postgres só tem o privilégio TRIGGER). Criar só se ainda não existir; a
-- função acima é atualizada pelo CREATE OR REPLACE.
do $do$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'registrar_arquivo_empresa' and tgrelid = 'storage.objects'::regclass
  ) then
    create trigger registrar_arquivo_empresa
    after insert on storage.objects
    for each row execute function private.trg_registrar_arquivo_empresa();
  end if;
end;
$do$;

-- ---------------------------------------------------------------------------
-- 2. Quem pode ler um arquivo de empresa
-- ---------------------------------------------------------------------------
-- true quando a empresa do usuário logado é a dona do arquivo ou divide um
-- projeto com ela.
create or replace function private.pode_ler_arquivo(p_object_id uuid, p_owner uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_catalog
as $$
declare
  v_uid uuid := (select auth.uid());
  v_minha uuid;
  v_dona uuid;
begin
  if v_uid is null then
    return false;
  end if;
  if p_owner = v_uid then
    return true;
  end if;
  v_minha := private.active_actor_company_id();
  if v_minha is null then
    return false;
  end if;
  select a.empresa_id into v_dona from private.arquivo_empresa a where a.object_id = p_object_id;
  if v_dona is null then
    return false;
  end if;
  if v_dona = v_minha then
    return true;
  end if;
  return exists (
    select 1
    from public.projetos p
    where (
        p.empresa_gestora_id = v_dona or p.empresa_cliente_id = v_dona
        or exists (select 1 from public.projeto_equipe_interna e
                   where e.projeto_id = p.id and e.ativo is true and e.empresa_id = v_dona)
      )
      and (
        p.empresa_gestora_id = v_minha or p.empresa_cliente_id = v_minha
        or exists (select 1 from public.projeto_equipe_interna e
                   where e.projeto_id = p.id and e.ativo is true
                     and (e.empresa_id = v_minha or e.usuario_id = v_uid))
      )
  );
end;
$$;
revoke all on function private.pode_ler_arquivo(uuid, uuid) from public, anon;
grant execute on function private.pode_ler_arquivo(uuid, uuid) to authenticated;

-- true quando o arquivo é da empresa do usuário logado (para alterar/apagar).
create or replace function private.arquivo_da_minha_empresa(p_object_id uuid, p_owner uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select (select auth.uid()) is not null and (
    p_owner = (select auth.uid())
    or exists (select 1 from private.arquivo_empresa a
               where a.object_id = p_object_id
                 and a.empresa_id = private.active_actor_company_id())
  );
$$;
revoke all on function private.arquivo_da_minha_empresa(uuid, uuid) from public, anon;
grant execute on function private.arquivo_da_minha_empresa(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Políticas
-- ---------------------------------------------------------------------------
-- Abertas a `public` (anon incluso) ou largas demais: saem.
drop policy if exists "Leitura Publica Avatars" on storage.objects;
drop policy if exists "Upload Avatars" on storage.objects;
drop policy if exists "Update Avatars" on storage.objects;
drop policy if exists "Permitir Uploads Estruturas(plantas) tk29ne_0" on storage.objects;
drop policy if exists "Permitir Uploads Estruturas(plantas) tk29ne_1" on storage.objects;
drop policy if exists "Permitir Uploads Estruturas(plantas) tk29ne_2" on storage.objects;
drop policy if exists "Permitir Uploads Estruturas(plantas) tk29ne_3" on storage.objects;
drop policy if exists "Permitir upload de fotos" on storage.objects;
drop policy if exists "Permitir visualizacao de fotos" on storage.objects;
drop policy if exists "uploadProject_photo 1iiiv1s_0" on storage.objects;
drop policy if exists "uploadProject_photo 1iiiv1s_1" on storage.objects;
drop policy if exists dv_project_storage_select_allow on storage.objects;

-- elementos-fotos: as regras por elemento já existentes valiam para
-- `public`; passam a valer só para `authenticated` (mesmo critério).
do $do$
declare
  v_nome text;
  v_cmd text;
  v_q text;
  v_c text;
begin
  for v_nome, v_cmd, v_q, v_c in
    select policyname, cmd, qual, with_check from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname in ('elementos_fotos_select_autorizado', 'elementos_fotos_insert_autorizado',
                         'elementos_fotos_update_autorizado', 'elementos_fotos_delete_autorizado')
      and 'public' = any(roles)
  loop
    execute format('drop policy %I on storage.objects', v_nome);
    execute format('create policy %I on storage.objects for %s to authenticated%s%s',
      v_nome, v_cmd,
      case when v_q is not null then ' using (' || v_q || ')' else '' end,
      case when v_c is not null then ' with check (' || v_c || ')' else '' end);
  end loop;
end;
$do$;

-- Leitura dos buckets de trabalho: empresa dona + parceiras de projeto.
drop policy if exists dv_arquivos_empresa_select on storage.objects;
create policy dv_arquivos_empresa_select on storage.objects
for select to authenticated
using (
  bucket_id in ('projetos', 'estruturas', 'elementos-fotos', 'relatorios')
  and private.pode_ler_arquivo(id, owner)
);

-- Upload nos buckets de trabalho: qualquer usuário ativo, com ou sem
-- empresa (a cota e as guardas de pasta de projetos continuam valendo por
-- serem restritivas). Sem empresa, só o próprio autor lê o arquivo.
drop policy if exists dv_arquivos_empresa_insert on storage.objects;
create policy dv_arquivos_empresa_insert on storage.objects
for insert to authenticated
with check (
  bucket_id in ('projetos', 'estruturas', 'relatorios')
  and private.is_active_actor()
);

-- Alterar/apagar nos buckets de trabalho: só arquivos da própria empresa.
drop policy if exists dv_arquivos_empresa_update on storage.objects;
create policy dv_arquivos_empresa_update on storage.objects
for update to authenticated
using (bucket_id in ('projetos', 'estruturas', 'relatorios') and private.arquivo_da_minha_empresa(id, owner))
with check (bucket_id in ('projetos', 'estruturas', 'relatorios'));

drop policy if exists dv_arquivos_empresa_delete on storage.objects;
create policy dv_arquivos_empresa_delete on storage.objects
for delete to authenticated
using (bucket_id in ('projetos', 'estruturas', 'relatorios') and private.arquivo_da_minha_empresa(id, owner));

-- educacao_midias: leitura para logados (as outras continuam como estão:
-- dv_avatars_select_allow e dv_empresas_bucket_select_allow já exigem login).
drop policy if exists dv_educacao_select on storage.objects;
create policy dv_educacao_select on storage.objects
for select to authenticated
using (bucket_id = 'educacao_midias');

-- ---------------------------------------------------------------------------
-- 4. Cota: arquivos da empresa (vínculo registrado) + os ainda sem vínculo
--    enviados por membros atuais.
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
      objetos as (
        select o.* from storage.objects o
        where o.id in (select a.object_id from private.arquivo_empresa a where a.empresa_id = p_empresa)
           or (%s in (select id from membros)
               and not exists (select 1 from private.arquivo_empresa a where a.object_id = o.id))
      ),
      arquivos as (
        select
          coalesce(sum((o.metadata->>'size')::bigint) filter (
            where coalesce(o.metadata->>'mimetype', '') <> 'application/pdf'
              and o.name not ilike '%%.pdf'), 0)::bigint as fotos,
          coalesce(sum((o.metadata->>'size')::bigint) filter (
            where o.metadata->>'mimetype' = 'application/pdf'
               or o.name ilike '%%.pdf'), 0)::bigint as relatorios
        from objetos o
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

-- Limpeza de vínculos de arquivos que já não existem (chamada pela retenção).
create or replace function private.limpar_arquivo_empresa()
returns int
language sql
security definer
set search_path = public, pg_catalog
as $$
  with apagados as (
    delete from private.arquivo_empresa a
    where not exists (select 1 from storage.objects o where o.id = a.object_id)
    returning 1
  )
  select count(*)::int from apagados;
$$;
revoke all on function private.limpar_arquivo_empresa() from public, anon, authenticated;

commit;

-- Relatório: arquivos sem empresa registrada (enviados por contas já
-- apagadas ou sem empresa). Depois da troca para privado, só o próprio
-- autor (se existir) consegue lê-los.
select o.bucket_id, count(*) as arquivos_sem_empresa
from storage.objects o
where not exists (select 1 from private.arquivo_empresa a where a.object_id = o.id)
group by 1
order by 1;
