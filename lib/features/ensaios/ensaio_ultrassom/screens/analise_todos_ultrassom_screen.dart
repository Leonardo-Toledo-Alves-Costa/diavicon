import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../models/analise_ultrassom_global_model.dart';
import '../providers/analise_todos_ultrassom_provider.dart';
import '../ultrassom_direto/models/ultrassom_direto_model.dart' show ClassificacaoWhitehurst;
import '../utils/ultrassom_math.dart';

class _PontoLinha {
  final String x;
  final double y;
  _PontoLinha(this.x, this.y);
}

class _BarraElemento {
  final String x;
  final double y;
  _BarraElemento(this.x, this.y);
}

class _GaussPonto {
  final double x;
  final double y;
  _GaussPonto(this.x, this.y);
}

class _BoxPlotUltrassom {
  final String rotuloEixoX;
  final String local;
  final List<double> valores;
  _BoxPlotUltrassom(this.rotuloEixoX, this.local, this.valores);
}

const _resistenciaLabel = 'Resistência à compressão axial estimada (MPa)';
const _moduloLabel = 'Módulo de elasticidade dinâmico (Ed)';

// Análise geral de Ultrassonografia (todos os pontos da estrutura, dos 3
// modos — Direto/Indireto/Mapeamento) — espelha a estrutura de
// `AnaliseEnsaioScreen` (Carbonatação: filtros + abas Gráficos/Tabelas/
// Estatísticas) e reaproveita o boxplot colorido por Local de
// `AnaliseTodosPotencialScreen`. Ed/fck (UltrassomMath, a partir do artigo
// ENSUS 2024 item 2.3) só são calculáveis pra elementos com resultado
// Longitudinal E Transversal — ver `ElementoAnaliseUltrassomModel`.
class AnaliseTodosUltrassomScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String projetoNome;
  final String estruturaId;
  final String estruturaNome;
  final String tipoEnsaioId;
  final String tipoEnsaioNome;

  const AnaliseTodosUltrassomScreen({
    super.key,
    required this.projetoId,
    required this.projetoNome,
    required this.estruturaId,
    required this.estruturaNome,
    required this.tipoEnsaioId,
    required this.tipoEnsaioNome,
  });

  @override
  ConsumerState<AnaliseTodosUltrassomScreen> createState() => _AnaliseTodosUltrassomScreenState();
}

class _AnaliseTodosUltrassomScreenState extends ConsumerState<AnaliseTodosUltrassomScreen> {
  int _abaSelecionada = 0; // 0: Gráficos, 1: Tabelas, 2: Estatísticas
  String _filtroLocal = 'Locais';
  String _filtroTipoElemento = 'Elementos';
  String _pulsoSelecionado = 'Longitudinal';
  String _graficoSelecionado = _resistenciaLabel;
  bool _expandirAlfaDensidade = false;
  final Set<String> _locaisExpandidosTabela = {};
  final Set<String> _tiposExpandidosTabela = {};
  bool _salvandoAlfaDensidade = false;

  final Map<String, TextEditingController> _alfaCtrls = {};
  final Map<String, TextEditingController> _densCtrls = {};

  final List<Color> _paletaLocais = [
    const Color(0xFF5C6BC0),
    const Color(0xFFEF5350),
    const Color(0xFF66BB6A),
    const Color(0xFFFFA726),
    const Color(0xFFAB47BC),
  ];

