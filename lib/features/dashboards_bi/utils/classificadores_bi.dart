import '../../../core/models/classe_qualitativa.dart';
import '../../ensaios/ensaio_ultrassom/ultrassom_direto/models/ultrassom_direto_model.dart' show ClassificacaoWhitehurst;
import '../../ensaios/ensaios_carbonatacao/utils/risco_carbonatacao.dart';
import '../../ensaios/ensaios_resistividade/utils/classificacao_resistividade.dart';
import '../models/bi_data_point.dart';
import '../models/campos_bi_catalogo.dart';
import '../models/serie_bi_model.dart';
import 'juncao_por_elemento.dart';

/// Uma escala exibida pelo badge (ex.: "Risco de corrosão"). A resistividade
/// tem três dimensões sobre a mesma entrada; os demais badges têm uma.
class DimensaoBadgeBi {
  final String nome;
  final List<ClasseQualitativa> classes;
  final ClasseQualitativa? Function(Map<String, double?> entradas) classificar;

  /// Texto do valor que gerou a classe, mostrado no selo de um elemento só
  /// (ex.: "V = 4.210 m/s").
  final String Function(Map<String, double?> entradas)? descreverValor;

  const DimensaoBadgeBi({required this.nome, required this.classes, required this.classificar, this.descreverValor});
}

/// Definição de um badge de classificação qualitativa.
///
/// As regras de cada escala NÃO vivem aqui: vêm das fontes únicas de cada
/// ensaio (ClassificacaoWhitehurst, ClassificacaoResistividade,
/// RiscoCarbonatacao). Assim o badge nunca discorda da tela de análise nem do
/// relatório.
class ClassificadorBi {
  final String id;
  final String rotulo;
  final String descricao;

  /// alias -> de onde vem o valor.
  final Map<String, ReferenciaValorBi> entradas;

  /// Entradas sem as quais o elemento não é classificável. As demais podem
  /// faltar (ex.: só um dos dois cobrimentos informado).
  final Set<String> obrigatorias;
  final List<DimensaoBadgeBi> dimensoes;

  /// Distribuição própria, para badges que não classificam elementos por um
  /// número — a inspeção visual conta ANOMALIAS por tipo de risco e
  /// intensidade, que já vêm categorizadas no registro.
  final ResultadoBadgeBi Function(ClassificadorBi, Map<String, List<BiDataPoint>>)? distribuir;

  const ClassificadorBi({
    required this.id,
    required this.rotulo,
    required this.descricao,
    required this.entradas,
    required this.obrigatorias,
    required this.dimensoes,
    this.distribuir,
  });
}

// ── Whitehurst ─────────────────────────────────────────────────────────────

/// Classes de Whitehurst como escala de gravidade (0 = pior), com as cores
/// que a tela de análise do ultrassom já usa.
final List<ClasseQualitativa> _classesWhitehurst = () {
  // Uma velocidade representativa de cada faixa, da pior para a melhor.
  const amostras = [1500.0, 2500.0, 3200.0, 4000.0, 5000.0];
  return [
    for (var i = 0; i < amostras.length; i++)
      () {
        final c = ClassificacaoWhitehurst.classificar(amostras[i]);
        return ClasseQualitativa(texto: c.texto, corTexto: c.cor, corFundo: c.cor.withValues(alpha: 0.12), posicao: i);
      }(),
  ];
}();

ClasseQualitativa? _whitehurst(double? v) {
  if (v == null || v <= 0) return null;
  final texto = ClassificacaoWhitehurst.classificar(v).texto;
  return _classesWhitehurst.where((c) => c.texto == texto).firstOrNull;
}

