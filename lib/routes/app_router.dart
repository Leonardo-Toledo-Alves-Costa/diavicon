import 'package:diavicon/features/legal/documentos_legais.dart';
import 'package:diavicon/features/legal/screens/documento_legal_screen.dart';
import 'package:diavicon/core/utils/diavicon_modal.dart';
import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:diavicon/features/auth/screens/auth_gate_screens.dart';
import 'package:diavicon/features/auth/screens/cadastro0_cliente.dart';
import 'package:diavicon/features/auth/screens/cadastro0_empresa.dart';
import 'package:diavicon/features/auth/screens/cadastro1_cliente.dart';
import 'package:diavicon/features/auth/screens/cadastro1_empresa.dart';
import 'package:diavicon/features/auth/screens/cadastro2_cliente.dart';
import 'package:diavicon/features/auth/screens/cadastro2_empresa.dart';
import 'package:diavicon/features/auth/screens/cadastro3_cliente.dart';
import 'package:diavicon/features/auth/screens/cadastro3_empresa.dart';
import 'package:diavicon/features/auth/screens/cadastro_academico_screen.dart';
import 'package:diavicon/features/auth/screens/cadastro_r0_screen.dart';
import 'package:diavicon/features/auth/screens/cadastro_r1_screen.dart';
import 'package:diavicon/features/auth/screens/cadastro_r2_screen.dart';
import 'package:diavicon/features/auth/screens/completar_cadastro_screen.dart';
import 'package:diavicon/features/auth/screens/empresa_bemvinda_screen.dart';
import 'package:diavicon/features/auth/screens/empresa_cadastro_screen.dart';
import 'package:diavicon/features/auth/screens/login_screen.dart';
import 'package:diavicon/features/auth/screens/nova_senha_screen.dart';
import 'package:diavicon/features/auth/screens/recupera_senha_screen.dart';
import 'package:diavicon/features/auth/screens/welcome_screen.dart';
import 'package:diavicon/features/elementos/screens/elementos_home_screen.dart';
import 'package:diavicon/features/elementos/screens/info_elementos_screen.dart';
import 'package:diavicon/features/empresas_servicos/screens/empresas_screen.dart';
import 'package:diavicon/features/feed_educacao/screens/feed_screen.dart';
import 'package:diavicon/features/home/screens/main_screen.dart';
import 'package:diavicon/features/home/screens/perfil_central_ajuda_screen.dart';
import 'package:diavicon/features/home/screens/perfil_dados_screen.dart';
import 'package:diavicon/features/home/screens/perfil_minha_conta_screen.dart';
import 'package:diavicon/features/home/screens/perfil_minha_privacidade_screen.dart';
import 'package:diavicon/features/home/screens/perfil_notificacoes_screen.dart';
import 'package:diavicon/features/notificacoes/screens/notificacoes_screen.dart';
import 'package:diavicon/features/projetos/controllers/clientes_projeto_controller.dart';
import 'package:diavicon/features/projetos/controllers/convites_projeto_controller.dart';
import 'package:diavicon/features/projetos/screens/project_companies_screen.dart';
import 'package:diavicon/features/projetos/screens/project_detail_screen.dart';
import 'package:diavicon/features/projetos/screens/project_info_screen.dart';
import 'package:diavicon/features/projetos/screens/projetos_screen.dart';
import 'package:diavicon/features/projetos/providers/projeto_form_provider.dart';
import 'package:diavicon/features/projetos/widgets/new_project_body.dart';
import 'package:diavicon/features/estrutura/screens/estruturas_tab_screen.dart';
import 'package:diavicon/core/routing/route_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/utils/cadastro_draft_utils.dart';
import 'app_route_guard.dart';
import 'app_routes.dart';
import 'package:diavicon/features/planos/acesso_plano.dart';
import 'package:diavicon/features/ensaios/ensaios_geral/repositories/relatorios_item_repository.dart';
import 'package:diavicon/features/ensaios/ensaios_geral/screens/relatorios_item_screen.dart';

