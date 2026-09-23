import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../documentos_legais.dart';

const _corTexto = Color(0xFF3E3E3D);

/// Mostra um documento legal a partir do Markdown em assets/legal/.
///
/// Renderizador mínimo, só com o que os documentos usam: títulos (#, ##),
/// parágrafos, listas (-), tabelas simples (| a | b |) e **negrito**. Evita
/// uma dependência nova só para isso.
class TextoLegal extends StatelessWidget {
  final DocumentoLegal documento;
  final EdgeInsetsGeometry padding;
  final bool rolavel;

  const TextoLegal({
    super.key,
    required this.documento,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 32),
    this.rolavel = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: rootBundle.loadString(documento.asset),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: padding,
            child: Text(
              'Não foi possível carregar o documento. Consulte ${documento == DocumentoLegal.privacidade ? DocumentosLegais.urlPrivacidade : DocumentosLegais.urlTermos}.',
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
        }
        final blocos = _montar(snap.data!);
        if (!rolavel) {
          return Padding(
            padding: padding,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: blocos),
          );
        }
        return ListView(padding: padding, children: blocos);
      },
    );
  }

  List<Widget> _montar(String md) {
    final linhas = md.replaceAll('\r\n', '\n').split('\n');
    final widgets = <Widget>[];
    final paragrafo = <String>[];
    final tabela = <List<String>>[];

    void fecharParagrafo() {
      if (paragrafo.isEmpty) return;
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _rico(paragrafo.join(' '), const TextStyle(fontSize: 14, height: 1.45, color: _corTexto)),
      ));
      paragrafo.clear();
    }

    void fecharTabela() {
      if (tabela.isEmpty) return;
      widgets.add(_Tabela(linhas: List.of(tabela)));
      tabela.clear();
    }

    for (final bruta in linhas) {
      final linha = bruta.trimRight();
      if (linha.startsWith('|')) {
        fecharParagrafo();
        final celulas = linha.substring(1, linha.endsWith('|') ? linha.length - 1 : linha.length).split('|').map((c) => c.trim()).toList();
        final separador = celulas.every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c));
        if (!separador) tabela.add(celulas);
        continue;
      }
      fecharTabela();
      if (linha.isEmpty) {
        fecharParagrafo();
      } else if (linha.startsWith('# ')) {
        fecharParagrafo();
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(linha.substring(2), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _corTexto, fontFamily: 'Lato')),
        ));
      } else if (linha.startsWith('## ')) {
        fecharParagrafo();
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Text(linha.substring(3), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _corTexto, fontFamily: 'Lato')),
        ));
      } else if (linha.startsWith('- ')) {
        fecharParagrafo();
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 1, right: 8), child: Text('•', style: TextStyle(fontSize: 14, color: _corTexto))),
            Expanded(child: _rico(linha.substring(2), const TextStyle(fontSize: 14, height: 1.4, color: _corTexto))),
          ]),
        ));
      } else {
        paragrafo.add(linha);
      }
    }
    fecharParagrafo();
    fecharTabela();
    return widgets;
  }
}

/// Texto com trechos entre ** em negrito.
Widget _rico(String texto, TextStyle estilo) {
  final partes = texto.split('**');
  return Text.rich(TextSpan(
    style: estilo,
    children: [
      for (var i = 0; i < partes.length; i++)
        TextSpan(text: partes[i], style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null),
    ],
  ));
}

class _Tabela extends StatelessWidget {
  final List<List<String>> linhas;
  const _Tabela({required this.linhas});

  @override
  Widget build(BuildContext context) {
    final colunas = linhas.first.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Table(
        border: TableBorder.all(color: const Color(0xFFD9D9D9)),
        columnWidths: {for (var i = 0; i < colunas; i++) i: const FlexColumnWidth()},
        children: [
          for (var l = 0; l < linhas.length; l++)
            TableRow(
              decoration: BoxDecoration(color: l == 0 ? const Color(0xFFF2F2F2) : null),
              children: [
                for (var c = 0; c < colunas; c++)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: _rico(
                      c < linhas[l].length ? linhas[l][c] : '',
                      TextStyle(fontSize: 12.5, height: 1.35, color: _corTexto, fontWeight: l == 0 ? FontWeight.w700 : FontWeight.normal),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
