import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../models/monitoramento_fissura_model.dart';
import '../providers/analise_todos_monitoramento_fissura_provider.dart';
import 'ponto_monitoramento_fissura_screen.dart';

class _PontoXY {
  final double x;
  final double y;
  _PontoXY(this.x, this.y);
}

// "Tela 2" do prompt — visão consolidada de todos os pontos de
// monitoramento de fissura DESSA ESTRUTURA (não do projeto inteiro: segue o
// mesmo escopo/entrada — drawer "Análises" de `PontosEnsaioScreen` — de
// TODAS as outras telas de análise global já existentes no app, que são
// por estrutura; um filtro "por Estrutura" não faria sentido aqui por
// já estar implícito na navegação).
class AnaliseTodosMonitoramentoFissuraScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String projetoNome;
  final String estruturaId;
  final String estruturaNome;
  final String tipoEnsaioId;
  final String tipoEnsaioNome;

  const AnaliseTodosMonitoramentoFissuraScreen({
    super.key,
    required this.projetoId,
    required this.projetoNome,
    required this.estruturaId,
    required this.estruturaNome,
    required this.tipoEnsaioId,
    required this.tipoEnsaioNome,
  });

  @override
  ConsumerState<AnaliseTodosMonitoramentoFissuraScreen> createState() => _AnaliseTodosMonitoramentoFissuraScreenState();
}

