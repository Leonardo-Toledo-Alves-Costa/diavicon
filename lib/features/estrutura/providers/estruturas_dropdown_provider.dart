import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';

final _supabase = Supabase.instance.client;

// Provider para Tipos de Estrutura
// --- STREAMS ORIGINAIS (ESTRUTURAS) ---
final conjuntosEstruturaisProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final empresaId = ref.watch(currentUserProvider)?.empresaId;
      if (empresaId == null) return Stream.value([]);

      return Supabase.instance.client
          .from('conjuntos_estruturais')
          .stream(primaryKey: ['id'])
          .eq('empresa_id', empresaId) // 👇 Filtro aplicado
          .order('nome');
    });

final utilizacoesEstruturaProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final empresaId = ref.watch(currentUserProvider)?.empresaId;
      if (empresaId == null) return Stream.value([]);

      return Supabase.instance.client
          .from('utilizacoes_estrutura')
          .stream(primaryKey: ['id'])
          .inFilter('empresa_id', [empresaId, '96b9a6b9-32d0-453e-9f69-74a2691ac5cc']) // 👇 Filtro aplicado
          .order('nome');
    });

final tiposEstruturaProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final empresaId = ref.watch(currentUserProvider)?.empresaId;
      if (empresaId == null) return Stream.value([]);

      return Supabase.instance.client
          .from('tipos_estrutura')
          .stream(primaryKey: ['id'])
          .inFilter('empresa_id', [empresaId, '96b9a6b9-32d0-453e-9f69-74a2691ac5cc']) // 👇 Filtro aplicado
          .order('nome');
    });

final tipologiasEstruturaProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final empresaId = ref.watch(currentUserProvider)?.empresaId;
      if (empresaId == null) return Stream.value([]);

      return Supabase.instance.client
          .from('tipologias_estrutura')
          .stream(primaryKey: ['id'])
          .inFilter('empresa_id', [empresaId, '96b9a6b9-32d0-453e-9f69-74a2691ac5cc']) // 👇 Filtro aplicado
          .order('nome');
    });

class EstruturaDropdownsController {
  final Ref ref;

  EstruturaDropdownsController(this.ref);

  Future<String> adicionarNovoItem({
    required String nomeTabela,
    required String nomeItem,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null || user.empresaId == null) {
      throw Exception('Usuário ou Empresa não identificados.');
    }

    final response = await _supabase
        .from(nomeTabela)
        .insert({'nome': nomeItem.trim(), 'empresa_id': user.empresaId})
        .select('id')
        .single();

    return response['id'] as String;
  }

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
      throw Exception(
        'Ação bloqueada! Verifique as permissões (RLS) de UPDATE na tabela $nomeTabela.',
      );
    }
  }

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
      throw Exception(
        'Ação bloqueada! Verifique as permissões (RLS) de DELETE na tabela $nomeTabela.',
      );
    }
  }
}

// Provider do Controller
final estruturaDropdownsControllerProvider = Provider((ref) {
  return EstruturaDropdownsController(ref);
});

// --- STREAMS PARA ELEMENTOS ESTRUTURAIS ---
final tiposElementoStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final empresaId = ref.watch(currentUserProvider)?.empresaId;
      if (empresaId == null) {
        return Stream.value(
          [],
        ); // Retorna lista vazia se não tiver empresa logada
      }

      return Supabase.instance.client
          .from('tipos_elemento')
          .stream(primaryKey: ['id'])
          .inFilter('empresa_id', [empresaId, '96b9a6b9-32d0-453e-9f69-74a2691ac5cc']) // 👇 Filtro aplicado
          .order('nome');
    });

final tipologiasElementoStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final empresaId = ref.watch(currentUserProvider)?.empresaId;
      if (empresaId == null) return Stream.value([]);

      return Supabase.instance.client
          .from('tipologias_elemento')
          .stream(primaryKey: ['id'])
          .inFilter('empresa_id', [empresaId, '96b9a6b9-32d0-453e-9f69-74a2691ac5cc']) // 👇 Filtro aplicado
          .order('nome');
    });

final revestimentosElementoStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final empresaId = ref.watch(currentUserProvider)?.empresaId;
      if (empresaId == null) return Stream.value([]);

      return Supabase.instance.client
          .from('revestimentos_elemento')
          .stream(primaryKey: ['id'])
          .inFilter('empresa_id', [empresaId, '96b9a6b9-32d0-453e-9f69-74a2691ac5cc']) // 👇 Filtro aplicado
          .order('nome');
    });

// --- STREAMS PARA LOCAIS ---
final tipologiasLocalStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final empresaId = ref.watch(currentUserProvider)?.empresaId;
      if (empresaId == null) return Stream.value([]);

      return Supabase.instance.client
          .from('tipologias_local')
          .stream(primaryKey: ['id'])
          .inFilter('empresa_id', [empresaId, '96b9a6b9-32d0-453e-9f69-74a2691ac5cc']) // 👇 Filtro aplicado
          .order('nome');
    });

final condicoesLocalStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final empresaId = ref.watch(currentUserProvider)?.empresaId;
      if (empresaId == null) return Stream.value([]);

      return Supabase.instance.client
          .from('condicoes_local')
          .stream(primaryKey: ['id'])
          .inFilter('empresa_id', [empresaId, '96b9a6b9-32d0-453e-9f69-74a2691ac5cc']) // 👇 Filtro aplicado
          .order('nome');
    });
