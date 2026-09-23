import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../providers/analise_todos_extracao_provider.dart';
import 'ponto_ensaio_extracao_screen.dart';

class _BarraResistencia {
  final String rotulo;
  final double valor;
  _BarraResistencia(this.rotulo, this.valor);
}

class _GaussPonto {
  final double x;
  final double y;
  _GaussPonto(this.x, this.y);
}

// Análise geral (por Estrutura) de Extração e Rompimento de Testemunho —
// mesmo seletor de seções (Gráficos/Tabela/Estatísticas) de
// `AnaliseTodosChumbadorScreen`. A "Estatística" aqui é o dropdown de
// agrupamento clássico (Local / Tipo de elemento) — pedido explícito do
// usuário ("o bom e velho dropdown"), não um boxplot.
class AnaliseTodosExtracaoScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String projetoNome;
  final String estruturaId;
  final String estruturaNome;
  final String tipoEnsaioId;
  final String tipoEnsaioNome;

  const AnaliseTodosExtracaoScreen({
    super.key,
    required this.projetoId,
    required this.projetoNome,
    required this.estruturaId,
    required this.estruturaNome,
    required this.tipoEnsaioId,
    required this.tipoEnsaioNome,
  });

  @override
  ConsumerState<AnaliseTodosExtracaoScreen> createState() => _AnaliseTodosExtracaoScreenState();
}

