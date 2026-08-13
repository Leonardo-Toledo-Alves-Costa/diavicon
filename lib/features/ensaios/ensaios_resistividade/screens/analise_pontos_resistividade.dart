import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';

import '../models/ponto_resistividade_model.dart';
import '../providers/analise_resistividade_provider.dart';

class AnalisePontoEnsaioResistividadeScreen extends ConsumerWidget {
  final String pontoGeralId;

  const AnalisePontoEnsaioResistividadeScreen({
    super.key,
    required this.pontoGeralId,
  });

  // Helper de tempo para o Gráfico
  DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return DateTime(2000, 1, 1);
    return DateTime(2000, 1, 1, int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
  }

  int _getDeltaMinutes(String horaAtual, String horaInicial) {
    final tAtual = _parseTime(horaAtual);
    final tIni = _parseTime(horaInicial);
    final diff = tAtual.difference(tIni);
    if (diff.isNegative) return 0;
    return diff.inMinutes;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analiseAsync = ref.watch(analiseResistividadeProvider(pontoGeralId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(systemNavigationBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        endDrawer: MenuDrawerAppBar(
          title: 'Ponto de\nensaio',
          items: [
            DiaviconMenuItem(
              icon: Icons.info_outline,
              label: 'Informações',
              onTap: () {
                Navigator.pop(context); // Fecha Drawer
                Navigator.pop(context); // Volta pra tela de inserção
              }
            ),
            Opacity(
              opacity: 0.4,
              child: DiaviconMenuItem(
                icon: Icons.show_chart_rounded,
                label: 'Análise',
                onTap: () {}, // Já estamos na tela
              ),
            ),
          ],
        ),
        appBar: const CustomAppBar(
          title: 'Ensaio',
          showBackButton: true,
          showMenuButton: false,
          titleWidget: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ponto de ensaio', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
              Text('Resistividade Elétrica', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.normal)),
            ],
          ),
        ),
        body: analiseAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, _) => Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text(err.toString(), style: const TextStyle(color: Colors.red)))),
          data: (dados) => SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- CABEÇALHO ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${dados.pontoNome} - ${dados.elementoNome}',
                        style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
                      ),
                    ),
                    const Icon(Icons.edit_square, color: Color(0xFF3E3E3D)),
                  ],
                ),
                Text(
                  '${dados.tipoElemento} \n${dados.local}',
                  style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF888888)),
                ),
                const SizedBox(height: 24),

                // --- CARD: RISCO DE CORROSÃO E MÉDIA ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFF57C00), size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Risco de Corrosão', style: GoogleFonts.lato(fontSize: 14, color: const Color(0xFF3E3E3D))),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(color: dados.riscoCorrosao['corFundo'], borderRadius: BorderRadius.circular(16)),
                              child: Text(
                                dados.riscoCorrosao['texto'],
                                style: TextStyle(color: dados.riscoCorrosao['corTxt'], fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            )
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Média', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('${dados.media.toStringAsFixed(0)} K.Ω.cm', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // --- GRÁFICO ---
                SizedBox(
                  height: 250,
                  child: SfCartesianChart(
                    primaryXAxis: NumericAxis(
                      title: AxisTitle(text: 'Tempo Decorrido (HH:mm)', textStyle: const TextStyle(fontSize: 10, color: Colors.grey)),
                      majorGridLines: const MajorGridLines(width: 0),
                      axisLabelFormatter: (AxisLabelRenderDetails details) {
                        final int totalMin = details.value.toInt();
                        final String h = (totalMin ~/ 60).toString().padLeft(2, '0');
                        final String m = (totalMin % 60).toString().padLeft(2, '0');
                        return ChartAxisLabel('$h:$m', details.textStyle);
                      },
                    ),
                    primaryYAxis: NumericAxis(
                      title: AxisTitle(text: 'Resistividade elétrica superficial (K.ohm.cm)', textStyle: const TextStyle(fontSize: 10, color: Colors.grey)),
                      axisLine: const AxisLine(width: 0),
                      majorTickLines: const MajorTickLines(size: 0),
                    ),
                    legend: Legend(isVisible: true, position: LegendPosition.top),
                    series: dados.leiturasAgrupadas.entries.map((entry) {
                      final dataList = List<PontoResistividadeLeituraModel>.from(entry.value);
                      dataList.sort((a, b) => _parseTime(a.hora).compareTo(_parseTime(b.hora)));
                      final horaInicial = dataList.isNotEmpty ? dataList.first.hora : '00:00';
                      
                      return LineSeries<PontoResistividadeLeituraModel, num>(
                        name: entry.key,
                        dataSource: dataList,
                        xValueMapper: (datum, index) => _getDeltaMinutes(datum.hora, horaInicial),
                        yValueMapper: (datum, index) => datum.resistividade,
                        markerSettings: const MarkerSettings(isVisible: true),
                        width: 2,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // --- ROW: MAIOR | MENOR | C.VAR ---
                Row(
                  children: [
                    Expanded(child: _buildValueCard('Maior', '${dados.maior.toStringAsFixed(0)} K.Ω.cm')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildValueCard('Menor', '${dados.menor.toStringAsFixed(0)} K.Ω.cm')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCVarCard(dados.coefVar, dados.isHomogeneo)),
                  ],
                ),
                const SizedBox(height: 16),

                // --- ROW: TAXA DE CORROSÃO | PERMISSIVIDADE ---
                Row(
                  children: [
                    Expanded(child: _buildStatusCard('Taxa de Corrosão', dados.taxaCorrosao)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatusCard('Permissividade iônica', dados.permissividade)),
                  ],
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Widgets Auxiliares ---
  Widget _buildValueCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
        ],
      ),
    );
  }

  Widget _buildCVarCard(double coefVar, bool isHomogeneo) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          const Text('C. Var', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text('${coefVar.toStringAsFixed(0)}%', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: isHomogeneo ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
            child: Text(
              isHomogeneo ? 'Homogêneo' : 'Heterogêneo',
              style: TextStyle(fontSize: 9, color: isHomogeneo ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String label, Map<String, dynamic> status) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: status['corFundo'], borderRadius: BorderRadius.circular(16)),
            child: Text(
              status['texto'],
              textAlign: TextAlign.center,
              style: TextStyle(color: status['corTxt'], fontWeight: FontWeight.bold, fontSize: 13),
            ),
          )
        ],
      ),
    );
  }
}