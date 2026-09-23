import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../models/modelo_rdo_model.dart';

class ModelosRdoRepository {
  final SupabaseClient _supabase;
  ModelosRdoRepository(this._supabase);

  static const _tabela = 'modelo_relatorio_rdo';

  // Mesma regra de `ModelosRelatorioRepository`/campos personalizáveis: a
  // empresa vê os próprios modelos + os modelos padrão da Diavicon. Filtro no
  // servidor (.or) + reforço no cliente, contra falha do filtro do servidor.
  Future<List<ModeloRdoModel>> listarModelos(String empresaId) async {
    try {
      final resp = await _supabase
          .from(_tabela)
          .select()
          .or('empresa_id.eq.$empresaId,empresa_id.eq.$DIAVICON_EMPRESA_ID')
          .order('criado_em', ascending: false);
      final lista = (resp as List).map((e) => ModeloRdoModel.fromJson(e)).toList();
      return lista.where((m) => m.empresaId == empresaId || m.empresaId == DIAVICON_EMPRESA_ID).toList();
    } on PostgrestException catch (e) {
      throw Exception('Erro ao carregar modelos de RDO: ${e.message}');
    }
  }

  Future<ModeloRdoModel> criarModelo({
    required String empresaId,
    required String nome,
    String? descricao,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final row = await _supabase.from(_tabela).insert({
        'empresa_id': empresaId,
        'nome': nome,
        'descricao': descricao,
        'criado_por': userId,
        'schema_json': const {},
      }).select().single();
      return ModeloRdoModel.fromJson(row);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao criar modelo: ${e.message}');
    }
  }

  Future<void> deletarModelo(String id) async {
    try {
      final apagados = await _supabase.from(_tabela).delete().eq('id', id).select('id');
      if ((apagados as List).isEmpty) {
        throw Exception('Não foi possível apagar: modelo padrão ou sem permissão.');
      }
    } on PostgrestException catch (e) {
      throw Exception('Erro ao apagar modelo: ${e.message}');
    }
  }

  Future<void> atualizarInfo(String id, {required String nome, String? descricao}) async {
    try {
      await _supabase.from(_tabela).update({'nome': nome, 'descricao': descricao}).eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao atualizar modelo: ${e.message}');
    }
  }

  Future<ModeloRdoModel> buscarPorId(String id) async {
    try {
      final row = await _supabase.from(_tabela).select().eq('id', id).single();
      return ModeloRdoModel.fromJson(row);
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

  Future<ModeloRdoModel> duplicarModelo(ModeloRdoModel original, String empresaId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final row = await _supabase.from(_tabela).insert({
        'empresa_id': empresaId,
        'nome': '${original.nome} (cópia)',
        'descricao': original.descricao,
        'criado_por': userId,
        'schema_json': original.schemaJson,
      }).select().single();
      return ModeloRdoModel.fromJson(row);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao duplicar modelo: ${e.message}');
    }
  }
}
