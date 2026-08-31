import 'dart:math';
import 'package:flutter/material.dart';

// Classe auxiliar para passar os dados para o Painter
class HeatmapPoint {
  final double x; // Posição X real (coluna * espaçamento)
  final double y; // Posição Y real (linha * espaçamento)
  final double value; // Valor em mV (em módulo)

  HeatmapPoint(this.x, this.y, this.value);
}

class HeatmapPainter extends CustomPainter {
  final List<HeatmapPoint> points;
  final double maxX;
  final double maxY;
  final double opacity;
  final int resolution; // Tamanho do "quadradinho" pintado. Menor = mais bonito, mas mais pesado (ex: 10)
  /// Escala de cores customizada (valor -> cor). Se nulo, usa a escala
  /// padrão calibrada para mV (potencial de corrosão).
  final Color Function(double value)? colorMapper;

  HeatmapPainter({
    required this.points,
    required this.maxX,
    required this.maxY,
    required this.opacity,
    this.resolution = 15,
    this.colorMapper,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || maxX == 0 || maxY == 0) return;

    final paint = Paint()..style = PaintingStyle.fill;

    // Percorre a tela em blocos (resolução) para otimizar o processamento
    for (double i = 0; i < size.width; i += resolution) {
      for (double j = 0; j < size.height; j += resolution) {
        
        // Converte a posição do ecrã para as coordenadas reais do seu ensaio
        double realX = (i / size.width) * maxX;
        double realY = (j / size.height) * maxY;

        // 1. Calcula o valor interpolado neste pixel usando IDW
        double val = _calcularIDW(realX, realY);

        // 2. Transforma o valor na cor correspondente da norma
        paint.color = (colorMapper ?? _getColorForValue)(val).withValues(alpha: opacity);

        // 3. Desenha o quadradinho no ecrã
        canvas.drawRect(Rect.fromLTWH(i, j, resolution.toDouble(), resolution.toDouble()), paint);
      }
    }
  }

  // Algoritmo Inverse Distance Weighting (Interpolação Espacial)
  double _calcularIDW(double x, double y) {
    double p = 2.0; // Potência de suavização
    double num = 0.0;
    double den = 0.0;

    for (var pt in points) {
      double d = sqrt(pow(x - pt.x, 2) + pow(y - pt.y, 2));
      if (d == 0) return pt.value; // Se estiver exatamente em cima do ponto
      
      double w = 1.0 / pow(d, p);
      num += w * pt.value;
      den += w;
    }
    
    return den == 0 ? 0 : num / den;
  }

  // Mapeamento de Cores (Verde -> Laranja -> Vermelho)
  Color _getColorForValue(double value) {
    if (value <= 200) {
      // De 0 a 200: Gradiente de Verde a Verde Amarelado
      double t = value / 200;
      return Color.lerp(Colors.green.shade700, Colors.lightGreen, t) ?? Colors.green;
    } else if (value <= 350) {
      // De 200 a 350: Gradiente de Amarelo a Laranja
      double t = (value - 200) / 150;
      return Color.lerp(Colors.yellow, Colors.orange, t) ?? Colors.orange;
    } else {
      // Acima de 350: Gradiente de Laranja a Vermelho Escuro
      double t = ((value - 350) / 150).clamp(0.0, 1.0); // Clamped para evitar estouro
      return Color.lerp(Colors.deepOrange, Colors.red.shade900, t) ?? Colors.red;
    }
  }

  @override
  bool shouldRepaint(covariant HeatmapPainter oldDelegate) {
    return oldDelegate.opacity != opacity || oldDelegate.points != points;
  }
}