import 'package:diavicon/features/auth/screens/cadastro0_cliente.dart';
import 'package:diavicon/features/auth/screens/cadastro1_cliente.dart';
import 'package:diavicon/features/auth/screens/cadastro2_cliente.dart';
import 'package:diavicon/features/auth/screens/cadastro3_cliente.dart';
import 'package:diavicon/features/auth/screens/completar_cadastro_screen.dart';
import 'package:diavicon/features/auth/screens/empresa_bemvinda_screen.dart';
import 'package:diavicon/features/auth/screens/empresa_cadastro_screen.dart';
import 'package:diavicon/features/elementos/screens/elementos_home_screen.dart';
import 'package:diavicon/features/elementos/screens/info_elementos_screen.dart';
import 'package:diavicon/features/elementos/screens/relatorios_screen.dart';
import 'package:diavicon/features/empresa/screens/empresa_screen.dart';
import 'package:diavicon/features/home/screens/perfil_central_ajuda_screen.dart';
import 'package:diavicon/features/home/screens/perfil_minha_conta_screen.dart';
import 'package:diavicon/features/home/screens/perfil_minha_privacidade_screen.dart';
import 'package:diavicon/features/home/screens/perfil_notificacoes_screen.dart';
import 'package:diavicon/features/home/screens/perfil_dados_screen.dart';
import 'package:diavicon/features/notificacoes/screens/notificacoes_screen.dart';
import 'package:diavicon/features/projetos/controllers/clientes_projeto_controller.dart';
import 'package:diavicon/features/projetos/controllers/convites_projeto_controller.dart';
import 'package:diavicon/features/projetos/screens/project_companies_screen.dart';
import 'package:diavicon/features/projetos/screens/project_info_screen.dart';
import 'package:diavicon/features/projetos/widgets/new_project_body.dart';
import 'package:diavicon/features/projetos/providers/projeto_form_provider.dart';
import 'package:diavicon/core/utils/diavicon_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:diavicon/features/estrutura/screens/estruturas_tab_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/cadastro_r0_screen.dart';
import '../../features/auth/screens/cadastro_r1_screen.dart';
import '../../features/auth/screens/cadastro_r2_screen.dart';
import '../../features/auth/screens/cadastro_academico_screen.dart';
import '../../features/auth/screens/recupera_senha_screen.dart';
import '../../features/auth/screens/nova_senha_screen.dart';

import '../../features/auth/screens/cadastro0_empresa.dart';
import '../../features/auth/screens/cadastro1_empresa.dart';
import '../../features/auth/screens/cadastro2_empresa.dart';
import '../../features/auth/screens/cadastro3_empresa.dart';

// ── Elementos Estruturais ─────────────────────────────────────────────────────
import '../../features/home/screens/main_screen.dart';
import '../../features/projetos/screens/projetos_screen.dart';
import '../../features/projetos/screens/project_detail_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'app_route_guard.dart';
import 'app_routes.dart';

// ── feed empresas produtos ─────────────────────────────────────────────────────

import '../../features/feed_educacao/screens/feed_screen.dart';

