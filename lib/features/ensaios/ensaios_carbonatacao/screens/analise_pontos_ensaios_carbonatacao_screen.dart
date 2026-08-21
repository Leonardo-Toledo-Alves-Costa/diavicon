import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';

// Imports locais
import '../providers/analise_carbonatacao_provider.dart';
import '../widgets/carbonatacao_chart_widget.dart';
import 'ponto_ensaio_carbonatacao_screen.dart';

class AnalisePontosEnsaiosCarbonatacaoScreen extends ConsumerWidget {
  final String pontoGeralId;


  const AnalisePontosEnsaiosCarbonatacaoScreen({
    super.key,
    required this.pontoGeralId,
  });

  // Exibe a Tabela de Riscos em formato de Modal/Popup
  void _mostrarPopupTabelaRiscos(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFFF1C40F), borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                    'Tempo Estimado para Despassivação',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),
                Table(
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columnWidths: const {
                    0: FlexColumnWidth(1.2),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                  },
                  children: [
                    _buildTableRow(const Color(0xFFFF4C4C), 'Armadura\nDespassivada', 'Corrosão iniciada', 'Intervenção\nIminente'),
                    _buildTableRow(const Color(0xFFFF8C00), '0 - 5 anos', 'Risco alto', 'Intervenção Urgente'),
                    _buildTableRow(const Color(0xFFFFB74D), '5 - 15 anos', 'Risco Moderado', 'Intervenção\nPreventiva'),
                    _buildTableRow(const Color(0xFFAED581), '15 - 30 anos', 'Risco Baixo', 'Monitoramento\nPeriódico'),
                    _buildTableRow(const Color(0xFF81C784), 'Mais que 30 anos', 'Risco Irrelevante', 'Monitoramento\nPeriódico'),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fechar', style: TextStyle(color: AppColors.primary)),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  TableRow _buildTableRow(Color bgColor, String col1, String col2, String col3) {
    return TableRow(
      children: [
        Container(
          color: bgColor,
          padding: const EdgeInsets.all(12),
          child: Center(child: Text(col1, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87))),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Center(child: Text(col2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Center(child: Text(col3, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analiseAsync = ref.watch(analiseCarbonatacaoProvider(pontoGeralId));

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
              onTap: (){
                Navigator.pop(context);
                Navigator.pop(context);
               } // Volta para a tela anterior
            ),
            DiaviconMenuItem(
              icon: Icons.camera_alt_outlined, 
              label: 'Fotos', 
              onTap: () {}, // Rota futura
            ),
            // Tratamento do VoidCallback: Usamos uma função vazia `() {}`
            Opacity(
              opacity: 0.4,
              child: DiaviconMenuItem(
              icon: Icons.show_chart_rounded, 
              label: 'Análise', 
              onTap: () {}, // <--- Correção aplicada. Desativa funcionalidade preservando tipagem.
              ),
            ),
          ],
        ),
        appBar: CustomAppBar(
          title: 'Ensaio',
          showBackButton: true,
          showMenuButton: false,
          titleWidget: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ponto de ensaio', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
              // Verifica dinamicamente se o dado já carregou para mostrar o tipo
              analiseAsync.maybeWhen(
                data: (dados) => Text(
                  dados.tipoEnsaio,
                  style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.normal),
                ),
                orElse: () => const SizedBox.shrink(), // Não mostra nada enquanto carrega
              ),
            ],
          ),
        ),
        body: analiseAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(err.toString(), style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            ),
          ),
          data: (dados) => SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // CABEÇALHO DO PONTO
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${dados.pontoNome} - ${dados.elementoNome}',
                        style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
                      ),
                    ),
                    //const Icon(Icons.edit_square, color: Color(0xFF3E3E3D)),
                  ],
                ),
                Text(
                  '${dados.tipoElemento} \n${dados.local}',
                  style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF888888)),
                ),
                const SizedBox(height: 24),

                // ROW: IDADE | AMBIENTE | CAA
                Row(
                  children: [
                    Expanded(child: _buildInfoCard('${dados.idadeAnos} anos', 'Exposição')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildInfoCard(dados.ambiente, 'Ambiente')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildInfoCard(dados.caa, 'CAA')),
                  ],
                ),
                const SizedBox(height: 8),

                // REVESTIMENTO
                _buildInfoCard(dados.revestimento, 'Revestimento'),
                const SizedBox(height: 16),

                // ARMADURAS
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        '${dados.cobArmP?.toStringAsFixed(0) ?? '-'} mm | Ø ${dados.bitArmP?.toStringAsFixed(1) ?? '-'}', 
                        'Armadura principal'
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        '${dados.cobArmS?.toStringAsFixed(0) ?? '-'} mm | Ø ${dados.bitArmS?.toStringAsFixed(1) ?? '-'}', 
                        'Armadura secundária'
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // FRENTE DE CARBONATAÇÃO
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Frente de Carbonatação', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                          const SizedBox(height: 4),
                          Text(
                            'Maior: ${dados.carbonatacaoMaior.toStringAsFixed(0)} mm | Menor: ${dados.carbonatacaoMenor.toStringAsFixed(0)} mm', 
                            style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Média', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('${dados.carbonatacaoMedia.toStringAsFixed(0)} mm', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // COEFICIENTES E VARIAÇÃO
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard('${dados.coefCarb.toStringAsFixed(1)} mm/ano½', 'Coef. de Carbonatação'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('Coef.de variação', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${dados.coefVariacao.toStringAsFixed(0)}%', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: dados.isHomogeneo ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    dados.isHomogeneo ? 'Homogêneo' : 'Heterogêneo',
                                    style: TextStyle(fontSize: 9, color: dados.isHomogeneo ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ALERTA DE TEMPO PARA DESPASSIVAÇÃO E BOTÃO DE INFO
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Tempo para despassivação', style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF3E3E3D))),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _mostrarPopupTabelaRiscos(context),
                                  child: const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                                )
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(color: dados.corRisco.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                              child: Text(
                                dados.condicaoRisco,
                                style: TextStyle(color: dados.corRisco, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            )
                          ],
                        ),
                      ),
                      Text(
                        dados.condicaoRisco == "Despassivado" ? 'Já ocorreu' : '${dados.tempoCalc.toStringAsFixed(0)} anos', 
                        style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // GRÁFICO
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem(Colors.grey.shade700, 'Frente de Carbonatação (mm)'),
                    const SizedBox(width: 12),
                    _buildLegendItem(Color(0xFFDDA0DD), 'Cobrimento (mm)'),
                    const SizedBox(width: 12),
                    _buildLegendItem(Colors.orange, 'Idade'),
                  ],
                ),
                const SizedBox(height: 16),
                
                CarbonatacaoChartWidget(
                  tempoAnalise: dados.tempoAnaliseGrafico,
                  cobrimento: dados.cobrimentoEfetivo,
                  coefCarb: dados.coefCarb,
                  idadeAtual: dados.idadeAnos,
                  tempoDespassivacao: dados.tempoCarbonatar,
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(value, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }
}