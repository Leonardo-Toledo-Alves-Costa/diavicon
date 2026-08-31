/// Pontuação de risco de uma anomalia (fórmula G.U.T.):
/// (Gravidade × Urgência × Tendência) × (1 + Majoração/100) × (Área afetada/100).
///
/// Gravidade/Urgência/Tendência vêm fixas do cadastro da anomalia (escala 1 a 5,
/// tabela `anomalias`); Majoração e Área afetada são digitadas em cada ocorrência,
/// como percentuais inteiros (ex: usuário digita 10 para dizer "10%").
///
/// Fonte única desta fórmula — usada tanto no registro de uma inspeção
/// (`registro_inspecao_screen.dart`) quanto nas telas de resumo (visão geral,
/// local, ponto) para que o "G.U.T" mostrado seja sempre o mesmo cálculo.
double calcularPontuacaoRiscoGut({
  required dynamic gravidadeValor,
  required dynamic urgenciaValor,
  required dynamic tendenciaValor,
  required dynamic majoracao,
  required dynamic areaAfetada,
}) {
  final gravidade = int.tryParse(gravidadeValor?.toString() ?? '') ?? 0;
  final urgencia = int.tryParse(urgenciaValor?.toString() ?? '') ?? 0;
  final tendencia = int.tryParse(tendenciaValor?.toString() ?? '') ?? 0;
  final maj = double.tryParse(majoracao?.toString() ?? '') ?? 0;
  final area = double.tryParse(areaAfetada?.toString() ?? '') ?? 0;

  final base = gravidade * urgencia * tendencia;
  final multiplicadorMajoracao = 1 + (maj / 100);
  final fatorArea = area / 100;

  return base * multiplicadorMajoracao * fatorArea;
}