Map<String, dynamic> _routeExtra(Object? extra) {
  if (extra is Map<String, dynamic>) return extra;
  if (extra is Map) {
    return extra.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

String? _stringExtra(Map<String, dynamic> extra, String key) {
  final value = extra[key];
  if (value == null) return null;
  return value.toString();
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
  final routerAlarm = ValueNotifier<bool>(false);

  // Só reavalia o redirect quando muda algo que o redirect usa. Toda
  // re-sincronização do perfil gera um UsuarioModel novo (ex: a cada
  // tokenRefreshed), e reavaliar as rotas por isso é trabalho à toa no meio
  // de telas empilhadas.
  ref.listen(currentUserProvider, (previous, next) {
    final mudouAlgoRelevante = previous?.id != next?.id ||
        previous?.empresaId != next?.empresaId ||
        previous?.ativo != next?.ativo ||
        previous?.convitePendente != next?.convitePendente;
    if (mudouAlgoRelevante) routerAlarm.value = !routerAlarm.value;
  });
  ref.listen(authAccessStatusProvider, (previous, next) {
    routerAlarm.value = !routerAlarm.value;
  });
  ref.onDispose(routerAlarm.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppPaths.welcome,
    refreshListenable: routerAlarm,
    observers: [appRouteObserver],

    redirect: (context, state) {
      final bloqueioAtivo = ref.read(bloqueioDeRotaProvider);
      if (bloqueioAtivo) return null;

      final path = state.uri.path;
      // Política e Termos abrem em qualquer estado (lojas e rodapé do site).
      if (AppPaths.isLegal(path)) return null;
      final usuario = ref.read(currentUserProvider);
      final accessStatus = ref.read(authAccessStatusProvider);
      final isAtivo = accessStatus == AuthAccessStatus.active;

      final isPublic = path == AppPaths.welcome ||
          path == AppPaths.login ||
          path.startsWith(AppPaths.register) ||
          path == AppPaths.companyGate ||
          path == AppPaths.companyOnboarding ||
          path == AppPaths.companyServices ||
          path == AppPaths.companyPlans ||
          path == AppPaths.recoverPassword ||
          path == AppPaths.newPassword ||
          path == '/confirmar-email' ||
          path == '/auth-indisponivel';

      if (accessStatus == AuthAccessStatus.loading) {
        return isPublic ? null : AppPaths.login;
      }
      if (accessStatus == AuthAccessStatus.signedOut) {
        return appRouteRedirect(
          path: path,
          requestedLocation: state.uri.toString(),
          auth: const AppRouteGuardState(
            isLoggedIn: false,
            isActive: false,
            hasCompany: false,
          ),
        );
      }
      if (accessStatus == AuthAccessStatus.awaitingEmailConfirmation) {
        return path == '/confirmar-email' ? null : '/confirmar-email';
      }
      if (accessStatus == AuthAccessStatus.registrationPending) {
        const registrationPaths = <String>{
          AppPaths.register,
          AppPaths.registerData,
          AppPaths.registerProfile,
          AppPaths.registerAcademic,
          AppPaths.registrationResume,
          AppPaths.registerClientGate,
          AppPaths.registerClientCheckboxes,
          AppPaths.registerClientPlans,
          AppPaths.registerClientWelcome,
          AppPaths.companyGate,
          AppPaths.companyOnboarding,
          AppPaths.companyServices,
          AppPaths.companyPlans,
          AppPaths.companyRegistration,
        };
        return registrationPaths.contains(path)
            ? null
            : AppPaths.registrationResume;
      }
      if (accessStatus == AuthAccessStatus.invitePending) {
        return path == AppPaths.completeRegistration
            ? null
            : AppPaths.completeRegistration;
      }
      if (accessStatus == AuthAccessStatus.inactive) {
        return path == '/conta-inativa' ? null : '/conta-inativa';
      }
      if (accessStatus == AuthAccessStatus.unavailable) {
        return path == '/auth-indisponivel' ? null : '/auth-indisponivel';
      }

      if (isAtivo && usuario != null) {
        return appRouteRedirect(
          path: path,
          requestedLocation: state.uri.toString(),
          auth: AppRouteGuardState(
            isLoggedIn: true,
            isActive: true,
            hasCompany: usuario.empresaId != null,
          ),
        );
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppPaths.welcome,
        name: AppRouteNames.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppPaths.login,
        name: AppRouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppPaths.privacyPolicy,
        name: AppRouteNames.privacyPolicy,
        builder: (context, state) => const DocumentoLegalScreen(documento: DocumentoLegal.privacidade),
      ),
      GoRoute(
        path: AppPaths.termsOfUse,
        name: AppRouteNames.termsOfUse,
        builder: (context, state) => const DocumentoLegalScreen(documento: DocumentoLegal.termos),
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
              dadosCadastro: CadastroDraftUtils.resolve(
                persisted: ref.read(rascunhoCadastroProvider),
                routeExtra: state.extra,
              ),
            ),
          ),
          GoRoute(
            path: 'retomar',
            name: AppRouteNames.registrationResume,
            builder: (context, state) => const RegistrationPendingScreen(),
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
          GoRoute(
            path: 'cliente/welcome',
            name: AppRouteNames.registerClientWelcome,
            builder: (context, state) =>
                Cadastro3Cliente(dadosUsuario: _routeExtra(state.extra)),
          ),
        ],
      ),
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
        builder: (context, state) => EmpresaCadastroScreen(
          dadosUsuario: CadastroDraftUtils.resolve(
            persisted: ref.read(rascunhoCadastroProvider),
            routeExtra: state.extra,
          ),
        ),
      ),
      GoRoute(
        path: AppPaths.companyWelcome,
        name: AppRouteNames.companyWelcome,
        builder: (context, state) =>
            EmpresaBemVindaScreen(dadosUsuario: _routeExtra(state.extra)),
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
        path: AppPaths.confirmEmail,
        name: AppRouteNames.confirmEmail,
        builder: (context, state) => const EmailConfirmationScreen(),
      ),
      GoRoute(
        path: AppPaths.inactiveAccount,
        name: AppRouteNames.inactiveAccount,
        builder: (context, state) => const InactiveAccountScreen(),
      ),
      GoRoute(
        path: AppPaths.authUnavailable,
        name: AppRouteNames.authUnavailable,
        builder: (context, state) => const AuthUnavailableScreen(),
      ),
      GoRoute(
        path: AppPaths.completeRegistration,
        name: AppRouteNames.completeRegistration,
        builder: (context, state) => const CompletarCadastroScreen(),
      ),
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
                initialMarcacaoImagemUrl:
                    _stringExtra(extra, 'marcacaoImagemUrl'),
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
              return RelatoriosItemScreen(
                nivel: NivelRelatorios.elemento,
                nomeItem: _stringExtra(extra, 'titulo') ?? 'Elemento',
                estruturaId: state.pathParameters[AppPaths.structureIdParameter],
                elementoId: state.pathParameters[AppPaths.elementIdParameter],
                projetoId: _stringExtra(extra, 'projetoId'),
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
          GoRoute(
            path: AppPaths.structures,
            name: AppRouteNames.structures,
            // Monitoramento é módulo de plano. A trava da aba não cobre quem
            // digita o endereço, por isso a rota também confere.
            builder: (context, state) => const GuardaModuloPlano(
              modulo: ModuloPlano.monitor,
              child: EstruturasTabScreen(),
            ),
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
});