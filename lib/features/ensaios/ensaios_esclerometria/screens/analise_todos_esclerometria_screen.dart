import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../models/analise_esclerometria_global_model.dart';
import '../providers/analise_todos_esclerometria_provider.dart';

class _BoxPlotDataGrupo {
  final String x;
  final List<double> y;
  _BoxPlotDataGrupo(this.x, this.y);
}

/// Análise global (todos os pontos da estrutura) de Esclerometria — mesmo
/// padrão de `AnaliseTodosPotencialScreen`: filtros de Local/Tipo de
/// elemento, sem abas (conteúdo simples, tudo numa página só).
class AnaliseTodosEsclerometriaScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String projetoNome;
  final String estruturaId;
  final String estruturaNome;
  final String tipoEnsaioId;
  final String tipoEnsaioNome;

  const AnaliseTodosEsclerometriaScreen({
    super.key,
    required this.projetoId,
    required this.projetoNome,
    required this.estruturaId,
    required this.estruturaNome,
    required this.tipoEnsaioId,
    required this.tipoEnsaioNome,
  });

  @override
  ConsumerState<AnaliseTodosEsclerometriaScreen> createState() => _AnaliseTodosEsclerometriaScreenState();
}

class _AnaliseTodosEsclerometriaScreenState extends ConsumerState<AnaliseTodosEsclerometriaScreen> {
  String _filtroLocal = 'Locais';
  String _filtroTipoElemento = 'Elementos';

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(analiseTodosEsclerometriaProvider((
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

          final todosLocais = ['Locais', ...todosPontos.map((p) => p.local).toSet()];
          final todosTipos = ['Elementos', ...todosPontos.map((p) => p.tipoElemento).toSet().toList()..sort()];

          final pontosFiltro = todosPontos.where((p) {
            final matchLocal = _filtroLocal == 'Locais' || p.local == _filtroLocal;
            final matchTipo = _filtroTipoElemento == 'Elementos' || p.tipoElemento == _filtroTipoElemento;
            return matchLocal && matchTipo;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCabecalho(todosLocais, todosTipos),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildGraficoBarras(pontosFiltro),
                      const SizedBox(height: 24),
                      _buildBoxplot('Boxplot por tipo de elemento', pontosFiltro, (p) => p.tipoElemento, 'Tipo de elemento'),
                      const SizedBox(height: 24),
                      _buildBoxplot('Boxplot por local', pontosFiltro, (p) => p.local, 'Local'),
                      const SizedBox(height: 24),
                      _buildTabelaResumo(pontosFiltro),
                    ],
                  ),
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
          Text('Esclerometria', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D))),
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

  // ==========================================
  // GRÁFICO DE BARRAS — Média Q por ponto de ensaio
  // ==========================================
  Widget _buildGraficoBarras(List<AnaliseEsclerometriaGlobalModel> pontos) {
    final comDados = pontos.where((p) => p.quantidadeAceitas > 0).toList();
    if (comDados.isEmpty) {
      return const Padding(padding: EdgeInsets.only(top: 32), child: Center(child: Text('Sem dados para o gráfico.', style: TextStyle(color: Colors.grey))));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
      child: SizedBox(
        height: 280,
        child: SfCartesianChart(
          title: const ChartTitle(
            text: 'Média Q por ponto de ensaio',
            textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D)),
          ),
          primaryXAxis: CategoryAxis(
            title: AxisTitle(text: 'Pontos de ensaio', textStyle: const TextStyle(fontSize: 10, color: Colors.grey)),
            majorGridLines: const MajorGridLines(width: 0),
          ),
          primaryYAxis: NumericAxis(
            title: AxisTitle(text: 'Índice esclerométrico (Q)', textStyle: const TextStyle(fontSize: 10, color: Colors.grey)),
            axisLine: const AxisLine(width: 0),
            majorTickLines: const MajorTickLines(size: 0),
            minimum: 0,
          ),
          series: <CartesianSeries>[
            ColumnSeries<AnaliseEsclerometriaGlobalModel, String>(
              dataSource: comDados,
              xValueMapper: (p, _) => '${p.nomeElemento}\n${p.nomePonto}',
              yValueMapper: (p, _) => p.mediaQ,
              color: AppColors.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              dataLabelSettings: const DataLabelSettings(isVisible: true, textStyle: TextStyle(fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // BOXPLOT — pooled por grupo (tipo de elemento OU local)
  // ==========================================
  Widget _buildBoxplot(
    String titulo,
    List<AnaliseEsclerometriaGlobalModel> pontos,
    String Function(AnaliseEsclerometriaGlobalModel) chaveDe,
    String tituloEixoX,
  ) {
    final grupos = <String, List<double>>{};
    for (final p in pontos) {
      grupos.putIfAbsent(chaveDe(p), () => []).addAll(p.valoresAceitos);
    }
    final dataSource = grupos.entries.where((e) => e.value.isNotEmpty).map((e) => _BoxPlotDataGrupo(e.key, e.value)).toList();

    if (dataSource.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
          const SizedBox(height: 8),
          const Center(child: Padding(padding: EdgeInsets.only(top: 16, bottom: 16), child: Text('Sem dados para o gráfico.', style: TextStyle(color: Colors.grey)))),
        ],
      );
    }

    return Container(
      height: 380,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
      child: SfCartesianChart(
        title: ChartTitle(text: titulo, textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D))),
        primaryXAxis: CategoryAxis(title: AxisTitle(text: tituloEixoX, textStyle: const TextStyle(fontSize: 10))),
        primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Índice esclerométrico (Q)', textStyle: TextStyle(fontSize: 10))),
        series: <CartesianSeries>[
          BoxAndWhiskerSeries<_BoxPlotDataGrupo, String>(
            dataSource: dataSource,
            xValueMapper: (d, _) => d.x,
            yValueMapper: (d, _) => d.y,
            boxPlotMode: BoxPlotMode.normal,
            showMean: true,
            color: AppColors.primary.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TABELA RESUMO
  // ==========================================
  Widget _buildTabelaResumo(List<AnaliseEsclerometriaGlobalModel> pontos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 40,
          columns: const [
            DataColumn(label: Text('Local', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tipo do elemento', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Nome do elemento', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Nome do ponto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Média Q', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text('Coef. Var. (%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text('Direção do impacto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Leituras aceitas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), numeric: true),
          ],
          rows: [
            for (final p in pontos)
              DataRow(cells: [
                DataCell(Text(p.local, style: const TextStyle(fontSize: 12))),
                DataCell(Text(p.tipoElemento, style: const TextStyle(fontSize: 12))),
                DataCell(Text(p.nomeElemento, style: const TextStyle(fontSize: 12))),
                DataCell(Text(p.nomePonto, style: const TextStyle(fontSize: 12))),
                DataCell(Text(p.quantidadeAceitas == 0 ? '-' : p.mediaQ.toStringAsFixed(1), style: const TextStyle(fontSize: 12))),
                DataCell(Text(p.quantidadeAceitas == 0 ? '-' : '${p.coefVariacao.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12))),
                DataCell(Text(p.direcaoImpacto, style: const TextStyle(fontSize: 12))),
                DataCell(Text('${p.quantidadeAceitas}', style: const TextStyle(fontSize: 12))),
              ]),
          ],
        ),
      ),
    );
  }
}
