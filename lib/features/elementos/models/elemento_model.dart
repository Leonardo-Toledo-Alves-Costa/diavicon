/// Modelo de um elemento estrutural, espelhando a tabela
/// `elementos_estruturais` do Supabase.
class ElementoModel {
  final String id;
  final String? estruturaId;
  final String? nome;
  final String? tipo;
  final String? local;
  final String? tipologiaEstrutural; // DB: "topologia"
  final String? revestimento;
  final double? latitude;
  final double? longitude;
  final double? posicaoX;
  final double? posicaoY;
  final double? posicaoZ;
  final String? plantaId; 
  final String? tipoMarcacao; // 🔥 NOVO: Recebe o tipo da marcação (Retângulo, Círculo, Ponto)
  final String? dimensoes;
  final String? secao;
  final String? microclima;
  final String? caa;
  final List<String>? fotos;
  final String? observacoes;
  final bool? ativo;
  final DateTime? criadoEm;

  ElementoModel({
    required this.id,
    this.estruturaId,
    this.nome,
    this.tipo,
    this.local,
    this.tipologiaEstrutural,
    this.revestimento,
    this.latitude,
    this.longitude,
    this.posicaoX,
    this.posicaoY,
    this.posicaoZ,
    this.plantaId,
    this.tipoMarcacao, // 🔥 NOVO
    this.dimensoes,
    this.secao,
    this.microclima,
    this.caa,
    this.fotos,
    this.observacoes,
    this.ativo,
    this.criadoEm,
  });

  factory ElementoModel.fromMap(Map<String, dynamic> map) {
    return ElementoModel(
      id: map['id'] ?? '',
      estruturaId: map['estrutura_id'],
      nome: map['nome'],
      tipo: map['tipo'],
      local: map['local'],
      tipologiaEstrutural: map['topologia'],
      revestimento: map['revestimento'],
      latitude: map['latitude'] != null
          ? double.tryParse(map['latitude'].toString())
          : null,
      longitude: map['longitude'] != null
          ? double.tryParse(map['longitude'].toString())
          : null,
      posicaoX: map['posicao_x'] != null
          ? double.tryParse(map['posicao_x'].toString())
          : null,
      posicaoY: map['posicao_y'] != null
          ? double.tryParse(map['posicao_y'].toString())
          : null,
      posicaoZ: map['posicao_z'] != null
          ? double.tryParse(map['posicao_z'].toString())
          : null,
      plantaId: map['planta_id'],
      tipoMarcacao: map['tipo_marcacao'], // 🔥 NOVO: Lê do banco
      dimensoes: map['dimensoes'],
      secao: map['secao'],
      microclima: map['microclima'],
      caa: map['caa'],
      fotos: map['fotos'] != null
          ? (map['fotos'] as List).map((e) => e.toString()).toList()
          : null,
      observacoes: map['observacoes'],
      ativo: map['ativo'],
      criadoEm: map['criado_em'] != null
          ? DateTime.parse(map['criado_em'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      if (estruturaId != null) 'estrutura_id': estruturaId,
      if (nome != null) 'nome': nome,
      if (tipo != null) 'tipo': tipo,
      if (local != null) 'local': local,
      if (tipologiaEstrutural != null) 'topologia': tipologiaEstrutural,
      if (revestimento != null) 'revestimento': revestimento,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (posicaoX != null) 'posicao_x': posicaoX,
      if (posicaoY != null) 'posicao_y': posicaoY,
      if (posicaoZ != null) 'posicao_z': posicaoZ,
      if (plantaId != null) 'planta_id': plantaId,
      if (tipoMarcacao != null) 'tipo_marcacao': tipoMarcacao, // 🔥 NOVO: Envia para o banco
      if (dimensoes != null) 'dimensoes': dimensoes,
      if (secao != null) 'secao': secao,
      if (microclima != null) 'microclima': microclima,
      if (caa != null) 'caa': caa,
      if (fotos != null) 'fotos': fotos,
      if (observacoes != null) 'observacoes': observacoes,
      if (ativo != null) 'ativo': ativo,
    };
  }
}