// Modelos do módulo de Gastos, mapeados para as tabelas EXATAMENTE como
// estão no Supabase (criadas pelo painel):
//
//   categoria_gastos: id, criado_em, empresa_id, nome, descricao
//   gastos:           id, criado_em, criado_por, projeto_id, empresa_id,
//                     categoria, reembolsavel, valor (bigint), meio,
//                     anexo_url, anexo_tipo
//
// Convenções que isso impõe:
//   * `valor` é bigint → gravado em CENTAVOS (R$ 48,50 = 4850).
//   * Não há coluna de data do gasto → a data escolhida no formulário vai em
//     `criado_em` (meio-dia no horário local, para não virar o dia no UTC).
//   * Não há descrição nem status de reembolso no gasto.
//   * Não há RLS nessas tabelas: o sigilo por empresa é aplicado nas
//     consultas do GastosRepository.

enum MeioPagamento {
  boleto('boleto', 'Boleto'),
  aVista('a_vista', 'À vista'),
  credito('credito', 'Crédito');

  final String valorBanco;
  final String rotulo;
  const MeioPagamento(this.valorBanco, this.rotulo);

  static MeioPagamento deBanco(String? valor) =>
      MeioPagamento.values.firstWhere((m) => m.valorBanco == valor, orElse: () => MeioPagamento.credito);
}

enum TipoAnexoGasto {
  foto('foto'),
  pdf('pdf');

  final String valorBanco;
  const TipoAnexoGasto(this.valorBanco);

  static TipoAnexoGasto? deBanco(String? valor) {
    for (final t in TipoAnexoGasto.values) {
      if (t.valorBanco == valor) return t;
    }
    return null;
  }
}

class CategoriaGastoModel {
  final String id;
  final String empresaId;
  final String nome;

  const CategoriaGastoModel({required this.id, required this.empresaId, required this.nome});

  factory CategoriaGastoModel.fromMap(Map<String, dynamic> m) => CategoriaGastoModel(
        id: m['id'].toString(),
        empresaId: m['empresa_id']?.toString() ?? '',
        nome: (m['nome'] ?? '').toString(),
      );
}

class GastoModel {
  final String id;
  final String empresaId;
  final String usuarioId;
  final String usuarioNome;
  final String projetoId;
  final String projetoNome;
  final String categoriaId;
  final String categoriaNome;
  final bool reembolsavel;

  /// Em reais (a conversão de/para centavos fica só aqui no modelo).
  final double valor;
  final DateTime data;
  final MeioPagamento meioPagamento;

  /// URL pública do comprovante (bucket `projetos`, pasta `gastos/`).
  final String? anexoUrl;
  final TipoAnexoGasto? anexoTipo;

  const GastoModel({
    required this.id,
    required this.empresaId,
    required this.usuarioId,
    required this.usuarioNome,
    required this.projetoId,
    required this.projetoNome,
    required this.categoriaId,
    required this.categoriaNome,
    required this.reembolsavel,
    required this.valor,
    required this.data,
    required this.meioPagamento,
    this.anexoUrl,
    this.anexoTipo,
  });

  /// Colunas + joins usados em todas as consultas de gastos.
  static const String selectPadrao =
      '*, projetos(nome), categoria_gastos(nome), usuarios(nome, sobrenome)';

  factory GastoModel.fromMap(Map<String, dynamic> m) {
    final usuario = m['usuarios'] as Map<String, dynamic>?;
    final nomeUsuario = [usuario?['nome'], usuario?['sobrenome']]
        .where((p) => p != null && p.toString().trim().isNotEmpty)
        .join(' ')
        .trim();
    final centavos = num.tryParse('${m['valor']}') ?? 0;
    return GastoModel(
      id: m['id'].toString(),
      empresaId: m['empresa_id']?.toString() ?? '',
      usuarioId: m['criado_por']?.toString() ?? '',
      usuarioNome: nomeUsuario.isEmpty ? 'Usuário' : nomeUsuario,
      projetoId: m['projeto_id']?.toString() ?? '',
      projetoNome: ((m['projetos'] as Map<String, dynamic>?)?['nome'] ?? 'Projeto').toString(),
      categoriaId: m['categoria']?.toString() ?? '',
      categoriaNome: ((m['categoria_gastos'] as Map<String, dynamic>?)?['nome'] ?? 'Sem categoria').toString(),
      reembolsavel: m['reembolsavel'] == true,
      valor: centavos / 100,
      data: (DateTime.tryParse('${m['criado_em']}') ?? DateTime.now()).toLocal(),
      meioPagamento: MeioPagamento.deBanco(m['meio']?.toString()),
      anexoUrl: m['anexo_url']?.toString(),
      anexoTipo: TipoAnexoGasto.deBanco(m['anexo_tipo']?.toString()),
    );
  }

  /// Só o autor edita/exclui — o admin vê os gastos da empresa, mas não
  /// altera os de terceiros.
  bool podeEditar(String? usuarioLogadoId) => usuarioLogadoId != null && usuarioLogadoId == usuarioId;

  static int paraCentavos(double reais) => (reais * 100).round();

  /// Meio-dia local → UTC. Gravar à meia-noite faria o dia "voltar" um em
  /// quem lê o timestamp em outro fuso.
  static String dataParaCriadoEm(DateTime d) => DateTime(d.year, d.month, d.day, 12).toUtc().toIso8601String();

  /// Campos editáveis gravados pelo app (dono e empresa entram no insert, no
  /// repositório).
  static Map<String, dynamic> dadosParaGravar({
    required String projetoId,
    required String categoriaId,
    required bool reembolsavel,
    required double valor,
    required DateTime data,
    required MeioPagamento meioPagamento,
    String? anexoUrl,
    TipoAnexoGasto? anexoTipo,
  }) =>
      {
        'projeto_id': projetoId,
        'categoria': categoriaId,
        'reembolsavel': reembolsavel,
        'valor': paraCentavos(valor),
        'criado_em': dataParaCriadoEm(data),
        'meio': meioPagamento.valorBanco,
        'anexo_url': anexoUrl,
        'anexo_tipo': anexoTipo?.valorBanco,
      };

  static String dataIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