Map<String, dynamic> _routeExtra(Object? extra) {
  if (extra is Map<String, dynamic>) return extra;
  if (extra is Map) {
    return extra.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

String? _stringExtra(Map<String, dynamic> extra, String key) {
  final value = extra[key];
  if (value is! String || value.trim().isEmpty) return null;
  return value;
}

String? _elementoTipo(Map<String, dynamic> extra) {
  final tipo = _stringExtra(extra, 'tipo');
  if (tipo == null || tipo.trim().isEmpty) return null;
  return tipo.split('-').first.trim();
}

String? _elementoTipologia(Map<String, dynamic> extra) {
  final tipo = _stringExtra(extra, 'tipo');
  if (tipo == null || !tipo.contains('-')) return null;
  return tipo.split('-').skip(1).join('-').trim();
}

final routerProvider = Provider<GoRouter>((ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final shellNavigatorKey = GlobalKey<NavigatorState>();

  final routerAlarme = ValueNotifier<bool>(false);

  // Se o Riverpod mudar, recarrega as rotas
  ref.listen(currentUserProvider, (previous, next) {
    routerAlarme.value = !routerAlarme.value;
  });
  ref.listen(bloqueioDeRotaProvider, (previous, next) {
    routerAlarme.value = !routerAlarme.value;
  });

  late final GoRouter router;
  router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppPaths.welcome,
    refreshListenable: routerAlarme,

    redirect: (context, state) {
      final usuario = ref.read(currentUserProvider);
      final hasAuthSession =
          Supabase.instance.client.auth.currentSession != null;
      return appRouteRedirect(
        path: state.uri.path,
        requestedLocation: state.uri.toString(),
        auth: AppRouteGuardState(
          isLoggedIn: hasAuthSession,
          isActive: usuario?.ativo ?? false,
          hasCompany: usuario?.empresaId != null,
          isTemporarilySuspended: ref.read(bloqueioDeRotaProvider),
        ),
      );
    },
    errorBuilder: (context, state) => _RouterErrorScreen(error: state.error),

    routes: [
      // --- ROTAS PÚBLICAS / AUTH ---
      GoRoute(
        path: AppPaths.welcome,
        name: AppRouteNames.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppPaths.login,
        name: AppRouteNames.login,
        builder: (context, state) => LoginScreen(
          redirectLocation: AppPaths.postLoginRedirect(state.uri),
        ),
      ),
      GoRoute(
        path: AppPaths.profiles,
        name: AppRouteNames.profiles,
        redirect: (context, state) =>
            state.uri.path == AppPaths.profiles ? AppPaths.profileData : null,
        builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
        routes: [
          GoRoute(
            path: 'perfil_dados',
            name: AppRouteNames.profileData,
            builder: (context, state) =>
                PerfilScreen(dadosCadastro: _routeExtra(state.extra)),
          ),
          GoRoute(
            path: 'perfil_minha_conta',
            name: AppRouteNames.profileAccount,
            builder: (context, state) =>
                PerfilMinhaConta(dadosCadastro: _routeExtra(state.extra)),
          ),
          GoRoute(
            path: 'perfil_notificacoes',
            name: AppRouteNames.profileNotifications,
            builder: (context, state) => const PerfilNotificacoes(),
          ),
          GoRoute(
            path: 'perfil_privacidade',
            name: AppRouteNames.profilePrivacy,
            builder: (context, state) => const PerfilMinhaPrivacidade(),
          ),
          GoRoute(
            path: 'perfil_central_ajuda',
            name: AppRouteNames.profileHelp,
            builder: (context, state) => const PerfilCentralAjuda(),
          ),
        ],
      ),
      // --- FLUXO DE CADASTRO ACADÊMICO E CLIENTE ---
      GoRoute(
        path: AppPaths.register,
        name: AppRouteNames.register,
        builder: (context, state) => const CadastroR0Screen(),
        routes: [
          GoRoute(
            path: 'dados',
            name: AppRouteNames.registerData,
            builder: (context, state) =>
                CadastroR1Screen(dadosCadastro: _routeExtra(state.extra)),
          ),
          GoRoute(
            path: 'perfil',
            name: AppRouteNames.registerProfile,
            builder: (context, state) =>
                CadastroR2Screen(dadosCadastro: _routeExtra(state.extra)),
          ),
          GoRoute(
            path: 'academico',
            name: AppRouteNames.registerAcademic,
            builder: (context, state) => CadastroAcademicoScreen(
              dadosCadastro: _routeExtra(state.extra),
            ),
          ),
          GoRoute(
            path: 'cliente/gate',
            name: AppRouteNames.registerClientGate,
            builder: (context, state) =>
                Cadastro0Cliente(dadosUsuario: _routeExtra(state.extra)),
          ),
          GoRoute(
            path: 'cliente/checkboxes',
            name: AppRouteNames.registerClientCheckboxes,
            builder: (context, state) =>
                Cadastro1Cliente(dadosUsuario: _routeExtra(state.extra)),
          ),
          GoRoute(
            path: 'cliente/planos',
            name: AppRouteNames.registerClientPlans,
            builder: (context, state) =>
                Cadastro2Cliente(dadosUsuario: _routeExtra(state.extra)),
          ),
          // Mantido caso precise de fallback, mas o fluxo normal agora pula pro /empresa/cadastro
          GoRoute(
            path: 'cliente/welcome',
            name: AppRouteNames.registerClientWelcome,
            builder: (context, state) =>
                Cadastro3Cliente(dadosUsuario: _routeExtra(state.extra)),
          ),
        ],
      ),

      // --- FLUXO DE ONBOARDING EMPRESA (FORA DO SHELL) ---
      GoRoute(
        path: AppPaths.companyGate,
        name: AppRouteNames.companyGate,
        builder: (context, state) =>
            Cadastro0Empresa(dadosCadastro: _routeExtra(state.extra)),
      ),
      GoRoute(
        path: AppPaths.companyOnboarding,
        name: AppRouteNames.companyOnboarding,
        builder: (context, state) =>
            Cadastro1Empresa(dadosCadastro: _routeExtra(state.extra)),
      ),
      GoRoute(
        path: AppPaths.recoverPassword,
        name: AppRouteNames.recoverPassword,
        builder: (context, state) => const RecuperaSenhaScreen(),
      ),
      GoRoute(
        path: AppPaths.newPassword,
        name: AppRouteNames.newPassword,
        builder: (context, state) => const NovaSenhaScreen(),
      ),
      GoRoute(
        path: AppPaths.companyServices,
        name: AppRouteNames.companyServices,
        builder: (context, state) =>
            Cadastro2Empresa(dadosUsuario: _routeExtra(state.extra)),
      ),
      GoRoute(
        path: AppPaths.companyPlans,
        name: AppRouteNames.companyPlans,
        builder: (context, state) =>
            Cadastro3Empresa(dadosUsuario: _routeExtra(state.extra)),
      ),
      GoRoute(
        path: AppPaths.companyRegistration,
        name: AppRouteNames.companyRegistration,
        builder: (context, state) {
          // LÊ OS DADOS DA MEMÓRIA DO RIVERPOD
          final dadosSalvos = ref.read(rascunhoCadastroProvider);
          return EmpresaCadastroScreen(dadosUsuario: dadosSalvos);
        },
      ),
      GoRoute(
        path: AppPaths.companyWelcome,
        name: AppRouteNames.companyWelcome,
        builder: (context, state) =>
            EmpresaBemVindaScreen(dadosUsuario: _routeExtra(state.extra)),
      ),
      GoRoute(
        path: AppPaths.completeRegistration,
        name: AppRouteNames.completeRegistration,
        builder: (context, state) => const CompletarCadastroScreen(),
      ),

      // --- ÁREA LOGADA (SHELL ROUTE COM RODAPÉ) ---
      GoRoute(
        path: AppPaths.structuralElementPattern,
        name: AppRouteNames.structuralElement,
        builder: (context, state) {
          final extra = _routeExtra(state.extra);
          return ElementosHomeScreen(
            estruturaId: state.pathParameters[AppPaths.structureIdParameter],
            elementoId: state.pathParameters[AppPaths.elementIdParameter],
            projetoId: _stringExtra(extra, 'projetoId'),
            titulo: _stringExtra(extra, 'titulo'),
            tipo: _stringExtra(extra, 'tipo'),
            local: _stringExtra(extra, 'local'),
            imageUrl: _stringExtra(extra, 'imageUrl'),
            marcacaoImagemUrl: _stringExtra(extra, 'marcacaoImagemUrl'),
          );
        },
        routes: [
          GoRoute(
            path: 'informacoes',
            name: AppRouteNames.structuralElementInfo,
            builder: (context, state) {
              final extra = _routeExtra(state.extra);
              return ElementoInfoScreen(
                initialNome: _stringExtra(extra, 'titulo') ?? 'ABC Corp.',
                initialTipoElemento: _elementoTipo(extra),
                initialTipologiaEstrutural: _elementoTipologia(extra),
                initialLocalElemento: _stringExtra(extra, 'local'),
                initialMarcacaoImagemUrl: _stringExtra(
                  extra,
                  'marcacaoImagemUrl',
                ),
                onOpenRelatorios: () => context.pushNamed(
                  AppRouteNames.structuralElementReports,
                  pathParameters: <String, String>{
                    AppPaths.structureIdParameter:
                        state.pathParameters[AppPaths.structureIdParameter]!,
                    AppPaths.elementIdParameter:
                        state.pathParameters[AppPaths.elementIdParameter]!,
                  },
                  extra: extra,
                ),
              );
            },
          ),
          GoRoute(
            path: 'relatorios',
            name: AppRouteNames.structuralElementReports,
            builder: (context, state) {
              final extra = _routeExtra(state.extra);
              return RelatoriosScreen(
                onOpenInformacoes: () => context.pushNamed(
                  AppRouteNames.structuralElementInfo,
                  pathParameters: <String, String>{
                    AppPaths.structureIdParameter:
                        state.pathParameters[AppPaths.structureIdParameter]!,
                    AppPaths.elementIdParameter:
                        state.pathParameters[AppPaths.elementIdParameter]!,
                  },
                  extra: extra,
                ),
              );
            },
          ),
        ],
      ),

      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => MainScreen(
          child: child,
          onProjectQuickAction: () async {
            ref.invalidate(projetoFormProvider);
            try {
              await showDiaviconModal(
                context: context,
                title: 'Novo Projeto',
                height: 540,
                body: const NewProjectBody(),
              );
            } finally {
              ref.invalidate(projetoFormProvider);
            }
          },
        ),
        routes: [
          // Projetos e suas sub-rotas
          GoRoute(
            path: AppPaths.projects,
            name: AppRouteNames.projects,
            builder: (context, state) => const ProjetosScreen(),
            routes: [
              GoRoute(
                path: AppPaths.projectDetailSegment,
                name: AppRouteNames.projectDetail,
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => ProjectDetailScreen(
                  projetoId: state.pathParameters[AppPaths.projectIdParameter]!,
                ),
                routes: [
                  GoRoute(
                    path: AppPaths.projectInfoSegment,
                    name: AppRouteNames.projectInfo,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => ProjectInfoScreen(
                      projetoId:
                          state.pathParameters[AppPaths.projectIdParameter]!,
                    ),
                  ),
                  GoRoute(
                    path: AppPaths.projectCompaniesSegment,
                    name: AppRouteNames.projectCompanies,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => ProjectCompaniesScreen(
                      projetoId:
                          state.pathParameters[AppPaths.projectIdParameter]!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Outras abas da Bottom Bar
          GoRoute(
            path: AppPaths.structures,
            name: AppRouteNames.structures,
            builder: (context, state) => const EstruturasTabScreen(),
          ),
          GoRoute(
            path: AppPaths.myCompany,
            name: AppRouteNames.myCompany,
            builder: (context, state) => const EmpresaScreen(),
          ),
          GoRoute(
            path: AppPaths.education,
            name: AppRouteNames.education,
            builder: (context, state) => const EducacaoFeedScreen(),
          ),

          GoRoute(
            path: AppPaths.notifications,
            name: AppRouteNames.notifications,
            builder: (context, state) => NotificacoesScreen(
              onResponderConviteProjeto:
                  ({
                    required String conviteId,
                    required String projetoId,
                    required String notificacaoId,
                    required bool aceitar,
                  }) => ref
                      .read(convitesProjetoControllerProvider)
                      .responderConvite(
                        conviteId: conviteId,
                        projetoId: projetoId,
                        notificacaoId: notificacaoId,
                        aceitar: aceitar,
                      ),
              onResponderConviteCliente:
                  ({
                    required String projetoId,
                    required String notificacaoId,
                    required bool aceitar,
                  }) => ref
                      .read(clientesProjetoControllerProvider)
                      .respondToInvite(
                        projectId: projetoId,
                        notificationId: notificacaoId,
                        accept: aceitar,
                      ),
            ),
          ),
        ],
      ),
    ],
  );

  final authSubscription = Supabase.instance.client.auth.onAuthStateChange
      .listen((data) async {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          router.goNamed(AppRouteNames.newPassword);
        } else if (data.event == AuthChangeEvent.signedIn ||
            data.event == AuthChangeEvent.initialSession) {
          await ref.read(currentUserProvider.notifier).sincronizarSessaoAtiva();
        } else if (data.event == AuthChangeEvent.signedOut) {
          ref.read(currentUserProvider.notifier).clearUser();
        }

        routerAlarme.value = !routerAlarme.value;
      });

  ref.onDispose(() {
    authSubscription.cancel();
    router.dispose();
    routerAlarme.dispose();
  });

  return router;
});

class _RouterErrorScreen extends StatelessWidget {
  const _RouterErrorScreen({required this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Não foi possível abrir esta página.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go(AppPaths.projects),
                  child: const Text('Voltar para projetos'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
