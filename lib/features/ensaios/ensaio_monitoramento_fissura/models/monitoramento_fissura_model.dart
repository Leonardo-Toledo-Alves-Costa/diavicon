import 'package:flutter/material.dart';

/// Tipo de selo instalado sobre a fissura — define se o campo "Rompido?"
/// aparece no formulário de nova medição (só gesso/vidro rompem; selo
/// adesivo e placa milimetrada só indicam deslocamento por leitura direta).
enum TipoSeloFissura {
  gesso('gesso', 'Selo de Gesso'),
  vidro('vidro', 'Selo de Vidro'),
  seloAdesivo('selo_adesivo', 'Selo Adesivo'),
  placaMilimetrada('placa_milimetrada', 'Placa Milimetrada');

  final String chave;
  final String label;
  const TipoSeloFissura(this.chave, this.label);

  bool get podeRomper => this == gesso || this == vidro;

  static TipoSeloFissura fromChave(String? chave) {
    return TipoSeloFissura.values.firstWhere((t) => t.chave == chave, orElse: () => TipoSeloFissura.seloAdesivo);
  }
}

/// Status de uma medição — calculado a partir da variação em relação à
/// leitura anterior (ou da instalação, pra primeira leitura), salvo junto
/// (mesmo padrão de `valor_resultado`/`cor_resultado` pré-calculados usados
/// no resto do app) em vez de recalculado toda vez a partir do zero.
enum StatusFissura {
  estavel('Estável', Color(0xFF4CAF50)),
  leve('Leve', Color(0xFFFFA000)),
  alerta('Alerta', Color(0xFFF44336)),
  rompido('Rompido', Color(0xFFF44336));

  final String label;
  final Color cor;
  const StatusFissura(this.label, this.cor);

  static StatusFissura fromLabel(String? label) {
    return StatusFissura.values.firstWhere((s) => s.label == label, orElse: () => StatusFissura.estavel);
  }

  // |variação| < 0,1mm → Estável; 0,1 a 0,3 → Leve; >= 0,3 → Alerta. Usa o
  // maior valor absoluto entre a variação X e a variação Y.
  static StatusFissura calcular({required double deltaX, required double deltaY, required bool rompido}) {
    if (rompido) return StatusFissura.rompido;
    final maiorDelta = deltaX.abs() > deltaY.abs() ? deltaX.abs() : deltaY.abs();
    if (maiorDelta >= 0.3) return StatusFissura.alerta;
    if (maiorDelta >= 0.1) return StatusFissura.leve;
    return StatusFissura.estavel;
  }
}

// `data`/`hora` no banco são texto livre (dd/mm/yyyy e HH:mm) — mesmo
// padrão já usado pro RDO nesse app.
DateTime? parseDataHoraFissura(String? data, String? hora) {
  if (data == null || data.isEmpty) return null;
  final partesData = data.split('/');
  if (partesData.length != 3) return null;
  final dia = int.tryParse(partesData[0]);
  final mes = int.tryParse(partesData[1]);
  final ano = int.tryParse(partesData[2]);
  if (dia == null || mes == null || ano == null) return null;

  var h = 0, m = 0;
  if (hora != null && hora.isNotEmpty) {
    final partesHora = hora.split(':');
    if (partesHora.isNotEmpty) h = int.tryParse(partesHora[0]) ?? 0;
    if (partesHora.length > 1) m = int.tryParse(partesHora[1]) ?? 0;
  }
  return DateTime(ano, mes, dia, h, m);
}

