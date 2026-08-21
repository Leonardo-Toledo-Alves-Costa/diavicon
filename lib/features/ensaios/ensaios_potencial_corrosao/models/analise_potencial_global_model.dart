class AnalisePotencialGlobalModel {
  final String id;
  final String nomePonto;
  final String local;
  final String nomeElemento;
  final String tipoElemento;
  final List<double> valoresMv;

  AnalisePotencialGlobalModel({
    required this.id,
    required this.nomePonto,
    required this.local,
    required this.nomeElemento,
    required this.tipoElemento,
    required this.valoresMv,
  });

  factory AnalisePotencialGlobalModel.fromMap(Map<String, dynamic> map) {
    final el = map['elementos_estruturais'] ?? {};
    final localNome = el['estruturas_locais']?['nome'] ?? el['local'] ?? 'Sem local';
    final elemNome = el['nome'] ?? 'Sem nome';
    final elemTipo = el['tipo'] ?? 'Sem tipo';

    List<double> valores = [];
    final potList = map['ponto_ensaio_potencial'] as List? ?? [];
    
    if (potList.isNotEmpty) {
      for (var pot in potList) {
        final leiturasList = pot['ponto_ensaio_potencial_leitura'] as List? ?? [];
        for (var lMap in leiturasList) {
          double? val = double.tryParse(lMap['potencial_mv']?.toString() ?? '');
          if (val != null) {
            // Converte para negativo (padrão do eletrodo)
            valores.add(-val.abs());
          }
        }
      }
    }

    return AnalisePotencialGlobalModel(
      id: map['id'].toString(),
      nomePonto: map['nome_ponto']?.toString() ?? 'Ponto',
      local: localNome,
      nomeElemento: elemNome,
      tipoElemento: elemTipo,
      valoresMv: valores,
    );
  }
}

// Classe auxiliar para o gráfico BoxPlot
class BoxPlotDataPotencialAgg {
  final String rotuloEixoX; // Ex: P01\nPilar
  final String local;
  final List<double> valores;

  BoxPlotDataPotencialAgg(this.rotuloEixoX, this.local, this.valores);
}