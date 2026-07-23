class EstruturaModel {
  final String id;
  final String? nome;
  final String? descricao;
  final DateTime? criadoEm;
  final String? caa;
  final int? anoConcepcao;
  final double? latitude;
  final double? longitude;
  final String? cep;
  final String? endereco;
  final String? cidade;
  final String? numero;
  final String? pais;
  final String? uf;
  final String? status;
  final String? imageUrl;
  final String? userId;
  final String? empresaGestoraId;
  final String? projetoId;

  final String? conjuntoNome;
  final String? utilizacaoNome;
  final String? tipoNome;
  final String? tipologiaNome;

  final String? conjuntoEstruturalId;
  final String? utilizacaoId;
  final String? tipoId;
  final String? tipologiaId;

  final String? proprietariaId;

  // calculo idade
  String get idadeCalculada {
    if (anoConcepcao == null) return '-';
    final anoAtual = DateTime.now().year;
    final idade = anoAtual - anoConcepcao!;
    return idade < 0 ? '0' : idade.toString(); // Proteção caso digitem um ano no futuro
  }

  EstruturaModel({
    required this.id,
    this.nome,
    this.empresaGestoraId,
    this.descricao,
    this.criadoEm,
    this.caa,
    this.anoConcepcao,
    this.latitude,
    this.longitude,
    this.cep,
    this.endereco,
    this.cidade,
    this.numero,
    this.pais,
    this.uf,
    this.status,
    this.imageUrl,
    this.userId,
    this.projetoId,
    this.conjuntoEstruturalId,
    this.utilizacaoId,
    this.tipoId,
    this.tipologiaId,
    this.proprietariaId,
    this.conjuntoNome,
    this.tipoNome,
    this.tipologiaNome,
    this.utilizacaoNome,
  });

  factory EstruturaModel.fromJson(Map<String, dynamic> json) {
    final conjuntoData = json['conjuntos_estruturais'] as Map<String, dynamic>?;
    final utilizacaoData = json['utilizacoes_estrutura'] as Map<String, dynamic>?;
    final tipoData = json['tipos_estrutura'] as Map<String, dynamic>?;
    final tipologiaData = json['tipologias_estrutura'] as Map<String, dynamic>?;
    return EstruturaModel(
      id: json['id'] as String,
      nome: json['nome'] as String?,
      descricao: json['descricao'] as String?,
      criadoEm: json['criado_em'] != null
          ? DateTime.parse(json['criado_em'])
          : null,
      caa: json['caa'] as String?,
      anoConcepcao: json['ano_concepcao'] as int?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      cep: json['cep'] as String?,
      endereco: json['endereco'] as String?,
      cidade: json['cidade'] as String?,
      numero: json['numero'] as String?,
      pais: json['pais'] as String?,
      uf: json['uf'] as String?,
      status: json['status'] as String?,
      imageUrl: json['image_url'] as String?,
      userId: json['user_id'] as String?,
      projetoId: json['projeto_id'] as String?,
      empresaGestoraId: json['empresa_gestora_id'] as String?,
      conjuntoEstruturalId: json['conjunto_estrutural_id'] as String?,
      utilizacaoId: json['utilizacao_id'] as String?,
      tipoId: json['tipo_id'] as String?,
      tipologiaId: json['tipologia_id'] as String?,
      proprietariaId: json['proprietaria_id'] as String?,
      conjuntoNome: conjuntoData?['nome'],
      utilizacaoNome: utilizacaoData?['nome'],
      tipoNome: tipoData?['nome'],
      tipologiaNome: tipologiaData?['nome'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'nome': nome,
      'descricao': descricao,
      'criado_em': criadoEm?.toIso8601String(),
      'caa': caa,
      'ano_concepcao': anoConcepcao,
      'latitude': latitude,
      'longitude': longitude,
      'cep': cep,
      'endereco': endereco,
      'cidade': cidade,
      'numero': numero,
      'pais': pais,
      'uf': uf,
      'status': status,
      'image_url': imageUrl,
      'user_id': userId,
      'empresa_gestora_id': empresaGestoraId,
      'conjunto_estrutural_id': conjuntoEstruturalId,
      'utilizacao_id': utilizacaoId,
      'tipo_id': tipoId,
      'tipologia_id': tipologiaId,
      'proprietaria_id': proprietariaId,
    };

    if (id.isNotEmpty) {
      map['id'] = id;
    }

    return map;
  }
}
