/// Número no padrão brasileiro (1.234,56), com casas decimais proporcionais
/// à grandeza: velocidade em m/s não precisa de centésimos, coeficiente de
/// variação precisa.
String formatarNumeroBi(double? v) {
  if (v == null || v.isNaN || v.isInfinite) return '—';
  final abs = v.abs();
  final casas = abs >= 1000 ? 0 : (abs >= 100 ? 1 : 2);
  final partes = v.toStringAsFixed(casas).split('.');
  final negativo = partes[0].startsWith('-');
  final digitos = negativo ? partes[0].substring(1) : partes[0];
  final inteiro = digitos.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  final sinal = negativo ? '-' : '';
  return partes.length > 1 ? '$sinal$inteiro,${partes[1]}' : '$sinal$inteiro';
}

/// Ordena rótulos de grupo de forma natural ("V2" antes de "V10").
int compararRotulosBi(String a, String b) {
  final re = RegExp(r'(\d+)|(\D+)');
  final pa = re.allMatches(a).map((m) => m.group(0)!).toList();
  final pb = re.allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final na = int.tryParse(pa[i]);
    final nb = int.tryParse(pb[i]);
    final c = (na != null && nb != null) ? na.compareTo(nb) : pa[i].toLowerCase().compareTo(pb[i].toLowerCase());
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}
