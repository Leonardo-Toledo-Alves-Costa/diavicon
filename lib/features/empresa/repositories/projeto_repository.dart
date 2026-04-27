import 'package:supabase_flutter/supabase_flutter.dart';
import '../../projetos/models/projeto_model.dart';

class ProjetoRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Busca apenas os projetos da empresa do usuário logado
  Future<List<ProjetoModel>> getProjetosPorEmpresa(String empresaId) async {
    final response = await _supabase
        .from('projetos')
        .select()
        .eq('empresa_gestora_id', empresaId)
        .order('criado_em', ascending: false); // Traz os mais recentes primeiro

    // Converte a lista de JSONs que o banco devolve para uma lista de Models do Flutter
    return response.map((json) => ProjetoModel.fromMap(json)).toList();
  }
}