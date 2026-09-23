import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/widgets/custom_appbar.dart';
import '../../../../../core/widgets/custom_empty_state.dart';
import '../../ultrassom_direto/models/ultrassom_direto_model.dart' show ClassificacaoWhitehurst;
import '../../ultrassom_direto/widgets/whitehurst_info_dialog.dart';
import '../models/ultrassom_indireto_model.dart';
import '../repositories/ultrassom_indireto_repository.dart';

// Análise individual do ensaio (todos os pontos de medição do MESMO ponto
// de ensaio geral) — praticamente igual à do método Direto
// (`AnalisePontoUltrassomDiretoScreen`), só trocando "média das leituras"
// por "velocidade verdadeira" de cada ponto (calculada por regressão).
class AnalisePontoUltrassomIndiretoScreen extends ConsumerStatefulWidget {
  final String pontoGeralId;
  const AnalisePontoUltrassomIndiretoScreen({super.key, required this.pontoGeralId});

  @override
  ConsumerState<AnalisePontoUltrassomIndiretoScreen> createState() => _AnalisePontoUltrassomIndiretoScreenState();
}

class _AnalisePontoUltrassomIndiretoScreenState extends ConsumerState<AnalisePontoUltrassomIndiretoScreen> {
  bool _isLoading = true;
  String _nomePonto = '';
  String _elementoNome = '';
  String _tipoElemento = '';
  String _local = '';
  PontoUltrassomIndiretoModel? _ultrassom;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final supabase = Supabase.instance.client;
      final geral = await supabase.from('pontos_ensaios_geral').select('nome_ponto, elementos_estruturais(nome, tipo, local)').eq('id', widget.pontoGeralId).maybeSingle();

      _nomePonto = geral?['nome_ponto'] ?? '';
      final elemento = geral?['elementos_estruturais'] as Map<String, dynamic>?;
      _elementoNome = elemento?['nome'] ?? '';
      _tipoElemento = elemento?['tipo'] ?? '-';
      _local = elemento?['local'] ?? '-';

      _ultrassom = await ref.read(ultrassomIndiretoRepositoryProvider).buscarPontoUltrassom(widget.pontoGeralId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar análise: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));

    final medicoesComDados = (_ultrassom?.medicoes ?? []).where((m) => m.valorVelocidade > 0).toList();
    final mediaGeral = _ultrassom?.mediaGeral ?? 0.0;
    final cv = _ultrassom?.coefVariacaoGeral ?? 0.0;
    final classificacao = ClassificacaoWhitehurst.classificar(mediaGeral);
    final isHomogeneo = cv <= 15.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ponto de ensaio', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Ultrassonografia', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$_nomePonto - $_elementoNome', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            Text('$_tipoElemento\n$_local', style: GoogleFonts.lato(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 24),
            if (medicoesComDados.isEmpty)
              const Padding(padding: EdgeInsets.only(top: 32), child: CustomEmptyState(text: 'Nenhuma leitura coletada.'))
            else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
                child: SizedBox(
                  height: 280,
                  child: SfCartesianChart(
                    primaryXAxis: const CategoryAxis(majorGridLines: MajorGridLines(width: 0)),
                    primaryYAxis: NumericAxis(title: const AxisTitle(text: 'Velocidade do pulso ultrassônico (m/s)', textStyle: TextStyle(fontSize: 10, color: Colors.grey)), axisLine: const AxisLine(width: 0)),
                    legend: const Legend(isVisible: true, position: LegendPosition.top),
                    series: <CartesianSeries>[
                      ColumnSeries<MedicaoUltrassomIndiretoModel, String>(
                        name: 'Velocidade',
                        dataSource: medicoesComDados,
                        xValueMapper: (m, _) => m.nomePonto,
                        yValueMapper: (m, _) => m.valorVelocidade,
                        color: AppColors.primary,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                      LineSeries<MedicaoUltrassomIndiretoModel, String>(
                        name: 'Média',
                        dataSource: medicoesComDados,
                        xValueMapper: (m, _) => m.nomePonto,
                        yValueMapper: (m, _) => mediaGeral,
                        color: const Color(0xFF1B2A4A),
                        dashArray: const [6, 4],
                        width: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _cardEstatistica('Média', '${mediaGeral.toStringAsFixed(0)} m/s')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
                      child: Column(
                        children: [
                          const Text('Coef. de variação', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Text('${cv.toStringAsFixed(0)}%', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: isHomogeneo ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
                            child: Text(isHomogeneo ? 'Homogêneo' : 'Heterogêneo', style: TextStyle(fontSize: 10, color: isHomogeneo ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => showWhitehurstInfoDialog(context),
                      child: _cardEstatistica('Classificação', classificacao.texto, corValor: classificacao.cor, iconeInfo: true),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cardEstatistica(String label, String valor, {Color? corValor, bool iconeInfo = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
              if (iconeInfo) ...[const SizedBox(width: 3), Icon(Icons.info_outline, size: 11, color: Colors.grey.shade400)],
            ],
          ),
          const SizedBox(height: 6),
          Text(valor, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: corValor ?? const Color(0xFF3E3E3D))),
        ],
      ),
    );
  }
}