  @override
  void dispose() {
    for (final c in _alfaCtrls.values) {
      c.dispose();
    }
    for (final c in _densCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _alfaCtrl(String elementoId, double valor) =>
      _alfaCtrls.putIfAbsent(elementoId, () => TextEditingController(text: valor.toStringAsFixed(2)));

  TextEditingController _densCtrl(String elementoId, double valor) =>
      _densCtrls.putIfAbsent(elementoId, () => TextEditingController(text: valor.toStringAsFixed(0)));

  // Um elemento entra aqui só se tiver ao menos 1 ponto Longitudinal e 1
  // Transversal — "a média das velocidades" (pedido do usuário) agrega
  // TODAS as leituras dos pontos daquele pulso naquele elemento, não a
  // média das médias de cada ponto.
  List<ElementoAnaliseUltrassomModel> _elementosComAmbasOndas(List<PontoAnaliseUltrassomModel> pontos) {
    final porElemento = <String, List<PontoAnaliseUltrassomModel>>{};
    for (final p in pontos) {
      porElemento.putIfAbsent(p.elementoId, () => []).add(p);
    }

    final resultado = <ElementoAnaliseUltrassomModel>[];
    for (final entry in porElemento.entries) {
      final pontosElemento = entry.value;
      final longitudinais = pontosElemento.where((p) => p.ehLongitudinal).expand((p) => p.valoresVelocidade).toList();
      final transversais = pontosElemento.where((p) => !p.ehLongitudinal).expand((p) => p.valoresVelocidade).toList();
      if (longitudinais.isEmpty || transversais.isEmpty) continue;

      final primeiro = pontosElemento.first;
      resultado.add(ElementoAnaliseUltrassomModel(
        elementoId: entry.key,
        nomeElemento: primeiro.nomeElemento,
        tipoElemento: primeiro.tipoElemento,
        local: primeiro.local,
        velocidadeLongitudinal: UltrassomMath.mean(longitudinais),
        velocidadeTransversal: UltrassomMath.mean(transversais),
        alfaE: primeiro.alfaE,
        densidade: primeiro.densidade,
      ));
    }
    resultado.sort((a, b) => a.nomeElemento.compareTo(b.nomeElemento));
    return resultado;
  }

  // Eixo X do gráfico de linhas = elemento (não ponto individual) — a média
  // de cada elemento é a média das médias dos seus pontos daquele pulso.
  List<_PontoLinha> _mediasPorElemento(List<PontoAnaliseUltrassomModel> pontosPulso) {
    final porElemento = <String, List<PontoAnaliseUltrassomModel>>{};
    for (final p in pontosPulso) {
      porElemento.putIfAbsent(p.elementoId, () => []).add(p);
    }
    final resultado = porElemento.values
        .map((pontosElemento) => _PontoLinha(pontosElemento.first.nomeElemento, UltrassomMath.mean(pontosElemento.map((p) => p.media).toList())))
        .toList();
    resultado.sort((a, b) => a.x.compareTo(b.x));
    return resultado;
  }

  Future<void> _salvarAlfaDensidade(String elementoId) async {
    final alfa = double.tryParse(_alfaCtrls[elementoId]?.text.replaceAll(',', '.') ?? '');
    final densidade = double.tryParse(_densCtrls[elementoId]?.text.replaceAll(',', '.') ?? '');
    if (alfa == null || densidade == null || alfa <= 0 || densidade <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe valores válidos.'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _salvandoAlfaDensidade = true);
    try {
      await ref.read(analiseUltrassomRepositoryProvider).atualizarAlfaEDensidade(elementoId: elementoId, alfaE: alfa, densidade: densidade);
      ref.invalidate(analiseTodosUltrassomProvider((projetoId: widget.projetoId, estruturaId: widget.estruturaId)));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _salvandoAlfaDensidade = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(analiseTodosUltrassomProvider((projetoId: widget.projetoId, estruturaId: widget.estruturaId)));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      endDrawer: MenuDrawerAppBar(
        title: 'Menu do\nEnsaio',
        items: [
          Opacity(opacity: 0.4, child: DiaviconMenuItem(icon: Icons.book_outlined, label: 'Informações', onTap: () {})),
          Opacity(opacity: 0.4, child: DiaviconMenuItem(icon: Icons.show_chart_rounded, label: 'Análises', onTap: () {})),
          DiaviconMenuItem(icon: Icons.assessment_outlined, label: 'Relatórios', onTap: () => Navigator.pop(context)),
        ],
      ),
      appBar: CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Projeto', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
            Text('Análise Global', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
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

          final elementosAmbasOndas = _elementosComAmbasOndas(pontosFiltro);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCabecalho(todosLocais, todosTipos),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.grey.shade200)),
                  child: Row(
                    children: [
                      _buildTabButton(0, 'Gráficos'),
                      _buildTabButton(1, 'Tabelas'),
                      _buildTabButton(2, 'Estatísticas'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _abaSelecionada == 0
                      ? _buildAbaGraficos(pontosFiltro, elementosAmbasOndas)
                      : _abaSelecionada == 1
                          ? _buildAbaTabelas(pontosFiltro, elementosAmbasOndas)
                          : _buildAbaEstatistica(pontosFiltro),
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
          Text('Ultrassonografia', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D))),
          const SizedBox(height: 2),
          Text(widget.projetoNome, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
          Text(widget.estruturaNome, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDropdown(_filtroLocal, locais, (val) => setState(() => _filtroLocal = val!))),
              const SizedBox(width: 10),
              Expanded(child: _buildDropdown(_filtroTipoElemento, elementos, (val) => setState(() => _filtroTipoElemento = val!))),
            ],
          ),
        ],
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

  Widget _buildTabButton(int index, String titulo) {
    final selecionado = _abaSelecionada == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _abaSelecionada = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: selecionado ? const Color(0xFFFFA726) : Colors.transparent, borderRadius: BorderRadius.circular(24)),
          alignment: Alignment.center,
          child: Text(titulo, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: selecionado ? Colors.white : const Color(0xFF686868))),
        ),
      ),
    );
  }

  // ==========================================
  // ABA 1: GRÁFICOS
  // ==========================================
  Widget _buildAbaGraficos(List<PontoAnaliseUltrassomModel> pontos, List<ElementoAnaliseUltrassomModel> elementosAmbasOndas) {
    final pontosPulso = pontos.where((p) => p.pulso == _pulsoSelecionado).toList()
      ..sort((a, b) => a.nomeElemento.compareTo(b.nomeElemento));
    final ehLongitudinal = _pulsoSelecionado == 'Longitudinal';

    final valoresPool = pontosPulso.expand((p) => p.valoresVelocidade).toList();
    final media = UltrassomMath.mean(valoresPool);
    final cv = UltrassomMath.coefVariacao(valoresPool);
    final classificacao = ehLongitudinal && media > 0 ? ClassificacaoWhitehurst.classificar(media) : null;
    final mediasPorElemento = _mediasPorElemento(pontosPulso);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pulso ultrassônico', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        _buildDropdown(_pulsoSelecionado, const ['Longitudinal', 'Transversal'], (val) => setState(() => _pulsoSelecionado = val!)),
        const SizedBox(height: 16),

        if (pontosPulso.isEmpty)
          Container(
            height: 200,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Text('Sem resultados para o pulso $_pulsoSelecionado.', style: GoogleFonts.lato(color: Colors.grey)),
          )
        else
          Container(
            height: 260,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
            child: SfCartesianChart(
              primaryXAxis: const CategoryAxis(title: AxisTitle(text: 'Elementos', textStyle: TextStyle(fontSize: 10, color: Colors.grey))),
              primaryYAxis: NumericAxis(
                minimum: 0,
                maximum: 5000,
                interval: 1000,
                title: const AxisTitle(text: 'Velocidade do pulso ultrassônico (m/s)', textStyle: TextStyle(fontSize: 10, color: Colors.grey)),
                plotBands: ehLongitudinal
                    ? [
                        PlotBand(start: 0, end: 2000, color: Colors.red.withValues(alpha: 0.1)),
                        PlotBand(start: 2000, end: 3000, color: Colors.orange.withValues(alpha: 0.12)),
                        PlotBand(start: 3000, end: 3500, color: Colors.yellow.withValues(alpha: 0.18)),
                        PlotBand(start: 3500, end: 4500, color: Colors.lightGreen.withValues(alpha: 0.15)),
                        PlotBand(start: 4500, end: 5000, color: Colors.green.withValues(alpha: 0.1)),
                      ]
                    : const [],
              ),
              series: <CartesianSeries>[
                LineSeries<_PontoLinha, String>(
                  dataSource: mediasPorElemento,
                  xValueMapper: (d, _) => d.x,
                  yValueMapper: (d, _) => d.y,
                  color: const Color(0xFFFFA726),
                  markerSettings: const MarkerSettings(isVisible: true),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(child: _cardResumo('Média', valoresPool.isNotEmpty ? '${media.toStringAsFixed(0)} m/s' : '-')),
            const SizedBox(width: 8),
            Expanded(child: _cardResumo('C.Var', valoresPool.isNotEmpty ? '${cv.toStringAsFixed(0)}%' : '-')),
            const SizedBox(width: 8),
            Expanded(
              child: _cardResumo(
                'Classificação',
                classificacao?.texto ?? (ehLongitudinal ? '-' : 'N/A'),
                corTexto: classificacao?.cor,
              ),
            ),
          ],
        ),
        if (!ehLongitudinal)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Classificação de Whitehurst só se aplica a pulsos longitudinais.', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey)),
          ),
        const SizedBox(height: 28),

        Text('Gráfico por elemento', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
        const SizedBox(height: 4),
        Text(
          'Calculado só pros elementos com resultado Longitudinal e Transversal (equações 1, 2 e 3 do modelo — ver seção abaixo pra αE/densidade).',
          style: GoogleFonts.lato(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        _buildDropdown(_graficoSelecionado, const [_resistenciaLabel, _moduloLabel], (val) => setState(() => _graficoSelecionado = val!)),
        const SizedBox(height: 12),
        _buildGraficoBarraElementos(elementosAmbasOndas),
        const SizedBox(height: 28),

        Text('Distribuição de fck', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
        const SizedBox(height: 4),
        Text(
          'Distribuição normal dos valores de resistência estimada — fck é o valor com 95% de confiabilidade (ABNT NBR 12655:2015).',
          style: GoogleFonts.lato(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        _buildGraficoFck(elementosAmbasOndas),
        const SizedBox(height: 28),

        _buildAcordeaoAlfaDensidade(pontos),
      ],
    );
  }

  Widget _cardResumo(String label, String valor, {Color? corTexto}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(valor, textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.bold, color: corTexto ?? const Color(0xFF3E3E3D))),
        ],
      ),
    );
  }

  Widget _buildGraficoBarraElementos(List<ElementoAnaliseUltrassomModel> elementos) {
    if (elementos.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Text('Nenhum elemento com ondas Longitudinal e Transversal ainda.', textAlign: TextAlign.center, style: GoogleFonts.lato(color: Colors.grey, fontSize: 12)),
      );
    }

    final usaResistencia = _graficoSelecionado == _resistenciaLabel;
    // Resistência fica em MPa (padrão NBR); Ed é convertido de MPa pra GPa
    // (÷1000) só na exibição — o cálculo de fck (equação 3) continua usando
    // o Ed em MPa internamente (ver UltrassomMath).
    final dados = elementos
        .map((e) => _BarraElemento(e.nomeElemento, usaResistencia ? e.resistenciaCompressao : e.moduloElasticidade / 1000))
        .toList();

    return Container(
      height: 260,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
      child: SfCartesianChart(
        primaryXAxis: CategoryAxis(labelStyle: GoogleFonts.lato(fontSize: 10, color: Colors.grey.shade700), title: const AxisTitle(text: 'Elemento ensaiado', textStyle: TextStyle(fontSize: 10, color: Colors.grey))),
        primaryYAxis: NumericAxis(title: AxisTitle(text: usaResistencia ? 'Resistência (MPa)' : 'Ed (GPa)', textStyle: const TextStyle(fontSize: 10, color: Colors.grey))),
        series: <CartesianSeries>[
          ColumnSeries<_BarraElemento, String>(
            dataSource: dados,
            xValueMapper: (d, _) => d.x,
            yValueMapper: (d, _) => d.y,
            color: const Color(0xFFFFC107),
            borderRadius: BorderRadius.circular(4),
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              textStyle: const TextStyle(fontSize: 9),
              builder: (data, point, series, pointIndex, seriesIndex) =>
                  Text((data as _BarraElemento).y.toStringAsFixed(1), style: const TextStyle(fontSize: 9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraficoFck(List<ElementoAnaliseUltrassomModel> elementos) {
    final valores = elementos.map((e) => e.resistenciaCompressao).where((v) => v > 0).toList();
    if (valores.length < 2) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Text('É preciso ao menos 2 elementos com ambas as ondas pra estimar a distribuição.', textAlign: TextAlign.center, style: GoogleFonts.lato(color: Colors.grey, fontSize: 12)),
      );
    }

    final media = UltrassomMath.mean(valores);
    final desvio = UltrassomMath.stdDev(valores);
    final fck = UltrassomMath.valorCaracteristico95(valores);
    final minX = (media - 4 * desvio).clamp(0, double.infinity).toDouble();
    final maxX = media + 4 * desvio;
    final passo = (maxX - minX) / 100;

    final curva = <_GaussPonto>[];
    double picoY = 0;
    for (double x = minX; x <= maxX; x += (passo == 0 ? 1 : passo)) {
      final y = UltrassomMath.normalPdf(x, media, desvio);
      if (y > picoY) picoY = y;
      curva.add(_GaussPonto(x, y));
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 260,
            child: SfCartesianChart(
              title: ChartTitle(text: 'fck estimado: ${fck.toStringAsFixed(1)} MPa', textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D))),
              primaryXAxis: const NumericAxis(title: AxisTitle(text: 'Resistência à compressão (MPa)', textStyle: TextStyle(fontSize: 10, color: Colors.grey))),
              primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Densidade de probabilidade', textStyle: TextStyle(fontSize: 10, color: Colors.grey)), majorGridLines: MajorGridLines(width: 0)),
              series: <CartesianSeries>[
                SplineAreaSeries<_GaussPonto, double>(
                  dataSource: curva,
                  xValueMapper: (d, _) => d.x,
                  yValueMapper: (d, _) => d.y,
                  color: const Color(0x333F51B5),
                  borderColor: const Color(0xFF3F51B5),
                  borderWidth: 2,
                ),
                LineSeries<_GaussPonto, double>(
                  dataSource: [_GaussPonto(media, 0), _GaussPonto(media, picoY * 1.05)],
                  xValueMapper: (d, _) => d.x,
                  yValueMapper: (d, _) => d.y,
                  color: const Color(0xFF3F51B5),
                  dashArray: const [4, 3],
                  width: 1.5,
                ),
                LineSeries<_GaussPonto, double>(
                  dataSource: [_GaussPonto(fck, 0), _GaussPonto(fck, picoY * 1.05)],
                  xValueMapper: (d, _) => d.x,
                  yValueMapper: (d, _) => d.y,
                  color: Colors.red,
                  dashArray: const [6, 4],
                  width: 2,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Text(
              'Média: ${media.toStringAsFixed(1)} MPa · fck (95%): ${fck.toStringAsFixed(1)} MPa',
              style: GoogleFonts.lato(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcordeaoAlfaDensidade(List<PontoAnaliseUltrassomModel> pontos) {
    final porElemento = <String, PontoAnaliseUltrassomModel>{};
    for (final p in pontos) {
      porElemento.putIfAbsent(p.elementoId, () => p);
    }
    final elementos = porElemento.values.toList()..sort((a, b) => a.nomeElemento.compareTo(b.nomeElemento));

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expandirAlfaDensidade = !_expandirAlfaDensidade),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(_expandirAlfaDensidade ? Icons.keyboard_arrow_down : Icons.chevron_right, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('αE e densidade por elemento', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF3E3E3D))),
                  ),
                ],
              ),
            ),
          ),
          if (_expandirAlfaDensidade)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: elementos.map((e) {
                  final alfaCtrl = _alfaCtrl(e.elementoId, e.alfaE);
                  final densCtrl = _densCtrl(e.elementoId, e.densidade);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text('${e.nomeElemento}\n${e.tipoElemento}', style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF3E3E3D))),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: alfaCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(labelText: 'αE', labelStyle: const TextStyle(fontSize: 11), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: densCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(labelText: 'Densidade', labelStyle: const TextStyle(fontSize: 11), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _salvandoAlfaDensidade ? null : () => _salvarAlfaDensidade(e.elementoId),
                          icon: const Icon(Icons.save_outlined, color: AppColors.primary),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // ABA 2: TABELAS (sanfonada: Local > Tipo de elemento > pontos)
  // ==========================================
  Widget _buildAbaTabelas(List<PontoAnaliseUltrassomModel> pontos, List<ElementoAnaliseUltrassomModel> elementosAmbasOndas) {
    if (pontos.isEmpty) return const Center(child: Text('Sem dados com este filtro.'));

    final mapaCombinado = {for (final e in elementosAmbasOndas) e.elementoId: e};

    final porLocal = <String, Map<String, List<PontoAnaliseUltrassomModel>>>{};
    for (final p in pontos) {
      porLocal.putIfAbsent(p.local, () => {}).putIfAbsent(p.tipoElemento, () => []).add(p);
    }
    final locaisOrdenados = porLocal.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: locaisOrdenados.map((local) {
        final tiposDoLocal = porLocal[local]!;
        final tiposOrdenados = tiposDoLocal.keys.toList()..sort();
        final expandidoLocal = _locaisExpandidosTabela.contains(local);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => expandidoLocal ? _locaisExpandidosTabela.remove(local) : _locaisExpandidosTabela.add(local)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Icon(expandidoLocal ? Icons.keyboard_arrow_down : Icons.chevron_right, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(local, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)))),
                    ],
                  ),
                ),
              ),
              if (expandidoLocal)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: tiposOrdenados.map((tipo) {
                      final chaveTipo = '$local|$tipo';
                      final expandidoTipo = _tiposExpandidosTabela.contains(chaveTipo);
                      final pontosGrupo = tiposDoLocal[tipo]!
                        ..sort((a, b) {
                          final c = a.nomeElemento.compareTo(b.nomeElemento);
                          return c != 0 ? c : a.pulso.compareTo(b.pulso);
                        });

                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () => setState(() => expandidoTipo ? _tiposExpandidosTabela.remove(chaveTipo) : _tiposExpandidosTabela.add(chaveTipo)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                child: Row(
                                  children: [
                                    Icon(expandidoTipo ? Icons.keyboard_arrow_down : Icons.chevron_right, size: 20, color: Colors.grey.shade600),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(tipo, style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF3E3E3D)))),
                                  ],
                                ),
                              ),
                            ),
                            if (expandidoTipo)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                                child: Column(children: pontosGrupo.map((p) => _buildCardPontoTabela(p, mapaCombinado[p.elementoId])).toList()),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCardPontoTabela(PontoAnaliseUltrassomModel p, ElementoAnaliseUltrassomModel? combinado) {
    final classificacao = p.ehLongitudinal && p.media > 0 ? ClassificacaoWhitehurst.classificar(p.media).texto : '-';
    final edTexto = combinado != null ? '${(combinado.moduloElasticidade / 1000).toStringAsFixed(1)} GPa' : '-';
    final resistTexto = combinado != null ? '${combinado.resistenciaCompressao.toStringAsFixed(1)} MPa' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _campoTabela('Elemento', p.nomeElemento),
              _campoTabela('Ponto', p.nomePonto),
              _campoTabela('Pulso', p.pulso),
              _campoTabela('Velocidade', '${p.media.toStringAsFixed(0)} m/s'),
              _campoTabela('Coef. var.', '${p.coefVariacao.toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _campoTabela('Classificação', classificacao),
              _campoTabela('Ed estimado', edTexto),
              _campoTabela('Resist. estimada', resistTexto),
            ],
          ),
        ],
      ),
    );
  }

  Widget _campoTabela(String rotulo, String valor) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: '$rotulo: ', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600)),
          TextSpan(text: valor, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF3E3E3D))),
        ],
      ),
    );
  }

  // ==========================================
  // ABA 3: ESTATÍSTICA (BOXPLOT)
  // ==========================================
  Widget _buildAbaEstatistica(List<PontoAnaliseUltrassomModel> pontos) {
    final pontosPulso = pontos.where((p) => p.pulso == _pulsoSelecionado).toList();
    if (pontosPulso.isEmpty) return Center(child: Text('Sem dados de pulso $_pulsoSelecionado com este filtro.', style: GoogleFonts.lato(color: Colors.grey)));

    final locaisUnicos = pontosPulso.map((p) => p.local).toSet().toList();
    final mapaCoresLocal = <String, Color>{};
    for (var i = 0; i < locaisUnicos.length; i++) {
      mapaCoresLocal[locaisUnicos[i]] = _paletaLocais[i % _paletaLocais.length];
    }

    final seriesList = <BoxAndWhiskerSeries<_BoxPlotUltrassom, String>>[];
    double maxGeral = 5000;
    for (final local in locaisUnicos) {
      // Cada caixa é um ELEMENTO (não um ponto isolado) — agrupa todos os
      // pontos daquele elemento (no local/pulso em vista) e junta TODAS as
      // leituras deles numa única distribuição, em vez de mostrar só as
      // leituras de um ponto por vez.
      final porElementoLocal = <String, List<PontoAnaliseUltrassomModel>>{};
      for (final p in pontosPulso.where((p) => p.local == local)) {
        porElementoLocal.putIfAbsent(p.elementoId, () => []).add(p);
      }

      final dataSourceLocal = <_BoxPlotUltrassom>[];
      for (final pontosElemento in porElementoLocal.values) {
        final valoresElemento = pontosElemento.expand((p) => p.valoresVelocidade).toList();
        // Boxplot precisa de pelo menos 2 leituras pra calcular quartis —
        // com 1 só leitura o box degenera (min=q1=mediana=q3=max) e o
        // Syncfusion não desenha nada, então nem entra no gráfico.
        if (valoresElemento.length < 2) continue;
        final maiorValor = valoresElemento.reduce(max);
        if (maiorValor > maxGeral) maxGeral = maiorValor;
        final primeiro = pontosElemento.first;
        dataSourceLocal.add(_BoxPlotUltrassom('${primeiro.nomeElemento}\n${primeiro.tipoElemento}', local, valoresElemento));
      }
      if (dataSourceLocal.isNotEmpty) {
        seriesList.add(BoxAndWhiskerSeries<_BoxPlotUltrassom, String>(
          dataSource: dataSourceLocal,
          name: local,
          xValueMapper: (d, _) => d.rotuloEixoX,
          yValueMapper: (d, _) => d.valores,
          showMean: true,
          boxPlotMode: BoxPlotMode.normal,
          color: mapaCoresLocal[local]!.withValues(alpha: 0.5),
          borderColor: mapaCoresLocal[local]!,
        ));
      }
    }
    final eixoMax = ((maxGeral / 500).ceil() * 500.0) + 500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDropdown(_pulsoSelecionado, const ['Longitudinal', 'Transversal'], (val) => setState(() => _pulsoSelecionado = val!)),
        const SizedBox(height: 16),
        Text('Local', style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: locaisUnicos.map((local) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 14, height: 14, decoration: BoxDecoration(color: mapaCoresLocal[local]!.withValues(alpha: 0.5), border: Border.all(color: mapaCoresLocal[local]!, width: 2), borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 6),
                Text(local, style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF3E3E3D))),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          height: max(350, pontosPulso.length * 75.0),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: SfCartesianChart(
            title: ChartTitle(text: 'Velocidade do pulso ultrassônico (m/s) — $_pulsoSelecionado', textStyle: const TextStyle(fontSize: 12, color: Color(0xFF3E3E3D)), alignment: ChartAlignment.center),
            margin: EdgeInsets.zero,
            isTransposed: true,
            plotAreaBorderWidth: 0,
            primaryXAxis: CategoryAxis(labelStyle: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600), majorGridLines: const MajorGridLines(width: 0), axisLine: const AxisLine(width: 0)),
            primaryYAxis: NumericAxis(
              minimum: 0,
              maximum: eixoMax,
              interval: 500,
              labelPosition: ChartDataLabelPosition.outside,
              opposedPosition: true,
              axisLine: const AxisLine(width: 0),
              majorTickLines: const MajorTickLines(size: 0),
              majorGridLines: const MajorGridLines(width: 1, color: Colors.white),
              plotBands: _pulsoSelecionado == 'Longitudinal'
                  ? [
                      PlotBand(start: 0, end: 2000, color: Colors.red.withValues(alpha: 0.1)),
                      PlotBand(start: 2000, end: 3000, color: Colors.orange.withValues(alpha: 0.12)),
                      PlotBand(start: 3000, end: 3500, color: Colors.yellow.withValues(alpha: 0.18)),
                      PlotBand(start: 3500, end: 4500, color: Colors.lightGreen.withValues(alpha: 0.15)),
                      PlotBand(start: 4500, end: eixoMax, color: Colors.green.withValues(alpha: 0.1)),
                    ]
                  : [],
            ),
            series: seriesList,
          ),
        ),
      ],
    );
  }
}
