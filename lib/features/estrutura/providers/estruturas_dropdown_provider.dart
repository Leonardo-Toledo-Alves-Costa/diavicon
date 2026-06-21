import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart'; 

final _supabase = Supabase.instance.client;

// ==========================================
// 1. PROVIDERS DE LEITURA EM TEMPO REAL (Streams)
// ==========================================

// Provider para Tipos de Estrutura
final tiposEstruturaProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return _supabase
      .from('tipos_estrutura')
      .stream(primaryKey: ['id'])
      .order('nome', ascending: true)
      .map((lista) => List<Map<String, dynamic>>.from(lista));
});

// Provider para Tipologias
final tipologiasEstruturaProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return _supabase
      .from('tipologias_estrutura')
      .stream(primaryKey: ['id'])
      .order('nome', ascending: true)
      .map((lista) => List<Map<String, dynamic>>.from(lista));
});

// Provider para Utilizações
final utilizacoesEstruturaProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return _supabase
      .from('utilizacoes_estrutura')
      .stream(primaryKey: ['id'])
      .order('nome', ascending: true)
      .map((lista) => List<Map<String, dynamic>>.from(lista));
});

// Provider para Conjuntos Estruturais
final conjuntosEstruturaisProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return _supabase
      .from('conjuntos_estruturais')
      .stream(primaryKey: ['id'])
      .order('nome', ascending: true)
      .map((lista) => List<Map<String, dynamic>>.from(lista));
});

// ==========================================
// 2. CONTROLLER DE ESCRITA (Pode manter exatamente como estava)
// ==========================================


class EstruturaDropdownsController {
  final Ref ref;

  EstruturaDropdownsController(this.ref);

  Future<String> adicionarNovoItem({
    required String nomeTabela,
    required String nomeItem,
  }) async {
    // Pega a empresa do usuário logado
    final user = ref.read(currentUserProvider);
    if (user == null || user.empresaId == null) {
      throw Exception('Usuário ou Empresa não identificados.');
    }

    // Faz o INSERT enviando o empresa_id (para satisfazer o RLS)
    final response = await _supabase.from(nomeTabela).insert({
      'nome': nomeItem.trim(),
      'empresa_id': user.empresaId,
    }).select('id').single();

    // Retorna o ID do novo item criado
    return response['id'] as String;
  }
}

// Provider do Controller
final estruturaDropdownsControllerProvider = Provider((ref) {
  return EstruturaDropdownsController(ref);
});