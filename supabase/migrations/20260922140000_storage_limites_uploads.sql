-- PENDENTE: para a equipe revisar e aplicar. Ainda NÃO está no Supabase.
--
-- Storage: limite de tamanho e de tipo por bucket + escrita no bucket
-- `avatars` restrita ao dono de cada pasta.
--
-- ESTADO ENCONTRADO (22/09/2026)
--   1. Nenhum bucket tem file_size_limit nem allowed_mime_types: qualquer
--      usuário logado podia enviar arquivo de qualquer tamanho e tipo — um
--      SVG ou HTML num bucket público vira página ativa no domínio do
--      Supabase (XSS armazenado).
--   2. `avatars`: as políticas dv_avatars_* (20260917234000) liberavam
--      INSERT/UPDATE/DELETE em QUALQUER objeto sob `empresas/` e `feed/` para
--      qualquer usuário logado — dava para trocar ou apagar a logo, as fotos
--      de serviço e as fotos do feed de outras empresas.
--   3. projetos/estruturas/relatorios: INSERT liberado a qualquer usuário
--      ativo, em qualquer caminho (dv_arquivos_empresa_insert, 20260921130100).
--
-- O QUE ESTA MIGRAÇÃO FAZ
--   A. Limite de tamanho e lista de tipos (Content-Type) por bucket. Vale só
--      para uploads NOVOS; arquivos já gravados não são tocados. Os tipos
--      saíram de TODOS os uploads que os apps (celular e web) fazem hoje:
--
--      bucket               limite   tipos aceitos
--      projetos             100 MB   JPEG, PNG, WEBP, HEIC/HEIF, PDF,
--                                    text/html, application/octet-stream
--      estruturas            50 MB   JPEG, PNG, WEBP, HEIC/HEIF, PDF
--      elementos-fotos       15 MB   JPEG, PNG, WEBP, HEIC/HEIF
--      relatorios           100 MB   PDF, text/html
--      avatars               15 MB   JPEG, PNG, WEBP, HEIC/HEIF
--      empresas              15 MB   JPEG, PNG, WEBP, HEIC/HEIF
--      educacao_midias      100 MB   JPEG, PNG, WEBP, PDF, MP4/WEBM/MOV
--      ensaios-importacoes   25 MB   text/csv, text/plain,
--                                    application/octet-stream
--      (financeiro já tem limite próprio em 20260922100000, também pendente.)
--
--      De onde vem cada tipo:
--      * fotos (todas as telas): o app detecta o tipo pelo conteúdo e só
--        envia JPEG/PNG/WEBP/HEIC/HEIF, com Content-Type explícito
--        (lib/core/security/upload_seguro.dart). SVG e GIF são recusados.
--      * PDF: relatórios de ensaio e RDO (projetos/relatorios/...), plantas
--        (estruturas/plantas/...) e comprovantes de gasto (projetos/gastos/...).
--      * text/html: relatórios em HTML (celular com formato HTML e o web app,
--        que não converte para PDF).
--      * application/octet-stream: séries da prova de carga dinâmica
--        (projetos/pcd/<prova>/...bin, web app). É servido como download,
--        nunca renderizado.
--      * text/csv: CSV original da importação do ultrassom (PL-200).
--
--      Tamanhos: foto de celular tem 3–12 MB (15 MB dá folga; o app recusa
--      acima disso antes de enviar). Relatório em PDF com muitas fotos passa
--      de 50 MB, por isso projetos/relatorios ficam em 100 MB. Plantas
--      escaneadas: 50 MB. CSV do PL-200 tem poucos MB; blocos da série PCD
--      têm < 1 MB (25 MB dá folga).
--      O limite GLOBAL do projeto (Storage > Settings) continua valendo por
--      cima destes: se ele for menor, é ele que manda.
--
--   B. `avatars`: escrita (INSERT/UPDATE/DELETE) só pelo dono da pasta, pela
--      função private.pode_gravar_avatar(name). Caminhos usados pelos apps:
--        usuarios/<uid>_<uuid>.<ext>            foto de perfil (cadastro)
--        perfis/<uid>_<uuid>.<ext>              foto de perfil (convite/perfil)
--          → como antes: o nome começa com o uid de quem envia ('_' ou '-').
--        feed/<uid>/<uuid>.<ext>                fotos de post do feed (NOVO
--          caminho; antes era feed/<timestamp>.<ext>, sem dono)
--          → só o próprio usuário.
--        empresas/cadastro/<uid>/<uuid>.<ext>   logo enviada no cadastro da
--          empresa, ANTES de a empresa existir (NOVO caminho; antes era
--          empresas/<timestamp>.<ext>, sem dono)
--          → só o próprio usuário.
--        empresas/servicos_cad/<servico_id>/... capa e galeria de serviço
--          → só admin (ativo) da empresa dona do serviço — a mesma regra das
--            tabelas empresa_servicos/empresa_servicos_galeria.
--        empresas/<empresa_id>/...              (reservado; não usado hoje)
--          → só admin (ativo) daquela empresa.
--      Arquivos antigos em feed/<arquivo> e empresas/<arquivo> (sem dono no
--      caminho) continuam LEGÍVEIS (a leitura, dv_avatars_select_allow, não
--      muda), mas deixam de poder ser alterados ou apagados pelos apps.
--      Nenhuma tela altera ou apaga esses arquivos.
--
--   C. projetos/estruturas/relatorios: o INSERT continua como está.
--      ATENÇÃO: os caminhos não começam por um id verificável (ensaios/<tipo>/,
--      rdo/galeria/, relatorios/<tipo>/, estruturas/, inspecoes/, marcacoes/,
--      gastos/<empresa>/<uid>/, users/<uid>/capas/, pcd/<prova>/;
--      estruturas/plantas/<estrutura_id>_<uuid>). Restringir por caminho
--      hoje quebraria uploads. O que fica valendo: login + usuário ativo +
--      cota (plano_armazenamento_upload) + tamanho/tipo acima; alterar e
--      apagar continuam só para arquivos da própria empresa. Para restringir
--      por projeto, primeiro padronizar os caminhos para <projeto_id>/...
--
-- ATENÇÃO
--   * projetos aceita text/html (relatórios HTML) de qualquer usuário ativo.
--     Os relatórios são gerados pelo app, mas um cliente modificado ainda
--     pode gravar HTML no bucket público. Mitigação futura: relatórios HTML
--     em bucket privado (links temporários) ou só PDF.
--   * `relatorios` não recebe upload de nenhuma tela hoje (os relatórios vão
--     para projetos/relatorios/...). Se nenhuma versão antiga do app ainda
--     grava lá, dá para tirar 'relatorios' de dv_arquivos_empresa_insert.
--   * educacao_midias não recebe upload dos apps (só pelo painel/serviço);
--     os tipos acima são uma suposição. Conferir com a consulta 3 abaixo
--     antes de aplicar.
--   * ensaios-importacoes aceita application/octet-stream porque as
--     políticas ensaios_importacoes_pcd_* (20260919210000) preveem arquivos
--     da PCD nesse bucket; hoje o web app grava a série PCD em `projetos`.
--   * Apps já instalados (versão anterior) ainda gravam feed/<arquivo> e
--     empresas/<arquivo> no avatars: depois desta migração esses uploads
--     falham (é justamente a brecha). Publicar a versão nova dos apps ANTES
--     ou junto com esta migração.
--
-- Pode rodar mais de uma vez sem erro.

