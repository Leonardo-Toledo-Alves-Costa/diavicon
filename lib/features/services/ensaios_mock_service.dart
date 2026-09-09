class EnsaioHistorico {
  final String data;
  final String empresa;
  final String descricao;

  const EnsaioHistorico({
    required this.data,
    required this.empresa,
    required this.descricao,
  });
}

class EnsaiosMockService {
  static const List<EnsaioHistorico> _ensaios = [
    EnsaioHistorico(
      data: '22/03/2026',
      empresa: 'Empresa Execução',
      descricao: 'Ensaio de compactação - Solo tipo A',
    ),
    EnsaioHistorico(
      data: '22/03/2026',
      empresa: 'Empresa Execução',
      descricao: 'Ensaio de resistência à compressão - Concreto CP-05',
    ),
    EnsaioHistorico(
      data: '02/02/2026',
      empresa: 'Empresa Execução',
      descricao: 'Ensaio de umidade - Aterro setor 2',
    ),
  ];

  static List<String> buscarPorData(String data, {String? empresa}) {
    return _ensaios
        .where((e) => e.data == data && (empresa == null || e.empresa == empresa))
        .map((e) => e.descricao)
        .toList();
  }
}