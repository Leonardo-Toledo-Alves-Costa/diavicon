import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../providers/analise_todos_chumbador_provider.dart';
import 'ponto_chumbador_screen.dart';

class _BarraPontoChumbador {
  final String rotulo;
  final double cargaMaxima;
  final double? deslocamentoMaximo;
  final Color cor;
  _BarraPontoChumbador(this.rotulo, this.cargaMaxima, this.deslocamentoMaximo, this.cor);
}

class _BoxPlotChumbador {
  final String x;
  final List<double> y;
  _BoxPlotChumbador(this.x, this.y);
}

// Análise geral (por Estrutura) de Tração em Chumbador — mesmo escopo de
// todas as outras telas "AnaliseTodos..." do app, com o mesmo seletor de
// seções em abas (Gráficos/Tabela/Estatísticas) usado por
// `AnaliseTodosArrancamentoScreen`.
class AnaliseTodosChumbadorScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String projetoNome;
  final String estruturaId;
  final String estruturaNome;
  final String tipoEnsaioId;
  final String tipoEnsaioNome;

  const AnaliseTodosChumbadorScreen({
    super.key,
    required this.projetoId,
    required this.projetoNome,
    required this.estruturaId,
    required this.estruturaNome,
    required this.tipoEnsaioId,
    required this.tipoEnsaioNome,
  });

  @override
  ConsumerState<AnaliseTodosChumbadorScreen> createState() => _AnaliseTodosChumbadorScreenState();
}

