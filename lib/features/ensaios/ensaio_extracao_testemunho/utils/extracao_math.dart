import '../models/extracao_model.dart';

/// Coeficientes de correção da ABNT NBR 7680-1:2015 (Seção 5.2) — fórmula
/// final em 6.2: fci,ext = [1 + (k1 + k2 + k3 + k4)] × fci,ext,inicial.
class ExtracaoMath {
  // Tabela 2 — k1 em função da relação h/d (interpolação linear permitida
  // entre os pontos; fora do intervalo, usa o extremo mais próximo — a
  // Norma só define o intervalo [1,00 – 2,00]).
  static const List<double> _tabelaHD = [2.00, 1.88, 1.75, 1.63, 1.50, 1.42, 1.33, 1.25, 1.21, 1.18, 1.14, 1.11, 1.07, 1.04, 1.00];
  static const List<double> _tabelaK1 = [0.00, -0.01, -0.02, -0.03, -0.04, -0.05, -0.06, -0.07, -0.08, -0.09, -0.10, -0.11, -0.12, -0.13, -0.14];

  static double _interpolar(double x, List<double> xs, List<double> ys) {
    // `xs` está em ordem DECRESCENTE (tabelas da Norma são assim).
    if (x >= xs.first) return ys.first;
    if (x <= xs.last) return ys.last;
    for (var i = 0; i < xs.length - 1; i++) {
      final x0 = xs[i], x1 = xs[i + 1];
      if (x <= x0 && x >= x1) {
        final y0 = ys[i], y1 = ys[i + 1];
        final t = (x - x0) / (x1 - x0);
        return y0 + t * (y1 - y0);
      }
    }
    return ys.last;
  }

  static double k1DeRelacaoHD(double hd) => _interpolar(hd, _tabelaHD, _tabelaK1);

  // Tabela 3 — k2 em função do diâmetro do testemunho (mm). Diâmetro de
  // 25 mm não é permitido pela Norma (retorna null); acima de 150 mm,
  // extrapola o último valor (0,04) — a Norma não define além disso.
  static const List<double> _tabelaDiametro = [50, 75, 100, 150];
  static const List<double> _tabelaK2 = [0.12, 0.09, 0.06, 0.04];

  static double? k2DeDiametro(double diametroMm) {
    if (diametroMm < 50) return null; // "Não permitido" (Tabela 3)
    if (diametroMm >= 150) return _tabelaK2.last;
    for (var i = 0; i < _tabelaDiametro.length - 1; i++) {
      final d0 = _tabelaDiametro[i], d1 = _tabelaDiametro[i + 1];
      if (diametroMm >= d0 && diametroMm <= d1) {
        final k0 = _tabelaK2[i], k1 = _tabelaK2[i + 1];
        final t = (diametroMm - d0) / (d1 - d0);
        return k0 + t * (k1 - k0);
      }
    }
    return _tabelaK2.first;
  }

  // 5.2.4 — extrações ortogonais ao lançamento (pilares/cortinas/paredes):
  // k3 = 0,05; no mesmo sentido do lançamento (lajes): k3 = 0.
  static double k3De(DirecaoExtracao direcao) => direcao == DirecaoExtracao.perpendicular ? 0.05 : 0.0;

  // 5.2.5 — saturado: k4 = 0; seco ao ar: k4 = -0,04.
  static double k4De(CondicaoUmidade umidade) => umidade == CondicaoUmidade.secoAoAr ? -0.04 : 0.0;

  // Retorna null quando o diâmetro não é permitido pela Norma (<50 mm) —
  // nesse caso a resistência corrigida não pode ser calculada.
  static double? resistenciaCorrigida({
    required double resistenciaSemCorrecao,
    required double relacaoHD,
    required double diametroTestemunho,
    required DirecaoExtracao direcao,
    required CondicaoUmidade umidade,
  }) {
    final k2 = k2DeDiametro(diametroTestemunho);
    if (k2 == null) return null;
    final k1 = k1DeRelacaoHD(relacaoHD);
    final k3 = k3De(direcao);
    final k4 = k4De(umidade);
    return (1 + (k1 + k2 + k3 + k4)) * resistenciaSemCorrecao;
  }
}