class _AnaliseTodosExtracaoScreenState extends ConsumerState<AnaliseTodosExtracaoScreen> {
  String _filtroLocal = 'Locais';
  String _filtroTipo = 'Tipos de elemento';
  int _abaSelecionada = 0; // 0: Gráficos, 1: Tabela, 2: Estatísticas
  String _agrupamentoEstatistica = 'Local';

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(analiseTodosExtracaoProvider((projetoId: widget.projetoId, estruturaId: widget.estruturaId)));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Projeto', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
            Text('Extração de Testemunho', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Erro: $err', style: const TextStyle(color: Colors.red))),
        data: (todosPontos) {
          if (todosPontos.isEmpty) {
            return const Center(child: Text('Nenhum testemunho registrado.', style: TextStyle(color: Colors.grey)));
          }

          final todosLocais = ['Locais', ...todosPontos.map((p) => p.local).toSet()];
          final todosTipos = ['Tipos de elemento', ...todosPontos.map((p) => p.tipoElemento).toSet()];
          final pontosFiltro = todosPontos.where((p) {
            final matchLocal = _filtroLocal == 'Locais' || p.local == _filtroLocal;
            final matchTipo = _filtroTipo == 'Tipos de elemento' || p.tipoElemento == _filtroTipo;
            return matchLocal && matchTipo;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCabecalho(todosLocais, todosTipos),
              _buildAbas(),
              Expanded(
                child: pontosFiltro.isEmpty
                    ? const Center(child: Text('Nenhum testemunho com este filtro.', style: TextStyle(color: Colors.grey)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: switch (_abaSelecionada) {
                          0 => _buildAbaGraficos(pontosFiltro),
                          1 => _buildAbaTabela(pontosFiltro),
                          _ => _buildAbaEstatistica(pontosFiltro),
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCabecalho(List<String> locais, List<String> tipos) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.projetoNome, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
          Text(widget.estruturaNome, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDropdown(_filtroLocal, locais, (v) => setState(() => _filtroLocal = v!))),
              const SizedBox(width: 10),
              Expanded(child: _buildDropdown(_filtroTipo, tipos, (v) => setState(() => _filtroTipo = v!))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAbas() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          children: [
            _buildTabBotao(0, 'Gráficos'),
            _buildTabBotao(1, 'Tabela'),
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
          decoration: BoxDecoration(color: sel ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(24)),
          alignment: Alignment.center,
          child: Text(titulo, style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.bold, color: sel ? Colors.white : const Color(0xFF686868))),
        ),
      ),
    );
  }

  Widget _buildDropdown(String value, List<String> items, void Function(String?) onChanged) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFD9D9D9)), borderRadius: BorderRadius.circular(20)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF3E3E3D)),
          items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  double _media(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
  double _desvioPadrao(List<double> v) {
    if (v.length < 2) return 0;
    final m = _media(v);
    return sqrt(v.map((x) => pow(x - m, 2)).reduce((a, b) => a + b) / v.length);
  }

  double _coefVariacao(List<double> v) {
    final m = _media(v);
    return m == 0 ? 0 : _desvioPadrao(v) / m * 100;
  }

  double _normalPdf(double x, double media, double desvio) {
    if (desvio <= 0) return 0;
    final expo = -pow(x - media, 2) / (2 * desvio * desvio);
    return (1 / (desvio * sqrt(2 * pi))) * exp(expo);
  }

  // ==========================================
  // ABA GRÁFICOS: barras de resistência corrigida + curva de fck.
  // ==========================================
  Widget _buildAbaGraficos(List<PontoExtracaoResumoModel> pontos) {
    final dados = pontos.where((p) => p.resistenciaComCorrecao != null).map((p) => _BarraResistencia('${p.nomeTestemunho}\n${p.elementoNome}', p.resistenciaComCorrecao!)).toList();
    final valores = pontos.map((p) => p.resistenciaComCorrecao).whereType<double>().toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Resistência corrigida por ponto', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
              const SizedBox(height: 12),
              if (dados.length < 2)
                SizedBox(height: 200, child: Center(child: Text('Cadastre ao menos 2 pontos (com resistência corrigida) para comparar.', textAlign: TextAlign.center, style: GoogleFonts.lato(color: Colors.grey))))
              else
                SizedBox(
                  height: 280,
                  child: SfCartesianChart(
                    primaryXAxis: CategoryAxis(labelStyle: GoogleFonts.lato(fontSize: 10, color: Colors.grey.shade700)),
                    primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Resistência corrigida (MPa)', textStyle: TextStyle(fontSize: 10, color: Colors.grey))),
                    series: <CartesianSeries>[
                      ColumnSeries<_BarraResistencia, String>(
                        dataSource: dados,
                        xValueMapper: (d, _) => d.rotulo,
                        yValueMapper: (d, _) => d.valor,
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                        dataLabelSettings: const DataLabelSettings(isVisible: true, textStyle: TextStyle(fontSize: 9)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildGraficoFck(valores),
      ],
    );
  }

  Widget _buildGraficoFck(List<double> valores) {
    if (valores.length < 2) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
        child: Text('É preciso ao menos 2 pontos com resistência corrigida pra estimar o fck.', textAlign: TextAlign.center, style: GoogleFonts.lato(color: Colors.grey, fontSize: 12)),
      );
    }

    final media = _media(valores);
    final desvio = _desvioPadrao(valores);
    final fck = media - 1.645 * desvio;
    final minX = (media - 4 * desvio).clamp(0, double.infinity).toDouble();
    final maxX = media + 4 * desvio;
    final passo = (maxX - minX) / 100;

    final curva = <_GaussPonto>[];
    double picoY = 0;
    for (double x = minX; x <= maxX; x += (passo == 0 ? 1 : passo)) {
      final y = _normalPdf(x, media, desvio);
      if (y > picoY) picoY = y;
      curva.add(_GaussPonto(x, y));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
      child: SizedBox(
        height: 260,
        child: SfCartesianChart(
          title: ChartTitle(text: 'fck estimado: ${fck.toStringAsFixed(1)} MPa', textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D))),
          primaryXAxis: const NumericAxis(title: AxisTitle(text: 'Resistência corrigida (MPa)', textStyle: TextStyle(fontSize: 10, color: Colors.grey))),
          primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Densidade de probabilidade', textStyle: TextStyle(fontSize: 10, color: Colors.grey)), majorGridLines: MajorGridLines(width: 0)),
          series: <CartesianSeries>[
            SplineAreaSeries<_GaussPonto, double>(dataSource: curva, xValueMapper: (d, _) => d.x, yValueMapper: (d, _) => d.y, color: const Color(0x333F51B5), borderColor: const Color(0xFF3F51B5), borderWidth: 2),
            LineSeries<_GaussPonto, double>(dataSource: [_GaussPonto(media, 0), _GaussPonto(media, picoY * 1.05)], xValueMapper: (d, _) => d.x, yValueMapper: (d, _) => d.y, color: const Color(0xFF3F51B5), dashArray: const [4, 3], width: 1.5),
            LineSeries<_GaussPonto, double>(dataSource: [_GaussPonto(fck, 0), _GaussPonto(fck, picoY * 1.05)], xValueMapper: (d, _) => d.x, yValueMapper: (d, _) => d.y, color: Colors.red, dashArray: const [6, 4], width: 2),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ABA TABELA: sanfonado expansível Local -> Tipo de elemento -> pontos.
  // ==========================================
  Widget _buildAbaTabela(List<PontoExtracaoResumoModel> pontos) {
    final porLocal = <String, List<PontoExtracaoResumoModel>>{};
    for (final p in pontos) {
      porLocal.putIfAbsent(p.local, () => []).add(p);
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Testemunhos por Local e Tipo de elemento', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            ),
            ...porLocal.entries.map((entradaLocal) {
              final porTipo = <String, List<PontoExtracaoResumoModel>>{};
              for (final p in entradaLocal.value) {
                porTipo.putIfAbsent(p.tipoElemento, () => []).add(p);
              }
              return ExpansionTile(
                title: Text(entradaLocal.key, style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                subtitle: Text('${entradaLocal.value.length} testemunho(s)', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey)),
                children: porTipo.entries.map((entradaTipo) {
                  return ExpansionTile(
                    tilePadding: const EdgeInsets.only(left: 28, right: 16),
                    title: Text(entradaTipo.key, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF3E3E3D))),
                    subtitle: Text('${entradaTipo.value.length} testemunho(s)', style: GoogleFonts.lato(fontSize: 10, color: Colors.grey)),
                    children: entradaTipo.value.map((p) => _buildLinhaPonto(p)).toList(),
                  );
                }).toList(),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLinhaPonto(PontoExtracaoResumoModel p) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PontoEnsaioExtracaoScreen(pontoGeralId: p.pontoGeralId))),
      child: Container(
        padding: const EdgeInsets.fromLTRB(40, 8, 16, 8),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text('${p.nomeTestemunho} · ${p.elementoNome}', style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF3E3E3D)))),
            Expanded(child: Text(p.resistenciaSemCorrecao != null ? '${p.resistenciaSemCorrecao!.toStringAsFixed(1)} MPa' : '-', textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade700))),
            Expanded(child: Text(p.resistenciaComCorrecao != null ? '${p.resistenciaComCorrecao!.toStringAsFixed(1)} MPa' : '—', textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)))),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ABA ESTATÍSTICA: dropdown de agrupamento (Local / Tipo de elemento) +
  // tabela de estatísticas da resistência corrigida.
  // ==========================================
  Widget _buildAbaEstatistica(List<PontoExtracaoResumoModel> pontos) {
    final grupos = <String, List<double>>{};
    for (final p in pontos) {
      if (p.resistenciaComCorrecao == null) continue;
      final chave = _agrupamentoEstatistica == 'Local' ? p.local : p.tipoElemento;
      grupos.putIfAbsent(chave, () => []).add(p.resistenciaComCorrecao!);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Estatística da resistência corrigida', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD9D9D9)), borderRadius: BorderRadius.circular(16)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _agrupamentoEstatistica,
                    style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF3E3E3D)),
                    items: ['Local', 'Tipo de elemento'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: (v) => setState(() => _agrupamentoEstatistica = v!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (grupos.isEmpty)
            SizedBox(height: 120, child: Center(child: Text('Sem resistências corrigidas registradas ainda.', style: GoogleFonts.lato(color: Colors.grey))))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 40,
                columns: [
                  DataColumn(label: Text(_agrupamentoEstatistica, style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Qtd', style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Média (MPa)', style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('CV (%)', style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Máx (MPa)', style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Mín (MPa)', style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.bold))),
                ],
                rows: grupos.entries.map((e) {
                  return DataRow(cells: [
                    DataCell(Text(e.key, style: GoogleFonts.lato(fontSize: 12))),
                    DataCell(Text(e.value.length.toString(), style: GoogleFonts.lato(fontSize: 12))),
                    DataCell(Text(_media(e.value).toStringAsFixed(1), style: GoogleFonts.lato(fontSize: 12))),
                    DataCell(Text(_coefVariacao(e.value).toStringAsFixed(1), style: GoogleFonts.lato(fontSize: 12))),
                    DataCell(Text(e.value.reduce(max).toStringAsFixed(1), style: GoogleFonts.lato(fontSize: 12))),
                    DataCell(Text(e.value.reduce(min).toStringAsFixed(1), style: GoogleFonts.lato(fontSize: 12))),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
