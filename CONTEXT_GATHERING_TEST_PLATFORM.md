# Context gathering — plataforma de testes do Diavicon

Este documento foi preparado para ser entregue a um modelo executor mais competente. O objetivo é dar contexto suficiente para que ele projete e implemente uma plataforma de testes abrangente para o aplicativo Diavicon, cobrindo Flutter, Supabase, Edge Functions, Storage, Realtime e a API Python.

## 1. Pedido original e limites

O pedido é construir uma plataforma de testes capaz de testar os fluxos do aplicativo tanto no lado Flutter quanto no lado Supabase.

Este documento é apenas contexto e especificação inicial. Não é uma autorização para implementar a plataforma agora.

O modelo executor deve:

- primeiro confirmar a arquitetura e as premissas com inspeção adicional do repositório;
- propor a solução de testes antes de fazer mudanças estruturais;
- preservar o comportamento do produto, salvo mudanças de testabilidade explicitamente justificadas;
- tratar como risco qualquer mudança em RLS, Edge Functions, autenticação, Storage ou dados remotos;
- produzir uma plataforma executável, reproduzível, isolada e adequada para CI, quando receber autorização para implementar.

Não deve:

- transformar testes estáticos em uma falsa prova de funcionamento end-to-end;
- usar `service_role` dentro do aplicativo Flutter, do binário de testes ou de qualquer cliente distribuído;
- usar o projeto remoto de produção como ambiente padrão de teste;
- confiar em permissões mostradas pela UI para concluir que uma operação é segura;
- considerar telas existentes como prova de que o fluxo está implementado;
- alterar lógica de negócio ou políticas de segurança sem registrar a razão e o impacto;
- apagar ou resetar um banco amplo sem resolver e validar o alvo exato.

## 2. Repositório e ambiente

Repositório Flutter:

`C:\diaviconCurrent\diavicon`

Diretório atualmente usado como workspace:

`C:\diaviconCurrent\diavicon\supabase`

Componentes principais:

- `lib/`: aproximadamente 371 arquivos Dart;
- `test/`: 11 testes Dart existentes, principalmente testes de contrato, rota e lógica isolada;
- `supabase/migrations/`: 22 migrações incrementais;
- `supabase/functions/auth-operations/index.ts`;
- `supabase/functions/convidar-funcionario/index.ts`;
- `python_api/main.py`;
- `assets/reports/`: arquivos de apoio para relatórios;
- `.env`: contém `SUPABASE_URL` e `SUPABASE_ANON_KEY`, e está incluído como asset do Flutter.

Dependências relevantes do Flutter:

- Dart `^3.10.7`;
- `supabase_flutter ^2.12.2`;
- `flutter_dotenv ^6.0.0`;
- Riverpod `^3.2.1` e `flutter_riverpod ^3.3.1`;
- `go_router ^17.2.0`;
- `google_sign_in ^7.2.0`;
- `image_picker`, `image_cropper`, `file_picker`;
- `google_maps_flutter`, `geocoding`, `geolocator`;
- `http`, `pdfx`, `flutter_html_to_pdf_plus`, `open_filex`, `path_provider`;
- `flutter_secure_storage` e `url_launcher`;
- `fl_chart` e `syncfusion_flutter_charts`;
- `google_fonts`, `flutter_svg` e componentes visuais diversos.

Dependências da API Python:

- FastAPI, Uvicorn, NumPy, SciPy, Matplotlib, cliente Supabase e Pydantic.

Observações do estado atual:

- o `README.md` ainda é o README genérico criado pelo Flutter e não documenta o sistema;
- não existe no repositório um dump completo e confiável do schema inicial do Supabase; as migrações são incrementais sobre um schema existente;
- houve execuções anteriores de harness local de RLS e de análise estática, mas isso não equivale a uma suíte end-to-end completa;
- `flutter analyze --no-pub` encontrou 147 problemas no estado observado, incluindo problemas legados;
- alguns comandos de Flutter/teste ficaram silenciosos ou travaram no ambiente observado; o executor deve validar o toolchain em sua própria execução;
- há alterações geradas e `pubspec.lock` modificados no worktree. Elas pertencem ao usuário e devem ser preservadas.

O estado histórico menciona o projeto Supabase `thmmxgzwjrydxrrfoaay`, mas há inconsistência cronológica no registro sobre o que foi aplicado remotamente. Antes de usar qualquer banco remoto como alvo, deve-se introspectar o ambiente real e confirmar seu propósito.

## 3. Inicialização e arquitetura Flutter

`lib/main.dart`:

- inicializa bindings;
- carrega `.env`;
- inicializa `Supabase` com `SUPABASE_URL` e `SUPABASE_ANON_KEY`;
- força orientação portrait;
- cria um `ProviderContainer`;
- carrega o rascunho persistido de cadastro por `CadastroDraftStore`;
- registra `routerProvider`;
- escuta mudanças de autenticação e direciona recuperação de senha para `/nova-senha`;
- monta o app com `UncontrolledProviderScope`.

`lib/app.dart` usa `MaterialApp.router`, Material 3, fonte Lato e tema próprio.

`lib/core/providers/supabase_provider.dart` expõe `Supabase.instance.client` como provider, mas vários pontos do código ainda acessam o singleton diretamente. A plataforma de testes deve prever uma costura de injeção de dependência ou um adaptador que capture o cliente, o transporte HTTP, o Storage e as chamadas de função sem esconder chamadas diretas existentes.

