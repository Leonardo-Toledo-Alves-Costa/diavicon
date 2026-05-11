class EstruturaModel {
  final String id;
  final String? nome;
  final String? tipo;
  final String? descricao;
  final DateTime? criadoEm;
  final String? imageUrl;
  final String? caa;
  final int? idadeAnos;
  final String? conjuntoEstrutural;
  final String? utilizacao;
  final String? tipologiaEstrutural;
  final double? latitude;
  final double? longitude;
  final String? cep;
  final String? endereco;
  final String? cidade;
  final String? numero;
  final String? pais;
  final String? uf;
  final String? status;

  EstruturaModel({
    required this.id,
    this.nome,
    this.tipo,
    this.descricao,
    this.criadoEm,
    this.imageUrl,
    this.caa,
    this.idadeAnos,
    this.conjuntoEstrutural,
    this.utilizacao,
    this.tipologiaEstrutural,
    this.latitude,
    this.longitude,
    this.cep,
    this.endereco,
    this.cidade,
    this.numero,
    this.pais,
    this.uf,
    this.status,
  });

  // Converte o JSON que vem do Supabase em um Objeto Dart
  factory EstruturaModel.fromMap(Map<String, dynamic> map) {
    return EstruturaModel(
      id: map['id'] ?? '',
      nome: map['nome'],
      tipo: map['tipo'],
      descricao: map['descricao'],
      criadoEm: map['criado_em'] != null ? DateTime.parse(map['criado_em'].toString()) : null,
      imageUrl: map['image_url'],
      caa: map['caa'],
      // Usamos num.tryParse para evitar erros caso o banco devolva um número como texto
      idadeAnos: map['idade_anos'] != null ? int.tryParse(map['idade_anos'].toString()) : null,
      conjuntoEstrutural: map['conjunto_estrutural'],
      utilizacao: map['utilizacao'],
      tipologiaEstrutural: map['tipologia_estrutural'],
      latitude: map['latitude'] != null ? double.tryParse(map['latitude'].toString()) : null,
      longitude: map['longitude'] != null ? double.tryParse(map['longitude'].toString()) : null,
      cep: map['cep'],
      endereco: map['endereco'],
      cidade: map['cidade'],
      numero: map['numero'],
      pais: map['pais'],
      uf: map['uf'],
      status: map['status'] ?? 'Pendente',
    );
  }

  // Converte o Objeto Dart em JSON para enviar ao Supabase
  Map<String, dynamic> toMap() {
    return {
      // Usamos o 'if' para só enviar o dado se ele não for nulo. 
      if (id.isNotEmpty) 'id': id,
      if (nome != null) 'nome': nome,
      if (tipo != null) 'tipo': tipo,
      if (descricao != null) 'descricao': descricao,
      if (imageUrl != null) 'image_url': imageUrl,
      if (caa != null) 'caa': caa,
      if (idadeAnos != null) 'idade_anos': idadeAnos,
      if (conjuntoEstrutural != null) 'conjunto_estrutural': conjuntoEstrutural,
      if (utilizacao != null) 'utilizacao': utilizacao,
      if (tipologiaEstrutural != null) 'tipologia_estrutural': tipologiaEstrutural,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (cep != null) 'cep': cep,
      if (endereco != null) 'endereco': endereco,
      if (cidade != null) 'cidade': cidade,
      if (numero != null) 'numero': numero,
      if (pais != null) 'pais': pais,
      if (uf != null) 'uf': uf,
      if (status != null) 'status': status,
      
      //criado_em preenchido automaticamente pelo supabase
    };
  }
}