import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart'; 

final _supabase = Supabase.instance.client;



// PROVIDERS DE LEITURA EM TEMPO REAL (Streams)


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


// 2. CONTROLLER DE ESCRITA 

class EstruturaDropdownsController {
  final Ref ref;

  EstruturaDropdownsController(this.ref);

  // Mantém a sua função existente
  Future<String> adicionarNovoItem({
    required String nomeTabela,
    required String nomeItem,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null || user.empresaId == null) {
      throw Exception('Usuário ou Empresa não identificados.');
    }

    final response = await _supabase.from(nomeTabela).insert({
      'nome': nomeItem.trim(),
      'empresa_id': user.empresaId,
    }).select('id').single();

    return response['id'] as String;
  }

  // 👇 ATUALIZE A FUNÇÃO DE EDITAR
  Future<void> editarItem({
    required String nomeTabela,
    required String id,
    required String novoNome,
  }) async {
    // O .select() obriga o Supabase a devolver a linha alterada.
    final response = await _supabase
        .from(nomeTabela)
        .update({'nome': novoNome.trim()})
        .eq('id', id)
        .select(); 

    // Se o RLS bloqueou a edição, a resposta vem vazia!
    if (response.isEmpty) {
      throw Exception('Ação bloqueada! Verifique as permissões (RLS) de UPDATE na tabela $nomeTabela.');
    }
  }

  // 👇 ATUALIZE A FUNÇÃO DE DELETAR
  Future<void> deletarItem({
    required String nomeTabela,
    required String id,
  }) async {
    // O .select() obriga o Supabase a devolver a linha apagada.
    final response = await _supabase
        .from(nomeTabela)
        .delete()
        .eq('id', id)
        .select();

    if (response.isEmpty) {
      throw Exception('Ação bloqueada! Verifique as permissões (RLS) de DELETE na tabela $nomeTabela.');
    }
  }
}

// Provider do Controller
final estruturaDropdownsControllerProvider = Provider((ref) {
  return EstruturaDropdownsController(ref);
});