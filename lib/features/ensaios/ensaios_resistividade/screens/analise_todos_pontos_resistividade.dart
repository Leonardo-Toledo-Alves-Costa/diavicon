import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../models/analise_resistividade_model.dart';
import '../providers/analise_todos_resistividade_provider.dart';

// Modelos utilitários para os Gráficos
class ChartDataResistividade {
  final String x;
  final double y;
  ChartDataResistividade(this.x, this.y);
}

class BoxPlotDataResistividade {
  final String x;
  final List<double> y;
  BoxPlotDataResistividade(this.x, this.y);
}

class AnaliseResistividadeScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String projetoNome;
  final String estruturaId;
  final String estruturaNome;
  final String tipoEnsaioId;
  final String tipoEnsaioNome;

  const AnaliseResistividadeScreen({
    super.key,
    required this.projetoId,
    required this.projetoNome,
    required this.estruturaId,
    required this.estruturaNome,
    required this.tipoEnsaioId,
    required this.tipoEnsaioNome,
  });

  @override
  ConsumerState<AnaliseResistividadeScreen> createState() => _AnaliseResistividadeScreenState();
}

class _AnaliseResistividadeScreenState extends ConsumerState<AnaliseResistividadeScreen> {
  int _abaSelecionada = 0; // 0: Gráficos, 1: Tabelas, 2: Estatística
  String _filtroLocal = 'Locais';
  String _filtroTipoElemento = 'Elementos';
  
