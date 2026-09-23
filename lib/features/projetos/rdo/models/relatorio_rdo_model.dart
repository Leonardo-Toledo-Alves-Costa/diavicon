import 'dart:convert';

// Uma linha de `relatorio_rdo` — status de geração de um relatório de RDO.
// Mesmo conceito de `RelatorioEnsaioModel` (ensaios): `conteudo` é `text`
// (não `jsonb`), então precisa de jsonEncode/jsonDecode manual; a coluna da
// empresa se chama `empresa_autora_id` (mesmo nome usado em
// `pontos_ensaios_geral`), não `empresa_id`.
class RelatorioRdoModel {
  final String id;
  final DateTime criadoEm;
  final String projetoId;
  final String empresaId;
  final Map<String, dynamic> conteudo;
  final String status;

  const RelatorioRdoModel({
    required this.id,
    required this.criadoEm,
    required this.projetoId,
    required this.empresaId,
    required this.conteudo,
    required this.status,
  });

  String get nomeRelatorio => conteudo['nome_relatorio']?.toString() ?? 'Relatório de RDO';
  String? get urlArquivo => conteudo['url_arquivo']?.toString();
  String get formato => conteudo['formato']?.toString() ?? 'pdf';
  String? get erro => conteudo['erro']?.toString();
  String? get data => conteudo['data']?.toString();
  String get projetoNome => conteudo['projeto_nome']?.toString() ?? 'Projeto';

  factory RelatorioRdoModel.fromMap(Map<String, dynamic> map) {
    final conteudoRaw = map['conteudo'];
    Map<String, dynamic> conteudo = const {};
    if (conteudoRaw is String && conteudoRaw.isNotEmpty) {
      try {
        conteudo = (jsonDecode(conteudoRaw) as Map).cast<String, dynamic>();
      } catch (_) {
        // Segue com conteúdo vazio se o texto salvo não for um JSON válido.
      }
    } else if (conteudoRaw is Map) {
      conteudo = conteudoRaw.cast<String, dynamic>();
    }

    return RelatorioRdoModel(
      id: map['id'].toString(),
      criadoEm: DateTime.tryParse(map['criado_em']?.toString() ?? '') ?? DateTime.now(),
      projetoId: map['projeto_id']?.toString() ?? '',
      empresaId: map['empresa_autora_id']?.toString() ?? '',
      conteudo: conteudo,
      status: map['status']?.toString() ?? 'Gerando',
    );
  }
}
