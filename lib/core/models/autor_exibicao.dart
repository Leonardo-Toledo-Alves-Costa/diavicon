/// Dados de autoria de um registro, no recorte que a tela pode mostrar.
///
/// Vem da função `autores_para_exibicao` — ver
/// supabase/migrations/20260917230500_autores_para_exibicao.sql. O recorte é
/// decidido no banco: [nome] e [fotoUrl] chegam nulos quando o usuário logado
/// não pertence à mesma empresa do autor, então a tela nunca precisa (nem
/// consegue) tomar essa decisão por conta própria.
class AutorExibicao {
  final String id;
  final String? empresaId;
  final String? empresaNome;
  final String? empresaLogoUrl;
  final String? nome;
  final String? fotoUrl;

  const AutorExibicao({
    required this.id,
    this.empresaId,
    this.empresaNome,
    this.empresaLogoUrl,
    this.nome,
    this.fotoUrl,
  });

  factory AutorExibicao.fromMap(Map<String, dynamic> map) => AutorExibicao(
        id: map['autor_id']?.toString() ?? '',
        empresaId: map['autor_empresa_id']?.toString(),
        empresaNome: _ouNulo(map['empresa_nome']),
        empresaLogoUrl: _ouNulo(map['empresa_logo_url']),
        nome: _ouNulo(map['autor_nome']),
        fotoUrl: _ouNulo(map['autor_foto_url']),
      );

  static String? _ouNulo(dynamic valor) {
    final texto = valor?.toString();
    return (texto == null || texto.isEmpty) ? null : texto;
  }

  bool get temLogoEmpresa => empresaLogoUrl != null;

  /// Só é verdadeiro pra quem é da mesma empresa do autor — o banco já
  /// apagou esses campos pros demais.
  bool get temAutorVisivel => fotoUrl != null || nome != null;
}