  int _agrupamentoGrafico = 0; // 0: Elemento, 1: Local
  final int _radioEstatisticaSelecionada = 0; // 0: Risco, 1: Taxa, 2: Permissividade

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(analiseResistividadeProvider((
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
        title: 'Ensaio',
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

          // Listas dinâmicas para os Dropdowns
          final todosLocais = ['Locais', ...todosPontos.map((p) => p.local).toSet()];
          final todosTipos = ['Elementos', ...todosPontos.map((p) => p.tipoElemento).toSet().toList()..sort()];

          // Aplicando filtros do Dropdown
          final pontosFiltro = todosPontos.where((p) {
            final matchDrop = _filtroLocal == 'Locais' || p.local == _filtroLocal;
            final matchTipo = _filtroTipoElemento == 'Elementos' || p.tipoElemento == _filtroTipoElemento;
            return matchDrop && matchTipo;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCabecalho(todosLocais, todosTipos),
              _buildAbas(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _abaSelecionada == 0
                      ? _buildAbaGraficos(pontosFiltro)
                      : _abaSelecionada == 1
                          ? _buildAbaTabelas(pontosFiltro)
                          : _buildAbaEstatisticas(pontosFiltro),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // CABEÇALHO (Títulos e Filtros)
  // ==========================================
  Widget _buildCabecalho(List<String> locais, List<String> elementos) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resistividade Elétrica', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D))),
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
            _buildTabBotao(2, 'Estatística'),
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

  // ==========================================
  // ABA 1: GRÁFICOS
  // ==========================================
  Widget _buildAbaGraficos(List<AnaliseResistividadePonto> pontos) {
    if (pontos.isEmpty) return const SizedBox();

    double mediaGlobal = pontos.map((p) => p.media).reduce((a, b) => a + b) / pontos.length;
    double maxGlobal = pontos.map((p) => p.leituras.isEmpty ? 0.0 : p.leituras.reduce(max)).reduce(max);
    double minGlobal = pontos.map((p) => p.leituras.isEmpty ? 0.0 : p.leituras.reduce(min)).reduce(min);
    
    // CV
    List<double> todasLeituras = pontos.expand((p) => p.leituras).toList();
    double dpGlobal = sqrt(todasLeituras.map((x) => pow(x - mediaGlobal, 2)).reduce((a,b) => a+b) / todasLeituras.length);
    double cvGlobal = mediaGlobal > 0 ? (dpGlobal / mediaGlobal) * 100 : 0;
    
    String statusRisco = mediaGlobal < 15 ? 'Muito Alto' : mediaGlobal < 20 ? 'Alto' : mediaGlobal < 55 ? 'Moderado' : mediaGlobal < 80 ? 'Baixo' : 'Desprezível';
    Color corRisco = statusRisco == 'Muito Alto' ? const Color(0xFFFF4C4C) : statusRisco == 'Alto' ? const Color(0xFFFF4C4C) : statusRisco == 'Moderado' ? Colors.orange : Colors.green;

    String statusTaxa = mediaGlobal < 5 ? 'Muito Alto' : mediaGlobal < 10 ? 'Alto' : mediaGlobal < 20 ? 'Moderado' : 'Baixo';
    Color corTaxa = statusTaxa == 'Muito Alto' ? const Color(0xFFFF4C4C) : statusTaxa == 'Alto' ? const Color(0xFFFF4C4C) : statusTaxa == 'Moderado' ? Colors.orange : Colors.green;

    String statusPermissividade = mediaGlobal < 12 ? 'Muito Alto' : mediaGlobal < 21 ? 'Alto' : mediaGlobal < 37 ? 'Moderado' : mediaGlobal < 254 ? 'Baixo' : 'Desprezível';
    Color corPermissividade = statusPermissividade == 'Muito Alto' ? const Color(0xFFFF4C4C) : statusPermissividade == 'Alto' ? const Color(0xFFFF4C4C) : statusPermissividade == 'Moderado' ? Colors.orange : Colors.green;
 
    // Agrupar p/ gráfico de colunas
    Map<String, double> dadosAgrupados = {};
    for (var p in pontos) {
      String chave = _agrupamentoGrafico == 0 ? p.tipoElemento : p.local;
      dadosAgrupados.update(chave, (val) => (val + p.media) / 2, ifAbsent: () => p.media);
    }
    List<ChartDataResistividade> colData = dadosAgrupados.entries.map((e) => ChartDataResistividade(e.key, e.value)).toList();

    return Column(
      children: [
        // Risco Global
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 36),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Risco de Corrosão', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(color: corRisco.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                        child: Text(statusRisco, style: TextStyle(color: corRisco, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Média', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('${mediaGlobal.toStringAsFixed(0)} K.Ω.cm', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Toggle Elemento / Local
        Container(
          height: 45,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade300)),
          child: Row(
            children: [
              _buildToggleGrafico('Elemento', 0),
              _buildToggleGrafico('Local', 1),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Gráfico de Colunas
        Container(
          height: 350,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
          child: SfCartesianChart(
            title: const ChartTitle(
              text: 'Distribuição dos resultados dado ao risco de corrosão', // Insira o título desejado
              textStyle: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E3E3D),
              ),
            ),
            margin: const EdgeInsets.all(16),
            primaryXAxis: const CategoryAxis(majorGridLines: MajorGridLines(width: 0)),
            primaryYAxis: NumericAxis(
              title: const AxisTitle(text: 'Resistividade K.Ω.cm', textStyle: TextStyle(fontSize: 10)),
              minimum: 0,
              maximum: max(80, maxGlobal * 1.2), // PlotBands fixas do Figma
              plotBands: [
                PlotBand(start: 0, end: 15, color: Colors.red.withValues(alpha: 0.3)),
                PlotBand(start: 0, end: 20, color: Colors.redAccent.withValues(alpha: 0.2)),
                PlotBand(start: 20, end: 55, color: Colors.orange.withValues(alpha: 0.15)),
                PlotBand(start: 55, end: 80, color: Colors.green.withValues(alpha: 0.3)),
                PlotBand(start: 80, end: max(80, maxGlobal * 1.2), color: Colors.greenAccent.withValues(alpha: 0.15)),
              ],
            ),
            series: <CartesianSeries>[
              ColumnSeries<ChartDataResistividade, String>(
                dataSource: colData,
                xValueMapper: (d, _) => d.x,
                yValueMapper: (d, _) => d.y,
                color: Colors.grey.shade500,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              )
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Row Maior, Menor, C.Var
        Row(
          children: [
            Expanded(child: _buildInfoCard('Maior', '${maxGlobal.toStringAsFixed(0)} K.Ω.cm')),
            const SizedBox(width: 10),
            Expanded(child: _buildInfoCard('Menor', '${minGlobal.toStringAsFixed(0)} K.Ω.cm')),
            const SizedBox(width: 10),
            Expanded(child: _buildInfoCard('C. Var', '${cvGlobal.toStringAsFixed(0)}%', badge: cvGlobal < 15 ? 'Homogêneo' : 'Heterogêneo', badgeColor: cvGlobal < 15 ? Colors.green : Colors.orange)),
          ],
        ),
        const SizedBox(height: 16),

        // Row Inferior child: Text(statusRisco, style: TextStyle(color: corRisco, fontWeight: FontWeight.bold, fontSize: 12)),
        Row(
          children: [
            Expanded(child: _buildInfoCard('Taxa de Corrosão', 
                                      statusTaxa, 
                                      titleColor: corTaxa, 
                                      //bgColor: const Color(0xFFFFEBEE)
                                      )),
            const SizedBox(width: 10),
            
            Expanded(child: _buildInfoCard('Permissividade iônica', 
                          statusPermissividade,
                          //badge: statusPermissividade ,
                          //badgeColor: corPermissividade,
                          titleColor: corPermissividade,
                          //bgColor: corPermissividade.withOpacity(0.3) 
                            )),
          ],
        )
      ],
    );
  }

  Widget _buildToggleGrafico(String label, int index) {
    bool selecionado = _agrupamentoGrafico == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _agrupamentoGrafico = index),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: selecionado ? const Color(0xFFFFA726) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(color: selecionado ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String valor, {String? badge, Color? badgeColor, Color? titleColor, Color? bgColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bgColor ?? Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade700), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(valor, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor ?? const Color(0xFF3E3E3D))),
          if (badge != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: badgeColor?.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: Text(badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor)),
            ),
          ]
        ],
      ),
    );
  }

  // ==========================================
  // ABA 2: TABELAS
  // ==========================================
  Widget _buildAbaTabelas(List<AnaliseResistividadePonto> pontos) {
    if (pontos.isEmpty) return const SizedBox();

    // Organiza por Local > Tipo > Lista de Pontos (Aninhado conforme o Figma)
    Map<String, Map<String, List<AnaliseResistividadePonto>>> hierarquia = {};
    for (var p in pontos) {
      hierarquia.putIfAbsent(p.local, () => {});
      hierarquia[p.local]!.putIfAbsent(p.tipoElemento, () => []);
      hierarquia[p.local]![p.tipoElemento]!.add(p);
    }

    return Column(
      children: hierarquia.entries.map((localEntry) {
        String localNome = localEntry.key;
        
        // Média geral do local apenas para display no título do accordion
        var todosDesteLocal = localEntry.value.values.expand((x) => x).toList();
        double mediaLocal = todosDesteLocal.isEmpty 
        ? 0.0 
        : todosDesteLocal.map((p) => p.media).reduce((a, b) => a + b) / todosDesteLocal.length;
          // 2. Calcula o Desvio Padrão Local
          double desvioPadraoLocal = 0.0;
          if (todosDesteLocal.length > 1 && mediaLocal > 0) {
            // Somatório do quadrado da diferença entre cada valor e a média
            double somaVariancia = todosDesteLocal
                .map((p) => pow(p.media - mediaLocal, 2))
                .reduce((a, b) => a + b)
                .toDouble(); 
            // Tira a raiz quadrada da variância (dividido pelo tamanho da amostra)
            desvioPadraoLocal = sqrt(somaVariancia / todosDesteLocal.length);
          }
          // 3. Calcula o Coeficiente de Variação (CV) em %
          double cvLocal = mediaLocal > 0 
              ? (desvioPadraoLocal / mediaLocal) * 100 
              : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),), //border: Border.all(color: Colors.orange.shade300, width: 2)),
            child: ExpansionTile(
              title: _buildLinhaTabela(localNome, mediaLocal < 20 ? 'Risco Alto' : mediaLocal < 55 ? 'Risco Moderado' :  ' Risco Baixo', mediaLocal.toStringAsFixed(0), '${cvLocal.toStringAsFixed(1)}%' ), // Status e CV simplificados no topo
              children: localEntry.value.entries.map((tipoEntry) {
                String tipoNome = tipoEntry.key;
                var listaPontos = tipoEntry.value;              
                // 1. Média do Tipo de Elemento
                double mediaTipo = listaPontos.isEmpty 
                    ? 0.0 
                    : listaPontos.map((p) => p.media).reduce((a, b) => a + b) / listaPontos.length; 
                // 2. Desvio Padrão do Tipo
                double desvioPadraoTipo = 0.0;
                if (listaPontos.length > 1 && mediaTipo > 0) {
                  double somaVariancia = listaPontos
                      .map((p) => pow(p.media - mediaTipo, 2))
                      .reduce((a, b) => a + b)
                      .toDouble();
                  desvioPadraoTipo = sqrt(somaVariancia / listaPontos.length);
                }
                // 3. Coeficiente de Variação (CV) do Tipo em %
                double cvTipo = mediaTipo > 0 
                    ? (desvioPadraoTipo / mediaTipo) * 100 
                    : 0.0;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
                  child: ExpansionTile(
                    title: _buildLinhaTabela(tipoNome, mediaLocal < 20 ? 'Risco Alto' : mediaLocal < 55 ? 'Risco Moderado' :  ' Risco Baixo', mediaTipo.toStringAsFixed(0), '${cvTipo.toStringAsFixed(1)}%'),
                    children: tipoEntry.value.map((p) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _buildLinhaTabela(p.nomeElemento,  p.media < 20 ? 'Risco Alto' : p.media < 55 ? 'Risco Moderado' :  ' Risco Baixo', p.media.toStringAsFixed(1), '${p.coeficienteVariacao.toStringAsFixed(1)}%'),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLinhaTabela(String titulo, String condicao, String media, String cv) {
    Color corBadge = condicao == 'Risco Alto' ? Colors.red.withValues(alpha: 0.8) : condicao == 'Risco Moderado' ? Colors.orange.withValues(alpha: 0.8) : Colors.green.withValues(alpha: 0.8);
    //Color corCv = cv. < '15' ? Colors.green.withOpacity(0.8) : cv == 'Risco Moderado' ? Colors.orange.withOpacity(0.8) : Colors.green.withOpacity(0.8);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300)),
            child: Text(titulo, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: corBadge, borderRadius: BorderRadius.circular(20)),
            child: Text(condicao, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
            child: Text(media, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
            child: Text(cv, style: const TextStyle( fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // ABA 3: ESTATÍSTICA (BoxPlot e Radio)
  // ==========================================
  Widget _buildAbaEstatisticas(List<AnaliseResistividadePonto> pontos) {
    double maxGlobal = pontos.map((p) => p.leituras.isEmpty ? 0.0 : p.leituras.reduce(max)).reduce(max);
    Set<String> tiposUnicos = pontos.map((p) => p.tipoElemento).toSet();
    
    // Preparar Series do Boxplot (Cor Fixa para cada tipo)
    List<BoxAndWhiskerSeries<BoxPlotDataResistividade, String>> seriesList = [];
    //List<Color> coresSeries = [const Color(0x995C6BC0), const Color.fromARGB(153, 195, 170, 5), const Color(0x99EF5350), const Color(0x9966BB6A), const Color.fromARGB(153, 220, 42, 226)]; 
    int corIndex = 0;

    for (String tipo in tiposUnicos) {
      List<BoxPlotDataResistividade> dataSource = [];
      var pontosDoTipo = pontos.where((p) => p.tipoElemento == tipo).toList();
      var locaisUnicos = pontosDoTipo.map((p) => p.local).toSet();

      for (String local in locaisUnicos) {
        var leiturasLocal = pontosDoTipo.where((p) => p.local == local).expand((p) => p.leituras).toList();
        if (leiturasLocal.isNotEmpty) dataSource.add(BoxPlotDataResistividade(local, leiturasLocal));
      }

      if (dataSource.isNotEmpty) {
        seriesList.add(
          BoxAndWhiskerSeries<BoxPlotDataResistividade, String>(
            dataSource: dataSource,
            name: tipo,
            xValueMapper: (d, _) => d.x,
            yValueMapper: (d, _) => d.y,
            boxPlotMode: BoxPlotMode.exclusive,
            //color: coresSeries[corIndex % coresSeries.length],
            showMean: true,
          )
        );
        corIndex++;
      }
    }

    return Column(
      children: [
        // BoxPlot
        Container(
          height: 450,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: SfCartesianChart(
            title: const ChartTitle(
              text: 'Análise estatística da distribuição dos resultados dado ao risco de corrosão', // Insira o título desejado
              textStyle: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E3E3D),
              ),
            ),
            legend: const Legend(isVisible: true, position: LegendPosition.bottom),
            primaryXAxis: const CategoryAxis(title: AxisTitle(text: 'Tipo')),
            primaryYAxis: NumericAxis(
              title: const AxisTitle(text: 'Resistividade elétrica kΩ·cm', textStyle: TextStyle(fontSize: 10)),
              minimum: 0, maximum:  max(80, maxGlobal * 1.2),
              plotBands: [
                PlotBand(start: 0, end: 15, color: Colors.red.withValues(alpha: 0.15)),
                PlotBand(start: 15, end: 55, color: Colors.orange.withValues(alpha: 0.1)),
                PlotBand(start: 55, end: max(80, maxGlobal * 1.2), color: Colors.green.withValues(alpha: 0.1)),
              ],
            ),
            series: seriesList,
          ),
        ),
        const SizedBox(height: 24),
        
        
      ],
    );
  }

  
}