import '../../../../core/models/classe_qualitativa.dart';

/// As três classificações qualitativas da resistividade elétrica (kΩ·cm).
///
/// FONTE ÚNICA. Antes estas regras existiam em cinco cópias (modelo,
/// provider da análise, relatório PDF e duas telas) que discordavam entre
/// si: umas usavam `<` e outras `<=` nos limites, a permissividade tinha os
/// nomes das classes deslocados um nível em duas delas, e a taxa de corrosão
/// só chegava em "Desprezível" quando a média era exatamente 20,0. O PDF
/// entregue ao cliente e a tela do app davam respostas diferentes para a
/// mesma leitura.
///
/// Limites inclusivos (`<=`): o valor exatamente no limite cai na classe
/// mais grave — convenção escolhida pela DIAVICON.
class ClassificacaoResistividade {
  /// Risco de corrosão da armadura.
  static const risco = EscalaQualitativa(
    nome: 'Risco de corrosão',
    faixas: [
      (ate: 15, texto: 'Muito Alto'),
      (ate: 20, texto: 'Alto'),
      (ate: 55, texto: 'Moderado'),
      (ate: 80, texto: 'Baixo'),
      (ate: null, texto: 'Desprezível'),
    ],
  );

  /// Taxa de corrosão. Quatro classes: não existe "Desprezível" aqui — a
  /// quinta classe das cópias antigas só era alcançada com média de
  /// exatamente 20,0, e era um defeito, não uma faixa.
  static const taxa = EscalaQualitativa(
    nome: 'Taxa de corrosão',
    faixas: [
      (ate: 5, texto: 'Muito Alto'),
      (ate: 10, texto: 'Alto'),
      (ate: 20, texto: 'Moderado'),
      (ate: null, texto: 'Baixo'),
    ],
  );

  /// Permissividade iônica (penetrabilidade de cloretos), AASHTO T 358.
  ///
  /// Os nomes seguem a norma: High / Moderate / Low / Very Low / Negligible.
  /// Duas das cópias antigas (inclusive a tela de análise do ponto) usavam
  /// os mesmos limites com os nomes deslocados um nível acima — "Muito
  /// Alto" onde a norma diz "Alto".
  static const permissividade = EscalaQualitativa(
    nome: 'Permissividade iônica',
    faixas: [
      (ate: 12, texto: 'Alto'),
      (ate: 21, texto: 'Moderado'),
      (ate: 37, texto: 'Baixo'),
      (ate: 254, texto: 'Muito Baixo'),
      (ate: null, texto: 'Desprezível'),
    ],
  );

  static const todas = [risco, taxa, permissividade];
}
