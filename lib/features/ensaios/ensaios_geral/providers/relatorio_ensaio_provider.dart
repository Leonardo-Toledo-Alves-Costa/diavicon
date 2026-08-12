import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/relatorio_ensaio_model.dart';

final relatorioEnsaioRepositoryProvider = Provider((ref) => RelatorioEnsaioRepository(Supabase.instance.client));

class RelatorioEnsaioRepository {
  final SupabaseClient _supabase;
  RelatorioEnsaioRepository(this._supabase);

  // Busca todos os relatórios de um ensaio/estrutura
  Future<List<RelatorioEnsaioModel>> buscarRelatorios({
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioId,
  }) async {
    try {
      final response = await _supabase
          .from('relatorio_ensaio')
          .select()
          .eq('projeto_id', projetoId)
          .eq('estrutura_id', estruturaId)
          .eq('tipo_ensaio_id', tipoEnsaioId)
          .order('criado_em', ascending: false);

      return (response as List).map((e) => RelatorioEnsaioModel.fromMap(e)).toList();
    } on PostgrestException catch (e) {
      throw Exception('Erro de BD ao buscar relatórios: ${e.message}');
    } catch (e) {
      throw Exception('Erro inesperado: $e');
    }
  }

  // Busca dados para os filtros (Locais e Tipos de Elemento)
  Future<Map<String, List<String>>> buscarOpcoesFiltros(String estruturaId) async {
    try {
      final elementos = await _supabase
          .from('elementos_estruturais')
          .select('local, tipo')
          .eq('estrutura_id', estruturaId);

      final locais = (elementos as List).map((e) => e['local'].toString()).toSet().toList();
      final tipos = elementos.map((e) => e['tipo'].toString()).toSet().toList();
      // O filtro de empresas demandaria uma query na tabela 'projeto_empresas_colaboradoras', 
      // aqui simularemos com base nas disponíveis.

      return {
        'locais': locais..removeWhere((e) => e == 'null'),
        'tipos': tipos..removeWhere((e) => e == 'null'),
      };
    } catch (e) {
      return {'locais': [], 'tipos': []};
    }
  }

  // Cria um novo relatório
  Future<void> criarRelatorio({
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioId,
    required Map<String, dynamic> configuracoes, // Dados do form
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const AuthException('Usuário não autenticado.');

      await _supabase.from('relatorio_ensaio').insert({
        'projeto_id': projetoId,
        'estrutura_id': estruturaId,
        'criado_por': userId,
        'status': 'Postado', // Status inicial
        'conteudo': jsonEncode(configuracoes),
        'tipo_ensaio_id': tipoEnsaioId,
      });
    } on PostgrestException catch (e) {
      throw Exception('Erro ao criar relatório: ${e.message}');
    }
  }

  // Apaga um relatório
  Future<void> apagarRelatorio(String relatorioId) async {
    try {
      await _supabase.from('relatorio_ensaio').delete().eq('id', relatorioId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao apagar relatório: ${e.message}');
    }
  }
}

// StreamProvider para a Central de Relatórios (atualiza em tempo real se houver deleção/criação)
final relatoriosProvider = FutureProvider.family.autoDispose<List<RelatorioEnsaioModel>, ({
  String projetoId, 
  String estruturaId,
  String tipoEnsaioId,
  })>((ref, params) async {
  final repo = ref.read(relatorioEnsaioRepositoryProvider);
  return repo.buscarRelatorios(projetoId: params.projetoId, estruturaId: params.estruturaId,tipoEnsaioId: params.tipoEnsaioId);
});