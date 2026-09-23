import 'package:flutter/material.dart' show Color;

// Ensaio de Líquido penetrante (estruturas metálicas).
//
// Estrutura dos dados:
//   pontos_ensaios_geral            1 por ELEMENTO ensaiado (ex.: Viga V07).
//     └ ponto_ensaio_liquido_penetrante   N pontos de LP (cordões/juntas),
//                                          ligados por `ponto_id`.
// `valor_resultado`/`cor_resultado` do registro geral guardam a CONTAGEM dos
// status dos pontos (ex.: "2 aprov. · 1 reprov."), que as listas mostram
// como badge — ver [ContagemStatusLP].

enum StatusLP {
  aprovado('aprovado', 'Aprovado', Color(0xFF2E7D32), Color(0xFFD7EFD9)),
  reprovado('reprovado', 'Reprovado', Color(0xFFC62828), Color(0xFFF9D6D6)),
  cabeAnalise('cabe_analise', 'Cabe análise', Color(0xFFB26A00), Color(0xFFFBE3BE));

  final String chave;
  final String label;
  final Color cor;
  final Color fundo;
  const StatusLP(this.chave, this.label, this.cor, this.fundo);

  /// Tolera o valor gravado como chave ('cabe_analise') ou como rótulo
  /// ('Cabe análise'), com ou sem acento.
  static StatusLP? fromChave(String? valor) {
    final v = (valor ?? '').trim().toLowerCase().replaceAll('á', 'a').replaceAll(' ', '_');
    if (v.isEmpty) return null;
    if (v.startsWith('aprov')) return StatusLP.aprovado;
    if (v.startsWith('reprov')) return StatusLP.reprovado;
    if (v.startsWith('cabe') || v.contains('analise')) return StatusLP.cabeAnalise;
    return null;
  }
}

class PontoLiquidoPenetranteModel {
  final String? id;
  final String? pontoGeralId;
  final String nomePonto;
  final String? fotoSolda;
  final String? fotoPenetrante;
  final String? fotoResultado;
  final String tamanhoAnalise; // cm (coluna texto)
  final String tempoPenetracao; // min (coluna texto)
  final String descricao;
  final StatusLP? status;
  final DateTime? criadoEm;

  const PontoLiquidoPenetranteModel({
    this.id,
    this.pontoGeralId,
    required this.nomePonto,
    this.fotoSolda,
    this.fotoPenetrante,
    this.fotoResultado,
    this.tamanhoAnalise = '',
    this.tempoPenetracao = '',
    this.descricao = '',
    this.status,
    this.criadoEm,
  });

  factory PontoLiquidoPenetranteModel.fromJson(Map<String, dynamic> j) => PontoLiquidoPenetranteModel(
        id: j['id']?.toString(),
        pontoGeralId: j['ponto_id']?.toString(),
        nomePonto: j['nome_ponto']?.toString() ?? '',
        fotoSolda: _url(j['foto_solda']),
        fotoPenetrante: _url(j['foto_penetrante']),
        fotoResultado: _url(j['foto_resultado']),
        tamanhoAnalise: j['tamanho_analise']?.toString() ?? '',
        tempoPenetracao: j['tempo_penetracao']?.toString() ?? '',
        descricao: j['descricao']?.toString() ?? '',
        status: StatusLP.fromChave(j['status']?.toString()),
        criadoEm: DateTime.tryParse(j['criado_em']?.toString() ?? ''),
      );

  Map<String, dynamic> toJson({required String pontoGeralId}) => {
        'ponto_id': pontoGeralId,
        'nome_ponto': nomePonto.trim(),
        'foto_solda': fotoSolda,
        'foto_penetrante': fotoPenetrante,
        'foto_resultado': fotoResultado,
        'tamanho_analise': tamanhoAnalise.trim(),
        'tempo_penetracao': tempoPenetracao.trim(),
        'descricao': descricao.trim(),
        'status': status?.chave,
      };

