import 'package:diavicon/core/providers/supabase_provider.dart';
import 'package:diavicon/features/notificacoes/repositories/notificacoes_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificacoesRepositoryProvider = Provider<NotificacoesRepository>((ref) {
  return NotificacoesRepository(ref.watch(supabaseClientProvider));
});

final contadorNaoLidasProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(notificacoesRepositoryProvider).watchUnreadCount();
});

final notificacoesProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      return ref.watch(notificacoesRepositoryProvider).watchNotifications();
    });
