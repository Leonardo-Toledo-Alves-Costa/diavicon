/// Nomes estaveis usados pelo GoRouter.
///
/// Centralizar os nomes evita que telas espalhem caminhos literais e permite
/// alterar a estrutura das URLs sem quebrar os pontos de navegacao.
abstract final class AppRouteNames {
  static const welcome = 'welcome';
  static const login = 'login';

  static const profiles = 'profiles';
  static const profileData = 'profile-data';
  static const profileAccount = 'profile-account';
  static const profileNotifications = 'profile-notifications';
  static const profilePrivacy = 'profile-privacy';
  static const profileHelp = 'profile-help';

  static const register = 'register';
  static const registerData = 'register-data';
  static const registerProfile = 'register-profile';
  static const registerAcademic = 'register-academic';
  static const registerClientGate = 'register-client-gate';
  static const registerClientCheckboxes = 'register-client-checkboxes';
  static const registerClientPlans = 'register-client-plans';
  static const registerClientWelcome = 'register-client-welcome';

  static const companyGate = 'company-gate';
  static const companyOnboarding = 'company-onboarding';
  static const companyServices = 'company-services';
  static const companyPlans = 'company-plans';
  static const companyRegistration = 'company-registration';
  static const companyWelcome = 'company-welcome';

  static const recoverPassword = 'recover-password';
  static const newPassword = 'new-password';
  static const confirmEmail = 'confirm-email';
  static const inactiveAccount = 'inactive-account';
  static const authUnavailable = 'auth-unavailable';
  static const completeRegistration = 'complete-registration';
  static const registrationResume = 'registration-resume';

  static const projects = 'projects';
  static const projectDetail = 'project-detail';
  static const projectInfo = 'project-info';
  static const projectCompanies = 'project-companies';

  static const structures = 'structures';
  static const structuralElement = 'structural-element';
  static const structuralElementInfo = 'structural-element-info';
  static const structuralElementReports = 'structural-element-reports';

  static const myCompany = 'my-company';
  static const education = 'education';
  static const notifications = 'notifications';
}

/// Caminhos canonicos e construtores de URLs do aplicativo.
abstract final class AppPaths {
  static const welcome = '/';
  static const login = '/login';
  static const redirectQueryParameter = 'redirect';

  static String loginWithRedirect(String location) => Uri(
    path: login,
    queryParameters: <String, String>{redirectQueryParameter: location},
  ).toString();

  static String? postLoginRedirect(Uri loginUri) {
    final rawTarget = loginUri.queryParameters[redirectQueryParameter];
    if (rawTarget == null ||
        !rawTarget.startsWith('/') ||
        rawTarget.startsWith('//')) {
      return null;
    }

    final target = Uri.tryParse(rawTarget);
    if (target == null ||
        target.hasScheme ||
        target.hasAuthority ||
        target.path == welcome ||
        target.path == login ||
        isRegisterFlow(target.path) ||
        isCompanyFlow(target.path) ||
        target.path == completeRegistration ||
        target.path == recoverPassword ||
        target.path == newPassword) {
      return null;
    }

    return target.toString();
  }

  static const profiles = '/perfis';
  static const profileData = '$profiles/perfil_dados';
  static const profileAccount = '$profiles/perfil_minha_conta';
  static const profileNotifications = '$profiles/perfil_notificacoes';
  static const profilePrivacy = '$profiles/perfil_privacidade';
  static const profileHelp = '$profiles/perfil_central_ajuda';

  static const register = '/register';
  static const registerData = '$register/dados';
  static const registerProfile = '$register/perfil';
  static const registerAcademic = '$register/academico';
  static const registerClientGate = '$register/cliente/gate';
  static const registerClientCheckboxes = '$register/cliente/checkboxes';
  static const registerClientPlans = '$register/cliente/planos';
  static const registerClientWelcome = '$register/cliente/welcome';

  static const companyGate = '/empresa/gate';
  static const companyOnboarding = '/empresa/onboarding';
  static const companyServices = '/empresa/servicos';
  static const companyPlans = '/empresa/planos';
  static const companyRegistration = '/empresa/cadastro';
  static const companyWelcome = '/empresa/bemvinda';

  static const recoverPassword = '/recuperar-senha';
  static const newPassword = '/nova-senha';
  static const confirmEmail = '/confirmar-email';
  static const inactiveAccount = '/conta-inativa';
  static const authUnavailable = '/auth-indisponivel';
  static const completeRegistration = '/completar-cadastro';
  static const registrationResume = '$register/retomar';

  static const projects = '/projetos';
  static const projectIdParameter = 'projetoId';
  static const projectDetailSegment = ':$projectIdParameter';
  static const projectInfoSegment = 'informacoes';
  static const projectCompaniesSegment = 'empresas';
  static const projectDetailPattern = '$projects/$projectDetailSegment';

  static String projectDetail(String projectId) =>
      '$projects/${Uri.encodeComponent(projectId)}';

  static String projectInfo(String projectId) =>
      '${projectDetail(projectId)}/$projectInfoSegment';

  static String projectCompanies(String projectId) =>
      '${projectDetail(projectId)}/$projectCompaniesSegment';

  static const structures = '/estruturas';
  static const structureIdParameter = 'estruturaId';
  static const elementIdParameter = 'elementoId';
  static const structuralElementPattern =
      '$structures/:$structureIdParameter/elementos/:$elementIdParameter';

  static String structuralElement({
    required String structureId,
    required String elementId,
  }) =>
      '$structures/${Uri.encodeComponent(structureId)}/elementos/'
      '${Uri.encodeComponent(elementId)}';

  static String structuralElementInfo({
    required String structureId,
    required String elementId,
  }) =>
      '${structuralElement(structureId: structureId, elementId: elementId)}'
      '/informacoes';

  static String structuralElementReports({
    required String structureId,
    required String elementId,
  }) =>
      '${structuralElement(structureId: structureId, elementId: elementId)}'
      '/relatorios';

  static const myCompany = '/minha-empresa';
  static const education = '/educacao';
  static const notifications = '/notificacoes';

  static bool isRegisterFlow(String path) =>
      path == register || path.startsWith('$register/');

  static bool isCompanyFlow(String path) => _companyFlowPaths.contains(path);

  static const Set<String> _companyFlowPaths = <String>{
    companyGate,
    companyOnboarding,
    companyServices,
    companyPlans,
    companyRegistration,
    companyWelcome,
  };
}
