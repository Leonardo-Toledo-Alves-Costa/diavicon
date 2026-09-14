import 'package:diavicon/features/notificacoes/providers/notificacoes_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificacoesControllerProvider = Provider<NotificacoesController>((ref) {
  return NotificacoesController(ref);
});

class NotificacoesController {
  NotificacoesController(this._ref);

  final Ref _ref;

  Future<void> marcarComoLida(String notificacaoId) {
    return _ref.read(notificacoesRepositoryProvider).markAsRead(notificacaoId);
  }
}
