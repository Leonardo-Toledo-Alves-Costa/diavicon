import 'dart:math';

class RupturaData {
  final String tipo;
  final double porcentagem;
  RupturaData({required this.tipo, required this.porcentagem});
}

class LeituraArrancamento {
  final double tensao;
  final List<RupturaData> rupturas;

  LeituraArrancamento({required this.tensao, required this.rupturas});
}

class PontoArrancamentoGlobal {
  final String id;
  final String local;
  final String nomeElemento;
  final String tipoElemento;
  final List<LeituraArrancamento> leituras;

  PontoArrancamentoGlobal({
    required this.id,
    required this.local,
    required this.nomeElemento,
    required this.tipoElemento,
    required this.leituras,
  });

  factory PontoArrancamentoGlobal.fromMap(Map<String, dynamic> map) {
    final el = map['elementos_estruturais'] ?? {};
    final localNome = el['estruturas_locais']?['nome'] ?? el['local'] ?? 'Sem local';
    final elemNome = el['nome'] ?? 'Sem nome';
    final elemTipo = el['tipo'] ?? 'Sem tipo';

    List<LeituraArrancamento> leiturasList = [];
    final arrList = map['ponto_ensaio_arrancamento'] as List? ?? [];
    
    if (arrList.isNotEmpty) {
      final arr = arrList.first; 
      final leituraMapList = arr['ponto_ensaio_arrancamento_leitura'] as List? ?? [];
      
      for (var lMap in leituraMapList) {
        double carga = double.tryParse(lMap['carga']?.toString() ?? '0') ?? 0;
        double area = double.tryParse(lMap['area']?.toString() ?? '0') ?? 0;
        double tensao = area > 0 ? (carga / area) : 0.0;

        List<RupturaData> rupturas = [];
        final rupMapList = lMap['ponto_ensaio_arrancamento_ruptura'] as List? ?? [];
        for (var rMap in rupMapList) {
          rupturas.add(RupturaData(
            tipo: rMap['tipo_ruptura']?.toString() ?? 'Outros',
            porcentagem: double.tryParse(rMap['porcentagem']?.toString() ?? '0') ?? 0.0,
          ));
        }
        leiturasList.add(LeituraArrancamento(tensao: tensao, rupturas: rupturas));
      }
    }

    return PontoArrancamentoGlobal(
      id: map['id'].toString(),
      local: localNome,
      nomeElemento: elemNome,
      tipoElemento: elemTipo,
      leituras: leiturasList,
    );
  }
}

/// Classe auxiliar para agrupar os resultados matemáticos por Elemento para a UI
class ElementoArrancamentoAgg {
  final String local;
  final String nomeElemento;
  final String tipoElemento;
  final List<double> tensoes;
  final Map<String, double> somaRupturas; // Soma das % para achar a predominante

  ElementoArrancamentoAgg({
    required this.local,
    required this.nomeElemento,
    required this.tipoElemento,
    required this.tensoes,
    required this.somaRupturas,
  });

  double get mediaTensao => tensoes.isEmpty ? 0 : tensoes.reduce((a, b) => a + b) / tensoes.length;
  double get minTensao => tensoes.isEmpty ? 0 : tensoes.reduce(min);
  double get maxTensao => tensoes.isEmpty ? 0 : tensoes.reduce(max);
  
  double get cv {
    if (tensoes.length < 2 || mediaTensao == 0) return 0.0;
    double variance = tensoes.map((t) => pow(t - mediaTensao, 2)).reduce((a, b) => a + b) / tensoes.length;
    return (sqrt(variance) / mediaTensao) * 100;
  }

  String get rupturaPredominante {
    if (somaRupturas.isEmpty) return '-';
    // Retorna a chave (tipo) com o maior valor somado
    return somaRupturas.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}