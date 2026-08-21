class PontoInspecaoVisualModel {
  final String id;
  final String registro;
  final String? descricao;
  final String? localId;
  final String? elementoId;
  final String? tipoElementoId;
  
  // Agregações para a UI
  final String? capaUrl;
  final int qtdFotos;
  final int gutTotal;
  final List<String> tags; // Ex: ['Pilar', 'Corrosão']

  PontoInspecaoVisualModel({
    required this.id,
    required this.registro,
    this.descricao,
    this.localId,
    this.elementoId,
    this.tipoElementoId,
    this.capaUrl,
    this.qtdFotos = 0,
    this.gutTotal = 0,
    this.tags = const [],
  });

  factory PontoInspecaoVisualModel.fromMap(Map<String, dynamic> map) {
    // Cálculo do GUT e extração de Tags via Inner Joins do Supabase
    int gut = 0;
    List<String> extraTags = [];
    
    final anomalias = map['ponto_inspecao_visual_anomalia'] as List? ?? [];
    for (var a in anomalias) {
      double risco = (a['risco_maj'] as num?)?.toDouble() ?? 0.0;
      gut += risco.toInt();
      if (a['anomalias'] != null && a['anomalias']['nome'] != null) {
         // Exemplo simplificado de extração de tag
         if (!extraTags.contains('Corrosão') && a['anomalias']['nome'].toString().toLowerCase().contains('corrosão')) {
           extraTags.add('Corrosão');
         }
      }
    }

    final galeria = map['ponto_inspecao_visual_galeria'] as List? ?? [];
    String? capa = galeria.isNotEmpty ? galeria.first['foto_url'] : null;

    final tipoElemento = map['tipos_elemento']?['nome'];
    if (tipoElemento != null) extraTags.insert(0, tipoElemento);

    return PontoInspecaoVisualModel(
      id: map['id'],
      registro: map['registro'] ?? 'Sem Registro',
      descricao: map['descricao'],
      localId: map['id_local'],
      elementoId: map['id_elemento'],
      tipoElementoId: map['id_tipo_elemento'],
      capaUrl: capa,
      qtdFotos: galeria.length,
      gutTotal: gut,
      tags: extraTags,
    );
  }
}

class InspecaoGaleriaModel {
  final String id;
  final String fotoUrl;
  final String descricao;

  InspecaoGaleriaModel({required this.id, required this.fotoUrl, required this.descricao});
  
  factory InspecaoGaleriaModel.fromMap(Map<String, dynamic> map) => InspecaoGaleriaModel(
    id: map['id'], fotoUrl: map['foto_url'], descricao: map['descricao'] ?? '',
  );
}

class InspecaoAnomaliaModel {
  final String id;
  final double areaAfetada;
  final double riscoMaj;
  final String nomeAnomalia;
  final String gravidadeValor;

  InspecaoAnomaliaModel({
    required this.id, required this.areaAfetada, required this.riscoMaj, required this.nomeAnomalia, required this.gravidadeValor
  });

  factory InspecaoAnomaliaModel.fromMap(Map<String, dynamic> map) {
    final anomalia = map['anomalias'] ?? {};
    return InspecaoAnomaliaModel(
      id: map['id'],
      areaAfetada: (map['area_afetada'] as num?)?.toDouble() ?? 0.0,
      riscoMaj: (map['risco_maj'] as num?)?.toDouble() ?? 0.0,
      nomeAnomalia: anomalia['nome'] ?? 'Desconhecida',
      gravidadeValor: anomalia['gravidade_valor'] ?? 'Baixa',
    );
  }
}