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
  import 'package:diavicon/features/estrutura/models/estrutura_model.dart';
  import 'package:diavicon/features/estrutura/screens/estrutura_home.dart';
  import 'package:diavicon/features/projetos/screens/notificacoes_screen.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';
  import 'package:supabase_flutter/supabase_flutter.dart';

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
  import '../../features/elementos/screens/elementos_screen.dart';

  import '../../features/home/screens/main_screen.dart';
  import '../../features/projetos/screens/projetos_screen.dart';
  import '../../features/projetos/screens/project_detail_screen.dart';
  import '../../features/auth/providers/auth_provider.dart';

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

    final routerAlarme = ValueNotifier<bool>(false);
    
    // Se o Riverpod mudar, recarrega as rotas
    ref.listen(currentUserProvider, (previous, next) {
      routerAlarme.value = !routerAlarme.value; 
    });

    //  Se o Supabase logar/deslogar, recarrega as rotas
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      routerAlarme.value = !routerAlarme.value;
    });

    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/',
      refreshListenable: routerAlarme, 

      redirect: (context, state) {
        final path = state.uri.toString();
        final usuario = ref.read(currentUserProvider);

        final bool isLoggedIn = usuario != null;
        final bool isAtivo = usuario?.ativo ?? false; 

        // --- Redirecionamento para usuários NÃO logados ---
        if (!isLoggedIn) {
          final bool isPublic =
              path == '/' ||
              path == '/login' ||
              path.startsWith('/register') ||
              path.startsWith('/empresa/') ||
              path == '/completar-cadastro'; 

          if (!isPublic) return '/login';
          return null;
        }

        // --- Redirecionamento para usuários LOGADOS (Com perfil carregado) ---
        if (isLoggedIn) {
          // Se NÃO está ativo e não está na tela de completar cadastro, joga ele pra lá!
          if (!isAtivo && path != '/completar-cadastro') {
            return '/completar-cadastro';
          }

          // Se ESTÁ ativo e tentar acessar telas iniciais ou a de completar cadastro, joga pra Projetos
          if (isAtivo && (path == '/completar-cadastro' || path == '/' || path == '/login' || path.startsWith('/register'))) {
            return '/projetos';
          }

          // Se ele estiver no fluxo de empresa, não interrompe
          if (path.startsWith('/empresa/')) {
            return null; 
          }
        }

        return null;
      },

      routes: [
        // --- ROTAS PÚBLICAS / AUTH ---
        GoRoute(path: '/', builder: (context, state) => const WelcomeScreen()),
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

        // --- FLUXO DE CADASTRO ACADÊMICO ---
        GoRoute(
          path: '/register',
          builder: (context, state) => const CadastroR0Screen(),
          routes: [
            GoRoute(
              path: 'dados',
              builder: (context, state) {
                final extra = state.extra as Map<String, dynamic>? ?? {};
                return CadastroR1Screen(dadosCadastro: extra);
              },
            ),
            GoRoute(
              path: 'perfil',
              builder: (context, state) {
                final extra = state.extra as Map<String, dynamic>? ?? {};
                return CadastroR2Screen(dadosCadastro: extra);
              },
            ),
            GoRoute(
              path: 'academico',
              builder: (context, state) {
                final extra = state.extra as Map<String, dynamic>? ?? {};
                return CadastroAcademicoScreen(dadosCadastro: extra);
              },
            ),
            GoRoute(path: 'cliente/gate',
              builder: (context, state) => Cadastro0Cliente(dadosUsuario: state.extra as Map<String, dynamic>? ?? {}),),
            GoRoute(path: 'cliente/checkboxes',
              builder: (context, state) => Cadastro1Cliente(dadosUsuario: state.extra as Map<String, dynamic>? ?? {}),),
            GoRoute(path: 'cliente/planos',
              builder: (context, state) => Cadastro2Cliente(dadosUsuario: state.extra as Map<String, dynamic>? ?? {}),),
            GoRoute(path: 'cliente/welcome',
              builder: (context, state) => Cadastro3Cliente(dadosUsuario: state.extra as Map<String, dynamic>? ?? {}),),
          ],
        ),

        // --- FLUXO DE ONBOARDING EMPRESA (FORA DO SHELL) ---
        GoRoute(
          path: '/empresa/gate',
          builder: (context, state) => Cadastro0Empresa(
            dadosCadastro: state.extra as Map<String, dynamic>? ?? {},
          ),
        ),
        GoRoute(
          path: '/empresa/onboarding',
          builder: (context, state) => Cadastro1Empresa(
            dadosCadastro: state.extra as Map<String, dynamic>? ?? {},
          ),
        ),
        GoRoute(
          path: '/empresa/servicos',
          builder: (context, state) => Cadastro2Empresa(
            dadosUsuario: state.extra as Map<String, dynamic>? ?? {},
          ),
        ),
        GoRoute(
          path: '/empresa/planos',
          builder: (context, state) => Cadastro3Empresa(
            dadosUsuario: state.extra as Map<String, dynamic>? ?? {},
          ),
        ),
        GoRoute(
          path: '/empresa/cadastro',
          builder: (context, state) => EmpresaCadastroScreen(
            dadosUsuario: state.extra as Map<String, dynamic>? ?? {},
          ),
        ),
        GoRoute(
          path: '/empresa/bemvinda',
          builder: (context, state) => EmpresaBemVindaScreen(
            dadosUsuario: state.extra as Map<String, dynamic>? ?? {},
          ),
        ),

        //completar cadastro
        GoRoute(
          path: '/completar-cadastro',
          builder: (context, state) => const CompletarCadastroScreen(),
        ),


        // --- ÁREA LOGADA (SHELL ROUTE COM RODAPÉ) ---
        GoRoute(
          path: '/estruturas/:estruturaId/elementos/:elementoId',
          builder: (context, state) {
            final extra = _routeExtra(state.extra);
            return ElementoScreen(
              estruturaId: state.pathParameters['estruturaId'],
              elementoId: state.pathParameters['elementoId'],
              projetoId: _stringExtra(extra, 'projetoId'),
              titulo: _stringExtra(extra, 'titulo'),
              tipo: _stringExtra(extra, 'tipo'),
              local: _stringExtra(extra, 'local'),
              imageUrl: _stringExtra(extra, 'imageUrl'),
            );
          },
          routes: [
            GoRoute(
              path: 'informacoes',
              builder: (context, state) {
                final extra = _routeExtra(state.extra);
                final basePath =
                    '/estruturas/${state.pathParameters['estruturaId']}/elementos/${state.pathParameters['elementoId']}';

                return ElementoInfoScreen(
                  initialNome: _stringExtra(extra, 'titulo') ?? 'ABC Corp.',
                  initialTipoElemento: _elementoTipo(extra),
                  initialTipologiaEstrutural: _elementoTipologia(extra),
                  initialLocalElemento: _stringExtra(extra, 'local'),
                  onOpenRelatorios: () => context.push(
                    '$basePath/relatorios',
                    extra: extra,
                  ),
                );
              },
            ),
            GoRoute(
              path: 'relatorios',
              builder: (context, state) {
                final extra = _routeExtra(state.extra);
                final basePath =
                    '/estruturas/${state.pathParameters['estruturaId']}/elementos/${state.pathParameters['elementoId']}';

                return RelatoriosScreen(
                  onOpenInformacoes: () => context.push(
                    '$basePath/informacoes',
                    extra: extra,
                  ),
                );
              },
            ),
          ],
        ),

      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => MainScreen(child: child),
        routes: [
          // Projetos e suas sub-rotas (detalhes)
          GoRoute(
            path: '/projetos',
            builder: (context, state) => const ProjetosScreen(),
            routes: [
              GoRoute(
                path: 'detalhes',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => ProjectDetailScreen(
                  projetoId: state.extra as String? ?? '',
                ),
              ),
            ],
          ),
          // Outras abas da Bottom Bar
          GoRoute(
            path: '/estruturas',
            builder: (context, state) => EstruturaHomeScreen(
              projetoId: 'demo-projeto',
              estrutura: EstruturaModel(
                id: 'demo-estrutura',
                nome: 'Estrutura BCDE',
                tipoId: 'Concreto armado',
                status: 'Em andamento',
                caa: 'II',
                anoConcepcao: 26,
                conjuntoEstruturalId: 'Conjunto Estrutural A',
                tipologiaId: 'Viga',
              ),
            ),
          ),
          GoRoute(
            path: '/minha-empresa',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Perfil da Empresa'))),
          ),
          GoRoute(
            path: '/educacao',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Educação'))),
          ),

            // NOTIFICACOES
            GoRoute(
              path: '/notificacoes',
              builder: (context, state) => const NotificacoesScreen(),
            ),
          ],
        ),
      ],
    );
  });