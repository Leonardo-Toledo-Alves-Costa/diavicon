import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

class CarbonatacaoChartWidget extends StatelessWidget {
  final double tempoAnalise;
  final double cobrimento;
  final double coefCarb;
  final int idadeAtual;
  final double tempoDespassivacao;

  const CarbonatacaoChartWidget({
    super.key,
    required this.tempoAnalise,
    required this.cobrimento,
    required this.coefCarb,
    required this.idadeAtual,
    required this.tempoDespassivacao,
  });

  @override
  Widget build(BuildContext context) {
    // Escala X e Y
    final double maxX = tempoAnalise == 0 ? 50 : tempoAnalise;
    final double maxY = max(35.0, max(cobrimento, coefCarb * sqrt(maxX)) + 5);

    double intervaloX;
    if (maxX < 45) {
      intervaloX = 5;
    } else if (maxX < 70) {
      intervaloX = 5;
    } else {
      intervaloX = 10;
}

double intervaloY;
    if (maxX < 40) {
      intervaloY = 5;
    } else if (maxY < 70) {
      intervaloY = 10;
    } else {
      intervaloY = 15;
}

    // Gerando os 100 pontos da curva de carbonatação como no Python[cite: 12]
    List<FlSpot> pontosCurva = [];
    for (double t = 0; t <= maxX; t += maxX / 100) {
      pontosCurva.add(FlSpot(t, coefCarb * sqrt(t)));
    }

  final cobrimentoSeries = List.generate(
  maxX.toInt(),
  (i) => FlSpot(i.toDouble(), cobrimento),
);


    return Container(
      height: 280,
      width: double.infinity,
      padding: const EdgeInsets.only(right: 16, top: 16),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 5,
            verticalInterval: 5,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 1),
            getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              axisNameWidget: Padding(
                padding: const EdgeInsets.only(top: 0),
                child: Text('Exposição (anos)',textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 13, color: Colors.black87)),
              ),
              axisNameSize: 24,
              sideTitles: SideTitles(
                showTitles: true,
                interval: intervaloX,
                reservedSize: 15,
                getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: GoogleFonts.lato(fontSize: 10)),
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: Text('Profundidade no concreto (mm)', textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 13, color: Colors.black87)),
              axisNameSize: 24,
              sideTitles: SideTitles(
                showTitles: true,
                interval: intervaloY,
                reservedSize: 15,
                getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: GoogleFonts.lato(fontSize: 10)),
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: const Border(bottom: BorderSide(color: Colors.black54), left: BorderSide(color: Colors.black54)),
          ),

           lineBarsData: [
            // Renderiza a curva principal
            LineChartBarData(
              spots: pontosCurva,
              isCurved: true, // Suavização
              color: Colors.grey.shade700,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.grey.withValues(alpha: 0.3),
              ),
            ),

            LineChartBarData(
              spots: cobrimentoSeries,
              isCurved: true, // Suavização
              color: Color(0xFFDDA0DD),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Color(0xFFDDA0DD).withValues(alpha: 0.3),
              ),
            ),
          ],
          
          // Renderiza Idade, Despassivação e Área de Cobrimento
          extraLinesData: ExtraLinesData(            
            verticalLines: [
              VerticalLine(
                x: idadeAtual.toDouble(),
                color: Colors.orange,
                strokeWidth: 2,
                dashArray: [5, 5],
                label: VerticalLineLabel(show: true, labelResolver: (l) => 'Idade', style: const TextStyle(color: Colors.orange, fontSize: 10)),
              ),
              if (tempoDespassivacao < 999)
                VerticalLine(
                  x: tempoDespassivacao,
                  color: Colors.red,
                  strokeWidth: 2,
                  dashArray: [5, 5],
                  label: VerticalLineLabel(show: true, labelResolver: (l) => 'Falha', style: const TextStyle(color: Colors.red, fontSize: 10)),
                ),
            ],
            
          ),

         
          
          // Tooltips interativos
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    'Ano: ${spot.x.toInt()}\nProf: ${spot.y.toStringAsFixed(1)} mm',
                    GoogleFonts.lato(color: Colors.white, fontSize: 12),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}