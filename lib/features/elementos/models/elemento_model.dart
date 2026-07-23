import 'dart:convert';

/// Modelo de um elemento estrutural, espelhando a tabela
/// `elementos_estruturais` do Supabase.
class ElementoModel {
  final String id;
  final String? estruturaId;
  final String? nome;
  final String? tipo;
  final String? local;
  final String? tipologiaEstrutural; 
  final String? revestimento;
  final double? latitude;
  final double? longitude;
  final double? posicaoX;
  final double? posicaoY;
  final double? posicaoZ;
  final String? plantaId; 
  final String? tipoMarcacao;
  final String? dimensoes;
  final String? secao;
  final String? microclima;
  final String? caa;
  final List<String>? fotos;
  final String? observacoes;
  final bool? ativo;
  final DateTime? criadoEm;
  
  final double? marcacaoLargura;
  final double? marcacaoAltura;
  final double? marcacaoRotacao;
  final String? marcacaoCor;
  final double? marcacaoNomeX;
  final double? marcacaoNomeY;

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
    this.tipoMarcacao,
    this.dimensoes,
    this.secao,
    this.microclima,
    this.caa,
    this.fotos,
    this.observacoes,
    this.ativo,
    this.criadoEm,
    this.marcacaoLargura,
    this.marcacaoAltura,
    this.marcacaoRotacao, this.marcacaoCor, this.marcacaoNomeX, this.marcacaoNomeY, 
  });

  factory ElementoModel.fromMap(Map<String, dynamic> map) {
    List<String>? fotosParseadas;
    if (map['fotos'] != null) {
      if (map['fotos'] is List) {
        fotosParseadas = (map['fotos'] as List).map((e) => e.toString()).toList();
      } else if (map['fotos'] is String) {
        try {
          final decoded = jsonDecode(map['fotos']);
          if (decoded is List) {
            fotosParseadas = decoded.map((e) => e.toString()).toList();
          } else {
            fotosParseadas = [map['fotos']];
          }
        } catch (_) {
          fotosParseadas = [map['fotos']]; 
        }
      }
    }

    return ElementoModel(
      id: map['id'] ?? '',
      estruturaId: map['estrutura_id'],
      nome: map['nome'],
      tipo: map['tipo'],
      local: map['local'],
      tipologiaEstrutural: map['topologia'],
      revestimento: map['revestimento'],
      latitude: map['latitude'] != null ? double.tryParse(map['latitude'].toString()) : null,
      longitude: map['longitude'] != null ? double.tryParse(map['longitude'].toString()) : null,
      posicaoX: map['posicao_x'] != null ? double.tryParse(map['posicao_x'].toString()) : null,
      posicaoY: map['posicao_y'] != null ? double.tryParse(map['posicao_y'].toString()) : null,
      posicaoZ: map['posicao_z'] != null ? double.tryParse(map['posicao_z'].toString()) : null,
      plantaId: map['planta_id'],
      tipoMarcacao: map['tipo_markup'] ?? map['tipo_marcacao'],
      dimensoes: map['dimensoes'],
      secao: map['secao'],
      microclima: map['microclima'],
      caa: map['caa'],
      fotos: fotosParseadas, 
      observacoes: map['observacoes'],
      ativo: map['ativo'], 
      criadoEm: map['criado_em'] != null ? DateTime.parse(map['criado_em'].toString()) : null,
      marcacaoLargura: map['marcacao_largura'] != null ? double.tryParse(map['marcacao_largura'].toString()) : null,
      marcacaoAltura: map['marcacao_altura'] != null ? double.tryParse(map['marcacao_altura'].toString()) : null,
      marcacaoRotacao: map['marcacao_rotacao'] != null ? double.tryParse(map['marcacao_rotacao'].toString()) : null,
      marcacaoCor: map['marcacao_cor']?.toString(),
      marcacaoNomeX: map['marcacao_nome_x'] != null ? double.tryParse(map['marcacao_nome_x'].toString()) : null,
      marcacaoNomeY: map['marcacao_nome_y'] != null ? double.tryParse(map['marcacao_nome_y'].toString()) : null,
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
      if (tipoMarcacao != null) 'tipo_marcacao': tipoMarcacao, 
      if (dimensoes != null) 'dimensoes': dimensoes,
      if (secao != null) 'secao': secao,
      if (microclima != null) 'microclima': microclima,
      if (caa != null) 'caa': caa,
      if (fotos != null) 'fotos': fotos,
      if (observacoes != null) 'observacoes': observacoes,
      if (ativo != null) 'ativo': ativo,
      if (marcacaoLargura != null) 'marcacao_largura': marcacaoLargura,
      if (marcacaoAltura != null) 'marcacao_altura': marcacaoAltura,
      if (marcacaoRotacao != null) 'marcacao_rotacao': marcacaoRotacao, 
      if (marcacaoCor != null) 'marcacao_cor': marcacaoCor,
      if (marcacaoNomeX != null) 'marcacao_nome_x': marcacaoNomeX,
      if (marcacaoNomeY != null) 'marcacao_nome_y': marcacaoNomeY,
    };
  }
}