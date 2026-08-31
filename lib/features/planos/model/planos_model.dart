class PlanosModel {
  final String id;
  final String nome;
  final String descricao;
  final double valor;
  final int vigenciaDias;
  final int armazenamentoMb;
  final List<String>? features;

  final int qtdUser;
  final bool ads;
  final bool offline;
  final bool servicos;
  final bool rdoGastos;
  final bool monitor;
  final bool publicarFeedEdu;
  final bool gerarRelatorio;
  final bool chatIa;
  final int? tokensChat;
  final int? tokensRelatorio;
  final int? tokensPublicidade;
  final int? tokensEstrutura;

  PlanosModel({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.valor,
    required this.vigenciaDias,
    required this.armazenamentoMb,
    this.features,
    this.qtdUser = 1,
    this.ads = false,
    this.offline = false,
    this.servicos = false,
    this.rdoGastos = false,
    this.monitor = false,
    this.publicarFeedEdu = false,
    this.gerarRelatorio = false,
    this.chatIa = false,
    this.tokensChat,
    this.tokensRelatorio,
    this.tokensPublicidade,
    this.tokensEstrutura,
  });

  /// Plano-fallback usado quando a empresa não tem `plano_id` definido
  /// (estado "freemium" sem linha de catálogo associada) — tudo travado.
  factory PlanosModel.semPlano() {
    return PlanosModel(
      id: '',
      nome: 'Sem plano',
      descricao: 'Nenhum plano ativo para esta empresa.',
      valor: 0,
      vigenciaDias: 0,
      armazenamentoMb: 200,
      qtdUser: 1,
    );
  }

  // Converte o JSON do Supabase para o Objeto Dart
  factory PlanosModel.fromMap(Map<String, dynamic> map) {
    return PlanosModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      descricao: map['descricao'] ?? '',
      valor: map['valor'] != null ? (map['valor'] as num).toDouble() : 0.0,
      vigenciaDias: map['vigencia_dias'] ?? 0,
      armazenamentoMb: map['armazenamento_mb'] ?? 0,
      features: map['features'] != null
          ? List<String>.from(map['features'])
          : null,
      qtdUser: (map['qtd_user'] as num?)?.toInt() ?? 1,
      ads: map['ads'] ?? false,
      offline: map['offline'] ?? false,
      servicos: map['servicos'] ?? false,
      rdoGastos: map['rdo_gastos'] ?? false,
      monitor: map['monitor'] ?? false,
      publicarFeedEdu: map['publicar_feed_edu'] ?? false,
      gerarRelatorio: map['gerar_relatorio'] ?? false,
      chatIa: map['chat_ia'] ?? false,
      tokensChat: (map['tokens_chat'] as num?)?.toInt(),
      tokensRelatorio: (map['tokens_relatorio'] as num?)?.toInt(),
      tokensPublicidade: (map['tokens_publicidade'] as num?)?.toInt(),
      tokensEstrutura: (map['tokens_estrutura'] as num?)?.toInt(),
    );
  }

  // Converte o Objeto Dart para JSON
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'valor': valor,
      'vigencia_dias': vigenciaDias,
      'armazenamento_mb': armazenamentoMb,
      'features': features,
      'qtd_user': qtdUser,
      'ads': ads,
      'offline': offline,
      'servicos': servicos,
      'rdo_gastos': rdoGastos,
      'monitor': monitor,
      'publicar_feed_edu': publicarFeedEdu,
      'gerar_relatorio': gerarRelatorio,
      'chat_ia': chatIa,
      'tokens_chat': tokensChat,
      'tokens_relatorio': tokensRelatorio,
      'tokens_publicidade': tokensPublicidade,
      'tokens_estrutura': tokensEstrutura,
    };
  }

  PlanosModel copywith({
    String? id,
    String? nome,
    String? descricao,
    double? valor,
    int? vigenciaDias,
    int? armazenamentoMb,
    List<String>? features,
    int? qtdUser,
    bool? ads,
    bool? offline,
    bool? servicos,
    bool? rdoGastos,
    bool? monitor,
    bool? publicarFeedEdu,
    bool? gerarRelatorio,
    bool? chatIa,
    int? tokensChat,
    int? tokensRelatorio,
    int? tokensPublicidade,
  }) {
    return PlanosModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      valor: valor ?? this.valor,
      vigenciaDias: vigenciaDias ?? this.vigenciaDias,
      armazenamentoMb: armazenamentoMb ?? this.armazenamentoMb,
      features: features ?? this.features,
      qtdUser: qtdUser ?? this.qtdUser,
      ads: ads ?? this.ads,
      offline: offline ?? this.offline,
      servicos: servicos ?? this.servicos,
      rdoGastos: rdoGastos ?? this.rdoGastos,
      monitor: monitor ?? this.monitor,
      publicarFeedEdu: publicarFeedEdu ?? this.publicarFeedEdu,
      gerarRelatorio: gerarRelatorio ?? this.gerarRelatorio,
      chatIa: chatIa ?? this.chatIa,
      tokensChat: tokensChat ?? this.tokensChat,
      tokensRelatorio: tokensRelatorio ?? this.tokensRelatorio,
      tokensPublicidade: tokensPublicidade ?? this.tokensPublicidade,
    );
  }
}
