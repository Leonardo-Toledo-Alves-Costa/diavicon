import '../models/dashboard_card_model.dart';

/// Reposiciona `gridX`/`gridY` de uma lista de cards (na ORDEM em que
/// aparecem na lista) num grid denso de [colunas] colunas — linha por
/// linha, encaixando cada card na primeira posição da linha atual onde
/// ele cabe (mesma ideia de um fluxo tipo "masonry" simplificado).
///
/// Simplificação deliberada: em vez de drag-and-drop livre de posição
/// (x,y arbitrários), a posição é sempre DERIVADA da ordem da lista + da
/// largura/altura de cada card — reordenar é feito via lista arrastável
/// (`ReorderableListView`) no drawer de edição, e mover = reordenar.
List<DashboardCardModel> reempacotarGrid(List<DashboardCardModel> cards, {int colunas = 7}) {
  final linhas = <List<bool>>[]; // ocupação por linha: linhas[y][x] = ocupado
  final resultado = <DashboardCardModel>[];

  bool cabe(int x, int y, int largura, int altura) {
    for (int dy = 0; dy < altura; dy++) {
      final linhaY = y + dy;
      if (linhaY >= linhas.length) continue;
      for (int dx = 0; dx < largura; dx++) {
        if (x + dx >= colunas) return false;
        if (linhas[linhaY][x + dx]) return false;
      }
    }
    return true;
  }

  void ocupar(int x, int y, int largura, int altura) {
    while (linhas.length < y + altura) {
      linhas.add(List.filled(colunas, false));
    }
    for (int dy = 0; dy < altura; dy++) {
      for (int dx = 0; dx < largura; dx++) {
        linhas[y + dy][x + dx] = true;
      }
    }
  }

  for (final card in cards) {
    final largura = card.largura.clamp(1, colunas);
    final altura = card.altura.clamp(1, alturaMaximaCardBi);
    int y = 0;
    int? posX;
    while (posX == null) {
      for (int x = 0; x <= colunas - largura; x++) {
        if (cabe(x, y, largura, altura)) {
          posX = x;
          break;
        }
      }
      if (posX == null) y++;
    }
    ocupar(posX, y, largura, altura);
    resultado.add(card.copyWith(gridX: posX, gridY: y, largura: largura, altura: altura));
  }
  return resultado;
}