O roteamento está concentrado em:

- `lib/routes/app_router.dart`;
- `lib/routes/app_routes.dart`.

O guard observa a sessão e o estado de acesso do usuário. Os estados observados são:

- `loading`;
- `signedOut`;
- `awaitingEmailConfirmation`;
- `registrationPending`;
- `invitePending`;
- `active`;
- `inactive`;
- `unavailable`.

O roteador também bloqueia temporariamente a navegação enquanto o estado de acesso está sendo sincronizado, restringe deep links a rotas internas seguras e impede que usuários ativos com empresa reiniciem indevidamente o onboarding empresarial.

Rotas públicas e de autenticação relevantes:

- `/`, `/login`;
- `/register`, `/register/dados`, `/register/perfil`, `/register/academico`, `/register/retomar`;
- `/register/cliente/gate`, `/register/cliente/checkboxes`, `/register/cliente/planos`, `/register/cliente/welcome`;
- `/empresa/gate`, `/empresa/onboarding`, `/empresa/servicos`, `/empresa/planos`, `/empresa/cadastro`, `/empresa/bemvinda`;
- `/recuperar-senha`, `/nova-senha`, `/confirmar-email`;
- `/conta-inativa`, `/auth-indisponivel`, `/completar-cadastro`.

Rotas protegidas relevantes:

- `/projetos`;
- `/projetos/:projetoId`;
- `/projetos/:projetoId/informacoes`;
- `/projetos/:projetoId/empresas`;
- `/estruturas`;
- `/estruturas/:estruturaId/elementos/:elementoId`;
- `/estruturas/:estruturaId/elementos/:elementoId/informacoes`;
- `/estruturas/:estruturaId/elementos/:elementoId/relatorios`;
- `/minha-empresa`, `/educacao`, `/notificacoes`;
- subrotas de perfil.

## 4. Fluxos de autenticação e onboarding

Arquivos principais:

- `lib/features/auth/providers/auth_provider.dart`;
- `lib/features/auth/controller/auth_controller.dart`;
- `lib/features/auth/repositories/auth_repository.dart`.

Fluxos que precisam ser testados de ponta a ponta:

### 4.1 Cadastro pessoal

1. Entrada em `/register`.
2. Preenchimento de dados pessoais.
3. Escolha do perfil.
4. Dados acadêmicos/profissionais quando aplicável.
5. Upload e crop de foto.
6. Persistência e retomada de rascunho no `flutter_secure_storage`.
7. Criação da conta por e-mail.
8. Estado aguardando confirmação.
9. Confirmação de e-mail.
10. Conclusão de `complete_self_registration`.
11. Criação/atualização do registro em `usuarios` e endereço.
12. Redirecionamento para a área de projetos.

O rascunho usa a chave `diavicon.registration_draft.v1`. Caminhos de arquivos do rascunho são sanitizados e devem ser tratados com fixtures temporárias no teste.

### 4.2 Cadastro de cliente

O wizard possui gate, checkboxes, escolha de plano e welcome. O teste deve distinguir:

- seleção feita na UI;
- plano realmente escolhido pelo backend;
- estados de validação;
- confirmação e ativação;
- retorno ao fluxo em caso de interrupção.

### 4.3 Cadastro de empresa

O fluxo passa por gate, onboarding, serviços, planos, cadastro e welcome. A empresa possui endereço comercial próprio, separado do endereço da pessoa. O CNPJ deve ser normalizado e validado.

Embora a UI apresente seleção de plano, o backend atualmente escolhe o plano Freemium por nome estável. O ID enviado pelo cliente não deve ser tratado como autoridade.

Testar:

- CNPJ inválido, duplicado e válido;
- empresa já existente;
- endereço comercial incompleto;
- usuário já vinculado a empresa;
- falha após upload de imagem;
- retry sem duplicar empresa ou usuário;
- confirmação de e-mail;
- limites e plano inicial.

### 4.4 Login, logout e recuperação

Testar:

- login correto;
- senha incorreta;
- usuário inexistente;
- usuário sem confirmação;
- usuário sem perfil;
- usuário convidado;
- usuário inativo;
- erro de leitura do perfil, que deve falhar fechado em `auth-unavailable`;
- logout e invalidação do estado local;
- pedido de recuperação;
- deep link de nova senha;
- senha vazia, inválida e alterada com sucesso;
- redirecionamento interno seguro após login;
- tentativa de usar esquema, autoridade ou URL externa em redirect.

### 4.5 Google Sign-In

O app inicializa `GoogleSignIn`, autentica, autoriza scopes e chama `signInWithIdToken`. Deve ser testado com um fake de Google Sign-In, não com uma conta real em CI.

Casos:

- usuário Google ativo;
- usuário Google novo sem perfil;
- limpeza do órfão recente por `cleanup_google_orphan`;
- identidade que não atende às condições de limpeza;
- falha no token;
- cancelamento;
- conta inativa ou convidada;
- logout após limpeza.

## 5. Shell e navegação principal

`MainScreen` disponibiliza navegação para:

- projetos;
- estruturas;
- minha empresa;
- educação/feed;
- notificações.

O drawer inclui perfil, conta, plano, ajuda e logout. Algumas telas de conta, privacidade, configurações e ajuda são parcialmente estáticas ou possuem callbacks sem implementação. A plataforma deve marcar esses casos como `partial`, `mocked` ou `not implemented`, e não como sucesso.

## 6. Projetos e empresas participantes

