import 'app_routes.dart';

/// Dados minimos necessarios para decidir um redirecionamento.
///
/// A regra fica independente de Flutter, Riverpod e Supabase para poder ser
/// exercitada por testes unitarios sem inicializar plugins ou rede.
class AppRouteGuardState {
  const AppRouteGuardState({
    required this.isLoggedIn,
    required this.isActive,
    required this.hasCompany,
    this.isTemporarilySuspended = false,
  });

  final bool isLoggedIn;
  final bool isActive;
  final bool hasCompany;
  final bool isTemporarilySuspended;
}

/// Retorna o caminho de destino ou `null` quando a navegacao deve prosseguir.
String? appRouteRedirect({
  required String path,
  required AppRouteGuardState auth,
  String? requestedLocation,
}) {
  if (!auth.isLoggedIn) {
    return _isPublicPath(path)
        ? null
        : AppPaths.loginWithRedirect(requestedLocation ?? path);
  }

  final isProtectedCompanyTransition =
      auth.isTemporarilySuspended && AppPaths.isCompanyFlow(path);
  final isCompanySetupCompletion =
      path == AppPaths.companyRegistration || path == AppPaths.companyWelcome;

  if (auth.hasCompany &&
      AppPaths.isCompanyFlow(path) &&
      !isProtectedCompanyTransition &&
      !isCompanySetupCompletion) {
    return AppPaths.projects;
  }

  if (AppPaths.isCompanyFlow(path)) return null;

  if (!auth.isActive && path != AppPaths.completeRegistration) {
    return AppPaths.completeRegistration;
  }

  if (auth.isActive && path == AppPaths.login) {
    final loginUri = Uri.tryParse(requestedLocation ?? path);
    return loginUri == null
        ? AppPaths.projects
        : AppPaths.postLoginRedirect(loginUri) ?? AppPaths.projects;
  }

  if (auth.isActive && _isEntryPath(path)) {
    return AppPaths.projects;
  }

  return null;
}

bool _isPublicPath(String path) {
  return path == AppPaths.welcome ||
      path == AppPaths.login ||
      AppPaths.isRegisterFlow(path) ||
      AppPaths.isCompanyFlow(path) ||
      path == AppPaths.recoverPassword ||
      path == AppPaths.newPassword;
}

bool _isEntryPath(String path) {
  return path == AppPaths.welcome ||
      path == AppPaths.login ||
      path == AppPaths.completeRegistration ||
      AppPaths.isRegisterFlow(path);
}
