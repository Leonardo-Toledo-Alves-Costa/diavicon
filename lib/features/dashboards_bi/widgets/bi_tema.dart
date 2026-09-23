import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../utils/cores_bi.dart';

/// Visual comum a todos os gráficos dos dashboards — um lugar só para eixos,
/// grades, legenda e dica (tooltip), para os cards não parecerem de sistemas
/// diferentes.

const kBiTinta = Color(0xFF2E3033);
const kBiTexto = Color(0xFF4A4C4F);
const kBiSuave = Color(0xFF7A7C80);
const kBiBorda = Color(0xFFE6E6E6);
const kBiGrade = Color(0xFFEDEDED);
const kBiFundo = Color(0xFFF6F5F2);

final List<Color> paletaBi = [for (final c in paletaBiInt) Color(c)];

Color corDaPaletaBi(int i) => paletaBi[i % paletaBi.length];

const _rotuloEixo = TextStyle(fontSize: 10, color: kBiSuave);

CategoryAxis eixoCategoriaBi({int rotacao = 0, String? titulo}) => CategoryAxis(
      majorGridLines: const MajorGridLines(width: 0),
      majorTickLines: const MajorTickLines(size: 0),
      axisLine: const AxisLine(color: kBiBorda),
      labelStyle: _rotuloEixo,
      labelRotation: rotacao,
      labelIntersectAction: AxisLabelIntersectAction.multipleRows,
      maximumLabelWidth: 90,
      title: titulo == null ? const AxisTitle() : AxisTitle(text: titulo, textStyle: _rotuloEixo),
    );

NumericAxis eixoNumericoBi({String? nome, bool oposto = false, String? titulo, double? minimo, double? maximo}) => NumericAxis(
      name: nome,
      opposedPosition: oposto,
      minimum: minimo,
      maximum: maximo,
      majorGridLines: MajorGridLines(width: oposto ? 0 : 1, color: kBiGrade, dashArray: const [3, 3]),
      majorTickLines: const MajorTickLines(size: 0),
      axisLine: const AxisLine(width: 0),
      labelStyle: _rotuloEixo,
      title: titulo == null ? const AxisTitle() : AxisTitle(text: titulo, textStyle: _rotuloEixo),
    );

DateTimeAxis eixoDataBi() => DateTimeAxis(
      majorGridLines: const MajorGridLines(width: 0),
      majorTickLines: const MajorTickLines(size: 0),
      axisLine: const AxisLine(color: kBiBorda),
      labelStyle: _rotuloEixo,
    );

Legend legendaBi({bool visivel = true, LegendPosition posicao = LegendPosition.top}) => Legend(
      isVisible: visivel,
      position: posicao,
      overflowMode: LegendItemOverflowMode.wrap,
      iconHeight: 10,
      iconWidth: 10,
      textStyle: const TextStyle(fontSize: 11, color: kBiTexto),
    );

/// Dica ao tocar/passar o mouse: sem ela não dava para ler o valor exato
/// de uma barra.
TooltipBehavior dicaBi({String? formato}) => TooltipBehavior(
      enable: true,
      format: formato,
      color: kBiTinta,
      textStyle: const TextStyle(fontSize: 11, color: Colors.white),
      duration: 2500,
    );

const rotuloDadoBi = TextStyle(fontSize: 9, color: kBiTexto, fontWeight: FontWeight.w600);

/// Preenchimento de listas que limita a largura de leitura: no computador a
/// lista ocupava a tela toda, com o nome numa ponta e os botões na outra.
EdgeInsets preenchimentoListaBi(BuildContext context, {double base = 20, double inferior = 90, double larguraMaxima = 960}) {
  final largura = MediaQuery.sizeOf(context).width;
  final sobra = ((largura - larguraMaxima) / 2).clamp(0.0, double.infinity);
  return EdgeInsets.fromLTRB(base + sobra, base, base + sobra, inferior);
}

/// Estado vazio padrão dentro de um card.
class VazioBi extends StatelessWidget {
  final String texto;
  final IconData icone;

  const VazioBi({super.key, this.texto = 'Sem dados suficientes', this.icone = Icons.insights_outlined});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, color: const Color(0xFFC7C7C7), size: 26),
            const SizedBox(height: 6),
            Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: kBiSuave, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
