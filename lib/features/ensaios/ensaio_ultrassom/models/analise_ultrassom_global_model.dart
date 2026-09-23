import '../ultrassom_direto/models/ultrassom_direto_model.dart';
import '../ultrassom_indireto/models/ultrassom_indireto_model.dart';
import '../ultrassom_mapeamento/models/ultrassom_mapeamento_model.dart';
import '../utils/ultrassom_math.dart';

// `alfa_e`/`densidade` podem vir como number OU como text (dependendo de
// como a coluna foi criada no banco) — aceita os dois em vez de um cast
// direto pra `num`, que quebra se vier string.
double? _paraDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.'));
}

// Um ponto de Ultrassonografia (qualquer modo) resolvido pra análise geral
// da estrutura — junta o resultado de `pontos_ensaios_geral` com o que
// existir em `ponto_ensaio_ultrassom` (Direto/Indireto/Mapeamento,
// diferenciados por `modo`). `valoresVelocidade` é o conjunto de leituras
// "cruas" daquele ponto (reaproveitando a lógica de cada modo — inclusive a
// regressão do Indireto, ver `MedicaoUltrassomIndiretoModel.valorVelocidade`)
// — usado tanto pra média/CV quanto pro boxplot.
class PontoAnaliseUltrassomModel {
  final String id;
  final String nomePonto;
  final String elementoId;
  final String nomeElemento;
  final String tipoElemento;
  final String local;
  final String modo; // 'direto' | 'indireto' | 'mapeamento'
  final String pulso; // 'Longitudinal' | 'Transversal'
  final double alfaE;
  final double densidade;
  final List<double> valoresVelocidade;

  const PontoAnaliseUltrassomModel({
    required this.id,
    required this.nomePonto,
    required this.elementoId,
    required this.nomeElemento,
    required this.tipoElemento,
    required this.local,
    required this.modo,
    required this.pulso,
    required this.alfaE,
    required this.densidade,
    required this.valoresVelocidade,
  });

  double get media => UltrassomMath.mean(valoresVelocidade);
  double get coefVariacao => UltrassomMath.coefVariacao(valoresVelocidade);
  bool get ehLongitudinal => pulso.toLowerCase() == 'longitudinal';

  static List<PontoAnaliseUltrassomModel> fromMap(Map<String, dynamic> map) {
    final el = map['elementos_estruturais'] as Map<String, dynamic>? ?? {};
    final localNome = (el['estruturas_locais'] as Map?)?['nome'] ?? el['local'] ?? 'Sem local';
    final elemNome = el['nome']?.toString() ?? 'Sem nome';
    final elemTipo = el['tipo']?.toString() ?? 'Sem tipo';
    final elemId = map['elemento_estrutural_id']?.toString() ?? '';

    final ultrassomList = map['ponto_ensaio_ultrassom'] as List? ?? const [];
    final resultado = <PontoAnaliseUltrassomModel>[];

    for (final u in ultrassomList) {
      final modo = u['modo']?.toString() ?? '';
      final pulso = u['tipo_onda']?.toString() ?? 'Longitudinal';
      final alfaE = _paraDouble(u['alfa_e']) ?? 1.0;
      final densidade = _paraDouble(u['densidade']) ?? 2400.0;

      List<double> valores = [];
      switch (modo) {
        case 'direto':
          final medicoesJson = u['ponto_ensaio_ultrassom_direto_medicao'] as List? ?? const [];
          for (final mJson in medicoesJson) {
            final leiturasJson = (mJson['ponto_ensaio_ultrassom_direto_leitura'] as List? ?? const [])
                .map((l) => LeituraUltrassomDiretoModel.fromJson((l as Map).cast<String, dynamic>()))
                .toList();
            valores.addAll(leiturasJson.map((l) => l.velocidade));
          }
          break;
        case 'indireto':
          final medicoesJson = u['ponto_ensaio_ultrassom_indireto_medicao'] as List? ?? const [];
          for (final mJson in medicoesJson) {
            final leiturasJson = (mJson['ponto_ensaio_ultrassom_indireto_leitura'] as List? ?? const [])
                .map((l) => LeituraUltrassomIndiretoModel.fromJson((l as Map).cast<String, dynamic>()))
                .toList();
            final medicao = MedicaoUltrassomIndiretoModel(nomePonto: '', leituras: leiturasJson);
            if (medicao.valorVelocidade > 0) valores.add(medicao.valorVelocidade);
          }
          break;
        case 'mapeamento':
          final mapeamentoJson = u['ponto_ensaio_ultrassom_mapeamento'] as List? ?? const [];
          for (final mpJson in mapeamentoJson) {
            final leiturasJson = (mpJson['ponto_ensaio_ultrassom_mapeamento_leitura'] as List? ?? const [])
                .map((l) => LeituraUltrassomMapeamentoModel.fromJson((l as Map).cast<String, dynamic>()))
                .toList();
            valores.addAll(leiturasJson.where((l) => l.velocidade != null).map((l) => l.velocidade!));
          }
          break;
      }

      if (valores.isEmpty) continue;

      resultado.add(PontoAnaliseUltrassomModel(
        id: map['id'].toString(),
        nomePonto: map['nome_ponto']?.toString() ?? 'Ponto',
        elementoId: elemId,
        nomeElemento: elemNome,
        tipoElemento: elemTipo,
        local: localNome.toString(),
        modo: modo,
        pulso: pulso,
        alfaE: alfaE,
        densidade: densidade,
        valoresVelocidade: valores,
      ));
    }

    return resultado;
  }
}

// Um elemento estrutural com resultado longitudinal E transversal — só
// esses têm Ed/fck calculáveis (ver UltrassomMath). `alfaE`/`densidade`
// usados são os do primeiro ponto encontrado (a edição na tela de análise
// mantém os dois modos sincronizados via update em lote).
class ElementoAnaliseUltrassomModel {
  final String elementoId;
  final String nomeElemento;
  final String tipoElemento;
  final String local;
  final double velocidadeLongitudinal;
  final double velocidadeTransversal;
  final double alfaE;
  final double densidade;

  const ElementoAnaliseUltrassomModel({
    required this.elementoId,
    required this.nomeElemento,
    required this.tipoElemento,
    required this.local,
    required this.velocidadeLongitudinal,
    required this.velocidadeTransversal,
    required this.alfaE,
    required this.densidade,
  });

  double get poisson => UltrassomMath.poisson(vp: velocidadeLongitudinal, vs: velocidadeTransversal);

  double get moduloElasticidade =>
      UltrassomMath.moduloElasticidadeDinamico(densidade: densidade, vs: velocidadeTransversal, poisson: poisson);

  double get resistenciaCompressao => UltrassomMath.resistenciaCompressaoEstimada(ed: moduloElasticidade, alfaE: alfaE);
}
