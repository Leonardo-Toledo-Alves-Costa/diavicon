import 'package:supabase_flutter/supabase_flutter.dart';

class AuthOperationsRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> execute(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final response = await _supabase.functions.invoke(
      'auth-operations',
      body: {'action': action, ...payload},
    );

    final data = response.data;
    if (response.status < 200 || response.status >= 300) {
      final message = data is Map ? data['erro'] : null;
      throw Exception(message?.toString() ?? 'Operação não autorizada.');
    }
    return data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
  }
}
