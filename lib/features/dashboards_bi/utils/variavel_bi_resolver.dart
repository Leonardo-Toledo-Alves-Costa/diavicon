import '../models/bi_data_point.dart';
import '../models/campos_bi_catalogo.dart';
import '../models/variavel_bi_model.dart';
import 'juncao_por_elemento.dart';
import 'variavel_bi_avaliador.dart';

/// Pontos calculados de uma variável derivada, com a contagem de elementos
/// que ficaram de fora.
///
/// A contagem existe porque "faltou dado" é o caso normal, não um erro: um
/// elemento pode ter esclerometria e nunca ter recebido ultrassom.
///
/// TODO(ui): a contagem ainda não é exibida no card — `buscarDadosCard`
/// devolve só os pontos, e o cache do dashboard guarda apenas eles. Quando
/// for exibida, o texto pretendido é "8 de 12 elementos calculados", pra
/// diferenciar lacuna de dado de um gráfico simplesmente menor.
class ResultadoVariavelBi {
  final List<BiDataPoint> pontos;
  final int elementosCalculados;
  final int elementosSemDado;

  const ResultadoVariavelBi({
    required this.pontos,
    required this.elementosCalculados,
    required this.elementosSemDado,
  });

  static const vazio = ResultadoVariavelBi(pontos: [], elementosCalculados: 0, elementosSemDado: 0);

  int get totalElementos => elementosCalculados + elementosSemDado;
  bool get temLacuna => elementosSemDado > 0;
}

/// Resolve uma [VariavelBiModel] em pontos por elemento.
///
/// A junção entre ensaios é sempre por ELEMENTO estrutural, porque é a chave
/// de [BiDataPoint]. Dentro de um elemento as leituras dos dois ensaios não
/// são pareadas entre si (foram feitas em pontos físicos diferentes), então
/// cada entrada é reduzida a um número por elemento antes da fórmula rodar —
/// é correlação de agregado com agregado, e a tela precisa dizer isso.
class VariavelBiResolver {
  /// Busca cada entrada no catálogo e combina. A parte de rede fica só aqui;
  /// a lógica de junção está em [combinar], que é pura.
  static Future<ResultadoVariavelBi> resolver(VariavelBiModel variavel, BiContexto ctx) async {
    final porAlias = <String, List<BiDataPoint>>{};

    for (final entrada in variavel.entradas) {
      final campo = buscarCampoBi(entrada.fonte, entrada.campo);
      // Entrada apontando pra um campo que não existe mais no catálogo: a
      // variável inteira fica sem resultado, em vez de calcular errado com
      // uma das parcelas faltando.
      if (campo == null) return ResultadoVariavelBi.vazio;

      final estatistica = entrada.estatistica == null
          ? null
          : EstatisticaBi.values.firstWhere(
              (e) => e.name == entrada.estatistica,
              orElse: () => EstatisticaBi.media,
            );

      porAlias[entrada.alias] = await campo.buscar(ctx, estatistica: estatistica);
    }

    return combinar(variavel, porAlias);
  }

  /// Junta as séries por elemento e aplica a fórmula. Parte pura.
  static ResultadoVariavelBi combinar(
    VariavelBiModel variavel,
    Map<String, List<BiDataPoint>> porAlias,
  ) {
    if (variavel.entradas.isEmpty) return ResultadoVariavelBi.vazio;

    // Um fetcher pode devolver mais de um ponto por elemento (campos brutos,
    // sem estatística). A junção reduz à média — coerente com a semântica
    // declarada de correlação por elemento.
    final juncao = JuncaoPorElemento.de(porAlias);
    final identidade = juncao.identidade;

    final aliases = variavel.entradas.map((e) => e.alias).toList();
    final pontos = <BiDataPoint>[];
    var semDado = 0;

    for (final elementoId in identidade.keys) {
      final entradaDoElemento = juncao.entradasDe(elementoId, aliases);
      final resultado = VariavelBiAvaliador.avaliar(variavel, entradaDoElemento);
      if (resultado == null) {
        semDado++;
        continue;
      }
      final referencia = identidade[elementoId]!;
      pontos.add(BiDataPoint(
        elementoId: referencia.elementoId,
        elementoNome: referencia.elementoNome,
        tipoElemento: referencia.tipoElemento,
        local: referencia.local,
        valor: resultado,
      ));
    }

    return ResultadoVariavelBi(
      pontos: pontos,
      elementosCalculados: pontos.length,
      elementosSemDado: semDado,
    );
  }
}