String formatarData(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String formatarHora(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Uma medição — `ponto_ensaio_monitoramento_fissura_leitura`.
class MedicaoFissuraModel {
  final String? id;
  final String? instalacaoId;
  final DateTime? dataHora;
  final String? foto;
  final String descricao;
  final double? temperatura;
  final double? umidade;
  final double medidaX;
  final double medidaY;
  final StatusFissura status;

  const MedicaoFissuraModel({
    this.id,
    this.instalacaoId,
    required this.dataHora,
    this.foto,
    this.descricao = '',
    this.temperatura,
    this.umidade,
    required this.medidaX,
    required this.medidaY,
    required this.status,
  });

  bool get rompido => status == StatusFissura.rompido;

  factory MedicaoFissuraModel.fromJson(Map<String, dynamic> json) {
    return MedicaoFissuraModel(
      id: json['id']?.toString(),
      instalacaoId: json['ponto_id']?.toString(),
      dataHora: parseDataHoraFissura(json['data']?.toString(), json['hora']?.toString()),
      foto: json['foto']?.toString(),
      descricao: json['descricao']?.toString() ?? '',
      temperatura: double.tryParse(json['temperatura']?.toString() ?? ''),
      umidade: double.tryParse(json['umidade']?.toString() ?? ''),
      medidaX: double.tryParse(json['medida_x']?.toString() ?? '') ?? 0,
      medidaY: double.tryParse(json['medida_y']?.toString() ?? '') ?? 0,
      status: StatusFissura.fromLabel(json['status']?.toString()),
    );
  }

  Map<String, dynamic> toJson(String instalacaoId) {
    final dh = dataHora ?? DateTime.now();
    return {
      if (id != null) 'id': id,
      'ponto_id': instalacaoId,
      'data': formatarData(dh),
      'hora': formatarHora(dh),
      if (foto != null) 'foto': foto,
      'descricao': descricao,
      if (temperatura != null) 'temperatura': temperatura.toString(),
      if (umidade != null) 'umidade': umidade.toString(),
      'medida_x': medidaX.toString(),
      'medida_y': medidaY.toString(),
      'status': status.label,
    };
  }
}

/// A instalação — `ponto_ensaio_monitoramento_fissura` — 1 por ponto geral.
/// Sem `temperatura`/`umidade` no banco real (só existem por medição) — o
/// card "Instalação" da tela usa a temperatura/umidade da PRIMEIRA medição,
/// se existir.
class InstalacaoFissuraModel {
  final String? id;
  final String? pontoGeralId;
  final DateTime? dataHora;
  final String? foto1;
  final String? foto2;
  final TipoSeloFissura tipoSelo;
  final List<MedicaoFissuraModel> medicoes;

  const InstalacaoFissuraModel({
    this.id,
    this.pontoGeralId,
    required this.dataHora,
    this.foto1,
    this.foto2,
    required this.tipoSelo,
    this.medicoes = const [],
  });

  List<MedicaoFissuraModel> get medicoesOrdenadas {
    final lista = [...medicoes];
    lista.sort((a, b) => (a.dataHora ?? DateTime(0)).compareTo(b.dataHora ?? DateTime(0)));
    return lista;
  }

  MedicaoFissuraModel? get ultimaMedicao => medicoesOrdenadas.isEmpty ? null : medicoesOrdenadas.last;

  double? get temperaturaInstalacao => medicoesOrdenadas.isEmpty ? null : medicoesOrdenadas.first.temperatura;
  double? get umidadeInstalacao => medicoesOrdenadas.isEmpty ? null : medicoesOrdenadas.first.umidade;

  factory InstalacaoFissuraModel.fromJson(Map<String, dynamic> json, {List<MedicaoFissuraModel> medicoes = const []}) {
    return InstalacaoFissuraModel(
      id: json['id']?.toString(),
      pontoGeralId: json['ponto_ensaio_id']?.toString(),
      dataHora: parseDataHoraFissura(json['data']?.toString(), json['hora']?.toString()),
      foto1: json['foto_1']?.toString(),
      foto2: json['foto_2']?.toString(),
      tipoSelo: TipoSeloFissura.fromChave(json['selo']?.toString()),
      medicoes: medicoes,
    );
  }

  Map<String, dynamic> toJson({required String pontoGeralId}) {
    final dh = dataHora ?? DateTime.now();
    return {
      if (id != null) 'id': id,
      'ponto_ensaio_id': pontoGeralId,
      'data': formatarData(dh),
      'hora': formatarHora(dh),
      if (foto1 != null) 'foto_1': foto1,
      if (foto2 != null) 'foto_2': foto2,
      'selo': tipoSelo.chave,
    };
  }

  InstalacaoFissuraModel copyWith({
    String? id,
    String? pontoGeralId,
    DateTime? dataHora,
    String? foto1,
    String? foto2,
    TipoSeloFissura? tipoSelo,
    List<MedicaoFissuraModel>? medicoes,
  }) {
    return InstalacaoFissuraModel(
      id: id ?? this.id,
      pontoGeralId: pontoGeralId ?? this.pontoGeralId,
      dataHora: dataHora ?? this.dataHora,
      foto1: foto1 ?? this.foto1,
      foto2: foto2 ?? this.foto2,
      tipoSelo: tipoSelo ?? this.tipoSelo,
      medicoes: medicoes ?? this.medicoes,
    );
  }
}

// Calcula o status + as variações (X/Y) de uma medição em relação à
// ANTERIOR imediata (cronologicamente) — ou contra a instalação (0,0) se
// for a primeira. `medicoesExistentes` deve estar ordenado por data.
({double deltaX, double deltaY, StatusFissura status}) calcularVariacao({
  required List<MedicaoFissuraModel> medicoesAnterioresOrdenadas,
  required double medidaX,
  required double medidaY,
  required bool rompidoInformado,
}) {
  final anterior = medicoesAnterioresOrdenadas.isEmpty ? null : medicoesAnterioresOrdenadas.last;
  final baseX = anterior?.medidaX ?? 0.0;
  final baseY = anterior?.medidaY ?? 0.0;
  final deltaX = medidaX - baseX;
  final deltaY = medidaY - baseY;
  return (
    deltaX: deltaX,
    deltaY: deltaY,
    status: StatusFissura.calcular(deltaX: deltaX, deltaY: deltaY, rompido: rompidoInformado),
  );
}
