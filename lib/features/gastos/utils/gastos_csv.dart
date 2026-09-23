import '../models/gasto_model.dart';
import 'agregacao_gastos.dart';

// CSV da análise de gastos. Formato pensado para abrir direto no Excel em
// português: separador `;` (a vírgula é o separador decimal), valores com
// vírgula decimal e BOM UTF-8 para os acentos aparecerem certos.
class GastosCsv {
  const GastosCsv._();

  static const cabecalho = [
    'Data',
    'Projeto',
    'Categoria',
    'Usuário',
    'Valor (R\$)',
    'Reembolsável',
    'Meio de pagamento',
  ];

  static String gerar(List<GastoModel> gastos) {
    final linhas = <String>[cabecalho.map(_celula).join(';')];
    for (final g in gastos) {
      linhas.add([
        formatarData(g.data),
        g.projetoNome,
        g.categoriaNome,
        g.usuarioNome,
        g.valor.toStringAsFixed(2).replaceAll('.', ','),
        g.reembolsavel ? 'Sim' : 'Não',
        g.meioPagamento.rotulo,
      ].map(_celula).join(';'));
    }
    return '﻿${linhas.join('\r\n')}\r\n';
  }

  // Aspas quando o texto tem separador, aspas ou quebra de linha (RFC 4180).
  static String _celula(String valor) {
    final precisaAspas = valor.contains(';') || valor.contains('"') || valor.contains('\n') || valor.contains('\r');
    if (!precisaAspas) return valor;
    return '"${valor.replaceAll('"', '""')}"';
  }
}
