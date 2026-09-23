/// Versões vigentes dos documentos legais e o canal de privacidade.
///
/// AO PUBLICAR UMA NOVA VERSÃO de um documento:
///   1. edite o .md em assets/legal/ (e a data no topo dele);
///   2. troque a versão aqui (formato AAAA-MM-DD);
///   3. regenere web/privacidade.html e web/termos.html no web app.
/// Quem já aceitou a versão antiga verá a tela de aceite de novo no próximo
/// acesso (ver ConsentimentoGate).
abstract final class DocumentosLegais {
  static const String versaoTermos = '2026-09-21';
  static const String versaoPrivacidade = '2026-09-21';

  /// Canal do titular (LGPD art. 41) — contato do Encarregado.
  static const String emailPrivacidade = 'contato@diavicon.com';

  static const String assetPrivacidade = 'assets/legal/politica_privacidade.md';
  static const String assetTermos = 'assets/legal/termos_uso.md';

  /// Páginas públicas (links das lojas de aplicativo e do rodapé do site).
  static const String urlPrivacidade = 'https://diavicon.com.br/app/privacidade.html';
  static const String urlTermos = 'https://diavicon.com.br/app/termos.html';
}

enum DocumentoLegal {
  privacidade('Política de Privacidade', DocumentosLegais.assetPrivacidade),
  termos('Termos de Uso', DocumentosLegais.assetTermos);

  final String titulo;
  final String asset;
  const DocumentoLegal(this.titulo, this.asset);
}
