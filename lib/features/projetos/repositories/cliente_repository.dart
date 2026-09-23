import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/entrada_segura.dart';

class ClienteRepository {
  ClienteRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<List<Map<String, dynamic>>> fetchClients(
    String managerCompanyId,
  ) async {
    final response = await _supabase.rpc(
      'list_company_clients',
      params: {'p_manager_company_id': managerCompanyId},
    );

    final clients = (response as List)
        .whereType<Map>()
        .map((row) => <String, dynamic>{'id': row['id'], 'nome': row['nome']})
        .toList();

    clients.insert(0, {'id': managerCompanyId, 'nome': 'Minha Empresa'});
    return clients;
  }

  Future<List<Map<String, dynamic>>> searchCompanies(String searchTerm) async {
    final termo = EntradaSegura.semControle(searchTerm)
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    if (termo.isEmpty) return const [];
    // Termo entre aspas e com curingas escapados: vírgulas, parênteses,
    // aspas, % ou _ digitados não alteram o filtro do PostgREST.
    final valor = EntradaSegura.valorFiltroPostgrest(
      EntradaSegura.padraoContem(termo.length > 100 ? termo.substring(0, 100) : termo),
    );

    final response = await _supabase
        .from('empresas')
        .select('id, nome, cnpj, foto_url, criado_em')
        .or('nome.ilike.$valor,cnpj.ilike.$valor')
        .limit(20);

    return (response as List).cast<Map<String, dynamic>>();
  }
}
