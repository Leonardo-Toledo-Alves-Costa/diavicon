import 'dart:convert';

class RelatorioEnsaioModel {
  final String id;
  final DateTime criadoEm;
  final String? criadoPor;
  final String? nomeRelatorio; // Extraído do conteudo json
  final Map<String, dynamic> conteudo;
  final String status;
  final String? anexo;
  final String projetoId;
  final String estruturaId;
  final String tipoEnsaioId;
  final String categoria;

  RelatorioEnsaioModel({
    required this.id,
    required this.criadoEm,
    this.criadoPor,
    this.nomeRelatorio,
    required this.conteudo,
    required this.status,
    this.anexo,
    required this.projetoId,
    required this.estruturaId,
    required this.tipoEnsaioId,
    required this.categoria,
  });

  factory RelatorioEnsaioModel.fromMap(Map<String, dynamic> map) {
    // Decodifica o campo 'conteudo' (armazenado como texto no banco) para um Map
    Map<String, dynamic> parsedConteudo = {};
    if (map['conteudo'] != null && map['conteudo'].toString().isNotEmpty) {
      try {
        parsedConteudo = jsonDecode(map['conteudo']);
      } catch (e) {
        parsedConteudo = {};
      }
    }

    return RelatorioEnsaioModel(
      id: map['id'] ?? '',
      criadoEm: DateTime.parse(map['criado_em']),
      criadoPor: map['criado_por'],
      nomeRelatorio: parsedConteudo['nome_relatorio'] ?? 'Relatório sem nome',
      conteudo: parsedConteudo,
      status: map['status'] ?? 'Gerando',
      anexo: map['anexo'],
      projetoId: map['projeto_id'] ?? '',
      estruturaId: map['estrutura_id'] ?? '',
      tipoEnsaioId: map['tipo_ensaio_id'] ?? '',
      categoria: map['categoria']??''
    );
  }
}