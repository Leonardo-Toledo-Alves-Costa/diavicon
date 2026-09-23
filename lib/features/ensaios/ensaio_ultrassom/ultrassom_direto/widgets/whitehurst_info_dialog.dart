import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ultrassom_direto_model.dart';

// Popup de ajuda com a tabela de classificação de Whitehurst — aberto ao
// tocar no ícone de informação junto ao card "Classificação".
Future<void> showWhitehurstInfoDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Classificação de Whitehurst', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16)),
      content: SingleChildScrollView(
        child: Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2)},
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade100),
              children: [
                _celula('Velocidade da onda ultrassônica (m/s)', negrito: true),
                _celula('Qualidade do concreto', negrito: true),
              ],
            ),
            for (final linha in ClassificacaoWhitehurst.tabela)
              TableRow(children: [_celula(linha.faixa), _celula(linha.classe)]),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
      ],
    ),
  );
}

Widget _celula(String texto, {bool negrito = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: Text(texto, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: negrito ? FontWeight.bold : FontWeight.normal)),
  );
}
