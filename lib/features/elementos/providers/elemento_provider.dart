import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/autor_exibicao.dart';
import '../../../core/repositories/autores_repository.dart';
import '../repositories/elemento_repository.dart';
import '../models/elemento_model.dart';

// --- REPOSITORY PROVIDER ---
final elementoRepositoryProvider = Provider<ElementoRepository>((ref) {
  return ElementoRepository(Supabase.instance.client);
});

// --- PROVIDER: ELEMENTOS (ATIVOS) DE UMA ESTRUTURA, EM TEMPO REAL ---
// O Supabase vigia a tabela; qualquer INSERT/UPDATE/DELETE dispara o fluxo.
final elementosPorEstruturaProvider = StreamProvider.autoDispose
    .family<List<ElementoModel>, String>((ref, estruturaId) {
  final supabase = Supabase.instance.client;

  return supabase
      .from('elementos_estruturais')
      .stream(primaryKey: ['id'])
      .eq('estrutura_id', estruturaId)
      .order('criado_em', ascending: false)
      .map((lista) => lista
          .where((item) => item['ativo'] != false)
          .map((item) => ElementoModel.fromMap(item))
          .toList());
});

// --- PROVIDER: TODOS OS ELEMENTOS DE UMA ESTRUTURA (INCLUSIVE OCULTOS) ---
// Diferente de [elementosPorEstruturaProvider], NÃO filtra por `ativo`. Usado
// no sheet "Incluir", onde os elementos ocultos precisam aparecer desmarcados
// para poderem ser reincluídos.
final todosElementosPorEstruturaProvider = StreamProvider.autoDispose
    .family<List<ElementoModel>, String>((ref, estruturaId) {
  final supabase = Supabase.instance.client;

  return supabase
      .from('elementos_estruturais')
      .stream(primaryKey: ['id'])
      .eq('estrutura_id', estruturaId)
      .order('criado_em', ascending: false)
      .map((lista) =>
          lista.map((item) => ElementoModel.fromMap(item)).toList());
});

// --- PROVIDER: AUTORIA DE UM ELEMENTO ---
// Resolve quem criou o elemento no recorte que a tela pode mostrar (logo da
// empresa sempre; foto e nome do autor só pra quem é da mesma empresa dele —
// a regra mora na função `autores_para_exibicao`, não aqui).
//
// Devolve null para os elementos criados antes da coluna `criado_por` existir:
// o selo simplesmente não aparece, sem erro.
final autoriaElementoProvider =
    FutureProvider.autoDispose.family<AutorExibicao?, String>((ref, elementoId) async {
  final supabase = Supabase.instance.client;

  final linha = await supabase
      .from('elementos_estruturais')
      .select('criado_por')
      .eq('id', elementoId)
      .maybeSingle();

  final criadoPor = linha?['criado_por']?.toString();
  if (criadoPor == null || criadoPor.isEmpty) return null;

  final autores = await AutoresRepository(supabase).buscarPorIds([criadoPor]);
  return autores[criadoPor];
});