begin;

-- ---------------------------------------------------------------------------
-- A. Limites por bucket
-- ---------------------------------------------------------------------------
update storage.buckets
set file_size_limit = 104857600, -- 100 MB
    allowed_mime_types = array[
      'image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif',
      'application/pdf', 'text/html', 'application/octet-stream'
    ]
where id = 'projetos';

update storage.buckets
set file_size_limit = 52428800, -- 50 MB
    allowed_mime_types = array[
      'image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif',
      'application/pdf'
    ]
where id = 'estruturas';

update storage.buckets
set file_size_limit = 15728640, -- 15 MB
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
where id in ('elementos-fotos', 'avatars', 'empresas');

update storage.buckets
set file_size_limit = 104857600, -- 100 MB
    allowed_mime_types = array['application/pdf', 'text/html']
where id = 'relatorios';

update storage.buckets
set file_size_limit = 104857600, -- 100 MB
    allowed_mime_types = array[
      'image/jpeg', 'image/png', 'image/webp', 'application/pdf',
      'video/mp4', 'video/webm', 'video/quicktime'
    ]
where id = 'educacao_midias';

update storage.buckets
set file_size_limit = 26214400, -- 25 MB
    allowed_mime_types = array['text/csv', 'text/plain', 'application/octet-stream']
where id = 'ensaios-importacoes';