class _AnaliseTodosChumbadorScreenState extends ConsumerState<AnaliseTodosChumbadorScreen> {
  String _filtroLocal = 'Locais';
  String _filtroTipo = 'Tipos de elemento';
  int _abaSelecionada = 0; // 0: Gráficos, 1: Tabela, 2: Estatísticas

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(analiseTodosChumbadorProvider((projetoId: widget.projetoId, estruturaId: widget.estruturaId)));

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
            Text('Tração em Chumbador', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Erro: $err', style: const TextStyle(color: Colors.red))),
        data: (todosPontos) {
          if (todosPontos.isEmpty) {
            return const Center(child: Text('Nenhum ponto de ensaio registrado.', style: TextStyle(color: Colors.grey)));
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
                    ? const Center(child: Text('Nenhum ponto com este filtro.', style: TextStyle(color: Colors.grey)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: switch (_abaSelecionada) {
                          0 => _buildSecaoGrafico(pontosFiltro),
                          1 => _buildSecaoTabela(pontosFiltro),
                          _ => _buildSecaoEstatistica(pontosFiltro),
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

  // Seletor de seções (Gráficos/Tabela/Estatísticas) — mesmo padrão visual
  // de `AnaliseTodosArrancamentoScreen._buildAbas`.
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

  // ==========================================
  // SEÇÃO GRÁFICOS: carga máxima (barra, cor por condição) + deslocamento
  // máximo (linha, eixo secundário) — um par por ponto de ensaio.
  // ==========================================
  Widget _buildSecaoGrafico(List<PontoChumbadorResumoModel> pontos) {
    final dados = pontos
        .where((p) => p.cargaMaxima != null)
        .map((p) => _BarraPontoChumbador('${p.nomePonto}\n${p.nomeElemento} · ${p.tipoElemento}', p.cargaMaxima!, p.deslocamentoMaximo, p.condicaoAvaliacao?.cor ?? Colors.grey))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Carga máxima × Deslocamento máximo por ponto', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
          const SizedBox(height: 4),
          Text('Barra verde: aprovado · vermelha: reprovado · cinza: cabe análise/pendente', style: GoogleFonts.lato(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 12),
          if (dados.isEmpty)
            SizedBox(height: 200, child: Center(child: Text('Sem cargas registradas ainda.', style: GoogleFonts.lato(color: Colors.grey))))
          else
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                legend: const Legend(isVisible: true, position: LegendPosition.top),
                primaryXAxis: CategoryAxis(labelRotation: -45, majorGridLines: const MajorGridLines(width: 0)),
                primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Carga máxima (kN)', textStyle: TextStyle(fontSize: 10, color: Colors.grey))),
                axes: const <ChartAxis>[
                  NumericAxis(name: 'deslocamento', opposedPosition: true, title: AxisTitle(text: 'Deslocamento máx. (mm)', textStyle: TextStyle(fontSize: 10, color: Colors.grey))),
                ],
                series: <CartesianSeries>[
                  ColumnSeries<_BarraPontoChumbador, String>(
                    name: 'Carga máxima',
                    dataSource: dados,
                    xValueMapper: (d, _) => d.rotulo,
                    yValueMapper: (d, _) => d.cargaMaxima,
                    pointColorMapper: (d, _) => d.cor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  LineSeries<_BarraPontoChumbador, String>(
                    name: 'Deslocamento máximo',
                    dataSource: dados,
                    xValueMapper: (d, _) => d.rotulo,
                    yValueMapper: (d, _) => d.deslocamentoMaximo,
                    yAxisName: 'deslocamento',
                    color: const Color(0xFF3E3E3D),
                    width: 2,
                    markerSettings: const MarkerSettings(isVisible: true, width: 6, height: 6),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // SEÇÃO TABELA: sanfonado expansível Local -> Tipo de elemento -> pontos.
  // ==========================================
  Widget _buildSecaoTabela(List<PontoChumbadorResumoModel> pontos) {
    final porLocal = <String, List<PontoChumbadorResumoModel>>{};
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
              child: Text('Pontos por Local e Tipo de elemento', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            ),
            ...porLocal.entries.map((entradaLocal) {
              final porTipo = <String, List<PontoChumbadorResumoModel>>{};
              for (final p in entradaLocal.value) {
                porTipo.putIfAbsent(p.tipoElemento, () => []).add(p);
              }
              return ExpansionTile(
                title: Text(entradaLocal.key, style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                subtitle: Text('${entradaLocal.value.length} ponto(s)', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey)),
                children: porTipo.entries.map((entradaTipo) {
                  return ExpansionTile(
                    tilePadding: const EdgeInsets.only(left: 28, right: 16),
                    title: Text(entradaTipo.key, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF3E3E3D))),
                    subtitle: Text('${entradaTipo.value.length} ponto(s)', style: GoogleFonts.lato(fontSize: 10, color: Colors.grey)),
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

  // Abre a tela de coleta do ponto — é lá que fica o drawer com "Análise"
  // (gráfico força×deslocamento) e "Fotos" (galeria), mesmo acesso de
  // quando o ponto é aberto pela lista de pontos de ensaio do elemento.
  Widget _buildLinhaPonto(PontoChumbadorResumoModel p) {
    final cor = p.condicaoAvaliacao?.cor ?? Colors.grey;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PontoChumbadorScreen(
            projetoId: widget.projetoId,
            pontoNome: p.nomePonto,
            elementoNome: p.nomeElemento,
            tipoElemento: p.tipoElemento,
            local: p.local,
            elementoId: '',
            pontoGeralId: p.pontoGeralId,
            tipoEnsaioId: widget.tipoEnsaioId,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(40, 8, 16, 8),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text('${p.nomeElemento} · ${p.nomePonto}', style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF3E3E3D)))),
            Expanded(child: Text(p.cargaMaxima != null ? '${p.cargaMaxima!.toStringAsFixed(1)} kN' : '-', textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade700))),
            Expanded(child: Text(p.deslocamentoMaximo != null ? '${p.deslocamentoMaximo!.toStringAsFixed(1)} mm' : '-', textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade700))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: cor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(p.condicaoAvaliacao?.label ?? 'Pendente', style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, color: cor)),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SEÇÃO ESTATÍSTICA: um boxplot só, uma caixa por combinação Local + Tipo
  // de elemento (não dois boxplots separados).
  // ==========================================
  Widget _buildSecaoEstatistica(List<PontoChumbadorResumoModel> pontos) {
    final grupos = <String, List<double>>{};
    for (final p in pontos) {
      if (p.cargaMaxima == null) continue;
      final chave = '${p.local} / ${p.tipoElemento}';
      grupos.putIfAbsent(chave, () => []).add(p.cargaMaxima!);
    }
    final dataSource = grupos.entries.map((e) => _BoxPlotChumbador(e.key, e.value)).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Distribuição da carga máxima por Local / Tipo de elemento', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
          const SizedBox(height: 12),
          if (dataSource.isEmpty)
            SizedBox(height: 200, child: Center(child: Text('Sem cargas registradas ainda.', style: GoogleFonts.lato(color: Colors.grey))))
          else
            SizedBox(
              height: 320,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(labelRotation: -45, majorGridLines: const MajorGridLines(width: 0), title: const AxisTitle(text: 'Local / Tipo de elemento')),
                primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Carga máxima (kN)', textStyle: TextStyle(fontSize: 10, color: Colors.grey))),
                series: <CartesianSeries>[
                  BoxAndWhiskerSeries<_BoxPlotChumbador, String>(
                    dataSource: dataSource,
                    xValueMapper: (d, _) => d.x,
                    yValueMapper: (d, _) => d.y,
                    boxPlotMode: BoxPlotMode.exclusive,
                    showMean: true,
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
