import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../models/analise_arrancamento_ceramica_model.dart';
import '../providers/analise_todos_arrancamento_ceramica_provider.dart';

class BoxPlotDataArrancamentoCeramica {
  final String x;
  final List<double> y;
  BoxPlotDataArrancamentoCeramica(this.x, this.y);
}

class AnaliseTodosArrancamentoCeramicaScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String projetoNome;
  final String estruturaId;
  final String estruturaNome;
  final String tipoEnsaioId;
  final String tipoEnsaioNome;

  const AnaliseTodosArrancamentoCeramicaScreen({
    super.key,
    required this.projetoId,
    required this.projetoNome,
    required this.estruturaId,
    required this.estruturaNome,
    required this.tipoEnsaioId,
    required this.tipoEnsaioNome,
  });

  @override
  ConsumerState<AnaliseTodosArrancamentoCeramicaScreen> createState() => _AnaliseTodosArrancamentoCeramicaScreenState();
}

class _AnaliseTodosArrancamentoCeramicaScreenState extends ConsumerState<AnaliseTodosArrancamentoCeramicaScreen> {
  int _abaSelecionada = 0; 
  String _filtroLocal = 'Locais';
  String _filtroTipoElemento = 'Elementos';

  Color _getRupturaColor(String tipo) {
    tipo = tipo.toUpperCase().trim();
    switch (tipo) {
      case 'S': return const Color(0xFF795548); 
      case 'E': return Colors.grey.shade600; 
      case 'AC': return Colors.orange; 
      case 'PC': return const Color(0xFFD84315); 
      case 'S/E': return const Color(0xFFA1887F); 
      case 'E/AC': return const Color(0xFFFFB74D); 
      case 'AC/PC': return const Color(0xFFFF8A65); 
      default: return Colors.primaries[tipo.hashCode % Colors.primaries.length];
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(analiseArrancamentoCeramicaProvider((
      projetoId: widget.projetoId,
      estruturaId: widget.estruturaId,
    )));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      endDrawer: MenuDrawerAppBar(
        title: 'Menu do\nEnsaio',
        items: [
          DiaviconMenuItem(icon: Icons.book_outlined, label: 'Informações', onTap: () => Navigator.pop(context)),
          Opacity(opacity: 0.4, child: DiaviconMenuItem(icon: Icons.show_chart_rounded, label: 'Análises', onTap: () {})),
          DiaviconMenuItem(icon: Icons.assessment_outlined, label: 'Relatórios', onTap: () => Navigator.pop(context)),
        ],
      ),
      appBar: CustomAppBar(
        title: 'Ensaio Cerâmica',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Projeto', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
            const Text('Análise Global', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Erro: $err', style: const TextStyle(color: Colors.red))),
        data: (todosPontos) {
          if (todosPontos.isEmpty) {
            return const Center(child: Text('Nenhum ponto registrado.', style: TextStyle(color: Colors.grey)));
          }

          final todosLocais = ['Locais', ...todosPontos.map((p) => p.local).toSet()];
          final todosTipos = ['Elementos', ...todosPontos.map((p) => p.tipoElemento).toSet().toList()..sort()];

          final pontosFiltro = todosPontos.where((p) {
            final matchDrop = _filtroLocal == 'Locais' || p.local == _filtroLocal;
            final matchTipo = _filtroTipoElemento == 'Elementos' || p.tipoElemento == _filtroTipoElemento;
            return matchDrop && matchTipo;
          }).toList();

          Map<String, ElementoArrancamentoCeramicaAgg> elementosAgrupados = {};
          
          for (var p in pontosFiltro) {
            String chave = '${p.local}_${p.nomeElemento}';
            
            if (!elementosAgrupados.containsKey(chave)) {
              elementosAgrupados[chave] = ElementoArrancamentoCeramicaAgg(
                local: p.local,
                nomeElemento: p.nomeElemento,
                tipoElemento: p.tipoElemento,
                tensoes: [],
                somaRupturas: {},
              );
            }

            for (var leitura in p.leituras) {
              elementosAgrupados[chave]!.tensoes.add(leitura.tensao);
              for (var rup in leitura.rupturas) {
                double valAtual = elementosAgrupados[chave]!.somaRupturas[rup.tipo] ?? 0.0;
                elementosAgrupados[chave]!.somaRupturas[rup.tipo] = valAtual + rup.porcentagem;
              }
            }
          }

          final listaElementos = elementosAgrupados.values.where((e) => e.tensoes.isNotEmpty).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCabecalho(todosLocais, todosTipos),
              _buildAbas(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _abaSelecionada == 0
                      ? _buildAbaGraficos(listaElementos)
                      : _abaSelecionada == 1
                          ? _buildAbaTabelas(listaElementos)
                          : _buildAbaEstatisticas(listaElementos),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCabecalho(List<String> locais, List<String> elementos) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Arrancamento em Placa Cerâmica', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D))),
          const SizedBox(height: 2),
          Text(widget.projetoNome, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
          Text(widget.estruturaNome, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildFiltroDropdown(_filtroLocal, locais, (val) => setState(() => _filtroLocal = val!))),
              const SizedBox(width: 10),
              Expanded(child: _buildFiltroDropdown(_filtroTipoElemento, elementos, (val) => setState(() => _filtroTipoElemento = val!))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroDropdown(String value, List<String> items, void Function(String?) onChanged) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFD9D9D9)), borderRadius: BorderRadius.circular(20)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF3E3E3D)),
          items: items.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildAbas() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          children: [
            _buildTabBotao(0, 'Gráficos'),
            _buildTabBotao(1, 'Tabelas'),
            _buildTabBotao(2, 'Estatísticas'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBotao(int index, String titulo) {
    final sel = _abaSelecionada == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _abaSelecionada = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: sel ? const Color(0xFFFFA726) : Colors.transparent, borderRadius: BorderRadius.circular(24)),
          alignment: Alignment.center,
          child: Text(titulo, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: sel ? Colors.white : const Color(0xFF686868))),
        ),
      ),
    );
  }

  Widget _buildAbaGraficos(List<ElementoArrancamentoCeramicaAgg> elementos) {
    if (elementos.isEmpty) return const SizedBox();

    double mediaGlobal = elementos.map((e) => e.mediaTensao).reduce((a, b) => a + b) / elementos.length;
    double maxGlobal = elementos.map((e) => e.maxTensao).reduce(max);
    double minGlobal = elementos.map((e) => e.minTensao).reduce(min);
    
    Set<String> tiposRupturaUnicos = {};
    for (var el in elementos) {
      tiposRupturaUnicos.addAll(el.somaRupturas.keys);
    }

    List<StackedColumnSeries<ElementoArrancamentoCeramicaAgg, String>> seriesGrafico = [];
    
    for (var tipoRup in tiposRupturaUnicos) {
      seriesGrafico.add(
        StackedColumnSeries<ElementoArrancamentoCeramicaAgg, String>(
          dataSource: elementos,
          xValueMapper: (el, _) => el.nomeElemento,
          yValueMapper: (el, _) {
            double totalRuptura = el.somaRupturas.values.fold(0, (a, b) => a + b);
            if (totalRuptura == 0) return 0;
            double porcentagemLocal = (el.somaRupturas[tipoRup] ?? 0) / totalRuptura;
            return el.mediaTensao * porcentagemLocal; 
          },
          name: tipoRup,
          color: _getRupturaColor(tipoRup),
        )
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tensão de Ruptura', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D))),
                  const SizedBox(height: 4),
                  Text('Maior: ${maxGlobal.toStringAsFixed(2)} MPa | Menor: ${minGlobal.toStringAsFixed(2)} MPa', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Média', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('${mediaGlobal.toStringAsFixed(2)} MPa', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Container(
          height: 380,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
          child: SfCartesianChart(
            margin: const EdgeInsets.all(16),
            legend: const Legend(isVisible: true, position: LegendPosition.top),
            primaryXAxis: const CategoryAxis(
              majorGridLines: MajorGridLines(width: 0),
              title: AxisTitle(text: 'Elementos', textStyle: TextStyle(fontSize: 10)),
            ),
            primaryYAxis: const NumericAxis(
              title: AxisTitle(text: 'Tensão (MPa)', textStyle: TextStyle(fontSize: 10)),
              minimum: 0,
            ),
            series: seriesGrafico,
          ),
        ),
      ],
    );
  }

  Widget _buildAbaTabelas(List<ElementoArrancamentoCeramicaAgg> elementos) {
    if (elementos.isEmpty) return const SizedBox();

    Map<String, List<ElementoArrancamentoCeramicaAgg>> hierarquiaLocal = {};
    for (var e in elementos) {
      hierarquiaLocal.putIfAbsent(e.local, () => []);
      hierarquiaLocal[e.local]!.add(e);
    }

    return Column(
      children: hierarquiaLocal.entries.map((entry) {
        String nomeLocal = entry.key;
        List<ElementoArrancamentoCeramicaAgg> lista = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(color: Color(0xFFFFCA28), borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                  alignment: Alignment.center,
                  child: const Text('Análise dos pontos de arrancamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3E3E3D))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: Colors.grey.shade300,
                  alignment: Alignment.center,
                  child: Text(nomeLocal, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3E3E3D))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  color: Colors.grey.shade100,
                  child: const Row(
                    children: [
                      Expanded(flex: 2, child: Text('Elemento', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Tensão\nmédia (MPa)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Tensão\nmin (MPa)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('coef. Var\n(%)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Ruptura\npredominante', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                ...lista.map((el) {
                  return Container(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade300))),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text(el.nomeElemento, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF686868)))),
                        Expanded(flex: 2, child: Text(el.mediaTensao.toStringAsFixed(2), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF686868)))),
                        Expanded(flex: 2, child: Text(el.minTensao.toStringAsFixed(2), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF686868)))),
                        Expanded(flex: 2, child: Text(el.cv.toStringAsFixed(1), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF686868)))),
                        Expanded(flex: 2, child: Text(el.rupturaPredominante, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D)))),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAbaEstatisticas(List<ElementoArrancamentoCeramicaAgg> elementos) {
    if (elementos.isEmpty) return const SizedBox();

    double maxGlobal = elementos.map((e) => e.maxTensao).reduce(max);
    List<BoxAndWhiskerSeries<BoxPlotDataArrancamentoCeramica, String>> seriesList = [];
    Set<String> tiposUnicos = elementos.map((e) => e.tipoElemento).toSet();
    
    for (String tipo in tiposUnicos) {
      List<BoxPlotDataArrancamentoCeramica> dataSource = [];
      var elementosDoTipo = elementos.where((e) => e.tipoElemento == tipo).toList();

      for (var el in elementosDoTipo) {
        if (el.tensoes.isNotEmpty) {
          dataSource.add(BoxPlotDataArrancamentoCeramica(el.nomeElemento, el.tensoes));
        }
      }

      if (dataSource.isNotEmpty) {
        seriesList.add(
          BoxAndWhiskerSeries<BoxPlotDataArrancamentoCeramica, String>(
            dataSource: dataSource,
            name: tipo,
            xValueMapper: (d, _) => d.x,
            yValueMapper: (d, _) => d.y,
            boxPlotMode: BoxPlotMode.exclusive,
            showMean: true,
          )
        );
      }
    }

    return Container(
      height: 450,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: SfCartesianChart(
        title: const ChartTitle(text: 'Distribuição Estatística da Tensão de Arrancamento', textStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D))),
        legend: const Legend(isVisible: true, position: LegendPosition.bottom),
        primaryXAxis: const CategoryAxis(title: AxisTitle(text: 'Elementos')),
        primaryYAxis: NumericAxis(
          title: const AxisTitle(text: 'Tensão (MPa)', textStyle: TextStyle(fontSize: 10)),
          minimum: 0, 
          maximum: maxGlobal * 1.2,
        ),
        series: seriesList,
      ),
    );
  }
}