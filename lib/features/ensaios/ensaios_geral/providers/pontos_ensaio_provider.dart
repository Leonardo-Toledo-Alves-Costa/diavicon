import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pontos_ensaio_model.dart';
import '../repositories/pontos_ensaio_repository.dart';

// ==============================================================
// 1. Provedor da Lista Principal de Pontos de Ensaio
// ==============================================================
typedef PontosFiltroArgs = ({String projetoId, String estruturaId, String tipoEnsaioId});

final pontosEnsaioProvider = FutureProvider.family.autoDispose<List<PontoEnsaioModel>, PontosFiltroArgs>((ref, args) async {
  final supabase = Supabase.instance.client;
  final repository = PontosEnsaioRepository(supabase);

  return await repository.getPontosEnsaio(
    projetoId: args.projetoId,
    estruturaId: args.estruturaId,
    tipoEnsaioId: args.tipoEnsaioId,
  );
});

// ==============================================================
// 2. Provedor de Cabeçalho (Nomes do Projeto e Estrutura)
// ==============================================================
typedef NomesHeaderArgs = ({String projetoId, String estruturaId});

final nomesHeaderProvider = FutureProvider.family.autoDispose<Map<String, String>, NomesHeaderArgs>((ref, args) async {
  final supabase = Supabase.instance.client;

  try {
    final projResp = await supabase.from('projetos').select('nome').eq('id', args.projetoId).maybeSingle();
    final estResp = await supabase.from('estruturas').select('nome').eq('id', args.estruturaId).maybeSingle();

    return {
      'projetoNome': projResp?['nome'] ?? 'Projeto Desconhecido',
      'estruturaNome': estResp?['nome'] ?? 'Estrutura Desconhecida',
    };
  } on PostgrestException catch (e) {
    throw Exception('Erro ao buscar nomes: ${e.message}');
  }
});

// ==============================================================
// 3. Provedor dos Elementos Estruturais (Usado no Modal)
// ==============================================================
final elementosEstruturaProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, estruturaId) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('elementos_estruturais')
      .select('id, nome, tipo, local, fotos')
      .eq('estrutura_id', estruturaId)
      .eq('ativo', true)
      .order('nome', ascending: true);

  return List<Map<String, dynamic>>.from(response);
});

// ==============================================================
// 4. Provedor para Buscar o Nome Dinâmico do Ensaio
// ==============================================================
final tipoEnsaioNomeProvider = FutureProvider.family.autoDispose<String, String>((ref, tipoEnsaioId) async {
  final supabase = Supabase.instance.client;
  try {
    final response = await supabase
        .from('tipos_ensaio')
        .select('nome')
        .eq('id', tipoEnsaioId)
        .maybeSingle();
        
    return response?['nome'] as String? ?? 'Ensaio Desconhecido';
  } catch (e) {
    return 'Ensaio Desconhecido';
  }
});