Arquivos centrais:

- `lib/features/projetos/repositories/project_repository.dart`;
- telas e providers da pasta `lib/features/projetos/`;
- repositórios de clientes e empresas do projeto.

### 6.1 Projetos

Operações a cobrir:

- listar projetos visíveis;
- filtros e estados vazio/carregando/erro;
- abrir detalhe;
- consultar informações;
- criar projeto com cliente existente;
- criar projeto com cliente novo;
- upload de capa;
- atualizar nome, status, prioridade e capa;
- excluir projeto;
- cancelar/repetir em falha de rede;
- verificar limpeza de arquivos quando a falha é definitiva;
- preservar arquivos quando a resposta é ambígua/timeout;
- verificar atomicidade do RPC.

O upload de capa usa o bucket `projetos`, normalmente em `users/<userId>/capas/<timestamp>.<ext>`. O cliente novo pode usar caminho sob `users/<userId>/clientes/...`. O teste deve verificar namespace canônico e rejeitar path de outro usuário.

### 6.2 Acesso por papel

Cobrir pelo menos:

- usuário ativo vinculado à empresa;
- administrador da empresa;
- administrador primário;
- gestor/manager do projeto;
- colaborador ativo do projeto;
- colaborador convidado ou inativo;
- cliente pendente;
- cliente aceito;
- empresa convidada pendente;
- empresa convidada aceita;
- empresa de outra organização;
- usuário sem empresa.

O usuário comum pode criar projeto conforme as regras atuais, mas a autorização real deve ser verificada no banco/RPC e não na UI.

### 6.3 Cliente e empresa no projeto

Testar convites, aceite, recusa, remoção e transferência de gerenciamento:

- cliente existente convidado;
- cliente novo cadastrado na criação;
- cliente pendente sem acesso prematuro;
- aceite/recusa pelo cliente;
- empresa convidada;
- resposta pela empresa convidada;
- projeto inexistente ou de outra empresa;
- transferência de gestão;
- tentativa de transferência por não administrador;
- notificações e marcação como lidas.

Os RPCs relevantes incluem `invite_project_client`, `respond_to_project_client_invite`, `remove_project_client`, `invite_project_company`, `set_project_company_invite_status`/legado `respond_to_project_company_invite`, `transfer_project_management` e `list_company_clients`.

### 6.4 Equipe interna

Testar:

- listar candidatos;
- adicionar membro;
- ativar/desativar membro;
- alterar gestor;
- impedir membro de outra empresa;
- impedir usuário sem vínculo ativo;
- preservar o invariante de um gestor válido;
- impedir escalada de privilégios;
- respeitar limite de usuários do plano, contando perfis vinculados, convidados e inativos conforme a regra atual.

## 7. Empresa, serviços e catálogo público

Há dois conceitos que não devem ser confundidos:

1. `Minha empresa` e painel administrativo da empresa.
2. Descoberta pública de empresas, serviços e produtos.

Cobrir:

- edição de nome, dados e endereço;
- upload de logo e capa;
- CRUD de serviços;
- galeria de serviços;
- anexos e links externos;
- categorias de inspeção, intervenção, produtos e equipamentos;
- filtros de empresas e serviços;
- paginação, busca e ordenação;
- detalhe público de empresa;
- detalhe de serviço;
- ausência de vazamento de campos privados;
- acesso anônimo versus usuário autenticado;
- escrita apenas por administrador autorizado.

RPCs públicos relevantes:

- `get_public_company`;
- `list_public_companies`;
- `list_public_company_services`;
- `list_public_service_gallery`.

Esses RPCs são `SECURITY DEFINER` e devem ser testados quanto a ACL, `search_path`, limite de paginação, filtragem de campos e ausência de exposição para `public`/`anon` quando isso não for intencional.

## 8. Estruturas, locais, plantas e elementos

### 8.1 Estruturas

Fluxo:

1. Selecionar um projeto.
2. Criar estrutura.
3. Vincular em `projeto_estruturas`.
4. Adicionar local, tipologia e condição.
5. Adicionar plantas.
6. Editar, transferir ou excluir.

O repositório de estruturas cria a estrutura e o vínculo do projeto. A exclusão depende de cascatas para elementos, ensaios, vínculos e locais/plantas. O teste deve validar a cascata no banco descartável.

Uploads observados:

- imagens de estrutura no bucket `projetos`, sob `estruturas/...`;
- plantas no bucket `estruturas`, sob `plantas/...`.

Há histórico de caminhos legados/públicos. O executor deve verificar o comportamento atual, documentar o contrato canônico e garantir que o teste não seja enganado por um arquivo público.

### 8.2 Elementos

Testar CRUD, ativação/desativação, exclusão, catálogos e imagens:

- `elementos_estruturais`;
- fotos em `elementos-fotos/<elementoId>/...`;
- marcação de planta em `<elementoId>/marcacao-planta.png`;
- download, substituição com upsert e remoção da marcação;
- limpeza de `planta_id`, posições e URL ao remover marcação;
- catálogos `tipos_elemento`, `tipologias_elemento`, `revestimentos_elemento`;
- escopo por empresa;
- tentativa de usar catálogo de outra empresa;
- nomes vazios, duplicidade e cancelamento de imagem.

### 8.3 Planejamento e regiões

As regiões precisam de `plantaId`, `projetoId` e `empresaId`. A UI deve carregar explicitamente o projeto através dos filtros/modais.

