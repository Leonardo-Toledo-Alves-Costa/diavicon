# Segurança de Home e Projetos

Este diretório contém a migration versionada
`migrations_manual/20260903120000_harden_home_projects_rls.sql`. Ela ainda
**não foi aplicada no projeto remoto** — está em `migrations_manual/` (não em
`migrations/`) justamente para não ser confundida com uma migration já
aplicada via pipeline automático.

## Escopo implementado

- RLS e grants mínimos para `projetos`, `projeto_equipe_interna`,
  `projeto_empresas_colaboradoras`, `projeto_convites_cliente`,
  `empresa_clientes` e `notificacoes`.
- Helpers em `app_private`, todos `SECURITY DEFINER`, com `search_path = ''` e
  referências a objetos qualificadas por schema.
- Operações multi-tabela atômicas nas RPCs públicas:
  - `create_project(p_name text, p_client_company_id uuid default null,
    p_new_client_email text default null, p_new_client_name text default null,
    p_image_url text default null, p_new_client_image_url text default null)`;
  - `update_project(p_project_id uuid, p_name text, p_description text,
    p_status_name text, p_priority_name text, p_image_url text default null)`;
  - `invite_project_company(p_project_id uuid, p_invited_company_id uuid)`;
  - `respond_to_project_company_invite(p_invitation_id uuid,
    p_notification_id uuid, p_accept boolean)`;
  - `transfer_project_management(p_project_id uuid,
    p_new_manager_company_id uuid)`;
  - `invite_project_client(p_project_id uuid, p_client_company_id uuid)`;
  - `respond_to_project_client_invite(p_project_id uuid,
    p_notification_id uuid, p_accept boolean)`;
  - `remove_project_client(p_project_id uuid)`;
  - `delete_project(p_project_id uuid)`.
- Escrita no bucket `projetos` limitada a
  `users/<auth.uid>/{capas|clientes}/<arquivo>` para as capas e fotos deste
  módulo. Os outros prefixos já usados por Estruturas/Ensaios continuam sob as
  policies existentes; a migration não altera a visibilidade pública do bucket.

As políticas antigas não são apagadas. As políticas `dv_*` permitidas têm uma
regra `PERMISSIVE` estreita e uma guarda `RESTRICTIVE` equivalente. Escritas
que devem passar exclusivamente pelas RPCs recebem uma guarda restritiva
sempre falsa. Uma policy restritiva legada ainda pode bloquear uma operação;
o arquivo `audit_home_projects_rls.sql` lista essas policies para revisão.

## Suposições validadas pelo preflight

- IDs de usuários, empresas, projetos, convites e notificações são UUID.
- `usuarios.id = auth.uid()` e usuários válidos têm `ativo = true` e
  `empresa_id` não nulo.
- `projeto_empresas_colaboradoras` é a tabela canônica do convite entre
  empresas; os estados conhecidos são `pendente`, `aceito`, `recusado` e
  `removida`.
- Os nomes de tabelas e colunas são exatamente os usados pelos repositories
  Flutter atuais. A migration aborta antes de alterar o schema quando alguma
  coluna exigida não existe.
- Não há duplicatas para `(projeto_id, usuario_id)`,
  `(projeto_id, empresa_id)` e `(gestora_id, cliente_id)`. O preflight aborta
  com uma mensagem específica se houver dados a reconciliar.
- Nomes de `status_projeto` e `prioridade` são únicos sem diferenciar
  maiúsculas/minúsculas. A edição resolve esses IDs dentro da mesma transação.
- A role proprietária das funções é a role de migration do Supabase
  (`postgres`, com `BYPASSRLS`). Isso permite que as RPCs façam a transação
  interna embora a escrita direta do cliente esteja bloqueada.

Decisões de autorização: qualquer usuário ativo vinculado a uma empresa pode
criar um projeto para essa empresa; somente administrador da empresa ou membro
ativo marcado como gestor pode convidar empresas, convidar/trocar clientes e
transferir a gestão; somente administrador ativo da empresa convidada pode
responder aos convites. Apenas administrador da empresa gestora pode excluir o
projeto. Um cliente existente de outra empresa começa como `pendente` e só
recebe acesso ao projeto depois do aceite; projeto, vínculo e notificações são
alterados na mesma transação.

## Verificação antes de aplicar

1. Execute `audit_home_projects_rls.sql` no ambiente alvo e revise colunas,
   duplicatas, grants, policies que não começam por `dv_` e objetos antigos do
   bucket fora do novo padrão.
2. Rode a migration primeiro em uma cópia/local com `supabase db reset`.
3. Teste com JWTs de, no mínimo: usuário sem empresa, funcionário comum,
   gestor do projeto, admin da gestora, admin da convidada e usuário de uma
   terceira empresa.
4. Confirme rollback de cada RPC provocando erro na última etapa: não pode
   restar projeto sem equipe, convite sem notificação nem transferência pela
   metade.
5. Depois da aplicação, execute novamente a auditoria e faça os smoke tests do
   app para criação/edição/listagem, convite/aceite/recusa/transferência,
   notificações e upload.

Os uploads acontecem antes da RPC no Flutter e não participam da transação do
PostgreSQL. O repository tenta removê-los quando a operação posterior falha,
desde que o rollback seja confirmado. Em timeout ambíguo ele preserva o objeto
para não quebrar uma transação que possa ter sido confirmada; uma rotina de
limpeza por idade continua recomendada para objetos órfãos. Apesar dos nomes
legados `p_image_url`, as RPCs recebem o caminho interno do objeto e constroem
a URL canônica no servidor depois de validar a existência e o proprietário.

## Riscos conhecidos fora deste escopo

- `functions/convidar-funcionario/index.ts` usa a service role e aceita dados
  sensíveis do body, enquanto `config.toml` mantém `verify_jwt = false`. A
  função precisa de JWT obrigatório, autorização derivada do ator, descarte de
  `empresa_id` fornecido pelo cliente e rollback do usuário Auth quando a
  gravação de perfil falhar. Ela não foi alterada porque pertence à feature
  Equipe.
- O fluxo de perfil atualmente envia campos de autorização de `usuarios`
  (`empresa_id`, `ativo` e `is_admin_empresa`) no upsert. A RLS dessa tabela
  deve impedir que o próprio usuário promova ou mova sua conta. `usuarios` não
  foi alterada nesta migration por estar fora do escopo acordado.
- `getPublicUrl` pressupõe que o bucket `projetos` seja público. Nesse modo, a
  policy de `SELECT` não torna os arquivos confidenciais; ela protege apenas o
  acesso autenticado pela API. Trocar para bucket privado exige URLs assinadas
  e uma mudança coordenada no Dart.
