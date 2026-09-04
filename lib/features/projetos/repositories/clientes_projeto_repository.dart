import 'package:supabase_flutter/supabase_flutter.dart';

class ClientesProjetoRepository {
  ClientesProjetoRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<void> inviteExistingClient({
    required String projectId,
    required String clientCompanyId,
  }) async {
    final result = await _supabase.rpc(
      'invite_project_client',
      params: {
        'p_project_id': projectId,
        'p_client_company_id': clientCompanyId,
      },
    );
    _expectProjectId(result, projectId);
  }

  Future<void> respondToInvite({
    required String projectId,
    required String notificationId,
    required bool accept,
  }) async {
    final result = await _supabase.rpc(
      'respond_to_project_client_invite',
      params: {
        'p_project_id': projectId,
        'p_notification_id': notificationId,
        'p_accept': accept,
      },
    );
    _expectProjectId(result, projectId);
  }

  Future<void> removeCurrentClient(String projectId) async {
    final result = await _supabase.rpc(
      'remove_project_client',
      params: {'p_project_id': projectId},
    );
    _expectProjectId(result, projectId);
  }

  static void _expectProjectId(Object? result, String expectedProjectId) {
    if (result?.toString() != expectedProjectId) {
      throw StateError('O banco não confirmou a alteração do projeto.');
    }
  }
}