Criar e atualizar região e contratos deve passar pelo RPC atômico `save_region_with_contracts`.

Testar:

- região sem projeto;
- região de outra estrutura/projeto;
- contrato duplicado;
- falha no meio da operação;
- rollback completo;
- reabertura da tela preservando o escopo correto;
- PDF/imagem de planta;
- estados mockados e botões ainda sem implementação.

## 9. Ensaios e inspeção visual

O app possui sete famílias principais de ensaio:

1. Carbonatação.
2. Resistividade elétrica superficial.
3. Arrancamento em argamassa.
4. Arrancamento em placa cerâmica.
5. Potencial de corrosão.
6. Prova de carga estática.
7. Esclerometria.

Cada fluxo deve ser testado em três níveis:

- formulário e validação Flutter;
- persistência de raiz, filhos, leituras, galerias e exclusão;
- análise, gráficos, relatório, Storage e permissões.

### 9.1 Cadeia geral

As tabelas gerais incluem:

- `ensaios_contratados`;
- `regioes_ensaio`;
- `pontos_ensaios_geral`;
- `relatorio_ensaio`;
- `galeria_pontos_ensaios_geral`;
- `tipos_ensaio`.

O teste deve conferir que o ponto é associado ao projeto, estrutura, elemento/local e empresa corretos, sem depender apenas de IDs fornecidos pela UI.

### 9.2 Carbonatação

Entidades específicas:

- `ponto_ensaio_carb`;
- `ponto_ensaio_carb_frentes`;
- `galeria_ponto_ensaio_carb`.

Cobrir capas, braços P/S, frentes, profundidades, fotos de quebra/aspersão e cálculo de idade, cobrimento, médias, coeficiente e risco.

Faixas observadas:

- `delta <= 0`: Despassivado;
- `< 5`: Risco Alto;
- `< 15`: Risco Moderado;
- `< 30`: Risco Baixo;
- caso contrário: Risco Irrelevante.

Uploads usam `projetos`, sob `ensaios/carbonatacao/...`.

### 9.3 Resistividade

Entidades:

- `ponto_ensaio_resistividade_leitura`;
- `galeria_ponto_ensaio_resistividade`.

Testar grade, linha/coluna, valores, resultado/cor, quatro referências de fotos, agrupamento e estatística. Uploads usam `ensaios/resistividade/...`.

### 9.4 Arrancamento

Há fluxos para argamassa e cerâmica, com tabelas de arrancamento, leituras, rupturas e galeria. Cobrir área, carga, tensão, percentuais de ruptura, imagens, cálculo e exclusão completa.

Uploads observados:

- `ensaios/arrancamento/...`;
- `ensaios/arrancamento_ceramica/...`.

### 9.5 Potencial de corrosão

Entidades:

- `ponto_ensaio_potencial`;
- `ponto_ensaio_potencial_leitura`.

Testar grade, linha, coluna, potencial em mV, eletrodo, saturação, temperatura, espaçamento, marcadores, fotos, análise e heatmap.

O mapa de calor pode chamar a API Python. O executor deve localizar a URL/configuração real no código e testar:

- token ausente;
- leituras vazias;
- ponto não autorizado;
- geração válida;
- falha de upload;
- limpeza após erro;
- atualização de `imagem_mapa_calor`.

### 9.6 Prova de carga

Fluxo em duas fases:

1. Criar área/ensaio.
2. Criar pontos de medição e leituras.

Entidades:

- `ponto_ensaio_prova_carga`;
- `ponto_ensaio_prova_carga_ponto_medicao`;
- `ponto_ensaio_prova_carga_ponto_leitura`;
- galeria geral.

Testar o comportamento quando o ensaio não está diretamente associado a elemento, a composição da imagem da planta, uploads e análise direta.

### 9.7 Esclerometria

Entidades:

- `ponto_ensaio_esclerometria`;
- `ponto_ensaio_esclerometria_leituras`;
- galeria geral.

Testar inclinação/direção, índice K, leituras aceitas/rejeitadas, janela, fotos, análise e exclusão.

### 9.8 Inspeção visual

Cadeia de dados:

`ponto_inspecao_visual` -> `ponto_inspecao_visual_geral` -> `pontos_ensaios_geral`

Tabelas adicionais:

- `ponto_inspecao_regiao`;
- `ponto_inspecao_visual_anomalia`;
- `ponto_inspecao_visual_galeria`.

O payload precisa carregar `id_projeto`, `id_estrutura` e `id_ponto_geral`. O RLS depende dessa cadeia. Cobrir local/elemento/tipo, catálogo de anomalias, risco GUT, marcação em imagem, galeria, remoção e autorização.

## 10. Relatórios

Telas e serviços de relatório aparecem em várias áreas. Algumas são reais; outras são estáticas ou têm fallback mockado.

O relatório de carbonatação gera HTML/CSS, usa QuickChart, converte para PDF, envia ao Storage, baixa e abre o arquivo.

Testar:

- dados incompletos;
- relatório sem ensaio;
- geração em modo headless;
- timeout de QuickChart;
- falha de conversão;
- upload/remoção do PDF;
- acesso somente ao projeto autorizado;
- reabertura e download;
- nomes de arquivo e caminhos;
- ausência de arquivos órfãos.

O executor deve diferenciar:

- relatório realmente persistido e gerado;
- relatório apenas visual/mock;
- botão ainda sem implementação;
- fallback `_mockReports`.

## 11. Feed, educação e notificações

Feed:

