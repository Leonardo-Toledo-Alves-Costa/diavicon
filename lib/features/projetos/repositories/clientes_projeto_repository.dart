import 'package:supabase_flutter/supabase_flutter.dart';

class ClientesProjetoRepository {
  ClientesProjetoRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<void> inviteExistingClient({
    required String projectId,
    required String clientCompanyId,
  }) async {
    _requireUserId();
    await _supabase.rpc(
      'invite_project_client',
      params: {
        'p_project_id': projectId,
        'p_client_company_id': clientCompanyId,
      },
    );
  }

  Future<void> respondToInvite({
    required String projectId,
    required String notificationId,
    required bool accept,
  }) async {
    _requireUserId();
    await _supabase.rpc(
      'respond_to_project_client_invite',
      params: {
        'p_project_id': projectId,
        'p_notification_id': notificationId,
        'p_accept': accept,
      },
    );
  }

  Future<void> removeCurrentClient(String projectId) async {
    _requireUserId();
    await _supabase.rpc(
      'remove_project_client',
      params: {'p_project_id': projectId},
    );
  }

  String _requireUserId() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sessão expirada. Faça login novamente.');
    }
    return userId;
  }
}
