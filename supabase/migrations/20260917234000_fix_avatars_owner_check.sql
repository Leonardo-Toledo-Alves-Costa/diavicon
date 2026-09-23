-- Corrige a checagem de dono nas policies de escrita do bucket `avatars`.
--
-- As policies de 20260917100000 identificam o dono do arquivo com
--   split_part(<nome sem a pasta>, '-', 1) = auth.uid()::text
-- para o padrão `perfis/<uid>-<timestamp>.<ext>`. Isso nunca é verdadeiro:
-- UUID contém hífen, então split_part devolve apenas o primeiro bloco do id
-- (8 caracteres) e a comparação com o uid inteiro sempre falha. A outra
-- ramificação (separador '_') também falha nesse caminho, porque não há
-- underscore no nome — split_part devolve o nome inteiro.
--
-- Resultado: toda escrita em `perfis/` era negada. Na prática isso quebrava
-- o "Salvar e Acessar" do convite (completar_cadastro_screen) e a troca de
-- foto em Perfil > Dados (perfil_dados_screen). O caminho `usuarios/` não
-- era afetado porque usa '_', e UUID não tem underscore.
--
-- A correção troca o split por comparação de prefixo, que é indiferente ao
-- conteúdo do id e aceita os dois separadores em uso no app. Vale para
-- INSERT, UPDATE e DELETE — as três tinham o mesmo predicado.
--
-- Nota: o app também passou a gravar `perfis/<uid>_<timestamp>` (com
-- underscore), que já funcionava com a policy antiga. Esta migration não
-- depende dessa mudança nem a torna obsoleta: ela garante que o bucket
-- aceite as duas formas, inclusive os arquivos já gravados com hífen.

begin;

drop policy if exists dv_avatars_insert_own on storage.objects;
create policy dv_avatars_insert_own
on storage.objects as permissive
for insert to authenticated
with check (
  bucket_id = 'avatars'
  and (
    (
      (storage.foldername(name))[1] in ('usuarios', 'perfis')
      and (
        starts_with(regexp_replace(name, '^[^/]+/', ''), auth.uid()::text || '_')
        or starts_with(regexp_replace(name, '^[^/]+/', ''), auth.uid()::text || '-')
      )
    )
    or (storage.foldername(name))[1] = 'empresas'
    or (storage.foldername(name))[1] = 'feed'
  )
);

drop policy if exists dv_avatars_update_own on storage.objects;
create policy dv_avatars_update_own
on storage.objects as permissive
for update to authenticated
using (
  bucket_id = 'avatars'
  and (
    (
      (storage.foldername(name))[1] in ('usuarios', 'perfis')
      and (
        starts_with(regexp_replace(name, '^[^/]+/', ''), auth.uid()::text || '_')
        or starts_with(regexp_replace(name, '^[^/]+/', ''), auth.uid()::text || '-')
      )
    )
    or (storage.foldername(name))[1] = 'empresas'
    or (storage.foldername(name))[1] = 'feed'
  )
)
with check (
  bucket_id = 'avatars'
  and (
    (
      (storage.foldername(name))[1] in ('usuarios', 'perfis')
      and (
        starts_with(regexp_replace(name, '^[^/]+/', ''), auth.uid()::text || '_')
        or starts_with(regexp_replace(name, '^[^/]+/', ''), auth.uid()::text || '-')
      )
    )
    or (storage.foldername(name))[1] = 'empresas'
    or (storage.foldername(name))[1] = 'feed'
  )
);

drop policy if exists dv_avatars_delete_own on storage.objects;
create policy dv_avatars_delete_own
on storage.objects as permissive
for delete to authenticated
using (
  bucket_id = 'avatars'
  and (
    (
      (storage.foldername(name))[1] in ('usuarios', 'perfis')
      and (
        starts_with(regexp_replace(name, '^[^/]+/', ''), auth.uid()::text || '_')
        or starts_with(regexp_replace(name, '^[^/]+/', ''), auth.uid()::text || '-')
      )
    )
    or (storage.foldername(name))[1] = 'empresas'
    or (storage.foldername(name))[1] = 'feed'
  )
);

commit;