- `feed_posts`;
- `feed_fotos`;
- `feed_likes`;
- `feed_comentarios`.

Testar criação/edição/exclusão do próprio post, múltiplas imagens, likes idempotentes, comentários, contagens, estados vazios e permissão de autor/admin. Imagens usam `avatars/feed`.

Notificações:

- stream de `notificacoes`;
- contagem de não lidas;
- marcação como lida;
- convite de projeto;
- convite de cliente;
- resposta aceitar/recusar;
- campos `dados_extras` como `convite_id`, `projeto_id` e `foto_url`;
- atualização realtime sem duplicar itens.

## 12. Planos, consumo e limites

Testar:

- leitura de `planos`;
- assinatura em `empresa_plano_assinatura`;
- consumo em `empresa_plano_consumo`;
- quantidade de usuários;
- tokens de estrutura;
- contagem de fotos, galerias, relatórios e projetos;
- bloqueio de convite quando excede quota;
- corrida entre dois convites concorrentes;
- backend como fonte de verdade, mesmo se a UI estiver desatualizada.

O RPC `create_invited_profile_if_capacity` deve prevalecer sobre qualquer cálculo visual do Flutter.

## 13. Supabase: migrações, RLS e RPCs

As migrações são incrementais e não formam, sozinhas, um banco inicial completo. O executor deve começar por:

1. introspectar tabelas, colunas, tipos, FKs, índices, triggers, funções, grants, buckets e policies;
2. identificar quais migrações já foram aplicadas;
3. criar um schema descartável ou ambiente local reproduzível;
4. só então montar seeds e testes.

Migrações de segurança relevantes:

- `20260903120000_harden_home_projects_rls.sql`;
- `20260908010000_project_team_access.sql`;
- `20260908020000_project_team_hardening.sql`;
- `20260908031000_project_team_followups.sql`;
- `20260908040000_project_team_followup.sql`;
- `20260909100000_remaining_rls.sql`;
- `20260909105000_enable_preexisting_rls_tables.sql`;
- `20260909110000_regions_rls_backfill_after_sanitation.sql`.

O último backfill de regiões deve falhar fechado quando encontra sete registros históricos ambíguos de `regioes_ensaio` com `projeto_id` nulo; o teste não deve adivinhar o projeto desses registros.

Estado de RLS observado no levantamento:

- intenção de RLS em 74 de 79 tabelas públicas;
- cinco tabelas estruturais ficaram explicitamente sem RLS nas migrações observadas: `estruturas`, `estruturas_locais`, `estruturas_plantas`, `elementos_estruturais`, `projeto_estruturas`;
- um harness local também apontou `tipologias_local` como sexta tabela pública sem RLS; essa discrepância precisa ser verificada contra o banco real;
- `projetos` tem política própria na migração de hardening e não deve ser recriada acidentalmente;
- todas as policies de UPDATE devem ter `USING` e `WITH CHECK` coerentes;
- várias mutações sensíveis foram movidas para RPCs atômicos;
- RPCs `SECURITY DEFINER` precisam de `search_path` fixo, ACL explícito e validação de identidade/empresa/projeto;
- nunca usar `user_metadata` como fonte de autorização;
- `app_metadata` é usado para o onboarding de convite.

RPCs relevantes:

- autenticação/ciclo de vida: `create_company_for_user`, `create_invited_profile_if_capacity`, `promote_admin_before_primary_delete`, `reactivate_user_if_capacity`, `transfer_primary_admin`;
- equipe: `list_project_team_candidates`, `list_project_team_visible`, `set_project_member_manager`, `set_project_member_status`;
- catálogo público: `complete_self_registration`, `get_public_company`, `list_public_companies`, `list_public_company_services`, `list_public_service_gallery`;
- projetos: `create_project`, `update_project`, `delete_project`, `save_region_with_contracts`, `invite_project_client`, `respond_to_project_client_invite`, `remove_project_client`, `transfer_project_management`, `list_company_clients`;
- convite de empresa: `set_project_company_invite_status` e o RPC legado `respond_to_project_company_invite`.

O executor deve testar as funções tanto por chamadas válidas quanto por chamadas forjadas com IDs de outro projeto, outra empresa, usuário inativo, usuário sem perfil, usuário anônimo e usuário sem o papel necessário.

## 14. Edge Functions

### 14.1 `auth-operations`

Arquivo: `supabase/functions/auth-operations/index.ts`.

A função usa Bearer token, valida o usuário com cliente anônimo e só depois usa cliente administrativo no servidor. Ações:

- `create_company`;
- `complete_self_registration`;
- `cleanup_google_orphan`;
- `complete_profile`;
- `manage_collaborator` com `set_admin`, `deactivate`, `reactivate` e `unlink`;
- `transfer_primary_admin`;
- `list_company_colleagues`;
- `list_company_members_admin`.

Testar validação, autenticação, autorização, normalização de CNPJ, status HTTP, rollback de Auth e banco, compensação quando atualização de metadata falha, proibição de autoalteração, proteção do admin primário, quota e isolamento entre empresas.

Mapeamento de erros observado:

- `23505`/`P0001` -> 409;
- `42501` -> 403;
- `P0002` -> 404;
- `22023` -> 400.

### 14.2 `convidar-funcionario`

Arquivo: `supabase/functions/convidar-funcionario/index.ts`.

Entrada obrigatória:

- e-mail;
- nome;
- sobrenome;
- cargo;
- `empresa_id` legado;
- `projeto_id` opcional.

