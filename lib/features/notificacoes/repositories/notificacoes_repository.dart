import 'package:supabase_flutter/supabase_flutter.dart';

class NotificacoesRepository {
  NotificacoesRepository(this._supabase);

  final SupabaseClient _supabase;

  Stream<int> watchUnreadCount() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value(0);

    return _supabase
        .from('notificacoes')
        .stream(primaryKey: ['id'])
        .eq('usuario_id', userId)
        .map((items) => items.where((item) => item['lida'] != true).length);
  }

  Stream<List<Map<String, dynamic>>> watchNotifications() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value(const []);

    return _supabase
        .from('notificacoes')
        .stream(primaryKey: ['id'])
        .eq('usuario_id', userId)
        .map((items) {
          final sorted = List<Map<String, dynamic>>.from(items);
          sorted.sort((a, b) => _createdAt(b).compareTo(_createdAt(a)));
          return sorted;
        });
  }

  Future<void> markAsRead(String notificationId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sessão expirada. Faça login novamente.');
    }

    final updated = await _supabase
        .from('notificacoes')
        .update({'lida': true})
        .eq('id', notificationId)
        .eq('usuario_id', userId)
        .select('id')
        .maybeSingle();

    if (updated == null) {
      throw StateError('Notificação não encontrada.');
    }
  }

  static DateTime _createdAt(Map<String, dynamic> notification) {
    return DateTime.tryParse(notification['criado_em']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}
