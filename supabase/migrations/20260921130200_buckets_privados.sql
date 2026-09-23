-- NÃO APLICAR. Decisão de 21/09/2026: os buckets atuais continuam públicos
-- (arquivos já existentes seguem abrindo pelo link). O app só usa link
-- temporário para buckets fora de StorageUrls.bucketsPublicos.
-- Torna os buckets privados.
--
-- ⚠ SÓ APLIQUE DEPOIS QUE A VERSÃO NOVA DOS APPS ESTIVER NO AR (web
-- publicado e app atualizado nas lojas, com a maioria dos usuários já na
-- versão nova). Os apps antigos abrem imagens e PDFs pelo link público;
-- depois desta migração esse link responde 400 e as imagens somem neles.
--
-- Pré-requisito: 20260921130100_storage_acesso_por_empresa.sql aplicada
-- (é ela que define quem pode gerar o link temporário de cada arquivo).
--
-- Para voltar atrás em caso de problema: rode o mesmo UPDATE com
-- public = true. Nenhum dado é alterado, só a forma de acesso.

update storage.buckets
set public = false
where id in ('projetos', 'estruturas', 'avatars', 'elementos-fotos', 'relatorios', 'empresas', 'educacao_midias');

select id, public from storage.buckets order by id;
