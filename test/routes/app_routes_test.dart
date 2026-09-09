import 'package:diavicon/routes/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppPaths', () {
    test('constroi a hierarquia de projeto usando o id no caminho', () {
      expect(AppPaths.projectDetail('project-1'), '/projetos/project-1');
      expect(
        AppPaths.projectInfo('project-1'),
        '/projetos/project-1/informacoes',
      );
      expect(
        AppPaths.projectCompanies('project-1'),
        '/projetos/project-1/empresas',
      );
    });

    test('codifica ids antes de inclui-los na URL', () {
      expect(
        AppPaths.projectDetail('projeto 1/á'),
        '/projetos/projeto%201%2F%C3%A1',
      );
    });

    test('constroi caminhos de elemento estrutural', () {
      expect(
        AppPaths.structuralElement(
          structureId: 'estrutura 1',
          elementId: 'elemento/2',
        ),
        '/estruturas/estrutura%201/elementos/elemento%2F2',
      );
      expect(
        AppPaths.structuralElementInfo(
          structureId: 'estrutura-1',
          elementId: 'elemento-2',
        ),
        '/estruturas/estrutura-1/elementos/elemento-2/informacoes',
      );
    });

    test('reconhece fluxos por segmento completo', () {
      expect(AppPaths.isRegisterFlow(AppPaths.register), isTrue);
      expect(AppPaths.isRegisterFlow(AppPaths.registerData), isTrue);
      expect(AppPaths.isRegisterFlow('/register-invalido'), isFalse);

      expect(AppPaths.isCompanyFlow(AppPaths.companyOnboarding), isTrue);
      expect(AppPaths.isCompanyFlow('/empresa/rota-inexistente'), isFalse);
    });

    test('preserva apenas redirects internos seguros no login', () {
      final target = AppPaths.projectInfo('project-1');
      final loginUri = Uri.parse(AppPaths.loginWithRedirect(target));

      expect(AppPaths.postLoginRedirect(loginUri), target);
      expect(
        AppPaths.postLoginRedirect(
          Uri.parse('${AppPaths.login}?redirect=https%3A%2F%2Fevil.test'),
        ),
        isNull,
      );
      expect(
        AppPaths.postLoginRedirect(
          Uri.parse('${AppPaths.login}?redirect=%2F%2Fevil.test'),
        ),
        isNull,
      );
    });
  });
}
