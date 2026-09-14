import 'package:diavicon/routes/app_route_guard.dart';
import 'package:diavicon/routes/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appRouteRedirect', () {
    const signedOut = AppRouteGuardState(
      isLoggedIn: false,
      isActive: false,
      hasCompany: false,
    );
    const inactiveWithoutCompany = AppRouteGuardState(
      isLoggedIn: true,
      isActive: false,
      hasCompany: false,
    );
    const activeWithoutCompany = AppRouteGuardState(
      isLoggedIn: true,
      isActive: true,
      hasCompany: false,
    );
    const activeWithCompany = AppRouteGuardState(
      isLoggedIn: true,
      isActive: true,
      hasCompany: true,
    );

    test('permite somente rotas publicas conhecidas sem login', () {
      const publicPaths = <String>[
        AppPaths.welcome,
        AppPaths.login,
        AppPaths.register,
        AppPaths.registerData,
        AppPaths.registerClientPlans,
        AppPaths.companyGate,
        AppPaths.companyRegistration,
        AppPaths.companyWelcome,
        AppPaths.recoverPassword,
        AppPaths.newPassword,
      ];

      for (final path in publicPaths) {
        expect(
          appRouteRedirect(path: path, auth: signedOut),
          isNull,
          reason: path,
        );
      }
    });

    test('redireciona rotas privadas e caminhos desconhecidos para login', () {
      final privatePaths = <String>[
        AppPaths.projects,
        AppPaths.projectDetail('project-1'),
        AppPaths.profileData,
        AppPaths.notifications,
        AppPaths.completeRegistration,
        '/empresa/rota-inexistente',
        '/register-invalido',
      ];

      for (final path in privatePaths) {
        expect(
          appRouteRedirect(path: path, auth: signedOut),
          AppPaths.loginWithRedirect(path),
          reason: path,
        );
      }
    });

    test('mantem usuario inativo no fluxo de completar cadastro', () {
      expect(
        appRouteRedirect(
          path: AppPaths.completeRegistration,
          auth: inactiveWithoutCompany,
        ),
        isNull,
      );
      expect(
        appRouteRedirect(path: AppPaths.projects, auth: inactiveWithoutCompany),
        AppPaths.completeRegistration,
      );
    });

    test('permite onboarding de empresa para usuario sem empresa', () {
      expect(
        appRouteRedirect(
          path: AppPaths.companyOnboarding,
          auth: inactiveWithoutCompany,
        ),
        isNull,
      );
      expect(
        appRouteRedirect(
          path: AppPaths.companyServices,
          auth: activeWithoutCompany,
        ),
        isNull,
      );
    });

    test('usuario ativo sai das telas de entrada para projetos', () {
      const entryPaths = <String>[
        AppPaths.welcome,
        AppPaths.login,
        AppPaths.completeRegistration,
        AppPaths.register,
        AppPaths.registerAcademic,
      ];

      for (final path in entryPaths) {
        expect(
          appRouteRedirect(path: path, auth: activeWithoutCompany),
          AppPaths.projects,
          reason: path,
        );
      }
    });

    test('retoma deep link privado depois do login', () {
      final target = AppPaths.projectCompanies('project-1');
      final loginLocation = AppPaths.loginWithRedirect(target);

      expect(
        appRouteRedirect(
          path: AppPaths.login,
          requestedLocation: loginLocation,
          auth: activeWithCompany,
        ),
        target,
      );
    });

    test('usuario ativo pode acessar projeto e perfis', () {
      expect(
        appRouteRedirect(
          path: AppPaths.projectInfo('project-1'),
          auth: activeWithCompany,
        ),
        isNull,
      );
      expect(
        appRouteRedirect(path: AppPaths.profileData, auth: activeWithCompany),
        isNull,
      );
    });

    test('usuario com empresa nao reinicia onboarding', () {
      const blockedCompanyPaths = <String>[
        AppPaths.companyGate,
        AppPaths.companyOnboarding,
        AppPaths.companyServices,
        AppPaths.companyPlans,
      ];

      for (final path in blockedCompanyPaths) {
        expect(
          appRouteRedirect(path: path, auth: activeWithCompany),
          AppPaths.projects,
          reason: path,
        );
      }

      expect(
        appRouteRedirect(
          path: AppPaths.companyRegistration,
          auth: activeWithCompany,
        ),
        AppPaths.projects,
      );
      expect(
        appRouteRedirect(
          path: AppPaths.companyWelcome,
          auth: activeWithCompany,
        ),
        AppPaths.projects,
      );
    });

    test('suspensao temporaria vale somente no onboarding da empresa', () {
      const signedOutSuspended = AppRouteGuardState(
        isLoggedIn: false,
        isActive: false,
        hasCompany: false,
        isTemporarilySuspended: true,
      );
      const companyTransition = AppRouteGuardState(
        isLoggedIn: true,
        isActive: true,
        hasCompany: true,
        isTemporarilySuspended: true,
      );

      expect(
        appRouteRedirect(path: AppPaths.projects, auth: signedOutSuspended),
        AppPaths.loginWithRedirect(AppPaths.projects),
      );
      expect(
        appRouteRedirect(
          path: AppPaths.companyWelcome,
          auth: companyTransition,
        ),
        isNull,
      );
    });
  });
}
