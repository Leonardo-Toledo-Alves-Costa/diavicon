import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../models/bi_data_point.dart';
import '../models/dashboard_card_model.dart';
import '../repositories/dashboard_bi_repository.dart';
import '../utils/formato_bi.dart';

/// Card de tabela: uma linha por grupo ([DashboardCardModel.agruparPor] —
/// elemento, local ou tipo de elemento) e uma coluna por
/// [DashboardCardModel.colunas], na ordem e com os títulos definidos no
/// dashboard.
class BiTabelaCard extends StatelessWidget {
  const BiTabelaCard({super.key, required this.card, required this.series});

  final DashboardCardModel card;

  /// id da coluna -> pontos buscados.
  final Map<String, List<BiDataPoint>> series;

  @override
  Widget build(BuildContext context) {
    final agruparPor = card.agruparPor ?? 'elemento';
    final repo = DashboardBiRepository();

    // coluna -> grupo -> valor (média ou soma do grupo, conforme o campo).
    final porColuna = {
      for (final c in card.colunas)
        c.id: repo.agruparValores(series[c.id] ?? const [], agruparPor, agregacao: DashboardBiRepository.agregacaoDe(c.valor)),
    };
    final linhas = porColuna.values.expand((m) => m.keys).toSet().toList()..sort(compararRotulosBi);

    if (card.colunas.isEmpty || linhas.isEmpty) {
      return Center(child: Text('Sem dados', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)));
    }

    final estiloCabecalho = GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textDark);
    final estiloCelula = GoogleFonts.lato(fontSize: 12, color: AppColors.textDark);

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          // Altura para até 3 linhas de título: títulos longos quebram em vez
          // de alargar a coluna (ou serem cortados).
          headingRowHeight: 50,
          dataRowMinHeight: 30,
          dataRowMaxHeight: 34,
          columnSpacing: 18,
          horizontalMargin: 4,
          columns: [
            DataColumn(label: _cabecalho(_rotuloAgrupamento(agruparPor), estiloCabecalho)),
            for (final c in card.colunas)
              DataColumn(
                numeric: true,
                label: _cabecalho(c.valor.unidade == null ? c.titulo : '${c.titulo} (${c.valor.unidade})', estiloCabecalho),
              ),
          ],
          rows: [
            for (final linha in linhas)
              DataRow(cells: [
                DataCell(Text(linha, style: estiloCelula.copyWith(fontWeight: FontWeight.w600))),
                for (final c in card.colunas)
                  () {
                    final valor = porColuna[c.id]?[linha];
                    final cor = c.corPara(valor);
                    return DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: cor == null
                            ? null
                            : BoxDecoration(color: cor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          formatarNumeroBi(valor),
                          style: estiloCelula.copyWith(
                            color: cor ?? AppColors.textDark,
                            fontWeight: cor == null ? FontWeight.w400 : FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  }(),
              ]),
          ],
        ),
      ),
    );
  }

  /// Título de coluna com quebra de linha: largura máxima fixa e até três
  /// linhas, com reticências só se ainda assim não couber.
  static Widget _cabecalho(String texto, TextStyle estilo) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 110),
        child: Text(texto, style: estilo, softWrap: true, maxLines: 3, overflow: TextOverflow.ellipsis),
      );

  static String _rotuloAgrupamento(String a) => switch (a) {
        'local' => 'Local',
        'tipoElemento' => 'Tipo',
        'estrutura' => 'Estrutura',
        'data' => 'Data',
        _ => 'Elemento',
      };
}
