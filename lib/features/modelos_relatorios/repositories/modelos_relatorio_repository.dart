import 'package:supabase_flutter/supabase_flutter.dart';

import '../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../models/modelo_relatorio_model.dart';

class ModelosRelatorioRepository {
  final SupabaseClient _supabase;
  ModelosRelatorioRepository(this._supabase);

  static const _tabela = 'modelos_relatorios';

  // Mesma regra dos campos personalizáveis (ver CamposMenuScreen/
  // camposListProvider): a empresa só vê os modelos que ela mesma criou e os
  // modelos padrão da Diavicon. Filtro no servidor (.or) + reforço no
  // cliente (.where), igual ao padrão já usado lá.
  Future<List<ResumoModelosEnsaioModel>> buscarResumoPorEnsaio(String empresaId) async {
    try {
      final tiposResp = await _supabase.from('tipos_ensaio').select('id, nome, icone_path').order('nome');
      if ((tiposResp as List).isEmpty) return [];

      final modelosResp = await _supabase
          .from(_tabela)
          .select('tipo_ensaio_id, empresa_id')
          .or('empresa_id.eq.$empresaId,empresa_id.eq.$DIAVICON_EMPRESA_ID');

      final contagem = <String, int>{};
      for (final m in (modelosResp as List)) {
        final idEmpresaModelo = m['empresa_id']?.toString();
        if (idEmpresaModelo != empresaId && idEmpresaModelo != DIAVICON_EMPRESA_ID) continue;
        final tipoId = m['tipo_ensaio_id']?.toString();
        if (tipoId != null) contagem[tipoId] = (contagem[tipoId] ?? 0) + 1;
      }

      final lista = tiposResp
          .map((t) => ResumoModelosEnsaioModel.fromJson(t, contagem[t['id']?.toString()] ?? 0))
          .toList();

      lista.sort((a, b) {
        if (a.quantidadeModelos > 0 && b.quantidadeModelos == 0) return -1;
        if (a.quantidadeModelos == 0 && b.quantidadeModelos > 0) return 1;
        return a.nome.compareTo(b.nome);
      });

      return lista;
    } on PostgrestException catch (e) {
      throw Exception('Erro ao carregar tipos de ensaio: ${e.message}');
    }
  }

  Future<List<ModeloRelatorioModel>> listarPorTipoEnsaio(String empresaId, String tipoEnsaioId) async {
    try {
      final resp = await _supabase
          .from(_tabela)
          .select()
          .eq('tipo_ensaio_id', tipoEnsaioId)
          .or('empresa_id.eq.$empresaId,empresa_id.eq.$DIAVICON_EMPRESA_ID')
          .order('criado_em', ascending: false);
      final lista = (resp as List).map((e) => ModeloRelatorioModel.fromJson(e)).toList();
      // Reforço no cliente, igual ao camposListProvider: nunca mostra modelo
      // de outra empresa mesmo que o filtro do servidor falhe.
      return lista.where((m) => m.empresaId == empresaId || m.empresaId == DIAVICON_EMPRESA_ID).toList();
    } on PostgrestException catch (e) {
      throw Exception('Erro ao carregar modelos: ${e.message}');
    }
  }

  Future<ModeloRelatorioModel> criarModelo({
    required String empresaId,
    required String tipoEnsaioId,
    required String nome,
    String? descricao,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final row = await _supabase.from(_tabela).insert({
        'empresa_id': empresaId,
        'tipo_ensaio_id': tipoEnsaioId,
        'nome': nome,
        'descricao': descricao,
        'criado_por': userId,
        'schema_json': const {},
      }).select().single();
      return ModeloRelatorioModel.fromJson(row);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao criar modelo: ${e.message}');
    }
  }

  Future<void> deletarModelo(String id) async {
    try {
      // `.select()` no retorno do delete deixa explícito quantas linhas
      // foram de fato apagadas — sem isso, um delete bloqueado
      // silenciosamente por RLS (0 linhas afetadas) não gera erro nenhum, e
      // a tela parece "não recarregar" porque na prática nada foi apagado.
      final apagados = await _supabase.from(_tabela).delete().eq('id', id).select('id');
      if ((apagados as List).isEmpty) {
        throw Exception('Não foi possível apagar: modelo padrão ou sem permissão.');
      }
    } on PostgrestException catch (e) {
      throw Exception('Erro ao apagar modelo: ${e.message}');
    }
  }

  // Só nome/descrição — modelos padrão (Diavicon) só podem ser editados
  // pela própria Diavicon; a tela já restringe quem chama isso.
  Future<void> atualizarInfo(String id, {required String nome, String? descricao}) async {
    try {
      await _supabase.from(_tabela).update({'nome': nome, 'descricao': descricao}).eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao atualizar modelo: ${e.message}');
    }
  }

  Future<ModeloRelatorioModel> buscarPorId(String id) async {
    try {
      final row = await _supabase.from(_tabela).select().eq('id', id).single();
      return ModeloRelatorioModel.fromJson(row);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao carregar modelo: ${e.message}');
    }
  }

  Future<void> salvarSchema(String id, Map<String, dynamic> schemaJson) async {
    try {
      await _supabase.from(_tabela).update({'schema_json': schemaJson}).eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao salvar modelo: ${e.message}');
    }
  }

  // Modelo padrão (eh_padrao=true) não é editável direto: duplica pra uma
  // cópia pertencente à empresa atual, já com o mesmo schema_json.
  Future<ModeloRelatorioModel> duplicarModelo(ModeloRelatorioModel original, String empresaId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final row = await _supabase.from(_tabela).insert({
        'empresa_id': empresaId,
        'tipo_ensaio_id': original.tipoEnsaioId,
        'nome': '${original.nome} (cópia)',
        'descricao': original.descricao,
        'criado_por': userId,
        'schema_json': original.schemaJson,
        'eh_padrao': false,
        'duplicado_de_id': original.id,
      }).select().single();
      return ModeloRelatorioModel.fromJson(row);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao duplicar modelo: ${e.message}');
    }
  }
}
