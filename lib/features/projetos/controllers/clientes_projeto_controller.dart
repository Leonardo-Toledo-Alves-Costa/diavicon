import 'package:diavicon/features/notificacoes/providers/notificacoes_provider.dart';
import 'package:diavicon/features/projetos/providers/clientes_provider.dart';
import 'package:diavicon/features/projetos/providers/clientes_projeto_provider.dart';
import 'package:diavicon/features/projetos/providers/empresas_projeto_provider.dart';
import 'package:diavicon/features/projetos/providers/projetos_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final clientesProjetoControllerProvider = Provider<ClientesProjetoController>((
  ref,
) {
  return ClientesProjetoController(ref);
});

class ClientesProjetoController {
  ClientesProjetoController(this._ref);

  final Ref _ref;

  Future<void> inviteExistingClient({
    required String projectId,
    required String clientCompanyId,
  }) async {
    await _ref
        .read(clientesProjetoRepositoryProvider)
        .inviteExistingClient(
          projectId: projectId,
          clientCompanyId: clientCompanyId,
        );
    _invalidateProject(projectId);
  }

  Future<void> respondToInvite({
    required String projectId,
    required String notificationId,
    required bool accept,
  }) async {
    await _ref
        .read(clientesProjetoRepositoryProvider)
        .respondToInvite(
          projectId: projectId,
          notificationId: notificationId,
          accept: accept,
        );
    _invalidateProject(projectId);
    _ref.invalidate(notificacoesProvider);
    _ref.invalidate(contadorNaoLidasProvider);
  }

  Future<void> removeCurrentClient({required String projectId}) async {
    await _ref
        .read(clientesProjetoRepositoryProvider)
        .removeCurrentClient(projectId);
    _invalidateProject(projectId);
  }

  void _invalidateProject(String projectId) {
    _ref.invalidate(projectDetailProvider(projectId));
    _ref.invalidate(projectsProvider);
    _ref.invalidate(clientesListaProvider);
    _ref.invalidate(projetoEmpresasIntegrantesProvider(projectId));
  }
}
