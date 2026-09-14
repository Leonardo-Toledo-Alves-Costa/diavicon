import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inspecao_visual_geral_model.dart';

final inspecaoVisualRepoProvider = Provider((ref) => InspecaoVisualRepository(Supabase.instance.client));

// Provider atualizado para exigir Projeto e Estrutura
final listaInspecoesGeraisProvider = FutureProvider.family.autoDispose<List<InspecaoVisualGeralModel>, ({String projetoId, String estruturaId})>((ref, params) async {
  final repo = ref.read(inspecaoVisualRepoProvider);
  return repo.buscarInspecoesGerais(params.projetoId, params.estruturaId);
});

class InspecaoVisualRepository {
  final SupabaseClient _supabase;

  InspecaoVisualRepository(this._supabase);

  Future<List<InspecaoVisualGeralModel>> buscarInspecoesGerais(String projetoId, String estruturaId) async {
    try {
      final response = await _supabase
          .from('ponto_inspecao_visual_geral')
          .select('''
            *,
            pontos_ensaios_geral!inner (
              projeto_id,
              estrutura_id,
              criado_em,
              tipos_ensaio ( icone_path )
            ),
            ponto_inspecao_visual (
              id,
              estruturas_locais (nome),
              ponto_inspecao_visual_anomalia (risco_maj)
            )
          ''')
          // Filtra rigidamente pelo Projeto e pela Estrutura
          .eq('pontos_ensaios_geral.projeto_id', projetoId)
          .eq('pontos_ensaios_geral.estrutura_id', estruturaId);

      return (response as List).map((e) => InspecaoVisualGeralModel.fromMap(e)).toList();
    } on PostgrestException catch (e) {
      throw Exception('Erro de base de dados: ${e.message}');
    } catch (e) {
      throw Exception('Erro inesperado: $e');
    }
  }

  Future<void> criarNovaInspecao({
    required String nome,
    required String tipo,
    required String descricao,
    required String projetoId,
    required String estruturaId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      // Salva na tabela mãe com a estrutura_id
      final resGeral = await _supabase.from('pontos_ensaios_geral').insert({
        'nome_ponto': nome,
        'tipo_ensaio': 'Inspeção Visual', 
        'projeto_id': projetoId,
        'estrutura_id': estruturaId, 
        'criado_por': userId, 
        // ID do tipo_ensaio para garantir que puxa o ícone correto depois
        'tipo_ensaio_id': '20c89940-e44c-4410-8a0b-1f42d20f16d6',
      }).select('id').single();
      
      final String idPontoGeral = resGeral['id'] as String;

      await _supabase.from('ponto_inspecao_visual_geral').insert({
        'nome': nome,
        'tipo': tipo,
        'descricao': descricao,
        'criado_por': userId,
        'id_ponto_geral': idPontoGeral, 
      });
      
    } on PostgrestException catch (e) {
      throw Exception('Erro ao criar inspeção no Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Erro inesperado: $e');
    }
  }
}