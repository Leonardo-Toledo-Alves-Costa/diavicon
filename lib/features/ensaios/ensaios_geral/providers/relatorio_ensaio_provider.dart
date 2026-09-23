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
      // `.select()` no retorno confirma que a linha foi mesmo apagada (uma
      // política de RLS que bloqueia silenciosamente resultaria em 0 linhas
      // afetadas sem erro nenhum, e a galeria pareceria "não atualizar").
      final apagados = await _supabase.from('relatorio_ensaio').delete().eq('id', relatorioId).select('id');
      if ((apagados as List).isEmpty) {
        throw Exception('Não foi possível apagar: relatório não encontrado ou sem permissão.');
      }
    } on PostgrestException catch (e) {
      throw Exception('Erro ao apagar relatório: ${e.message}');
    }
  }

  // Cria a linha com status "Gerando" antes de começar a gerar de verdade —
  // permite mostrar o relatório na galeria (e atualizar via Realtime) mesmo
  // enquanto a geração roda em segundo plano, incluindo se o usuário navegar
  // pra outra tela nesse meio tempo.
  Future<String> criarRelatorioPendente({
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioId,
    required Map<String, dynamic> conteudo,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const AuthException('Usuário não autenticado.');

      final row = await _supabase.from('relatorio_ensaio').insert({
        'projeto_id': projetoId,
        'estrutura_id': estruturaId,
        'tipo_ensaio_id': tipoEnsaioId,
        'criado_por': userId,
        'status': 'Gerando',
        'conteudo': jsonEncode(conteudo),
      }).select('id').single();
      return row['id'].toString();
    } on PostgrestException catch (e) {
      throw Exception('Erro ao criar relatório: ${e.message}');
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

// Realtime (Supabase Stream), filtrado só por estrutura_id — o filtro fino
// por tipo_ensaio_id é feito no `.map()`, já que o Stream só suporta uma
// cláusula `.eq()`. Usado pela galeria de relatórios de qualquer ensaio pra
// refletir automaticamente quando um relatório "Gerando" em segundo plano
// termina (mesmo que o usuário tenha saído e voltado à tela nesse meio
// tempo). Genérico por tipo de ensaio — Carbonatação usa direto; Inspeção
// Visual usa o wrapper abaixo, que também filtra por inspecao_geral_id
// (conceito que só existe pra ela).
final relatoriosPorEstruturaStreamProvider =
    StreamProvider.family.autoDispose<List<RelatorioEnsaioModel>, ({String estruturaId, String tipoEnsaioId})>((ref, params) {
  final supabase = Supabase.instance.client;
  return supabase
      .from('relatorio_ensaio')
      .stream(primaryKey: ['id'])
      .eq('estrutura_id', params.estruturaId)
      .order('criado_em', ascending: false)
      .map((linhas) => linhas.map((e) => RelatorioEnsaioModel.fromMap(e)).where((r) => r.tipoEnsaioId == params.tipoEnsaioId).toList());
});

final relatoriosInspecaoVisualStreamProvider = StreamProvider.family
    .autoDispose<List<RelatorioEnsaioModel>, ({String estruturaId, String tipoEnsaioId, String inspecaoGeralId})>((ref, params) {
  final supabase = Supabase.instance.client;
  return supabase
      .from('relatorio_ensaio')
      .stream(primaryKey: ['id'])
      .eq('estrutura_id', params.estruturaId)
      .order('criado_em', ascending: false)
      .map((linhas) => linhas
          .map((e) => RelatorioEnsaioModel.fromMap(e))
          .where((r) => r.tipoEnsaioId == params.tipoEnsaioId && r.conteudo['inspecao_geral_id'] == params.inspecaoGeralId)
          .toList());
});