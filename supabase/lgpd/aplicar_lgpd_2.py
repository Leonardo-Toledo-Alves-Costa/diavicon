#!/usr/bin/env python3
"""Segunda etapa: rotas, gate de consentimento, pubspec, modelo e edge function.

Uso: python3 aplicar_lgpd_2.py <raiz_do_repo> [--web]
"""
import os
import re
import sys

RAIZ = sys.argv[1]
WEB = '--web' in sys.argv
erros = []


def ler(rel):
    p = os.path.join(RAIZ, rel)
    t = open(p, 'rb').read().decode('utf-8')
    return p, t.replace('\r\n', '\n'), '\r\n' in t


def gravar(p, t, crlf):
    open(p, 'wb').write((t.replace('\n', '\r\n') if crlf else t).encode('utf-8'))


def trocar(rel, antigo, novo, obrigatorio=True, contar=1):
    p, t, crlf = ler(rel)
    if novo in t and antigo not in t:
        print(f'{rel}: já aplicado')
        return
    n = t.count(antigo)
    if n != contar:
        (erros.append if obrigatorio else print)(f'{rel}: esperado {contar} ocorrência(s), achei {n}: {antigo[:60]!r}')
        return
    gravar(p, t.replace(antigo, novo), crlf)
    print(f'{rel}: ok')


# -- imports http que ficaram sem uso depois da primeira etapa ---------------
for base, _, arqs in os.walk(os.path.join(RAIZ, 'lib')):
    for nome in arqs:
        if not nome.endswith('.dart'):
            continue
        p = os.path.join(base, nome)
        t = open(p, 'rb').read().decode('utf-8')
        crlf = '\r\n' in t
        t = t.replace('\r\n', '\n')
        m = re.search(r"^import 'package:http/http\.dart' as http;\n", t, re.M)
        if m and 'StorageUrls.' in t and not re.search(r'\bhttp\.', t[:m.start()] + t[m.end():]):
            t = t[:m.start()] + t[m.end():]
            gravar(p, t, crlf)
            print(os.path.relpath(p, RAIZ), ': import http removido (sem uso)')

# -- pubspec: assets legais ----------------------------------------------------
trocar('pubspec.yaml', '    - assets/config.env\n', '    - assets/config.env\n    - assets/legal/\n')

# -- modelo: e-mail sai do UPDATE do perfil (troca de e-mail é pelo Auth) -----
trocar('lib/features/auth/models/usuario_model.dart',
       "      'email': email,\n      'celular': celular,",
       "      // 'email' fica de fora: o banco não aceita mais UPDATE direto nessa\n"
       "      // coluna (migração 20260921130000). E-mail muda pelo Supabase Auth.\n"
       "      'celular': celular,")

# -- logout limpa os links assinados em memória --------------------------------
trocar('lib/features/auth/controller/auth_controller.dart',
       "    await repo.signOut();\n    _ref.read(currentUserProvider.notifier).clearUser();",
       "    await repo.signOut();\n    StorageUrls.limparCache();\n    _ref.read(currentUserProvider.notifier).clearUser();")
p, t, crlf = ler('lib/features/auth/controller/auth_controller.dart')
if "storage_urls.dart" not in t:
    t = "import 'package:diavicon/core/services/storage_urls.dart';\n" + t
    gravar(p, t, crlf)

# -- rotas públicas /privacidade e /termos ------------------------------------
trocar('lib/routes/app_routes.dart',
       "  static const welcome = 'welcome';\n  static const login = 'login';\n",
       "  static const welcome = 'welcome';\n  static const login = 'login';\n"
       "  static const privacyPolicy = 'privacy-policy';\n  static const termsOfUse = 'terms-of-use';\n")
trocar('lib/routes/app_routes.dart',
       "  static const welcome = '/';\n  static const login = '/login';\n",
       "  static const welcome = '/';\n  static const login = '/login';\n"
       "  static const privacyPolicy = '/privacidade';\n  static const termsOfUse = '/termos';\n\n"
       "  /// Páginas legais: abertas para qualquer um, logado ou não.\n"
       "  static bool isLegal(String path) => path == privacyPolicy || path == termsOfUse;\n")

trocar('lib/routes/app_route_guard.dart',
       "bool _isPublicPath(String path) {\n  return path == AppPaths.welcome ||",
       "bool _isPublicPath(String path) {\n  return AppPaths.isLegal(path) ||\n      path == AppPaths.welcome ||")

