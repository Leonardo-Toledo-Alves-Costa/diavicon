import 'dart:math' as math;

import 'package:expressions/expressions.dart';

import '../models/variavel_bi_model.dart';

/// Resultado da validação estática de uma variável — o que dá pra decidir
/// SEM nenhum dado, e que por isso deve bloquear o salvamento.
class ValidacaoVariavelBi {
  final List<String> erros;
  const ValidacaoVariavelBi(this.erros);
  bool get ok => erros.isEmpty;
}

/// Avalia a expressão de uma [VariavelBiModel].
///
/// A validação é deliberadamente em duas camadas, porque os dois tipos de
/// falha são diferentes:
///
///  - o que independe de dado (sintaxe, alias inexistente, função
///    desconhecida) é erro do autor e **impede salvar** — ver [validar];
///  - o que só o dado revela (divisão por zero, raiz de negativo, elemento
///    sem um dos ensaios) é normal em campo e **não é erro**: [avaliar]
///    devolve null e quem chama conta quantos elementos ficaram de fora.
///
/// Só existe aritmética e um conjunto fechado de funções matemáticas. Nada
/// vindo do banco chega a executar código.
class VariavelBiAvaliador {
  static final Map<String, Function> _funcoes = {
    'pow': (num x, num e) => math.pow(x, e),
    'sqrt': (num x) => math.sqrt(x),
    'log': (num x) => math.log(x),
    'exp': (num x) => math.exp(x),
    'abs': (num x) => x.abs(),
    'min': (num a, num b) => math.min(a, b),
    'max': (num a, num b) => math.max(a, b),
  };

  /// Nomes que a expressão pode referenciar: aliases das entradas, chaves dos
  /// parâmetros e as funções acima.
  static Set<String> _nomesPermitidos(VariavelBiModel v) => {
        ...v.entradas.map((e) => e.alias),
        ...v.parametros.keys,
        ..._funcoes.keys,
      };

  static final RegExp _identificador = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  /// Tudo que é decidível sem dado nenhum. Se retornar erros, não salve.
  static ValidacaoVariavelBi validar(VariavelBiModel variavel) {
    final erros = <String>[];

    if (variavel.nome.trim().isEmpty) erros.add('Dê um nome à variável.');
    if (variavel.expressao.trim().isEmpty) erros.add('A expressão está vazia.');
    if (variavel.entradas.isEmpty) erros.add('Escolha ao menos uma variável de ensaio.');

    final vistos = <String>{};
    for (final entrada in variavel.entradas) {
      if (!_identificador.hasMatch(entrada.alias)) {
        erros.add('"${entrada.alias}" não serve como nome na fórmula (use letras, números e _, começando por letra).');
      }
      if (!vistos.add(entrada.alias)) {
        erros.add('O nome "${entrada.alias}" está sendo usado por mais de uma variável de ensaio.');
      }
      if (entrada.fonte.isEmpty || entrada.campo.isEmpty) {
        erros.add('A variável "${entrada.alias}" não está ligada a um campo de ensaio.');
      }
    }
    for (final parametro in variavel.parametros.keys) {
      if (!_identificador.hasMatch(parametro)) {
        erros.add('"$parametro" não serve como nome de parâmetro.');
      }
      if (!vistos.add(parametro)) {
        erros.add('O nome "$parametro" é usado por uma variável de ensaio e por um parâmetro ao mesmo tempo.');
      }
    }

    if (variavel.valorMin != null && variavel.valorMax != null && variavel.valorMin! > variavel.valorMax!) {
      erros.add('A faixa esperada está invertida: o mínimo é maior que o máximo.');
    }

    if (erros.isNotEmpty) return ValidacaoVariavelBi(erros);

    // Parse + checagem de nomes só depois que os aliases estão sãos, senão a
    // mensagem de sintaxe abafa o erro real.
    final Expression expressao;
    try {
      expressao = Expression.parse(variavel.expressao);
    } catch (e) {
      return ValidacaoVariavelBi(['A expressão não pôde ser interpretada. Confira parênteses e operadores.']);
    }

    final permitidos = _nomesPermitidos(variavel);
    for (final nome in _identificadoresUsados(variavel.expressao)) {
      if (!permitidos.contains(nome)) {
        erros.add('"$nome" não existe: não é uma variável de ensaio, um parâmetro nem uma função conhecida.');
      }
    }
    if (erros.isNotEmpty) return ValidacaoVariavelBi(erros);

    // Última prova: a expressão precisa rodar. Usa 1.0 em tudo, que é neutro
    // o bastante pra não disparar divisão por zero nem raiz de negativo.
    try {
      final teste = {for (final nome in permitidos) nome: 1.0, ..._funcoes};
      final valor = const ExpressionEvaluator().eval(expressao, teste);
      if (valor is! num) {
        erros.add('A expressão não resulta em um número.');
      }
    } catch (e) {
      erros.add('A expressão não pôde ser calculada. Confira as funções usadas.');
    }

    return ValidacaoVariavelBi(erros);
  }