-- ---------------------------------------------------------------------------
-- B. avatars: quem pode gravar/alterar/apagar cada caminho
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER: consulta empresa_servicos/usuarios sem depender das
-- políticas dessas tabelas e trata texto que não é uuid como "sem acesso"
-- (em vez de erro de conversão dentro da política).
create or replace function private.pode_gravar_avatar(p_nome text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_catalog
as $$
declare
  v_uid uuid := (select auth.uid());
  v_pastas text[] := storage.foldername(p_nome);
  v_resto text;
  v_id uuid;
begin
  if v_uid is null or p_nome is null then
    return false;
  end if;

  -- Foto de perfil: usuarios/<uid>_... e perfis/<uid>_... (arquivos antigos
  -- usam '-'). Mesma regra de 20260917234000.
  if v_pastas[1] in ('usuarios', 'perfis') then
    v_resto := regexp_replace(p_nome, '^[^/]+/', '');
    return starts_with(v_resto, v_uid::text || '_') or starts_with(v_resto, v_uid::text || '-');
  end if;

  -- Feed: feed/<uid>/<arquivo>.
  if v_pastas[1] = 'feed' then
    return v_pastas[2] = v_uid::text and v_pastas[3] is null;
  end if;

  if v_pastas[1] = 'empresas' then
    -- Logo do cadastro, antes de a empresa existir: empresas/cadastro/<uid>/<arquivo>.
    if v_pastas[2] = 'cadastro' then
      return v_pastas[3] = v_uid::text and v_pastas[4] is null;
    end if;

    -- Serviços: empresas/servicos_cad/<servico_id>/<arquivo> → admin da
    -- empresa dona do serviço.
    if v_pastas[2] = 'servicos_cad' then
      begin
        v_id := v_pastas[3]::uuid;
      exception when others then
        return false;
      end;
      return v_id is not null and exists (
        select 1 from public.empresa_servicos s
        where s.id = v_id and private.is_active_company_admin(s.empresa_id)
      );
    end if;

    -- empresas/<empresa_id>/<arquivo> → admin daquela empresa. Arquivo solto
    -- em empresas/ (legado, sem dono) → ninguém.
    begin
      v_id := v_pastas[2]::uuid;
    exception when others then
      return false;
    end;
    return v_id is not null and private.is_active_company_admin(v_id);
  end if;

  return false;
end;
$$;
revoke all on function private.pode_gravar_avatar(text) from public, anon;
grant execute on function private.pode_gravar_avatar(text) to authenticated;

drop policy if exists dv_avatars_insert_own on storage.objects;
create policy dv_avatars_insert_own
on storage.objects as permissive
for insert to authenticated
with check (bucket_id = 'avatars' and private.pode_gravar_avatar(name));

drop policy if exists dv_avatars_update_own on storage.objects;
create policy dv_avatars_update_own
on storage.objects as permissive
for update to authenticated
using (bucket_id = 'avatars' and private.pode_gravar_avatar(name))
with check (bucket_id = 'avatars' and private.pode_gravar_avatar(name));

drop policy if exists dv_avatars_delete_own on storage.objects;
create policy dv_avatars_delete_own
on storage.objects as permissive
for delete to authenticated
using (bucket_id = 'avatars' and private.pode_gravar_avatar(name));

-- dv_avatars_select_allow (leitura por qualquer logado) não muda: fotos
-- antigas em feed/ e empresas/ continuam aparecendo.

commit;

-- ---------------------------------------------------------------------------
-- VERIFICAÇÃO (rodar depois de aplicar)
-- ---------------------------------------------------------------------------
-- 1. Limites gravados:
--      select id, public, file_size_limit, allowed_mime_types
--      from storage.buckets order by id;
--
-- 2. Nenhuma OUTRA política permissiva de escrita no avatars (criada à mão
--    no painel, por exemplo) pode continuar liberando empresas/ e feed/.
--    Entre as PERMISSIVE abaixo, só dv_avatars_insert_own/update_own/
--    delete_own podem citar 'avatars', e nenhuma pode ficar sem bucket_id:
--      select policyname, cmd, permissive, roles, qual, with_check
--      from pg_policies
--      where schemaname = 'storage' and tablename = 'objects'
--        and cmd in ('INSERT', 'UPDATE', 'DELETE', 'ALL')
--      order by permissive, policyname;
--
-- 3. Tipos já gravados em cada bucket (confere se algum uso real ficou de
--    fora da lista — em especial educacao_midias e relatorios):
--      select bucket_id, metadata->>'mimetype' as tipo, count(*),
--             pg_size_pretty(max((metadata->>'size')::bigint)) as maior
--      from storage.objects
--      group by 1, 2 order by 1, 3 desc;
--
-- 4. Regra do avatars simulando um usuário (troque os uuids; ROLLBACK no fim):
--      begin;
--      set local role authenticated;
--      select set_config('request.jwt.claims',
--        '{"sub":"<uid-do-usuario>","role":"authenticated"}', true);
--      select
--        private.pode_gravar_avatar('perfis/<uid-do-usuario>_x.jpg')          as perfil_proprio,   -- true
--        private.pode_gravar_avatar('perfis/<outro-uid>_x.jpg')               as perfil_alheio,    -- false
--        private.pode_gravar_avatar('feed/<uid-do-usuario>/x.jpg')            as feed_proprio,     -- true
--        private.pode_gravar_avatar('feed/<outro-uid>/x.jpg')                 as feed_alheio,      -- false
--        private.pode_gravar_avatar('feed/x.jpg')                             as feed_legado,      -- false
--        private.pode_gravar_avatar('empresas/cadastro/<uid-do-usuario>/x.png') as logo_cadastro,  -- true
--        private.pode_gravar_avatar('empresas/123.png')                       as empresa_legado,   -- false
--        private.pode_gravar_avatar('empresas/servicos_cad/<servico-da-minha-empresa>/x.jpg') as servico; -- true se admin
--      rollback;