trocar('lib/routes/app_router.dart',
       "      final path = state.uri.path;\n      final usuario = ref.read(currentUserProvider);",
       "      final path = state.uri.path;\n"
       "      // Política e Termos abrem em qualquer estado (lojas e rodapé do site).\n"
       "      if (AppPaths.isLegal(path)) return null;\n"
       "      final usuario = ref.read(currentUserProvider);")
trocar('lib/routes/app_router.dart',
       "      GoRoute(\n        path: AppPaths.login,\n        name: AppRouteNames.login,\n        builder: (context, state) => const LoginScreen(),\n      ),\n",
       "      GoRoute(\n        path: AppPaths.login,\n        name: AppRouteNames.login,\n        builder: (context, state) => const LoginScreen(),\n      ),\n"
       "      GoRoute(\n        path: AppPaths.privacyPolicy,\n        name: AppRouteNames.privacyPolicy,\n"
       "        builder: (context, state) => const DocumentoLegalScreen(documento: DocumentoLegal.privacidade),\n      ),\n"
       "      GoRoute(\n        path: AppPaths.termsOfUse,\n        name: AppRouteNames.termsOfUse,\n"
       "        builder: (context, state) => const DocumentoLegalScreen(documento: DocumentoLegal.termos),\n      ),\n")
p, t, crlf = ler('lib/routes/app_router.dart')
if 'documento_legal_screen.dart' not in t:
    t = ("import 'package:diavicon/features/legal/documentos_legais.dart';\n"
         "import 'package:diavicon/features/legal/screens/documento_legal_screen.dart';\n") + t
    gravar(p, t, crlf)

# -- app.dart: gate de consentimento (e, no web, rodapé + aviso de cookies) ----
if not WEB:
    trocar('lib/app.dart',
           "      routerConfig: router,\n      theme: theme,\n    );",
           "      routerConfig: router,\n      theme: theme,\n"
           "      // Aceite dos Termos e da Política (LGPD) antes de usar o app.\n"
           "      builder: (context, child) => ConsentimentoGate(child: child ?? const SizedBox.shrink()),\n    );")
    p, t, crlf = ler('lib/app.dart')
    if 'consentimento_gate.dart' not in t:
        t = t.replace("import 'routes/app_router.dart';", "import 'features/legal/consentimento_gate.dart';\nimport 'routes/app_router.dart';", 1)
        gravar(p, t, crlf)

# -- edge function auth-operations ---------------------------------------------
EDGE = 'supabase/functions/auth-operations/index.ts'
if os.path.exists(os.path.join(RAIZ, EDGE)):
    novas = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'edge_novas_funcoes.ts'), encoding='utf-8').read().replace('\r\n', '\n')
    p, t, crlf = ler(EDGE)
    if 'async function deleteOwnAccount' not in t:
        t = t.replace('Deno.serve(async (req) => {', novas + 'Deno.serve(async (req) => {', 1)
        t = t.replace(
            "    if (action === 'delete_own_company') return await deleteOwnCompany(auth.user.id, body)\n",
            "    if (action === 'delete_own_company') return await deleteOwnCompany(auth.user.id, body)\n"
            "    if (action === 'delete_own_account') return await deleteOwnAccount(auth.user.id, body)\n", 1)
        # delete_permanently: fotos/publicações pessoais + auditoria
        antigo = ("      const { error: authError } = await admin.auth.admin.deleteUser(targetId)\n"
                  "      if (authError) throw authError\n")
        novo = ("      await admin.rpc('preparar_exclusao_conta', { p_usuario_id: targetId })\n"
                "      await auditar(admin, userId, 'conta.excluida_pelo_administrador', 'usuarios', targetId, companyId)\n"
                "      const { error: authError } = await admin.auth.admin.deleteUser(targetId)\n"
                "      if (authError) throw authError\n")
        if t.count(antigo) == 1:
            t = t.replace(antigo, novo)
            t = t.replace("      if (deleteRowError) throw deleteRowError\n\n      return jsonResponse(200, { sucesso: true })",
                          "      if (deleteRowError) throw deleteRowError\n\n      await esvaziarFilaDeArquivos(admin)\n      return jsonResponse(200, { sucesso: true })", 1)
        else:
            erros.append(f'{EDGE}: trecho de delete_permanently não encontrado')
        gravar(p, t, crlf)
        print(EDGE, ': ok')
    else:
        print(EDGE, ': já aplicado')

for e in erros:
    print('ERRO:', e)