  /// Calcula a variável para um conjunto de valores já resolvidos por
  /// elemento (`{'V': 4200, 'R': 38}`).
  ///
  /// Devolve null quando não dá pra calcular — falta uma entrada (o elemento
  /// não tem aquele ensaio), ou a conta produziu NaN/Infinito. Isso é dado
  /// faltando, não erro: quem chama deve mostrar "N de M elementos
  /// calculados" em vez de falhar o card inteiro.
  static double? avaliar(VariavelBiModel variavel, Map<String, double?> valoresEntrada) {
    final contexto = <String, dynamic>{};
    for (final entrada in variavel.entradas) {
      final valor = valoresEntrada[entrada.alias];
      if (valor == null) return null;
      contexto[entrada.alias] = valor;
    }
    contexto.addAll(variavel.parametros);
    contexto.addAll(_funcoes);

    try {
      final resultado = const ExpressionEvaluator().eval(Expression.parse(variavel.expressao), contexto);
      if (resultado is! num) return null;
      final numero = resultado.toDouble();
      if (numero.isNaN || numero.isInfinite) return null;
      return numero;
    } catch (_) {
      return null;
    }
  }

  /// Nomes de função aceitos nas expressões.
  static Set<String> get funcoes => _funcoes.keys.toSet();

  /// Compila uma expressão para avaliação repetida — o Monte Carlo avalia a
  /// mesma expressão 1.000 vezes, uma por amostra. Null se não compilar.
  static Expression? compilar(String expressao) {
    try {
      return Expression.parse(expressao);
    } catch (_) {
      return null;
    }
  }

  /// Avalia uma expressão já compilada. Null se o resultado não for um
  /// número finito (divisão por zero, raiz de negativo...).
  static double? avaliarCompilada(Expression expressao, Map<String, double> variaveis) {
    try {
      final r = const ExpressionEvaluator().eval(expressao, {...variaveis, ..._funcoes});
      if (r is! num) return null;
      final d = r.toDouble();
      return (d.isNaN || d.isInfinite) ? null : d;
    } catch (_) {
      return null;
    }
  }

  /// Validação estática de uma expressão solta (sem VariavelBiModel), dado o
  /// conjunto de nomes que ela pode usar.
  static List<String> validarExpressao(String expressao, Set<String> nomes) {
    if (expressao.trim().isEmpty) return ['A expressão está vazia.'];
    if (compilar(expressao) == null) return ['A expressão não pôde ser interpretada. Confira parênteses e operadores.'];
    final permitidos = {...nomes, ..._funcoes.keys};
    return [
      for (final n in _identificadoresUsados(expressao).toSet())
        if (!permitidos.contains(n)) '"$n" não existe: não é uma série nem uma função conhecida.',
    ];
  }

  /// Identificadores que a expressão referencia (sem as funções).
  static Set<String> nomesUsados(String expressao) =>
      _identificadoresUsados(expressao).where((n) => !_funcoes.containsKey(n)).toSet();

  /// True quando o valor caiu fora da faixa plausível declarada. Não invalida
  /// o número — serve pra sinalizar na tela.
  static bool foraDaFaixa(VariavelBiModel variavel, double valor) {
    if (variavel.valorMin != null && valor < variavel.valorMin!) return true;
    if (variavel.valorMax != null && valor > variavel.valorMax!) return true;
    return false;
  }

  // Identificadores do texto da expressão, ignorando os que são chamada de
  // função já coberta e os números. Comparado com a lista de permitidos, é o
  // que pega "usei R mas só cadastrei V".
  static Iterable<String> _identificadoresUsados(String expressao) sync* {
    for (final m in RegExp(r'[A-Za-z_][A-Za-z0-9_]*').allMatches(expressao)) {
      yield m.group(0)!;
    }
  }
}
