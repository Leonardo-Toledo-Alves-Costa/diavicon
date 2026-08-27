class FeedPostModel {
  final String id;
  final String usuarioId; 
  final String texto;
  final String tag;
  final bool patrocinado;
  final String? anexoNome;
  final String? anexoUrl;
  final DateTime criadoEm;
  final String usuarioNome;
  final String? usuarioFoto;
  final String empresaNome; 
  final String? empresaFoto; 
  final int totalLikes;
  final int totalComentarios;
  final bool userLiked;
  final List<String> fotos;

  FeedPostModel({
    required this.id,
    required this.usuarioId,
    required this.texto,
    required this.tag,
    required this.patrocinado,
    this.anexoNome,
    this.anexoUrl,
    required this.criadoEm,
    required this.usuarioNome,
    this.usuarioFoto,
    required this.empresaNome,
    this.empresaFoto,
    required this.totalLikes,
    required this.totalComentarios,
    required this.userLiked,
    required this.fotos,
  });

  factory FeedPostModel.fromMap(Map<String, dynamic> json) {
    String parsedUsuarioNome = 'Usuário';
    String? parsedUsuarioFoto;
    String parsedEmpresaNome = 'Empresa Desconhecida';
    String? parsedEmpresaFoto;

    if (json['usuarios'] != null && json['usuarios'] is Map) {
      final userMap = json['usuarios'];
      parsedUsuarioNome = userMap['nome'] ?? parsedUsuarioNome;
      parsedUsuarioFoto = userMap['foto_url'];

      if (userMap['empresas'] != null && userMap['empresas'] is Map) {
        final empresaMap = userMap['empresas'];
        parsedEmpresaNome = empresaMap['nome'] ?? parsedEmpresaNome;
        parsedEmpresaFoto = empresaMap['foto_url'];
      }
    }

    return FeedPostModel(
      id: json['id'],
      usuarioId: json['usuario_id'] ?? '',
      texto: json['texto'] ?? '',
      tag: json['tag'] ?? 'artigo',
      patrocinado: json['patrocinado'] ?? false,
      anexoNome: json['anexo_nome'],
      anexoUrl: json['anexo_url'],
      criadoEm: DateTime.tryParse(json['criado_em'].toString()) ?? DateTime.now(),
      usuarioNome: parsedUsuarioNome,
      usuarioFoto: parsedUsuarioFoto,
      empresaNome: parsedEmpresaNome,
      empresaFoto: parsedEmpresaFoto,
      totalLikes: json['total_likes'] ?? 0,
      totalComentarios: json['total_comentarios'] ?? 0,
      userLiked: json['user_liked'] ?? false,
      fotos: List<String>.from(json['fotos'] ?? []),
    );
  }

  FeedPostModel copyWith({
    String? texto,
    int? totalLikes,
    int? totalComentarios,
    bool? userLiked,
  }) {
    return FeedPostModel(
      id: id,
      usuarioId: usuarioId,
      texto: texto ?? this.texto,
      tag: tag,
      patrocinado: patrocinado,
      anexoNome: anexoNome,
      anexoUrl: anexoUrl,
      criadoEm: criadoEm,
      usuarioNome: usuarioNome,
      usuarioFoto: usuarioFoto,
      empresaNome: empresaNome,
      empresaFoto: empresaFoto,
      totalLikes: totalLikes ?? this.totalLikes,
      totalComentarios: totalComentarios ?? this.totalComentarios,
      userLiked: userLiked ?? this.userLiked,
      fotos: fotos,
    );
  }
}