import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../models/variavel_bi_model.dart';

/// CRUD das variáveis derivadas (`variavel_bi`).
///
/// Mesma postura de `dashboard_modelos`: a listagem traz as variáveis da
/// própria empresa MAIS as da DIAVICON, que valem como padrão para todas e
/// são somente-leitura — quem quiser alterar duplica via [duplicar], e a
/// linhagem fica em `variavel_origem_id`.
class VariavelBiRepository {
  final SupabaseClient _s;
  VariavelBiRepository(this._s);

  Future<List<VariavelBiModel>> listar({required String empresaId}) async {
    final resp = await _s
        .from('variavel_bi')
        .select('*')
        .or('empresa_id.eq.$empresaId,empresa_id.eq.$DIAVICON_EMPRESA_ID')
        .order('nome');
    return (resp as List).map((m) => VariavelBiModel.fromMap((m as Map).cast<String, dynamic>())).toList();
  }

  Future<VariavelBiModel?> buscar(String id) async {
    final r = await _s.from('variavel_bi').select('*').eq('id', id).maybeSingle();
    return r == null ? null : VariavelBiModel.fromMap(r);
  }

  Future<String> criar(VariavelBiModel variavel) async {
    final resp = await _s.from('variavel_bi').insert(variavel.toMap()).select('id').single();
    return resp['id'].toString();
  }

  Future<void> atualizar(String id, VariavelBiModel variavel) async {
    // `empresa_id` fica de fora do update: o dono de uma variável não muda.
    final dados = variavel.toMap()..remove('empresa_id');
    await _s.from('variavel_bi').update(dados).eq('id', id);
  }

  Future<void> excluir(String id) async {
    await _s.from('variavel_bi').delete().eq('id', id);
  }

  /// Copia uma variável (tipicamente um padrão DIAVICON) para a empresa, que
  /// é como se recalibram os coeficientes sem tocar no original.
  Future<String> duplicar(
    VariavelBiModel origem, {
    required String empresaId,
    required String? criadoPor,
    String? novoNome,
  }) async {
    final copia = VariavelBiModel(
      id: '',
      empresaId: empresaId,
      criadoPor: criadoPor,
      nome: novoNome ?? '${origem.nome} (cópia)',
      unidade: origem.unidade,
      descricao: origem.descricao,
      expressao: origem.expressao,
      entradas: origem.entradas,
      parametros: origem.parametros,
      referencia: origem.referencia,
      valorMin: origem.valorMin,
      valorMax: origem.valorMax,
      variavelOrigemId: origem.id,
    );
    return criar(copia);
  }
}

final variavelBiRepositoryProvider = Provider<VariavelBiRepository>(
  (ref) => VariavelBiRepository(Supabase.instance.client),
);

/// Variáveis visíveis para a empresa (as dela + os padrões DIAVICON).
final variaveisBiProvider =
    FutureProvider.autoDispose.family<List<VariavelBiModel>, String>((ref, empresaId) async {
  return ref.read(variavelBiRepositoryProvider).listar(empresaId: empresaId);
});
