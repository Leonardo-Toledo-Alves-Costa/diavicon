import 'package:diavicon/features/equipe/providers/equipe_provider.dart';
import 'package:diavicon/features/projetos/providers/empresas_projeto_provider.dart';
import 'package:diavicon/features/projetos/providers/projetos_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final empresasProjetoControllerProvider = Provider<EmpresasProjetoController>((
  ref,
) {
  return EmpresasProjetoController(ref);
});

class EmpresasProjetoController {
  EmpresasProjetoController(this._ref);

  final Ref _ref;

  Future<Map<String, dynamic>> buscarEmpresaParaPreview(String cnpj) async {
    final company = await _ref
        .read(empresasProjetoRepositoryProvider)
        .findCompany(cnpj);
    if (company == null) {
      throw StateError('Nenhuma empresa encontrada com este CNPJ.');
    }
    return company;
  }

  Future<void> enviarConviteEmpresa({
    required String projetoId,
    required String empresaConvidadaId,
  }) async {
    await _ref
        .read(empresasProjetoRepositoryProvider)
        .inviteCompany(
          projectId: projetoId,
          invitedCompanyId: empresaConvidadaId,
        );
    _ref.invalidate(empresasVinculadasProjetoProvider(projetoId));
  }

  Future<void> alterarEmpresaGestora({
    required String projetoId,
    required String novaEmpresaGestoraId,
  }) async {
    await _ref
        .read(empresasProjetoRepositoryProvider)
        .transferManagement(
          projectId: projetoId,
          newManagerCompanyId: novaEmpresaGestoraId,
        );

    _ref.invalidate(gestaoProjetoProvider(projetoId));
    _ref.invalidate(empresasVinculadasProjetoProvider(projetoId));
    _ref.invalidate(projectDetailProvider(projetoId));
    _ref.invalidate(projectsProvider);
  }
}
