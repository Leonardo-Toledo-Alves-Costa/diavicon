// Padrão de legenda (timestamp) que a empresa aplica sobre as fotos
// registradas nas inspeções visuais e na galeria geral de ensaios.
// Espelha a tabela `empresa_timestamp_fotos_padrao` no Supabase.

const List<String> posicoesLegendaFoto = [
  'Superior esquerdo',
  'Superior direito',
  'Inferior esquerdo',
  'Inferior direito',
  'Centro',
];

const List<String> coresLegendaFoto = [
  'Branco',
  'Preto',
  'Amarelo',
  'Vermelho',
];

class TimestampFotoPadraoModel {
  final String? id;
  final String empresaId;
  final String posicaoLegenda;
  final int tamanho;
  final String cor;
  final bool projeto;
  final bool estrutura;
  final bool conjuntoEstrutural;
  final bool local;
  final bool sistema;
  final bool tipoElemento;
  final bool elemento;
  final bool data;
  final bool hora;
  final bool nomeEmpresa;
  final bool logo;
  final bool nomeUser;
  final bool latitudeLongitude;
  final bool descricao;

  const TimestampFotoPadraoModel({
    this.id,
    required this.empresaId,
    this.posicaoLegenda = 'Inferior direito',
    this.tamanho = 12,
    this.cor = 'Branco',
    this.projeto = false,
    this.estrutura = false,
    this.conjuntoEstrutural = false,
    this.local = false,
    this.sistema = false,
    this.tipoElemento = false,
    this.elemento = false,
    this.data = false,
    this.hora = false,
    this.nomeEmpresa = false,
    this.logo = false,
    this.nomeUser = false,
    this.latitudeLongitude = false,
    this.descricao = false,
  });

  // Verdadeiro se pelo menos um campo de legenda estiver habilitado.
  bool get temAlgumCampoAtivo =>
      projeto ||
      estrutura ||
      conjuntoEstrutural ||
      local ||
      sistema ||
      tipoElemento ||
      elemento ||
      data ||
      hora ||
      nomeEmpresa ||
      logo ||
      nomeUser ||
      latitudeLongitude ||
      descricao;

  factory TimestampFotoPadraoModel.fromMap(Map<String, dynamic> map, String empresaId) {
    return TimestampFotoPadraoModel(
      id: map['id'] as String?,
      empresaId: map['empresa_id'] as String? ?? empresaId,
      posicaoLegenda: (map['posicao_legenda'] as String?)?.isNotEmpty == true
          ? map['posicao_legenda'] as String
          : 'Inferior direito',
      tamanho: (map['tamanho'] as num?)?.toInt() ?? 12,
      cor: (map['cor'] as String?)?.isNotEmpty == true ? map['cor'] as String : 'Branco',
      projeto: map['projeto'] as bool? ?? false,
      estrutura: map['estrutura'] as bool? ?? false,
      conjuntoEstrutural: map['conjunto_estrutural'] as bool? ?? false,
      local: map['local'] as bool? ?? false,
      sistema: map['sistema'] as bool? ?? false,
      tipoElemento: map['tipo_elemento'] as bool? ?? false,
      elemento: map['elemento'] as bool? ?? false,
      data: map['data'] as bool? ?? false,
      hora: map['hora'] as bool? ?? false,
      nomeEmpresa: map['nome_empresa'] as bool? ?? false,
      logo: map['logo'] as bool? ?? false,
      nomeUser: map['nome_user'] as bool? ?? false,
      latitudeLongitude: map['latitude_longitude'] as bool? ?? false,
      descricao: map['descricao'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'empresa_id': empresaId,
      'posicao_legenda': posicaoLegenda,
      'tamanho': tamanho,
      'cor': cor,
      'projeto': projeto,
      'estrutura': estrutura,
      'conjunto_estrutural': conjuntoEstrutural,
      'local': local,
      'sistema': sistema,
      'tipo_elemento': tipoElemento,
      'elemento': elemento,
      'data': data,
      'hora': hora,
      'nome_empresa': nomeEmpresa,
      'logo': logo,
      'nome_user': nomeUser,
      'latitude_longitude': latitudeLongitude,
      'descricao': descricao,
    };
  }

  TimestampFotoPadraoModel copyWith({
    String? id,
    String? posicaoLegenda,
    int? tamanho,
    String? cor,
    bool? projeto,
    bool? estrutura,
    bool? conjuntoEstrutural,
    bool? local,
    bool? sistema,
    bool? tipoElemento,
    bool? elemento,
    bool? data,
    bool? hora,
    bool? nomeEmpresa,
    bool? logo,
    bool? nomeUser,
    bool? latitudeLongitude,
    bool? descricao,
  }) {
    return TimestampFotoPadraoModel(
      id: id ?? this.id,
      empresaId: empresaId,
      posicaoLegenda: posicaoLegenda ?? this.posicaoLegenda,
      tamanho: tamanho ?? this.tamanho,
      cor: cor ?? this.cor,
      projeto: projeto ?? this.projeto,
      estrutura: estrutura ?? this.estrutura,
      conjuntoEstrutural: conjuntoEstrutural ?? this.conjuntoEstrutural,
      local: local ?? this.local,
      sistema: sistema ?? this.sistema,
      tipoElemento: tipoElemento ?? this.tipoElemento,
      elemento: elemento ?? this.elemento,
      data: data ?? this.data,
      hora: hora ?? this.hora,
      nomeEmpresa: nomeEmpresa ?? this.nomeEmpresa,
      logo: logo ?? this.logo,
      nomeUser: nomeUser ?? this.nomeUser,
      latitudeLongitude: latitudeLongitude ?? this.latitudeLongitude,
      descricao: descricao ?? this.descricao,
    );
  }
}

// Valores textuais já resolvidos (nomes reais) para compor a legenda de uma foto específica.
// Campos nulos/ausentes são simplesmente omitidos da legenda final.
class WatermarkFotoContexto {
  final String? nomeProjeto;
  final String? nomeEstrutura;
  final String? nomeConjuntoEstrutural;
  final String? nomeLocal;
  final String? nomeSistema;
  final String? nomeTipoElemento;
  final String? nomeElementoEspecifico;
  final String? nomeEmpresa;
  final String? logoUrl;
  final String? nomeUsuario;
  final double? latitude;
  final double? longitude;
  final String? descricaoImagem;
  final DateTime? capturadoEm;

  const WatermarkFotoContexto({
    this.nomeProjeto,
    this.nomeEstrutura,
    this.nomeConjuntoEstrutural,
    this.nomeLocal,
    this.nomeSistema,
    this.nomeTipoElemento,
    this.nomeElementoEspecifico,
    this.nomeEmpresa,
    this.logoUrl,
    this.nomeUsuario,
    this.latitude,
    this.longitude,
    this.descricaoImagem,
    this.capturadoEm,
  });

  WatermarkFotoContexto copyWith({String? descricaoImagem}) {
    return WatermarkFotoContexto(
      nomeProjeto: nomeProjeto,
      nomeEstrutura: nomeEstrutura,
      nomeConjuntoEstrutural: nomeConjuntoEstrutural,
      nomeLocal: nomeLocal,
      nomeSistema: nomeSistema,
      nomeTipoElemento: nomeTipoElemento,
      nomeElementoEspecifico: nomeElementoEspecifico,
      nomeEmpresa: nomeEmpresa,
      logoUrl: logoUrl,
      nomeUsuario: nomeUsuario,
      latitude: latitude,
      longitude: longitude,
      descricaoImagem: descricaoImagem ?? this.descricaoImagem,
      capturadoEm: capturadoEm,
    );
  }
}
