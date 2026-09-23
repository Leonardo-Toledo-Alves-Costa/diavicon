// Uma foto genérica de relatório (URL + legenda) — usada pelos blocos de
// Galeria/Registros de qualquer ensaio. Cada ensaio resolve suas próprias
// fotos a partir das tabelas que tiver (ex: `InspecaoVisualReportData`
// usa `typedef FotoReal = FotoRelatorio` pra manter os nomes já usados lá).
class FotoRelatorio {
  final String url;
  final String descricao;
  const FotoRelatorio({required this.url, required this.descricao});
}
