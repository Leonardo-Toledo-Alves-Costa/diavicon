/// Cores dos dashboards, em inteiros (é assim que ficam salvas no
/// `schema_json` dos cards e séries).
///
/// A paleta parte do laranja e do grafite da marca e segue com tons
/// distinguíveis entre si (inclusive para quem tem dificuldade com
/// vermelho/verde), sem o azul/vermelho/roxo padrão do Material.
const paletaBiInt = <int>[
  0xFFF08A24, // laranja Diavicon
  0xFF3F4B5B, // grafite
  0xFF2A9D8F, // verde-azulado
  0xFFE4572E, // coral
  0xFF5B7DB1, // azul acinzentado
  0xFFE9B949, // areia
  0xFF8C6BB1, // lilás
  0xFF7A8B99, // cinza-azulado
];

/// Cor de um card/série novo.
const corPadraoBiInt = 0xFFF08A24;

/// Azul que era o padrão antigo (e a primeira opção do seletor). Cards e
/// séries salvos com ele passam a aparecer na cor da marca, sem precisar
/// migrar os dados salvos.
const corPadraoAntigaBiInt = 0xFF2F6FED;

int corBiNormalizada(int cor) => cor == corPadraoAntigaBiInt ? corPadraoBiInt : cor;
