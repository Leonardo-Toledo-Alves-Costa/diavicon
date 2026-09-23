import 'package:flutter/material.dart';

/// Uma classe de uma escala qualitativa (ex.: "Alto", "Moderado").
///
/// [posicao] ordena por gravidade: 0 é a classe MAIS GRAVE da escala. É o
/// que permite comparar classes de escalas diferentes (a "pior" encontrada)
/// e ordenar uma distribuição do pior para o melhor, independente do texto.
class ClasseQualitativa {
  final String texto;
  final Color corTexto;
  final Color corFundo;
  final int posicao;

  const ClasseQualitativa({
    required this.texto,
    required this.corTexto,
    required this.corFundo,
    required this.posicao,
  });

  /// Formato legado `{'texto', 'corTxt', 'corFundo'}` usado pelas telas de
  /// análise antigas. Existe só pra migrar essas telas sem reescrevê-las.
  Map<String, dynamic> get comoMapaLegado => {'texto': texto, 'corTxt': corTexto, 'corFundo': corFundo};

  @override
  bool operator ==(Object other) => other is ClasseQualitativa && other.texto == texto && other.posicao == posicao;

  @override
  int get hashCode => Object.hash(texto, posicao);
}

/// Paleta de gravidade compartilhada pelas escalas qualitativas. A posição
/// na escala decide a cor, não o nome da classe — assim duas escalas com
/// nomes diferentes ("Muito Alto" vs "Despassivado") ficam visualmente
/// comparáveis num mesmo dashboard.
class PaletaGravidade {
  static const _cores = <(Color, Color)>[
    (Color(0xFFD32F2F), Color(0xFFFFEBEE)), // mais grave
    (Color(0xFFF57C00), Color(0xFFFFF3E0)),
    (Color(0xFFF9A825), Color(0xFFFFFDE7)),
    (Color(0xFF388E3C), Color(0xFFE8F5E9)),
    (Color(0xFF1B5E20), Color(0xFFE8F5E9)), // menos grave
  ];

  /// Cores da classe [posicao] numa escala de [total] classes. Escalas
  /// menores que a paleta usam as pontas (a mais grave é sempre vermelha, a
  /// mais branda sempre verde), pra "Baixo" nunca sair amarelo só porque a
  /// escala tem quatro classes em vez de cinco.
  static (Color, Color) para(int posicao, int total) {
    if (total <= 1) return _cores.last;
    final indice = (posicao * (_cores.length - 1) / (total - 1)).round();
    return _cores[indice.clamp(0, _cores.length - 1)];
  }
}

/// Escala por faixas com limite superior INCLUSIVO (`valor <= limite`).
///
/// O limite inclusivo foi a convenção escolhida para todas as escalas: o
/// valor exatamente no limite cai na classe mais grave (ex.: 15,0 kΩ·cm é
/// "Muito Alto" no risco de corrosão).
class EscalaQualitativa {
  final String nome;

  /// Faixas da mais grave para a menos grave. A última tem limite null
  /// ("acima de tudo").
  final List<({double? ate, String texto})> faixas;

  const EscalaQualitativa({required this.nome, required this.faixas});

  List<ClasseQualitativa> get classes => [
        for (var i = 0; i < faixas.length; i++) _classe(i),
      ];

  ClasseQualitativa _classe(int i) {
    final (texto, fundo) = PaletaGravidade.para(i, faixas.length);
    return ClasseQualitativa(texto: faixas[i].texto, corTexto: texto, corFundo: fundo, posicao: i);
  }

  /// Null para valor ausente ou não positivo — leitura zerada é "sem
  /// medição", não a classe mais grave.
  ClasseQualitativa? classificar(double? valor) {
    if (valor == null || valor.isNaN || valor <= 0) return null;
    for (var i = 0; i < faixas.length; i++) {
      final ate = faixas[i].ate;
      if (ate == null || valor <= ate) return _classe(i);
    }
    return _classe(faixas.length - 1);
  }
}
