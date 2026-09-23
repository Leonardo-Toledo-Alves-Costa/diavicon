import '../models/gasto_model.dart';

// Toda conta das telas de gastos (Meus Gastos, Gastos do Projeto, Análise
// de Gastos) e da exportação passa por aqui — uma fonte só, para a tela e o
// relatório nunca divergirem.

const _meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

/// "R$ 12.400" (sem centavos, para cards e gráficos) ou "R$ 12.400,50".
String formatarMoeda(double valor, {bool centavos = true}) {
  final negativo = valor < 0;
  // Arredonda uma vez só, em centavos (12,999 vira 13,00, não 12,99).
  final totalCentavos = (valor.abs() * 100).round();
  final inteiro = centavos ? totalCentavos ~/ 100 : (totalCentavos / 100).round();
  final digitos = inteiro.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digitos[i]);
  }
  var texto = 'R\$ ${negativo ? '-' : ''}$buffer';
  if (centavos) {
    texto += ',${(totalCentavos % 100).toString().padLeft(2, '0')}';
  }
  return texto;
}

/// Valor digitado pelo usuário ("1.234,56", "1234.56", "48") → double.
double? lerValorDigitado(String texto) {
  var t = texto.replaceAll('R\$', '').replaceAll(' ', '').trim();
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
    // "1.234" sem vírgula é milhar à brasileira, não 1,234.
    t = t.replaceAll('.', '');
  }
  return double.tryParse(t);
}

String formatarData(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String formatarMesAno(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${d.year}';

String rotuloMesCurto(DateTime d) => _meses[d.month - 1];

/// "Set/26" — rótulo de eixo, curto o bastante para caber lado a lado.
String rotuloMesAnoCurto(DateTime d) => '${rotuloMesCurto(d)}/${(d.year % 100).toString().padLeft(2, '0')}';

class TotaisGastos {
  final double total;
  final double reembolsavel;
  final double naoReembolsavel;
  const TotaisGastos({required this.total, required this.reembolsavel, required this.naoReembolsavel});
}

/// Um item de ranking (projeto, categoria ou usuário) e o valor somado.
class ItemAgregado {
  final String chave;
  final String rotulo;
  final double valor;
  final double reembolsavel;
  final double naoReembolsavel;
  const ItemAgregado({
    required this.chave,
    required this.rotulo,
    required this.valor,
    this.reembolsavel = 0,
    this.naoReembolsavel = 0,
  });
}

class ValorMensal {
  final DateTime mes;
  final double valor;
  const ValorMensal(this.mes, this.valor);
}

class AgregacaoGastos {
  const AgregacaoGastos._();

  static TotaisGastos totais(Iterable<GastoModel> gastos) {
    var reemb = 0.0;
    var nao = 0.0;
    for (final g in gastos) {
      if (g.reembolsavel) {
        reemb += g.valor;
      } else {
        nao += g.valor;
      }
    }
    return TotaisGastos(total: reemb + nao, reembolsavel: reemb, naoReembolsavel: nao);
  }

  /// Soma por uma chave, do maior para o menor (empate: ordem alfabética).
  static List<ItemAgregado> agrupar(
    Iterable<GastoModel> gastos, {
    required String Function(GastoModel) chave,
    required String Function(GastoModel) rotulo,
  }) {
    final somas = <String, _Acumulador>{};
    for (final g in gastos) {
      final acc = somas.putIfAbsent(chave(g), () => _Acumulador(rotulo(g)));
      if (g.reembolsavel) {
        acc.reembolsavel += g.valor;
      } else {
        acc.naoReembolsavel += g.valor;
      }
    }
    final itens = somas.entries
        .map((e) => ItemAgregado(
              chave: e.key,
              rotulo: e.value.rotulo,
              valor: e.value.reembolsavel + e.value.naoReembolsavel,
              reembolsavel: e.value.reembolsavel,
              naoReembolsavel: e.value.naoReembolsavel,
            ))
        .toList()
      ..sort((a, b) {
        final porValor = b.valor.compareTo(a.valor);
        return porValor != 0 ? porValor : a.rotulo.toLowerCase().compareTo(b.rotulo.toLowerCase());
      });
    return itens;
  }

  static List<ItemAgregado> porProjeto(Iterable<GastoModel> gastos) =>
      agrupar(gastos, chave: (g) => g.projetoId, rotulo: (g) => g.projetoNome);

  static List<ItemAgregado> porCategoria(Iterable<GastoModel> gastos) =>
      agrupar(gastos, chave: (g) => g.categoriaId, rotulo: (g) => g.categoriaNome);

  static List<ItemAgregado> porUsuario(Iterable<GastoModel> gastos) =>
      agrupar(gastos, chave: (g) => g.usuarioId, rotulo: (g) => g.usuarioNome);

  /// Soma dos últimos [quantidade] meses terminando em [mesFinal] (inclusive),
  /// em ordem cronológica — meses sem gasto entram com 0.
  static List<ValorMensal> ultimosMeses(Iterable<GastoModel> gastos, DateTime mesFinal, {int quantidade = 4}) {
    final meses = [
      for (var i = quantidade - 1; i >= 0; i--) DateTime(mesFinal.year, mesFinal.month - i),
    ];
    return [
      for (final m in meses)
        ValorMensal(
          m,
          gastos.where((g) => mesmoMes(g.data, m)).fold(0.0, (soma, g) => soma + g.valor),
        ),
    ];
  }

  /// Soma por mês de [inicio] a [fim], em ordem cronológica.
  ///
  /// Meses sem gasto entram com zero: sem isso o gráfico "pula" períodos e
  /// dá a impressão de que o dinheiro foi gasto de forma contínua.
  static List<ValorMensal> porMesNoPeriodo(Iterable<GastoModel> gastos, DateTime inicio, DateTime fim) {
    final pontos = <ValorMensal>[];
    var m = DateTime(inicio.year, inicio.month);
    final ultimo = DateTime(fim.year, fim.month);
    while (!m.isAfter(ultimo)) {
      final mes = m;
      pontos.add(
        ValorMensal(mes, gastos.where((g) => mesmoMes(g.data, mes)).fold(0.0, (soma, g) => soma + g.valor)),
      );
      m = DateTime(m.year, m.month + 1);
    }
    return pontos;
  }

  static bool mesmoMes(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  /// Filtro de período inclusivo nos dois extremos (datas sem hora).
  static List<GastoModel> noPeriodo(Iterable<GastoModel> gastos, DateTime inicio, DateTime fim) {
    final i = DateTime(inicio.year, inicio.month, inicio.day);
    final f = DateTime(fim.year, fim.month, fim.day);
    return gastos.where((g) {
      final d = DateTime(g.data.year, g.data.month, g.data.day);
      return !d.isBefore(i) && !d.isAfter(f);
    }).toList();
  }
}

class _Acumulador {
  final String rotulo;
  double reembolsavel = 0;
  double naoReembolsavel = 0;
  _Acumulador(this.rotulo);
}
