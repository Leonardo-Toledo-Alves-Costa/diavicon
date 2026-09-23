import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/classe_qualitativa.dart';
import '../models/bi_data_point.dart';
import '../utils/classificadores_bi.dart';

/// Card de badge de classificação qualitativa.
///
/// Com um elemento só (dashboard de elemento), mostra o selo da classe e o
/// valor que a gerou. Com vários, mostra a distribuição — quantos elementos
/// em cada classe, da mais grave para a mais branda.
class BiBadgeCard extends StatelessWidget {
  const BiBadgeCard({super.key, required this.classificador, required this.series});

  final ClassificadorBi classificador;

  /// alias da entrada -> pontos buscados.
  final Map<String, List<BiDataPoint>> series;

  @override
  Widget build(BuildContext context) {
    final resultado = distribuirBadge(classificador, series);
    if (resultado.vazio) {
      return Center(
        child: Text('Sem dados para classificar', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
      );
    }

    final variasDimensoes = resultado.dimensoes.length > 1;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final dim in resultado.dimensoes) ...[
            if (variasDimensoes)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Text(
                  dim.dimensao.nome,
                  style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.greyMediumDark),
                ),
              ),
            if (dim.unico != null)
              _Selo(classe: dim.unico!.classe, valor: dim.unico!.valor)
            else if (dim.contagens.isEmpty)
              Text('Nenhuma ocorrência', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in dim.contagens) _Chip(classe: c.classe, quantidade: c.quantidade),
                ],
              ),
            if (dim.semClassificacao > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${dim.semClassificacao} ${dim.semClassificacao == 1 ? 'elemento' : 'elementos'} sem dado suficiente',
                  style: GoogleFonts.lato(fontSize: 10, color: Colors.grey),
                ),
              ),
            if (variasDimensoes) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _Selo extends StatelessWidget {
  const _Selo({required this.classe, required this.valor});
  final ClasseQualitativa classe;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: classe.corFundo, borderRadius: BorderRadius.circular(14)),
          child: Text(
            classe.texto,
            style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w900, color: classe.corTexto),
          ),
        ),
        if (valor.isNotEmpty) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text(valor, style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyMediumDark)),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.classe, required this.quantidade});
  final ClasseQualitativa classe;
  final int quantidade;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: classe.corFundo, borderRadius: BorderRadius.circular(12)),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$quantidade ', style: const TextStyle(fontWeight: FontWeight.w900)),
          TextSpan(text: classe.texto),
        ]),
        style: GoogleFonts.lato(fontSize: 11, color: classe.corTexto, fontWeight: FontWeight.w600),
      ),
    );
  }
}
