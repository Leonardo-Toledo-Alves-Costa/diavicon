import 'package:supabase_flutter/supabase_flutter.dart';

class ClienteRepository {
  ClienteRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<List<Map<String, dynamic>>> fetchClients(
    String managerCompanyId,
  ) async {
    final response = await _supabase
        .from('empresa_clientes')
        .select('cliente_id, empresas!cliente_id(id, nome)')
        .eq('gestora_id', managerCompanyId)
        .eq('status_vinculo', 'ativo');

    final clients = (response as List).map((link) {
      final company =
          (link as Map<String, dynamic>)['empresas'] as Map<String, dynamic>;
      return <String, dynamic>{'id': company['id'], 'nome': company['nome']};
    }).toList();

    clients.insert(0, {'id': managerCompanyId, 'nome': 'Minha Empresa'});
    return clients;
  }

  Future<List<Map<String, dynamic>>> searchCompanies(String searchTerm) async {
    final sanitized = searchTerm
        .trim()
        .replaceAll(RegExp(r'[,()%"]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (sanitized.isEmpty) return const [];

    final response = await _supabase
        .from('empresas')
        .select('id, nome, cnpj, foto_url, criado_em')
        .or('nome.ilike.%$sanitized%,cnpj.ilike.%$sanitized%')
        .limit(20);

    return (response as List).cast<Map<String, dynamic>>();
  }
}