class _AnaliseTodosMonitoramentoFissuraScreenState extends ConsumerState<AnaliseTodosMonitoramentoFissuraScreen> {
  String _filtroLocal = 'Locais';
  final Set<String> _statusSelecionados = {}; // vazio = todos

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(analiseTodosMonitoramentoFissuraProvider((projetoId: widget.projetoId, estruturaId: widget.estruturaId)));

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
            Text('Monitoramento de Fissuras', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Erro: $err', style: const TextStyle(color: Colors.red))),
        data: (todosPontos) {
          if (todosPontos.isEmpty) {
            return const Center(child: Text('Nenhum ponto de monitoramento registrado.', style: TextStyle(color: Colors.grey)));
          }

          final todosLocais = ['Locais', ...todosPontos.map((p) => p.local).toSet()];
          final pontosFiltro = todosPontos.where((p) {
            final matchLocal = _filtroLocal == 'Locais' || p.local == _filtroLocal;
            final matchStatus = _statusSelecionados.isEmpty || _statusSelecionados.contains(_chaveStatus(p));
            return matchLocal && matchStatus;
          }).toList();

          // Criticidade: Rompido/Alerta primeiro, depois Leve, depois Estável, depois Pendente (sem leitura).
          pontosFiltro.sort((a, b) => _pesoCriticidade(a).compareTo(_pesoCriticidade(b)));

          final totais = _contarPorStatus(todosPontos);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCabecalho(todosLocais, totais),
              Expanded(
                child: pontosFiltro.isEmpty
                    ? const Center(child: Text('Nenhum ponto com este filtro.', style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        itemCount: pontosFiltro.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _buildCardPonto(pontosFiltro[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _chaveStatus(PontoMonitoramentoResumoModel p) => p.dataUltimaLeitura == null ? 'Pendente' : p.status.label;

  int _pesoCriticidade(PontoMonitoramentoResumoModel p) {
    if (p.dataUltimaLeitura == null) return 4;
    switch (p.status) {
      case StatusFissura.rompido:
      case StatusFissura.alerta:
        return 0;
      case StatusFissura.leve:
        return 1;
      case StatusFissura.estavel:
        return 2;
    }
  }

  Map<String, int> _contarPorStatus(List<PontoMonitoramentoResumoModel> pontos) {
    final contagem = {'Estável': 0, 'Leve': 0, 'Alerta': 0, 'Pendente': 0};
    for (final p in pontos) {
      if (p.dataUltimaLeitura == null) {
        contagem['Pendente'] = (contagem['Pendente'] ?? 0) + 1;
      } else if (p.status == StatusFissura.rompido || p.status == StatusFissura.alerta) {
        contagem['Alerta'] = (contagem['Alerta'] ?? 0) + 1;
      } else if (p.status == StatusFissura.leve) {
        contagem['Leve'] = (contagem['Leve'] ?? 0) + 1;
      } else {
        contagem['Estável'] = (contagem['Estável'] ?? 0) + 1;
      }
    }
    return contagem;
  }

  Widget _buildCabecalho(List<String> locais, Map<String, int> totais) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monitoramento de Fissuras', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D))),
          const SizedBox(height: 2),
          Text(widget.projetoNome, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
          Text(widget.estruturaNome, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCardResumo('Total', totais.values.reduce((a, b) => a + b).toString(), const Color(0xFF3E3E3D))),
              const SizedBox(width: 8),
              Expanded(child: _buildCardResumo('Estáveis', '${totais['Estável']}', const Color(0xFF4CAF50))),
              const SizedBox(width: 8),
              Expanded(child: _buildCardResumo('Atenção', '${totais['Leve']}', const Color(0xFFFFA000))),
              const SizedBox(width: 8),
              Expanded(child: _buildCardResumo('Alerta', '${totais['Alerta']}', const Color(0xFFF44336))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDropdown(_filtroLocal, locais, (val) => setState(() => _filtroLocal = val!))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _buildFiltroStatus()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardResumo(String rotulo, String valor, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Text(valor, style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: cor)),
          Text(rotulo, style: GoogleFonts.lato(fontSize: 10, color: Colors.grey.shade600)),
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

  Widget _buildFiltroStatus() {
    const opcoes = ['Estável', 'Leve', 'Alerta', 'Pendente'];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: opcoes.map((op) {
        final selecionado = _statusSelecionados.contains(op);
        return GestureDetector(
          onTap: () => setState(() => selecionado ? _statusSelecionados.remove(op) : _statusSelecionados.add(op)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selecionado ? AppColors.primary : Colors.white,
              border: Border.all(color: selecionado ? AppColors.primary : const Color(0xFFD9D9D9)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(op, style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w600, color: selecionado ? Colors.white : const Color(0xFF3E3E3D))),
          ),
        );
      }).toList(),
    );
  }

  // Miniatura do card: se rompido, a foto da última medição (mais
  // informativa que um gráfico abstrato); senão, um mini-gráfico do
  // movimento (X,Y) — só quando há dados pra isso.
  Widget _buildThumb(PontoMonitoramentoResumoModel p) {
    const tamanho = 60.0;

    if (p.status == StatusFissura.rompido && p.fotoUltimaMedicao != null && p.fotoUltimaMedicao!.isNotEmpty) {
      // `DecorationImage` (não um `Image` filho) — o tamanho da pintura fica
      // preso ao box do Container independente da resolução nativa da foto,
      // evitando que a miniatura tente medir/ocupar o tamanho da imagem.
      return Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          image: DecorationImage(image: StorageNetworkImage(p.fotoUltimaMedicao!), fit: BoxFit.cover),
        ),
      );
    }

    if (p.medicoes.isEmpty) {
      return Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.show_chart, color: Colors.grey.shade400, size: 20),
      );
    }

    final pontos = p.medicoes.map((m) => _PontoXY(m.medidaX, m.medidaY)).toList();
    final maiorAbs = pontos.expand((pt) => [pt.x.abs(), pt.y.abs()]).reduce(max).clamp(0.2, double.infinity);
    final limite = maiorAbs * 1.4;

    return Container(
      width: tamanho,
      height: tamanho,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(10)),
      // ClipRRect + SizedBox.expand garante que o chart nunca peça mais
      // espaço do que a miniatura tem, mesmo que o Syncfusion tente medir
      // um tamanho mínimo próprio internamente.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox.expand(
          child: SfCartesianChart(
            margin: EdgeInsets.zero,
            plotAreaBorderWidth: 0,
            primaryXAxis: NumericAxis(minimum: -limite, maximum: limite, crossesAt: 0, isVisible: false, majorGridLines: const MajorGridLines(width: 0)),
            primaryYAxis: NumericAxis(minimum: -limite, maximum: limite, crossesAt: 0, isVisible: false, majorGridLines: const MajorGridLines(width: 0)),
            series: <CartesianSeries>[
              LineSeries<_PontoXY, double>(
                dataSource: pontos,
                xValueMapper: (d, _) => d.x,
                yValueMapper: (d, _) => d.y,
                color: AppColors.primary,
                width: 1.5,
              ),
              ScatterSeries<_PontoXY, double>(
                dataSource: [pontos.last],
                xValueMapper: (d, _) => d.x,
                yValueMapper: (d, _) => d.y,
                color: Colors.red,
                markerSettings: const MarkerSettings(isVisible: true, width: 6, height: 6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardPonto(PontoMonitoramentoResumoModel p) {
    final semLeitura = p.dataUltimaLeitura == null;
    final corStatus = semLeitura ? Colors.grey : p.status.cor;
    final rotuloStatus = semLeitura ? 'Pendente' : p.status.label;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PontoMonitoramentoFissuraScreen(
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 4, height: 60, decoration: BoxDecoration(color: corStatus, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 10),
            // Miniatura + status embaixo dela — mantém as duas coisas juntas
            // como uma unidade visual só, em vez de competir por espaço
            // horizontal com o texto (era isso que estourava o layout).
            Column(
              children: [
                _buildThumb(p),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: corStatus.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(rotuloStatus, style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, color: corStatus)),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p.nomePonto} · ${p.nomeElemento}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
                  ),
                  Text(p.local, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                        child: Text(p.tipoSelo.label, style: GoogleFonts.lato(fontSize: 10, color: Colors.grey.shade700)),
                      ),
                      if (!semLeitura)
                        Text(
                          '${DateFormat('dd/MM/yyyy').format(p.dataUltimaLeitura!)}${p.deltaMaxUltima != null ? ' · ±${p.deltaMaxUltima!.toStringAsFixed(1)}mm' : ''}',
                          style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