A função:

- exige Bearer;
- valida perfil ativo e administrador;
- confere que `empresa_id` corresponde à empresa do ator;
- valida o projeto, quando informado;
- cria usuário Auth com senha temporária e e-mail confirmado;
- define `app_metadata.onboarding=invite`;
- chama `create_invited_profile_if_capacity`;
- opcionalmente cria `projeto_equipe_interna`;
- faz rollback de Auth/perfil se uma etapa falhar;
- retorna `senhaProvisoria`.

Testar duplicidade, quota, projeto de outra empresa, ator não administrador, cargo inválido, rollback, vazamento da senha temporária em logs e comportamento sob concorrência.

`supabase/config.toml` informa `verify_jwt=true` para essas funções, confirmações de e-mail habilitadas e redirects `diavicon://login-callback` e `diavicon://nova-senha`.

## 15. Storage

Buckets e paths observados no código incluem:

- `avatars`: avatar de usuário, serviços e feed;
- `projetos`: capas, estruturas, ensaios, mapas e relatórios;
- `estruturas`: plantas;
- `elementos-fotos`: fotos de elementos;
- paths especiais de marcação de planta.

O teste deve validar:

- upload autenticado;
- download autenticado;
- update/upsert somente no namespace permitido;
- remoção pelo proprietário autorizado;
- tentativa de ler/escrever path de outro usuário/empresa;
- path traversal e nomes malformados;
- arquivos órfãos em rollback;
- limites de tamanho/extensão;
- existência de imagens e PDFs de fixture;
- se a operação depende indevidamente de URL pública.

Um app de teste não deve receber a `service_role`. Para seed, reset, criação de usuários e limpeza privilegiada, use um harness server-side controlado, uma função administrativa isolada ou um canal SQL de ambiente descartável, com credenciais fora do artefato distribuído.

## 16. API Python de mapa de potencial

Arquivo: `python_api/main.py`.

Endpoint:

`POST /gerar-mapa-calor`

Entrada:

- `linhas`;
- `colunas`;
- `espacamento_x`;
- `espacamento_y`;
- `leituras[]` com `linha`, `coluna`, `potencial_mv`;
- `potencial_id` UUID.

Comportamento observado:

- exige Bearer;
- usa o token do chamador no cliente Supabase, para que PostgREST e Storage respeitem RLS;
- verifica `ponto_ensaio_potencial` antes de consumir CPU/Storage;
- interpola com SciPy cubic e fallback nearest;
- gera PNG transparente com Matplotlib;
- envia para bucket `projetos`, path `mapas/<potencial_id>_<random>.png`;
- atualiza `imagem_mapa_calor`;
- remove upload se uma etapa posterior falhar.

Respostas esperadas:

- 401 sem token ou token vazio;
- 400 sem leituras;
- 403 quando o ponto ou update não é autorizado;
- 500 para configuração/geração.

Testar a API isoladamente e integrada ao Flutter, inclusive timeout, payload inválido, colunas/linhas incompatíveis, token de outro usuário, falha de Storage e limpeza.

## 17. Personas e matriz de autorização

O seed/test harness deve criar usuários Auth e perfis `usuarios` determinísticos para pelo menos:

| Persona | Estado | Empresa | Papel/relacionamento |
|---|---|---|---|
| anônimo | sem sessão | — | nenhuma |
| não confirmado | e-mail não confirmado | — | conta Auth sem acesso ao app |
| sem perfil | confirmado | — | cadastro pendente |
| convidado | ativo/inativo conforme o fluxo | empresa A | onboarding de convite pendente |
| usuário ativo sem empresa | ativo | — | pode iniciar onboarding permitido |
| colaborador | ativo | empresa A | membro ativo de projeto |
| gestor | ativo | empresa A | manager/gestor do projeto |
| admin empresa | ativo | empresa A | `is_admin_empresa` |
| admin primário | ativo | empresa A | proprietário/admin primário |
| cliente pendente | ativo | empresa B ou vínculo de cliente | convite pendente |
| cliente aceito | ativo | empresa B ou vínculo de cliente | acesso aceito |
| empresa convidada | ativo | empresa C | convite de empresa pendente |
| outra empresa | ativo | empresa Z | deve ser isolada |
| inativo | inativo | empresa A | sem mutações protegidas |
| usuário Google órfão | Auth recente | — | candidato a cleanup |

Para cada persona, executar uma matriz de allow/deny para:

- leitura de cada agregado;
- insert/update/delete;
- RPC;
- Edge Function;
- Storage;
- Realtime;
- deep link/navegação Flutter.

O resultado deve registrar não apenas “passou/falhou”, mas também o motivo esperado da decisão de RLS/autorização.

## 18. Seed graph determinístico

Criar fixtures como um grafo coerente de FKs, usando UUIDs fixos e nomes legíveis, por exemplo:

- `company_a`, `company_b`, `company_c`;
- `user_primary_a`, `user_admin_a`, `user_manager_a`, `user_member_a`, `user_inactive_a`;
- `user_client_b`, `user_company_c`;
- `project_a_1`, `project_a_2`;
- convites pendentes/aceitos/recusados;
- notificações correspondentes;
- planos, assinatura, consumo e limites;
- estruturas, locais, plantas, elementos e catálogos;
- ensaios contratados, regiões, pontos e filhos para cada modalidade;
- inspeção visual com a cadeia completa;
- posts, fotos, likes, comentários;
- serviços e galerias públicas;
- fotos, plantas, PDFs e imagens de marcação no Storage.