  PontoLiquidoPenetranteModel copyWith({String? fotoSolda, String? fotoPenetrante, String? fotoResultado}) => PontoLiquidoPenetranteModel(
        id: id,
        pontoGeralId: pontoGeralId,
        nomePonto: nomePonto,
        fotoSolda: fotoSolda ?? this.fotoSolda,
        fotoPenetrante: fotoPenetrante ?? this.fotoPenetrante,
        fotoResultado: fotoResultado ?? this.fotoResultado,
        tamanhoAnalise: tamanhoAnalise,
        tempoPenetracao: tempoPenetracao,
        descricao: descricao,
        status: status,
        criadoEm: criadoEm,
      );

  List<String> get fotos => [fotoSolda, fotoPenetrante, fotoResultado].whereType<String>().toList();

  /// "15 cm analisados · 3 fotos" (linha de apoio do card).
  String get resumo {
    final partes = <String>[
      if (tamanhoAnalise.trim().isNotEmpty) '${tamanhoAnalise.trim()} cm analisados',
      if (tempoPenetracao.trim().isNotEmpty) '${tempoPenetracao.trim()} min',
      '${fotos.length} ${fotos.length == 1 ? 'foto' : 'fotos'}',
    ];
    return partes.join(' · ');
  }

  static String? _url(dynamic v) {
    final s = v?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }
}

/// Contagem por status — é a "análise" do ensaio: individual (os pontos de
/// um elemento) e geral (todos os elementos da estrutura).
class ContagemStatusLP {
  final int aprovados;
  final int reprovados;
  final int cabeAnalise;
  final int semStatus;

  const ContagemStatusLP({this.aprovados = 0, this.reprovados = 0, this.cabeAnalise = 0, this.semStatus = 0});

  factory ContagemStatusLP.de(Iterable<StatusLP?> status) {
    var a = 0, r = 0, c = 0, s = 0;
    for (final st in status) {
      switch (st) {
        case StatusLP.aprovado:
          a++;
        case StatusLP.reprovado:
          r++;
        case StatusLP.cabeAnalise:
          c++;
        case null:
          s++;
      }
    }
    return ContagemStatusLP(aprovados: a, reprovados: r, cabeAnalise: c, semStatus: s);
  }

  ContagemStatusLP operator +(ContagemStatusLP o) => ContagemStatusLP(
        aprovados: aprovados + o.aprovados,
        reprovados: reprovados + o.reprovados,
        cabeAnalise: cabeAnalise + o.cabeAnalise,
        semStatus: semStatus + o.semStatus,
      );

  int get total => aprovados + reprovados + cabeAnalise + semStatus;

  int de(StatusLP s) => switch (s) {
        StatusLP.aprovado => aprovados,
        StatusLP.reprovado => reprovados,
        StatusLP.cabeAnalise => cabeAnalise,
      };

  /// Pior resultado presente: reprovado > cabe análise > aprovado.
  StatusLP? get pior {
    if (reprovados > 0) return StatusLP.reprovado;
    if (cabeAnalise > 0) return StatusLP.cabeAnalise;
    if (aprovados > 0) return StatusLP.aprovado;
    return null;
  }

  /// Texto da badge (`pontos_ensaios_geral.valor_resultado`). Só entram os
  /// status que existem: "3 aprov." / "2 aprov. · 1 reprov. · 1 análise".
  String get textoBadge {
    if (aprovados + reprovados + cabeAnalise == 0) return 'Pendente';
    return [
      if (aprovados > 0) '$aprovados aprov.',
      if (reprovados > 0) '$reprovados reprov.',
      if (cabeAnalise > 0) '$cabeAnalise análise',
    ].join(' · ');
  }

  /// Cor da badge (`pontos_ensaios_geral.cor_resultado`) = cor do pior status.
  String get corHex {
    final p = pior;
    if (p == null) return '#E0E0E0';
    return '#${p.cor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }
}
