import 'package:diavicon/features/equipe/providers/equipe_provider.dart';
import 'package:diavicon/features/notificacoes/providers/notificacoes_provider.dart';
import 'package:diavicon/features/projetos/providers/empresas_projeto_provider.dart';
import 'package:diavicon/features/projetos/providers/projetos_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final convitesProjetoControllerProvider = Provider<ConvitesProjetoController>((
  ref,
) {
  return ConvitesProjetoController(ref);
});

class ConvitesProjetoController {
  ConvitesProjetoController(this._ref);

  final Ref _ref;

  Future<void> responderConvite({
    required String conviteId,
    required String projetoId,
    required String notificacaoId,
    required bool aceitar,
  }) async {
    await _ref
        .read(empresasProjetoRepositoryProvider)
        .respondToInvite(
          invitationId: conviteId,
          notificationId: notificacaoId,
          accept: aceitar,
        );

    _ref.invalidate(empresasVinculadasProjetoProvider(projetoId));
    if (aceitar) {
      _ref.invalidate(projectsProvider);
      _ref.invalidate(colaboradoresAtivosProjetoProvider(projetoId));
    }
    _ref.invalidate(notificacoesProvider);
    _ref.invalidate(contadorNaoLidasProvider);
  }
}
