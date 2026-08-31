import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'campos_personalizaveis_provider.dart';

/// Opções fixas da coluna `anomalias.categoria`, usadas tanto no formulário
/// de cadastro quanto no filtro por badges da listagem.
const List<String> categoriaAnomaliaOpcoes = [
  'durabilidade',
  'integridade',
  'desempenho',
  'qualidade',
  'habitabilidade',
];

class AnomaliaModel {
  final String id;
  final DateTime? criadoEm;
  final String? criadoPor;
  final String nome;
  final String? descricao;
  final String? gravidadeValor;
  final String? gravidadeDescricao;
  final String? urgenciaValor;
  final String? urgenciaDescricao;
  final String? tendenciaValor;
  final String? tendenciaDescricao;
  final String? sistemaConstrutivo;
  final String? categoria;
  final String? riscoTipo;
  final String? riscoDescricao;
  final String? riscoValor;
  final String? riscoMajor;
  final String? empresaId;

  AnomaliaModel({
    required this.id,
    this.criadoEm,
    this.criadoPor,
    required this.nome,
    this.descricao,
    this.gravidadeValor,
    this.gravidadeDescricao,
    this.urgenciaValor,
    this.urgenciaDescricao,
    this.tendenciaValor,
    this.tendenciaDescricao,
    this.sistemaConstrutivo,
    this.categoria,
    this.riscoTipo,
    this.riscoDescricao,
    this.riscoValor,
    this.riscoMajor,
    this.empresaId,
  });

  factory AnomaliaModel.fromMap(Map<String, dynamic> map) {
    return AnomaliaModel(
      id: map['id'].toString(),
      criadoEm: map['criado_em'] != null
          ? DateTime.tryParse(map['criado_em'].toString())
          : null,
      criadoPor: map['criado_por']?.toString(),
      nome: map['nome']?.toString() ?? '',
      descricao: map['descricao']?.toString(),
      gravidadeValor: map['gravidade_valor']?.toString(),
      gravidadeDescricao: map['gravidade_descricao']?.toString(),
      urgenciaValor: map['urgencia_valor']?.toString(),
      urgenciaDescricao: map['urgencia_descricao']?.toString(),
      tendenciaValor: map['tendencia_valor']?.toString(),
      tendenciaDescricao: map['tendencia_descricao']?.toString(),
      sistemaConstrutivo: map['sistema_construtivo']?.toString(),
      categoria: map['categoria']?.toString(),
      riscoTipo: map['risco_tipo']?.toString(),
      riscoDescricao: map['risco_descricao']?.toString(),
      riscoValor: map['risco_valor']?.toString(),
      riscoMajor: map['risco_major']?.toString(),
      empresaId: map['empresa_id']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'descricao': descricao,
      'gravidade_valor': gravidadeValor,
      'gravidade_descricao': gravidadeDescricao,
      'urgencia_valor': urgenciaValor,
      'urgencia_descricao': urgenciaDescricao,
      'tendencia_valor': tendenciaValor,
      'tendencia_descricao': tendenciaDescricao,
      'sistema_construtivo': sistemaConstrutivo,
      'categoria': categoria,
      'risco_tipo': riscoTipo,
      'risco_descricao': riscoDescricao,
      'risco_valor': riscoValor,
      'risco_major': riscoMajor,
      'empresa_id': empresaId,
    };
  }

  bool isPadrao() => empresaId == DIAVICON_EMPRESA_ID;

  bool canEdit(String currentEmpresaId) {
    if (currentEmpresaId == DIAVICON_EMPRESA_ID) return true;
    return !isPadrao() && empresaId == currentEmpresaId;
  }
}

final anomaliasListProvider = FutureProvider.family
    .autoDispose<List<AnomaliaModel>, String>((ref, empresaId) async {
  try {
    final response = await Supabase.instance.client
        .from('anomalias')
        .select('*')
        .or('empresa_id.eq.$empresaId, empresa_id.eq.$DIAVICON_EMPRESA_ID')
        .order('nome', ascending: true);

    var lista = response.map((e) => AnomaliaModel.fromMap(e)).toList();

    lista = lista.where((item) {
      return item.empresaId == empresaId || item.isPadrao();
    }).toList();

    return lista;
  } on PostgrestException catch (e) {
    throw Exception('Erro de banco de dados ao carregar anomalias: ${e.message}');
  } on AuthException catch (e) {
    throw Exception('Erro de autenticação: ${e.message}');
  } catch (e) {
    throw Exception('Erro inesperado: $e');
  }
});
