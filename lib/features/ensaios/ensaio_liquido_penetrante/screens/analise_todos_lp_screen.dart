import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../models/liquido_penetrante_model.dart';
import '../providers/analise_todos_lp_provider.dart';
import '../widgets/lp_widgets.dart';
import 'ponto_liquido_penetrante_screen.dart';

/// Análise geral de Líquido penetrante (por estrutura): contagem por status
/// de todos os pontos, por elemento, com filtro de Local e Tipo de elemento.
class AnaliseTodosLPScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String projetoNome;
  final String estruturaId;
  final String estruturaNome;
  final String tipoEnsaioId;

  const AnaliseTodosLPScreen({
    super.key,
    required this.projetoId,
    required this.projetoNome,
    required this.estruturaId,
    required this.estruturaNome,
    required this.tipoEnsaioId,
  });

  @override
  ConsumerState<AnaliseTodosLPScreen> createState() => _AnaliseTodosLPScreenState();
}

class _AnaliseTodosLPScreenState extends ConsumerState<AnaliseTodosLPScreen> {
  static const _todosLocais = 'Locais';
  static const _todosTipos = 'Tipos de elemento';
  String _local = _todosLocais;
  String _tipo = _todosTipos;

  @override
  Widget build(BuildContext context) {
    final params = (projetoId: widget.projetoId, estruturaId: widget.estruturaId);
    final async = ref.watch(analiseTodosLPProvider(params));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Análise geral', style: TextStyle(fontSize: 11, color: Colors.white70)),
            Text('Líquido penetrante', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Erro ao carregar: $e', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => ref.invalidate(analiseTodosLPProvider(params)), child: const Text('Tentar de novo')),
              ],
            ),
          ),
        ),
        data: (todos) {
          if (todos.isEmpty) {
            return const Center(child: Text('Nenhum elemento ensaiado ainda.', style: TextStyle(color: Colors.grey)));
          }
          final locais = [_todosLocais, ...{for (final e in todos) e.local}];
          final tipos = [_todosTipos, ...{for (final e in todos) e.tipoElemento}];
          final filtrados = todos
              .where((e) => (_local == _todosLocais || e.local == _local) && (_tipo == _todosTipos || e.tipoElemento == _tipo))
              .toList();
          final total = filtrados.fold(const ContagemStatusLP(), (acc, e) => acc + e.contagem);

          return RefreshIndicator(
            onRefresh: () => ref.refresh(analiseTodosLPProvider(params).future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(widget.projetoNome, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
                Text(widget.estruturaNome, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _dropdown(_local, locais, (v) => setState(() => _local = v))),
                    const SizedBox(width: 10),
                    Expanded(child: _dropdown(_tipo, tipos, (v) => setState(() => _tipo = v))),
                  ],
                ),
                const SizedBox(height: 16),
                ResumoContagemLP(contagem: total, titulo: 'Todos os pontos · ${filtrados.length} elemento(s)'),
                const SizedBox(height: 16),
                if (filtrados.isNotEmpty) _grafico(filtrados),
                const SizedBox(height: 16),
                Text('Por elemento', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                for (final e in filtrados) _linhaElemento(e),
              ],
            ),
          );
        },
      ),
    );
  }

  // Barras empilhadas: uma por elemento, segmentada por status.
  Widget _grafico(List<ElementoLPResumo> elementos) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
      child: SizedBox(
        height: (elementos.length * 34.0 + 80).clamp(160.0, 420.0),
        child: SfCartesianChart(
          margin: EdgeInsets.zero,
          plotAreaBorderWidth: 0,
          legend: const Legend(isVisible: true, position: LegendPosition.top),
          primaryXAxis: const CategoryAxis(majorGridLines: MajorGridLines(width: 0)),
          primaryYAxis: const NumericAxis(interval: 1, title: AxisTitle(text: 'Pontos', textStyle: TextStyle(fontSize: 10))),
          series: <CartesianSeries<ElementoLPResumo, String>>[
            for (final s in StatusLP.values)
              StackedBarSeries<ElementoLPResumo, String>(
                name: s.label,
                color: s.cor,
                dataSource: elementos,
                xValueMapper: (e, _) => e.nomeElemento,
                yValueMapper: (e, _) => e.contagem.de(s),
              ),
          ],
        ),
      ),
    );
  }

  Widget _linhaElemento(ElementoLPResumo e) {
    final pior = e.contagem.pior;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PontoLiquidoPenetranteScreen(
              projetoId: widget.projetoId,
              pontoNome: e.nomeEnsaio,
              elementoNome: e.nomeElemento,
              tipoElemento: e.tipoElemento,
              local: e.local,
              elementoId: '',
              pontoGeralId: e.pontoGeralId,
              tipoEnsaioId: widget.tipoEnsaioId,
            ),
          ),
        ).then((_) => ref.invalidate(analiseTodosLPProvider)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: Row(
            children: [
              Container(width: 6, height: 36, decoration: BoxDecoration(color: pior?.cor ?? Colors.grey.shade300, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.nomeElemento, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D))),
                    Text('${e.tipoElemento} · ${e.local}', style: GoogleFonts.lato(fontSize: 11.5, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Text(e.contagem.textoBadge, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w700, color: pior?.cor ?? Colors.grey)),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown(String valor, List<String> itens, ValueChanged<String> onChanged) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFD9D9D9)), borderRadius: BorderRadius.circular(20)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: itens.contains(valor) ? valor : itens.first,
          style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF3E3E3D)),
          items: [for (final v in itens) DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