Não inventar colunas, defaults ou IDs sem consultar o schema real. Como o repositório não tem schema inicial completo, o gerador de seed deve validar as colunas da instalação-alvo e falhar com diagnóstico claro quando houver divergência.

O reset precisa ser determinístico, repetível e limitado ao namespace/ambiente de teste. Idealmente, cada execução terá um `run_id` e fixtures isoladas, permitindo paralelismo sem colisão.

## 19. Camadas de teste desejadas

### 19.1 Testes puros

Cobrir sem Supabase:

- modelos e serialização;
- filtros e ordenação;
- validação de cadastro/CNPJ;
- rotas e redirects seguros;
- cálculo de carbonatação;
- análise de resistividade, potencial, arrancamento, carga e esclerometria;
- manipulação de draft;
- limpeza de paths de imagem;
- estados de formulário;
- mapeamento de ensaio para tela.

### 19.2 Contratos de repositório

Capturar e verificar as operações efetivamente feitas pelo Flutter:

- tabela/coluna/filtro;
- RPC e argumentos;
- chamada de Edge Function;
- upload/download/remove de Storage;
- tratamento de erro e retry;
- invalidação de providers;
- cancelamento e timeout.

Não presumir que todos os acessos passam pelos repositórios: existem providers e telas que acessam o singleton Supabase diretamente.

### 19.3 Widget tests

Para cada tela relevante, testar:

- loading;
- sucesso;
- lista vazia;
- erro;
- validação;
- retry;
- permissões/visibilidade;
- upload e cancelamento;
- navegação após sucesso;
- mensagens de erro e confirmação;
- callbacks ainda sem implementação.

Usar fakes para câmera, picker, geolocalização, mapas, URLs externas, abertura de PDF, Google Sign-In, relógio, UUID e aleatoriedade.

### 19.4 Integration/e2e

Criar cenários por persona, preferencialmente headless:

1. cadastro pessoal;
2. confirmação e login;
3. criação de empresa;
4. convite de funcionário;
5. criação de projeto;
6. convite/aceite de cliente e empresa;
7. equipe e gestor;
8. estrutura, local, planta e elemento;
9. um ensaio de cada uma das sete modalidades;
10. inspeção visual;
11. relatório/mapa de potencial;
12. notificações e feed;
13. plano/quota;
14. logout, conta inativa e recuperação.

O cenário completo deve poder parar em cada etapa, inspecionar o banco/Storage e continuar após reset ou retomada.

### 19.5 Supabase/DB

Executar contra banco local/descartável ou projeto de staging:

- aplicação de migrações;
- introspecção de schema;
- testes de cada policy relevante;
- testes de RPC com sessão real;
- testes de transação/rollback;
- testes de concorrência e lock order;
- testes de grants e `SECURITY DEFINER`;
- testes de Storage;
- testes de Realtime;
- testes de Edge Functions;
- testes negativos por usuário/empresa/projeto.

## 20. Observabilidade e evidências

Cada cenário deve produzir, quando aplicável:

- nome do cenário e persona;
- precondições/fixture IDs;
- ações executadas;
- resultado visual Flutter;
- tabela/RPC/Function/Storage chamado;
- resposta/status/erro;
- snapshot das linhas relevantes antes/depois;
- decisão de autorização esperada e observada;
- arquivos criados/removidos;
- eventos Realtime recebidos;
- screenshot ou vídeo na falha;
- logs correlacionados por `run_id`;
- classificação: `implemented`, `partial`, `mocked`, `blocked` ou `not implemented`.

Erros devem ser classificados como:

- bug do produto;
- bug da plataforma de testes;
- fixture inválida;
- ambiente indisponível;
- comportamento deliberadamente não implementado;
- divergência de contrato/schema;
- violação de segurança.

## 21. Lacunas e falsos positivos conhecidos

O executor deve tratar explicitamente como lacunas, não como casos verdes:

- `README.md` sem documentação real;
- RDO e algumas telas de relatório/visualização estáticas ou mockadas;
- `lib/features/services/ensaios_mock_service.dart` usado por `novo_rdo_screen.dart`;
- `_BuscaMock` em seleção de planta e planejamento;
- fallback `_mockReports` em relatórios;
- botões sem ação em painéis de empresa, planejamento, inspeção visual, modais de estrutura e telas de RDO/relatório;
- `solicitacao_acesso_body.dart` com TODO para solicitar acesso;
- `tabela_interativa.dart` com mock de inserção para teste visual;
- mapeamento geral sem `getAnaliseScreen` para prova de carga e esclerometria, que possuem telas diretas;
- análise estática com problemas legados;
- ausência de uma suíte real de widget/integration/E2E no estado atual;
- discrepância de RLS em `tipologias_local` versus o grupo estrutural declarado;
- sete regiões históricas ambíguas não saneadas;
- incerteza sobre o estado remoto atual.

O relatório da plataforma deve mostrar cobertura funcional real e cobertura simulada separadamente.

## 22. Decisões que o modelo executor precisa tomar ou pedir

Antes da implementação, resolver:

- o ambiente-alvo é Supabase local, staging descartável, ou ambos;
- o projeto remoto citado é produção, staging ou apenas histórico;
- haverá testes reais de e-mail ou um mail catcher;
- Google Sign-In será fake em CI e real apenas em smoke manual;
- plataformas alvo: Android, iOS, Web, Windows, macOS;
- execução headless e dispositivos disponíveis;
- o escopo inclui RDO/relatórios mockados ou apenas fluxos efetivos;
- como gerar fixtures binárias de imagem/PDF;
- se Realtime precisa ser validado de forma real ou por contrato;
- estratégia de isolamento/concurrency por `run_id`;
- canal seguro para seed/reset privilegiado;
- política de retenção dos dados de teste;
- formato do relatório (JUnit, JSON, HTML, screenshots, vídeo);
- quais mudanças de testabilidade no app serão aceitas.

Se uma decisão mudar segurança, dados remotos, custo ou comportamento do produto, o executor deve parar e pedir confirmação em vez de assumir.

## 23. Critérios de aceitação da futura plataforma

A implementação futura estará pronta quando, no mínimo:

- um comando documentado subir ou selecionar o ambiente de teste;
- seeds determinísticos criarem todas as personas e dependências;
- reset/cleanup funcionar sem atingir produção;
- houver execução seletiva por fluxo, persona e camada;
- o smoke test completo conseguir atravessar autenticação, empresa, projeto, estrutura, elemento e todos os sete ensaios;
- a matriz de RLS validar allow/deny para as personas críticas;
- Edge Functions e API Python forem testadas com sucesso e falhas;
- Storage e Realtime tiverem cobertura própria;
- nenhum segredo privilegiado entrar no Flutter, fixtures distribuídas ou logs;
- testes rodarem headless e gerarem artefatos CI;
- falhas mostrarem evidência suficiente para reproduzir;
- fluxos mockados/stubados aparecerem como tal;
- o relatório separar falha de produto, falha de teste, ambiente e funcionalidade ausente;
- o executor validar o banco real antes de aplicar qualquer premissa derivada do histórico.

## 24. Prompt pronto para o modelo executor

Você é responsável por projetar e, após aprovação, implementar uma plataforma de testes para o aplicativo Flutter Diavicon e seu backend Supabase. Use o arquivo `CONTEXT_GATHERING_TEST_PLATFORM.md` como contexto inicial, mas trate o código e o schema introspectado como fonte de verdade.

Comece com uma auditoria do repositório e do ambiente. Não implemente ainda. Entregue:

1. arquitetura proposta da plataforma;
2. escolha entre mocks, Supabase local, staging e E2E real;
3. mapa de dependências e costuras de testabilidade necessárias;
4. modelo de seed/reset isolado;
5. matriz de personas e autorização;
6. inventário de fluxos `implemented`, `partial`, `mocked` e `not implemented`;
7. plano de execução por fases;
8. riscos, pré-requisitos e decisões que exigem confirmação;
9. comandos de execução e formato dos artefatos;
10. estimativa de cobertura por camada.

Depois de receber autorização para implementar, siga estas regras:

- não use `service_role` no Flutter nem em artefato cliente;
- não use produção como default;
- não confie em `user_metadata` para autorização;
- não invente schema, FK, coluna ou UUID;
- faça seed através de um canal server-side isolado;
- teste RLS, RPC, Edge Functions, Storage e Realtime com sessões que representem as personas;
- preserve rollback, locks, limites de quota e namespaces de arquivos;
- injete ou adapte Supabase, HTTP, Storage, tempo, UUID, pickers, mapas, Google Sign-In e abertura de arquivos;
- registre evidência de cada fluxo;
- não marque UI mockada como E2E aprovado;
- valide com testes proporcionais e explique toda mudança feita no aplicativo.

O primeiro resultado esperado não é código: é uma proposta técnica executável, baseada em evidências do repositório, com as decisões abertas claramente listadas.

## 25. Arquivos de referência mais importantes

- `C:\diaviconCurrent\diavicon\lib\main.dart`
- `C:\diaviconCurrent\diavicon\lib\app.dart`
- `C:\diaviconCurrent\diavicon\lib\core\providers\supabase_provider.dart`
- `C:\diaviconCurrent\diavicon\lib\routes\app_router.dart`
- `C:\diaviconCurrent\diavicon\lib\routes\app_routes.dart`
- `C:\diaviconCurrent\diavicon\lib\features\auth\providers\auth_provider.dart`
- `C:\diaviconCurrent\diavicon\lib\features\auth\controller\auth_controller.dart`
- `C:\diaviconCurrent\diavicon\lib\features\auth\repositories\auth_repository.dart`
- `C:\diaviconCurrent\diavicon\lib\features\projetos\repositories\project_repository.dart`
- `C:\diaviconCurrent\diavicon\supabase\functions\auth-operations\index.ts`
- `C:\diaviconCurrent\diavicon\supabase\functions\convidar-funcionario\index.ts`
- `C:\diaviconCurrent\diavicon\supabase\migrations\20260903120000_harden_home_projects_rls.sql`
- `C:\diaviconCurrent\diavicon\supabase\migrations\20260909100000_remaining_rls.sql`
- `C:\diaviconCurrent\diavicon\python_api\main.py`
- `C:\diaviconCurrent\diavicon\test\routes\app_route_guard_test.dart`
- `C:\diaviconCurrent\diavicon\test\routes\app_routes_test.dart`
- `C:\diaviconCurrent\diavicon\test\supabase\home_projects_rls_contract_test.dart`
- `C:\diaviconCurrent\diavicon\test\supabase\remaining_rls_contract_test.dart`
- `C:\diaviconCurrent\diavicon\state.md`

