# LGPD — o que mudou e ordem de implantação (21/09/2026)

## Ordem de implantação

1. **Banco: `20260921130000_lgpd_privacidade.sql`** — pode aplicar já. Compatível com as versões atuais dos apps.
   - Corrige a falha de segurança de UPDATE em `usuarios` e `empresas` (escalada para Gestor de qualquer empresa e troca de plano sem pagar).
   - Cria consentimento, preferências, exportação, auditoria e retenção.
   - Liga o pg_cron (se não ligar sozinho: Database > Extensions > pg_cron e rode o último bloco de novo).
2. **Banco: `20260921130100_storage_acesso_por_empresa.sql`** — pode aplicar já.
   - Tira o acesso anônimo a listar, baixar, enviar e apagar arquivos.
   - Leitura por empresa e parceiras de projeto.
   - Com os buckets ainda públicos, os apps antigos seguem funcionando.
3. **Edge function `auth-operations`** — publicar (ação nova `delete_own_account`, auditoria e limpeza de fotos pessoais).
4. **Apps** — `flutter pub get` e `flutter analyze` nos dois projetos, testar, publicar o web e enviar o app às lojas.
5. ~~Buckets privados~~ — **não aplicar** (decisão de 21/09/2026: os arquivos atuais continuam públicos pelo link). As políticas do passo 2 continuam valendo: sem login ninguém lista, envia, altera ou apaga. O app já sabe usar link temporário para qualquer bucket novo que seja criado privado (fora de `StorageUrls.bucketsPublicos`).
6. Depois disso: `revoke update (email) on public.usuarios from authenticated;`

## Lojas

- **App Store:** URL da política = https://diavicon.com.br/app/privacidade.html. A exclusão de conta fica em Perfil > Minha conta.
- **Google Play:** preencher "Segurança dos dados" (localização precisa, fotos, nome, e-mail, telefone, ID do usuário). Informar a URL de exclusão (a mesma política, seção 7) e a opção dentro do app.

## Onde está cada coisa

| Item | Arquivo |
|---|---|
| Textos legais (fonte única) | `assets/legal/politica_privacidade.md`, `assets/legal/termos_uso.md` |
| Versões e e-mail de privacidade | `lib/features/legal/documentos_legais.dart` |
| Aceite obrigatório | `lib/features/legal/consentimento_gate.dart` |
| Links temporários | `lib/core/services/storage_urls.dart`, `lib/core/widgets/imagem_storage.dart` |
| Remoção de EXIF | `lib/core/services/foto_metadados.dart` |
| Páginas públicas (web) | `web/privacidade.html`, `web/termos.html` (geradas dos .md) |
| Aviso de cookies (web) | `web/index.html`, bloco `dv-aviso-cookies` |
| Rodapé legal (web) | `lib/features/legal/widgets/rodape_legal.dart` |

## Ao mudar um texto legal

1. Edite o `.md` e a data no topo.
2. Troque a versão em `documentos_legais.dart`. Todos aceitam de novo no próximo acesso.
3. Regenere as páginas `web/*.html`.