String _num(double v, {int casas = 0}) {
  final s = v.toStringAsFixed(casas);
  // Separador de milhar no padrão brasileiro, só na parte inteira.
  final partes = s.split('.');
  final inteiro = partes[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return partes.length > 1 ? '$inteiro,${partes[1]}' : inteiro;
}

// ── Catálogo de badges ─────────────────────────────────────────────────────

final List<ClassificadorBi> classificadoresBi = [
  ClassificadorBi(
    id: 'whitehurst',
    rotulo: 'Ultrassom — Whitehurst',
    descricao: 'Qualidade do concreto pela velocidade longitudinal média do elemento.',
    entradas: {
      'V': ReferenciaValorBi(fonte: 'ultrassom', campo: 'velocidade_longitudinal', estatistica: EstatisticaBi.media.name),
    },
    obrigatorias: {'V'},
    dimensoes: [
      DimensaoBadgeBi(
        nome: 'Whitehurst',
        classes: _classesWhitehurst,
        classificar: (e) => _whitehurst(e['V']),
        descreverValor: (e) => e['V'] == null ? '' : 'V = ${_num(e['V']!)} m/s',
      ),
    ],
  ),
  ClassificadorBi(
    id: 'resistividade',
    rotulo: 'Resistividade — 3 classificações',
    descricao: 'Risco de corrosão, taxa de corrosão e permissividade iônica (AASHTO T 358) pela resistividade média.',
    entradas: {
      'rho': ReferenciaValorBi(fonte: 'resistividade', campo: 'resistividade', estatistica: EstatisticaBi.media.name),
    },
    obrigatorias: {'rho'},
    dimensoes: [
      for (final escala in ClassificacaoResistividade.todas)
        DimensaoBadgeBi(
          nome: escala.nome,
          classes: escala.classes,
          classificar: (e) => escala.classificar(e['rho']),
          descreverValor: (e) => e['rho'] == null ? '' : 'ρ = ${_num(e['rho']!, casas: 1)} kΩ·cm',
        ),
    ],
  ),
  _classificadorRiscoIV,
  ClassificadorBi(
    id: 'carbonatacao',
    rotulo: 'Carbonatação — risco',
    descricao: 'Folga até a despassivação: tempo para a frente atingir o cobrimento, menos a idade da estrutura.',
    entradas: {
      'frente': ReferenciaValorBi(fonte: 'carbonatacao', campo: 'frente', estatistica: EstatisticaBi.media.name),
      'cobP': const ReferenciaValorBi(fonte: 'carbonatacao', campo: 'cob_arm_p'),
      'cobS': const ReferenciaValorBi(fonte: 'carbonatacao', campo: 'cob_arm_s'),
      'idade': const ReferenciaValorBi(fonte: 'dados_gerais', campo: 'idade'),
    },
    // Os cobrimentos podem faltar individualmente; RiscoCarbonatacao devolve
    // "sem classificação" se faltarem os dois.
    obrigatorias: {'frente', 'idade'},
    dimensoes: [
      DimensaoBadgeBi(
        nome: 'Risco por carbonatação',
        classes: RiscoCarbonatacao.classes,
        classificar: (e) => _avaliarCarbonatacao(e)?.classe,
        descreverValor: (e) {
          final a = _avaliarCarbonatacao(e);
          if (a == null || a.classe == null) return '';
          return 'Δ = ${_num(a.deltaCarb, casas: 1)} anos';
        },
      ),
    ],
  ),
];

AvaliacaoCarbonatacao? _avaliarCarbonatacao(Map<String, double?> e) {
  final frente = e['frente'];
  final idade = e['idade'];
  if (frente == null || idade == null) return null;
  return RiscoCarbonatacao.avaliar(
    frenteMedia: frente,
    cobP: e['cobP'] ?? 0,
    cobS: e['cobS'] ?? 0,
    idade: idade.round(),
  );
}

// ── Inspeção visual: risco por tipo e intensidade ──────────────────────────

/// Os valores gravados pelo registro de inspeção (ver registro_inspecao_screen).
const _tiposRiscoIV = ['Humano', 'Material', 'Ambiental'];
const _intensidadesIV = ['Alto', 'Médio', 'Baixo'];

final List<ClasseQualitativa> _classesIntensidadeIV = [
  for (var i = 0; i < _intensidadesIV.length; i++)
    () {
      final (texto, fundo) = PaletaGravidade.para(i, _intensidadesIV.length);
      return ClasseQualitativa(texto: _intensidadesIV[i], corTexto: texto, corFundo: fundo, posicao: i);
    }(),
];

ResultadoBadgeBi _distribuirRiscoIV(ClassificadorBi c, Map<String, List<BiDataPoint>> porAlias) {
  // "Humano · Alto" -> contagem por tipo e intensidade.
  final contagem = <String, Map<String, int>>{};
  for (final p in porAlias['risco'] ?? const <BiDataPoint>[]) {
    final partes = (p.categoria ?? '').split(' · ');
    if (partes.length != 2) continue;
    contagem.putIfAbsent(partes[0], () => {})[partes[1]] = (contagem[partes[0]]![partes[1]] ?? 0) + 1;
  }
  return ResultadoBadgeBi(c, [
    for (final dim in c.dimensoes)
      DistribuicaoDimensaoBi(
        dimensao: dim,
        contagens: [
          for (final classe in _classesIntensidadeIV)
            if ((contagem[dim.nome]?[classe.texto] ?? 0) > 0) (classe: classe, quantidade: contagem[dim.nome]![classe.texto]!),
        ],
        semClassificacao: 0,
      ),
  ]);
}

final _classificadorRiscoIV = ClassificadorBi(
  id: 'inspecao_visual_risco',
  rotulo: 'Inspeção visual — risco',
  descricao: 'Quantidade de anomalias por tipo de risco (humano, material, ambiental) e intensidade (alto, médio, baixo).',
  entradas: const {'risco': ReferenciaValorBi(fonte: 'inspecao_visual', campo: 'risco')},
  obrigatorias: const {},
  dimensoes: [
    for (final tipo in _tiposRiscoIV)
      DimensaoBadgeBi(nome: tipo, classes: _classesIntensidadeIV, classificar: (_) => null),
  ],
  distribuir: _distribuirRiscoIV,
);

ClassificadorBi? buscarClassificadorBi(String? id) => classificadoresBi.where((c) => c.id == id).firstOrNull;

// ── Distribuição ───────────────────────────────────────────────────────────

/// Resultado de uma dimensão: quantos elementos caíram em cada classe.
class DistribuicaoDimensaoBi {
  final DimensaoBadgeBi dimensao;

  /// Na ordem da escala, da classe mais grave para a mais branda. Só entram
  /// classes com pelo menos um elemento.
  final List<({ClasseQualitativa classe, int quantidade})> contagens;

  /// Elementos presentes no contexto que não puderam ser classificados.
  final int semClassificacao;

  /// Preenchido quando exatamente um elemento foi classificado — o badge
  /// vira um selo único com o valor.
  final ({ClasseQualitativa classe, String valor})? unico;

  const DistribuicaoDimensaoBi({
    required this.dimensao,
    required this.contagens,
    required this.semClassificacao,
    this.unico,
  });

  int get classificados => contagens.fold(0, (s, c) => s + c.quantidade);
}

class ResultadoBadgeBi {
  final ClassificadorBi classificador;
  final List<DistribuicaoDimensaoBi> dimensoes;
  const ResultadoBadgeBi(this.classificador, this.dimensoes);

  bool get vazio => dimensoes.every((d) => d.classificados == 0);
}

/// Classifica cada elemento pela própria média e conta por classe.
///
/// É uma distribuição, não a classificação da média geral, de propósito:
/// uma viga ruim no meio de vinte boas precisa continuar visível.
ResultadoBadgeBi distribuirBadge(ClassificadorBi classificador, Map<String, List<BiDataPoint>> porAlias) {
  if (classificador.distribuir != null) return classificador.distribuir!(classificador, porAlias);
  final juncao = JuncaoPorElemento.de(porAlias);
  final aliases = classificador.entradas.keys;

  final dimensoes = <DistribuicaoDimensaoBi>[];
  for (final dim in classificador.dimensoes) {
    final contagem = <ClasseQualitativa, int>{};
    var sem = 0;
    ({ClasseQualitativa classe, String valor})? ultimo;

    for (final elementoId in juncao.identidade.keys) {
      final entradas = juncao.entradasDe(elementoId, aliases);
      final faltaObrigatoria = classificador.obrigatorias.any((a) => entradas[a] == null);
      final classe = faltaObrigatoria ? null : dim.classificar(entradas);
      if (classe == null) {
        sem++;
        continue;
      }
      contagem[classe] = (contagem[classe] ?? 0) + 1;
      ultimo = (classe: classe, valor: dim.descreverValor?.call(entradas) ?? '');
    }

    final ordenadas = contagem.entries.toList()..sort((a, b) => a.key.posicao.compareTo(b.key.posicao));
    final total = ordenadas.fold(0, (s, e) => s + e.value);
    dimensoes.add(DistribuicaoDimensaoBi(
      dimensao: dim,
      contagens: [for (final e in ordenadas) (classe: e.key, quantidade: e.value)],
      semClassificacao: sem,
      unico: total == 1 ? ultimo : null,
    ));
  }
  return ResultadoBadgeBi(classificador, dimensoes);
}
