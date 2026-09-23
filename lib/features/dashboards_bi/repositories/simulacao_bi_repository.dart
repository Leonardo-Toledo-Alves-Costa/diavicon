import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../models/monte_carlo_bi_model.dart';

/// Um modelo de simulação da biblioteca da empresa (`simulacao_bi`).
class SimulacaoBiModel {
  final String id;
  final String empresaId;
  final String? criadoPor;
  final String nome;
  final String? descricao;
  final ConfigMonteCarloBi configuracao;
  final String? simulacaoOrigemId;

  const SimulacaoBiModel({
    required this.id,
    required this.empresaId,
    required this.nome,
    required this.configuracao,
    this.criadoPor,
    this.descricao,
    this.simulacaoOrigemId,
  });

  factory SimulacaoBiModel.fromMap(Map<String, dynamic> m) {
    final bruto = m['configuracao'];
    final cfg = bruto is String ? jsonDecode(bruto) : bruto;
    return SimulacaoBiModel(
      id: m['id'].toString(),
      empresaId: m['empresa_id'].toString(),
      criadoPor: m['criado_por']?.toString(),
      nome: m['nome']?.toString() ?? '',
      descricao: m['descricao']?.toString(),
      configuracao: cfg is Map ? ConfigMonteCarloBi.fromJson(cfg.cast<String, dynamic>()) : const ConfigMonteCarloBi(),
      simulacaoOrigemId: m['simulacao_origem_id']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'empresa_id': empresaId,
        if (criadoPor != null) 'criado_por': criadoPor,
        'nome': nome,
        'descricao': descricao,
        'configuracao': configuracao.toJson(),
        if (simulacaoOrigemId != null) 'simulacao_origem_id': simulacaoOrigemId,
      };
}

/// CRUD da biblioteca de simulações. Mesma postura de `variavel_bi`: lista
/// as da empresa mais as da DIAVICON (padrão, somente leitura).
class SimulacaoBiRepository {
  final SupabaseClient _s;
  SimulacaoBiRepository(this._s);

  Future<List<SimulacaoBiModel>> listar({required String empresaId}) async {
    final resp = await _s
        .from('simulacao_bi')
        .select('*')
        .or('empresa_id.eq.$empresaId,empresa_id.eq.$DIAVICON_EMPRESA_ID')
        .order('nome');
    return (resp as List).map((m) => SimulacaoBiModel.fromMap((m as Map).cast<String, dynamic>())).toList();
  }

  Future<String> criar(SimulacaoBiModel s) async {
    final resp = await _s.from('simulacao_bi').insert(s.toMap()).select('id').single();
    return resp['id'].toString();
  }

  Future<void> atualizar(String id, SimulacaoBiModel s) async {
    // O dono não muda.
    await _s.from('simulacao_bi').update(s.toMap()..remove('empresa_id')).eq('id', id);
  }

  Future<void> excluir(String id) async {
    await _s.from('simulacao_bi').delete().eq('id', id);
  }

  Future<String> duplicar(SimulacaoBiModel origem, {required String empresaId, required String? criadoPor}) => criar(
        SimulacaoBiModel(
          id: '',
          empresaId: empresaId,
          criadoPor: criadoPor,
          nome: '${origem.nome} (cópia)',
          descricao: origem.descricao,
          configuracao: origem.configuracao,
          simulacaoOrigemId: origem.id,
        ),
      );
}

final simulacaoBiRepositoryProvider = Provider<SimulacaoBiRepository>(
  (ref) => SimulacaoBiRepository(Supabase.instance.client),
);

final simulacoesBiProvider =
    FutureProvider.autoDispose.family<List<SimulacaoBiModel>, String>((ref, empresaId) async {
  return ref.read(simulacaoBiRepositoryProvider).listar(empresaId: empresaId);
});
