// Editor de "Quadro": Linha -> Divisão -> Slot. Usado por Cabeçalho e
// Registros (e, dentro de Registros, recursivamente pelo Bloco de anomalias).

int _contadorId = 0;
String gerarIdQuadro() {
  _contadorId++;
  return '${DateTime.now().microsecondsSinceEpoch}_$_contadorId';
}

// `subLista` é o mesmo mecanismo de `anomalias` (Quadro aninhado, repetido
// uma vez por item de uma lista dentro do registro) generalizado pra
// qualquer ensaio — ex: "Pontos de leitura" da Resistividade. Mantido como
// valor separado (em vez de renomear `anomalias`) pra não invalidar
// schema_json de modelos de Inspeção Visual já salvos.
//
// `matriz` é outro bloco genérico: um campo cujo valor já vem pronto como
// HTML de tabela (ex: a grade linha×coluna de potencial_mv da Potencial de
// Corrosão) — a resolução dos dados pré-renderiza a tabela inteira (mesma
// ideia dos campos de gráfico, que pré-renderizam a imagem) e o Quadro só
// posiciona esse HTML já pronto, sem escapar como texto.
enum TipoConteudoSlot { texto, imagem, galeria, anomalias, subLista, matriz }

extension TipoConteudoSlotX on TipoConteudoSlot {
  // Rótulo genérico — quem monta o Quadro com um catálogo/legenda de
  // sub-lista específico (ex: "Pontos de leitura" da Resistividade) pode
  // mostrar um texto mais específico no lugar deste ao listar o tipo.
  String get rotulo {
    switch (this) {
      case TipoConteudoSlot.texto:
        return 'Campo de texto';
      case TipoConteudoSlot.imagem:
        return 'Imagem';
      case TipoConteudoSlot.galeria:
        return 'Galeria de fotos';
      case TipoConteudoSlot.anomalias:
        return 'Bloco de anomalias';
      case TipoConteudoSlot.subLista:
        return 'Sub-lista';
      case TipoConteudoSlot.matriz:
        return 'Matriz (tabela)';
    }
  }

  // Blocos (galeria/anomalias/subLista/matriz) só podem ocupar uma linha
  // inteira, sem divisão.
  bool get ehBloco =>
      this == TipoConteudoSlot.galeria ||
      this == TipoConteudoSlot.anomalias ||
      this == TipoConteudoSlot.subLista ||
      this == TipoConteudoSlot.matriz;

  static TipoConteudoSlot fromChave(String chave) =>
      TipoConteudoSlot.values.firstWhere((t) => t.name == chave, orElse: () => TipoConteudoSlot.texto);
}

// `matriz` é o tipo de campo cujo valor já vem pronto como HTML de tabela
// (ver TipoConteudoSlot.matriz) — separado de `texto` pra que o seletor de
// campo do editor (quadro_editor.dart) filtre corretamente: um slot de texto
// comum não deve oferecer campos de matriz, e vice-versa.
enum TipoCampoCatalogo { texto, imagem, matriz }

class CampoCatalogo {
  final String chave;
  final String rotulo;
  final TipoCampoCatalogo tipo;
  const CampoCatalogo(this.chave, this.rotulo, this.tipo);
}

// Catálogos fixos de campos (Inspeção Visual). "Fotos do registro" não entra
// aqui: o bloco "Galeria de fotos" já pega todas as fotos automaticamente,
// sem precisar de campo_vinculado.
const List<CampoCatalogo> camposCabecalho = [
  CampoCatalogo('logo_empresa', 'Logo da empresa', TipoCampoCatalogo.imagem),
  CampoCatalogo('nome_empresa', 'Nome da empresa', TipoCampoCatalogo.texto),
  CampoCatalogo('nome_projeto', 'Nome do projeto', TipoCampoCatalogo.texto),
  CampoCatalogo('cliente', 'Cliente', TipoCampoCatalogo.texto),
  CampoCatalogo('foto_capa', 'Foto de capa', TipoCampoCatalogo.imagem),
];

// Só usado no seletor "De qual tabela extrair o dado?" da Tabela Resumo.
const List<CampoCatalogo> camposProjeto = [
  CampoCatalogo('nome_projeto', 'Nome do projeto', TipoCampoCatalogo.texto),
  CampoCatalogo('cliente', 'Cliente', TipoCampoCatalogo.texto),
];

const List<CampoCatalogo> camposRegistro = [
  CampoCatalogo('nome_registro', 'Nome do registro', TipoCampoCatalogo.texto),
  CampoCatalogo('descricao_registro', 'Descrição', TipoCampoCatalogo.texto),
  CampoCatalogo('estrutura', 'Estrutura', TipoCampoCatalogo.texto),
  CampoCatalogo('local', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('condicao_exposicao_registro', 'Condição de exposição', TipoCampoCatalogo.texto),
  CampoCatalogo('sistema', 'Sistema', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento', 'Tipo de elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('elemento', 'Elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('tipologia_elemento', 'Tipologia do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('marcacao_planta', 'Marcação em planta', TipoCampoCatalogo.imagem),
];

// Os 3 blocos de repetição de "Informações iniciais".
const List<CampoCatalogo> camposEquipe = [
  CampoCatalogo('nome_user_equipe', 'Nome do usuário (equipe)', TipoCampoCatalogo.texto),
  CampoCatalogo('funcao_user_equipe', 'Função (equipe)', TipoCampoCatalogo.texto),
];

const List<CampoCatalogo> camposEmpresasProjeto = [
  CampoCatalogo('nome_empresa_projeto', 'Nome da empresa', TipoCampoCatalogo.texto),
  CampoCatalogo('user_empresa_projeto', 'Usuário da empresa', TipoCampoCatalogo.texto),
  CampoCatalogo('funcao_user_empresa_projeto', 'Função do usuário', TipoCampoCatalogo.texto),
];

const List<CampoCatalogo> camposEstruturasProjeto = [
  CampoCatalogo('nome_estrutura_ip', 'Nome', TipoCampoCatalogo.texto),
  CampoCatalogo('descricao_estrutura_ip', 'Descrição', TipoCampoCatalogo.texto),
  CampoCatalogo('proprietario_estrutura_ip', 'Proprietário', TipoCampoCatalogo.texto),
  CampoCatalogo('caa_estrutura_ip', 'CAA', TipoCampoCatalogo.texto),
  CampoCatalogo('ano_construcao_estrutura_ip', 'Ano de construção e idade', TipoCampoCatalogo.texto),
  CampoCatalogo('conjunto_estrutural_ip', 'Conjunto Estrutural', TipoCampoCatalogo.texto),
  CampoCatalogo('utilizacao_estrutura_ip', 'Utilização', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_estrutura_ip', 'Tipo de estrutura', TipoCampoCatalogo.texto),
  CampoCatalogo('tipologia_estrutural_ip', 'Tipologia estrutural', TipoCampoCatalogo.texto),
  // Idade em anos, isolada (número puro) — 'ano_construcao_estrutura_ip' acima
  // já mostra "2010 (15 anos)" formatado, o que serve pra exibir mas não pra
  // operar numa fórmula.
  CampoCatalogo('idade_estrutura_ip', 'Idade (anos)', TipoCampoCatalogo.texto),
  CampoCatalogo('endereco_estrutura_ip', 'Endereço completo (com CEP)', TipoCampoCatalogo.texto),
  CampoCatalogo('lat_long_estrutura_ip', 'Latitude e longitude', TipoCampoCatalogo.texto),
  // Imagem de mapa estática real, gerada a partir de lat/long via serviço
  // público (sem chave de API) — ver InspecaoVisualReportData._urlMapaEstatico.
  CampoCatalogo('mapa_estrutura_ip', 'Mapa', TipoCampoCatalogo.imagem),
];

// Novo bloco de repetição de "Informações iniciais": locais da estrutura
// (uma estrutura pode ter N locais, cada um com seus próprios registros).
const List<CampoCatalogo> camposLocal = [
  CampoCatalogo('nome_local', 'Nome', TipoCampoCatalogo.texto),
  CampoCatalogo('tipologia_local', 'Tipologia', TipoCampoCatalogo.texto),
  CampoCatalogo('condicao_local', 'Condições', TipoCampoCatalogo.texto),
  CampoCatalogo('descricao_local', 'Descrição', TipoCampoCatalogo.texto),
];

const List<CampoCatalogo> camposAnomalia = [
  CampoCatalogo('nome_anomalia', 'Nome da anomalia', TipoCampoCatalogo.texto),
  CampoCatalogo('area_afetada', 'Área afetada', TipoCampoCatalogo.texto),
  CampoCatalogo('majoracao', 'Majoração', TipoCampoCatalogo.texto),
  CampoCatalogo('gravidade_valor', 'G (Gravidade)', TipoCampoCatalogo.texto),
  CampoCatalogo('urgencia_valor', 'U (Urgência)', TipoCampoCatalogo.texto),
  CampoCatalogo('tendencia_valor', 'T (Tendência)', TipoCampoCatalogo.texto),
  CampoCatalogo('gut', 'GUT', TipoCampoCatalogo.texto),
  CampoCatalogo('descricao_anomalia', 'Descrição da anomalia', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_risco', 'Tipo do risco', TipoCampoCatalogo.texto),
  CampoCatalogo('classe_risco', 'Classe do risco', TipoCampoCatalogo.texto),
  CampoCatalogo('descricao_risco', 'Descrição do risco', TipoCampoCatalogo.texto),
];

// Variáveis da Tabela Resumo (Inspeção Visual) que podem compor uma "coluna
// personalizada" (fórmula). Numéricas entram direto na conta; categóricas só
// entram depois que o usuário numeraliza cada valor possível (ex: CAA "II" =
// 40) — ver `NumeralizacaoCampo`. Todo o resto (nomes, descrições, endereço,
// datas etc.) é só texto e nunca aparece no seletor de variável da fórmula.
const Set<String> camposNumericosParaFormula = {
  'majoracao',
  'gravidade_valor',
  'urgencia_valor',
  'tendencia_valor',
  'gut',
  'area_afetada',
  'idade_estrutura_ip',
};

const Set<String> camposCategoricosParaFormula = {
  'caa_estrutura_ip',
  'tipo_estrutura_ip',
  'tipologia_estrutural_ip',
  'condicao_exposicao_registro',
  'sistema',
  'local',
  'tipologia_elemento',
  'tipo_risco',
  'classe_risco',
};

// Catálogos usados só pela seção "Referencial" — cada um espelha um dos
// "campos personalizáveis" da empresa (ver CamposMenuScreen). A maioria só
// tem nome/descrição; Anomalias tem muito mais campos (categoria, sistema,
// gravidade/urgência/tendência, risco).
const List<CampoCatalogo> camposCatalogoPadrao = [
  CampoCatalogo('nome', 'Nome', TipoCampoCatalogo.texto),
  CampoCatalogo('descricao', 'Descrição', TipoCampoCatalogo.texto),
];

// "Tipos de elemento" também mostra a qual sistema o tipo pertence
// (tipos_elemento.sistemas_id -> sistemas_habitacionais).
const List<CampoCatalogo> camposTipoElementoReferencial = [
  CampoCatalogo('nome', 'Nome', TipoCampoCatalogo.texto),
  CampoCatalogo('descricao', 'Descrição', TipoCampoCatalogo.texto),
  CampoCatalogo('sistema', 'Sistema', TipoCampoCatalogo.texto),
];

const List<CampoCatalogo> camposAnomaliaReferencial = [
  CampoCatalogo('nome', 'Nome', TipoCampoCatalogo.texto),
  CampoCatalogo('descricao', 'Descrição', TipoCampoCatalogo.texto),
  CampoCatalogo('categoria', 'Categoria', TipoCampoCatalogo.texto),
  CampoCatalogo('sistema_construtivo', 'Sistema construtivo', TipoCampoCatalogo.texto),
  CampoCatalogo('gravidade_valor', 'Gravidade (valor)', TipoCampoCatalogo.texto),
  CampoCatalogo('gravidade_descricao', 'Gravidade (descrição)', TipoCampoCatalogo.texto),
  CampoCatalogo('urgencia_valor', 'Urgência (valor)', TipoCampoCatalogo.texto),
  CampoCatalogo('urgencia_descricao', 'Urgência (descrição)', TipoCampoCatalogo.texto),
  CampoCatalogo('tendencia_valor', 'Tendência (valor)', TipoCampoCatalogo.texto),
  CampoCatalogo('tendencia_descricao', 'Tendência (descrição)', TipoCampoCatalogo.texto),
  CampoCatalogo('risco_tipo', 'Tipo de risco', TipoCampoCatalogo.texto),
  CampoCatalogo('risco_descricao', 'Descrição do risco', TipoCampoCatalogo.texto),
  CampoCatalogo('risco_valor', 'Valor do risco', TipoCampoCatalogo.texto),
  CampoCatalogo('risco_major', 'Majoração do risco', TipoCampoCatalogo.texto),
];

// Um catálogo disponível na seção Referencial: chave da tabela real
// (`campos_personalizaveis`), rótulo de exibição, grupo (pra organizar o
// seletor "+ Adicionar catálogo") e os campos que podem ser mostrados.
class CatalogoReferencial {
  final String chave;
  final String rotulo;
  final String grupo;
  final List<CampoCatalogo> campos;
  const CatalogoReferencial(this.chave, this.rotulo, this.grupo, this.campos);
}

final List<CatalogoReferencial> catalogosReferencial = [
  CatalogoReferencial('tipos_estrutura', 'Tipos de estrutura', 'ESTRUTURA', camposCatalogoPadrao),
  CatalogoReferencial('tipologias_estrutura', 'Tipologias de estrutura', 'ESTRUTURA', camposCatalogoPadrao),
  CatalogoReferencial('utilizacoes_estrutura', 'Utilização da estrutura', 'ESTRUTURA', camposCatalogoPadrao),
  CatalogoReferencial('condicoes_local', 'Condições do local', 'LOCAL', camposCatalogoPadrao),
  CatalogoReferencial('tipologias_local', 'Tipologia do local', 'LOCAL', camposCatalogoPadrao),
  CatalogoReferencial('tipos_elemento', 'Tipos de elemento', 'ELEMENTO', camposTipoElementoReferencial),
  CatalogoReferencial('tipologias_elemento', 'Tipologias de elemento', 'ELEMENTO', camposCatalogoPadrao),
  CatalogoReferencial('sistemas_habitacionais', 'Sistemas', 'ELEMENTO', camposCatalogoPadrao),
  CatalogoReferencial('revestimentos_elemento', 'Revestimento de elemento', 'ELEMENTO', camposCatalogoPadrao),
  CatalogoReferencial('anomalias', 'Anomalias e manifestações patológicas', 'INSPEÇÃO VISUAL E GUT', camposAnomaliaReferencial),
];

CatalogoReferencial? buscarCatalogoReferencial(String chave) {
  for (final c in catalogosReferencial) {
    if (c.chave == chave) return c;
  }
  return null;
}

CampoCatalogo? buscarCampo(List<CampoCatalogo> catalogo, String? chave) {
  if (chave == null) return null;
  for (final c in catalogo) {
    if (c.chave == chave) return c;
  }
  return null;
}

List<CampoCatalogo> _semImagem(List<CampoCatalogo> catalogo) =>
    catalogo.where((c) => c.tipo != TipoCampoCatalogo.imagem).toList();

// "De qual tabela extrair o dado?" — usado só pela Tabela Resumo de
// Registros. Fotos nunca aparecem numa tabela, então cada catálogo entra sem
// os campos do tipo imagem.
class TabelaResumo {
  final String chave;
  final String rotulo;
  final List<CampoCatalogo> campos;
  const TabelaResumo(this.chave, this.rotulo, this.campos);
}

final List<TabelaResumo> tabelasResumo = [
  TabelaResumo('projeto', 'Projeto', camposProjeto),
  TabelaResumo('estrutura', 'Estrutura', _semImagem(camposEstruturasProjeto)),
  TabelaResumo('registro', 'Registro', _semImagem(camposRegistro)),
  TabelaResumo('anomalia', 'Anomalia', camposAnomalia),
];

enum OperadorCondicional { igual, diferente, contem, maiorQue, menorQue }

extension OperadorCondicionalX on OperadorCondicional {
  String get rotulo {
    switch (this) {
      case OperadorCondicional.igual:
        return 'é igual a';
      case OperadorCondicional.diferente:
        return 'é diferente de';
      case OperadorCondicional.contem:
        return 'contém';
      case OperadorCondicional.maiorQue:
        return 'maior que';
      case OperadorCondicional.menorQue:
        return 'menor que';
    }
  }

  static OperadorCondicional fromChave(String chave) =>
      OperadorCondicional.values.firstWhere((o) => o.name == chave, orElse: () => OperadorCondicional.igual);

  bool avalia(String valorCampo, String valorComparacao) {
    switch (this) {
      case OperadorCondicional.igual:
        return valorCampo.trim().toLowerCase() == valorComparacao.trim().toLowerCase();
      case OperadorCondicional.diferente:
        return valorCampo.trim().toLowerCase() != valorComparacao.trim().toLowerCase();
      case OperadorCondicional.contem:
        return valorCampo.toLowerCase().contains(valorComparacao.toLowerCase());
      case OperadorCondicional.maiorQue:
        final a = double.tryParse(valorCampo);
        final b = double.tryParse(valorComparacao);
        return a != null && b != null && a > b;
      case OperadorCondicional.menorQue:
        final a = double.tryParse(valorCampo);
        final b = double.tryParse(valorComparacao);
        return a != null && b != null && a < b;
    }
  }
}

// Regra de estilo condicional pra um slot de texto: a primeira regra (em
// `ordem`) cujo `campoReferencia` bater com `valorComparacao` define
// `corTexto`/`corFundo`. `campoReferencia` pode ser o próprio campo do slot
// ou outro campo do mesmo catálogo (ex: colorir a "Classe do risco" com base
// no valor de "GUT").
class RegraCondicional {
  final String campoReferencia;
  final OperadorCondicional operador;
  final String valorComparacao;
  final String corTexto;
  final String corFundo;

  const RegraCondicional({
    required this.campoReferencia,
    required this.operador,
    required this.valorComparacao,
    required this.corTexto,
    required this.corFundo,
  });

  factory RegraCondicional.fromJson(Map<String, dynamic> json) {
    return RegraCondicional(
      campoReferencia: json['campo_referencia']?.toString() ?? '',
      operador: OperadorCondicionalX.fromChave(json['operador']?.toString() ?? 'igual'),
      valorComparacao: json['valor_comparacao']?.toString() ?? '',
      corTexto: json['cor_texto']?.toString() ?? 'preto',
      corFundo: json['cor_fundo']?.toString() ?? 'branco',
    );
  }

  Map<String, dynamic> toJson() => {
        'campo_referencia': campoReferencia,
        'operador': operador.name,
        'valor_comparacao': valorComparacao,
        'cor_texto': corTexto,
        'cor_fundo': corFundo,
      };

  RegraCondicional copyWith({
    String? campoReferencia,
    OperadorCondicional? operador,
    String? valorComparacao,
    String? corTexto,
    String? corFundo,
  }) {
    return RegraCondicional(
      campoReferencia: campoReferencia ?? this.campoReferencia,
      operador: operador ?? this.operador,
      valorComparacao: valorComparacao ?? this.valorComparacao,
      corTexto: corTexto ?? this.corTexto,
      corFundo: corFundo ?? this.corFundo,
    );
  }
}

enum AjusteImagem { cobrir, conter }

extension AjusteImagemX on AjusteImagem {
  String get rotulo {
    switch (this) {
      case AjusteImagem.cobrir:
        return 'Preencher';
      case AjusteImagem.conter:
        return 'Conter';
    }
  }

  // Equivalente CSS: "cover" recorta pra preencher a caixa, "contain" encaixa
  // a imagem inteira dentro da caixa (pode sobrar espaço).
  String get cssObjectFit => this == AjusteImagem.cobrir ? 'cover' : 'contain';

  static AjusteImagem fromChave(String chave) =>
      AjusteImagem.values.firstWhere((a) => a.name == chave, orElse: () => AjusteImagem.cobrir);
}

class ConteudoSlot {
  final TipoConteudoSlot tipo;
  final String? campoVinculado; // usado por texto/imagem
  final int colunas; // usado por galeria
  final bool mostrarDescricao; // usado por galeria
  final Quadro? quadroAninhado; // usado por anomalias
  final List<RegraCondicional> decoracaoCondicional; // usado por texto
  final double alturaImagem; // usado por imagem, em pixels
  final AjusteImagem ajusteImagem; // usado por imagem

  const ConteudoSlot({
    required this.tipo,
    this.campoVinculado,
    this.colunas = 3,
    this.mostrarDescricao = true,
    this.quadroAninhado,
    this.decoracaoCondicional = const [],
    this.alturaImagem = 160,
    this.ajusteImagem = AjusteImagem.cobrir,
  });

  factory ConteudoSlot.fromJson(Map<String, dynamic> json) {
    final regrasJson = json['decoracao_condicional'] as List? ?? const [];
    return ConteudoSlot(
      tipo: TipoConteudoSlotX.fromChave(json['tipo']?.toString() ?? 'texto'),
      campoVinculado: json['campo_vinculado']?.toString(),
      colunas: (json['colunas'] as num?)?.toInt() ?? 3,
      mostrarDescricao: json['mostrar_descricao'] as bool? ?? true,
      quadroAninhado:
          json['quadro_aninhado'] != null ? Quadro.fromJson((json['quadro_aninhado'] as Map).cast<String, dynamic>()) : null,
      decoracaoCondicional: regrasJson.map((r) => RegraCondicional.fromJson((r as Map).cast<String, dynamic>())).toList(),
      alturaImagem: (json['altura_imagem'] as num?)?.toDouble() ?? 160,
      ajusteImagem: AjusteImagemX.fromChave(json['ajuste_imagem']?.toString() ?? 'cobrir'),
    );
  }

  Map<String, dynamic> toJson() => {
        'tipo': tipo.name,
        'campo_vinculado': campoVinculado,
        'colunas': colunas,
        'mostrar_descricao': mostrarDescricao,
        'quadro_aninhado': quadroAninhado?.toJson(),
        'decoracao_condicional': decoracaoCondicional.map((r) => r.toJson()).toList(),
        'altura_imagem': alturaImagem,
        'ajuste_imagem': ajusteImagem.name,
      };

  ConteudoSlot copyWith({
    TipoConteudoSlot? tipo,
    String? campoVinculado,
    int? colunas,
    bool? mostrarDescricao,
    Quadro? quadroAninhado,
    List<RegraCondicional>? decoracaoCondicional,
    double? alturaImagem,
    AjusteImagem? ajusteImagem,
  }) {
    return ConteudoSlot(
      tipo: tipo ?? this.tipo,
      campoVinculado: campoVinculado ?? this.campoVinculado,
      colunas: colunas ?? this.colunas,
      mostrarDescricao: mostrarDescricao ?? this.mostrarDescricao,
      quadroAninhado: quadroAninhado ?? this.quadroAninhado,
      decoracaoCondicional: decoracaoCondicional ?? this.decoracaoCondicional,
      alturaImagem: alturaImagem ?? this.alturaImagem,
      ajusteImagem: ajusteImagem ?? this.ajusteImagem,
    );
  }
}

class DivisaoQuadro {
  final String id;
  final double larguraPercentual;
  final ConteudoSlot? conteudo;

  const DivisaoQuadro({required this.id, required this.larguraPercentual, this.conteudo});

  factory DivisaoQuadro.fromJson(Map<String, dynamic> json) {
    return DivisaoQuadro(
      id: json['id']?.toString() ?? gerarIdQuadro(),
      larguraPercentual: (json['largura_percentual'] as num?)?.toDouble() ?? 100.0,
      conteudo: json['conteudo'] != null ? ConteudoSlot.fromJson((json['conteudo'] as Map).cast<String, dynamic>()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'largura_percentual': larguraPercentual,
        'conteudo': conteudo?.toJson(),
      };

  DivisaoQuadro copyWith({double? larguraPercentual, ConteudoSlot? conteudo, bool removerConteudo = false}) {
    return DivisaoQuadro(
      id: id,
      larguraPercentual: larguraPercentual ?? this.larguraPercentual,
      conteudo: removerConteudo ? null : (conteudo ?? this.conteudo),
    );
  }
}

class LinhaQuadro {
  final String id;
  final List<DivisaoQuadro> divisoes;

  const LinhaQuadro({required this.id, required this.divisoes});

  factory LinhaQuadro.nova() =>
      LinhaQuadro(id: gerarIdQuadro(), divisoes: [DivisaoQuadro(id: gerarIdQuadro(), larguraPercentual: 100)]);

  factory LinhaQuadro.fromJson(Map<String, dynamic> json) {
    final divisoesJson = json['divisoes'] as List? ?? const [];
    return LinhaQuadro(
      id: json['id']?.toString() ?? gerarIdQuadro(),
      divisoes: divisoesJson.map((d) => DivisaoQuadro.fromJson((d as Map).cast<String, dynamic>())).toList(),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'divisoes': divisoes.map((d) => d.toJson()).toList()};

  bool get ehBloco => divisoes.length == 1 && divisoes.first.conteudo?.tipo.ehBloco == true;

  LinhaQuadro copyWith({List<DivisaoQuadro>? divisoes}) => LinhaQuadro(id: id, divisoes: divisoes ?? this.divisoes);

  // Reequilibra: 2 divisões somam 100 sempre; 3+ são normalizadas
  // proporcionalmente se a soma não fechar em 100 (nunca trava o usuário).
  LinhaQuadro normalizada() {
    if (divisoes.length < 2) return this;
    final soma = divisoes.fold<double>(0, (acc, d) => acc + d.larguraPercentual);
    if (soma <= 0) {
      final igual = 100.0 / divisoes.length;
      return copyWith(divisoes: divisoes.map((d) => d.copyWith(larguraPercentual: igual)).toList());
    }
    if ((soma - 100).abs() < 0.01) return this;
    return copyWith(
      divisoes: divisoes.map((d) => d.copyWith(larguraPercentual: d.larguraPercentual * 100 / soma)).toList(),
    );
  }
}

class Quadro {
  final List<LinhaQuadro> linhas;
  const Quadro({required this.linhas});

  factory Quadro.vazio() => const Quadro(linhas: []);

  factory Quadro.fromJson(Map<String, dynamic> json) {
    final linhasJson = json['linhas'] as List? ?? const [];
    return Quadro(linhas: linhasJson.map((l) => LinhaQuadro.fromJson((l as Map).cast<String, dynamic>())).toList());
  }

  Map<String, dynamic> toJson() => {'linhas': linhas.map((l) => l.toJson()).toList()};

  Quadro copyWith({List<LinhaQuadro>? linhas}) => Quadro(linhas: linhas ?? this.linhas);

  Quadro normalizado() => Quadro(linhas: linhas.map((l) => l.normalizada()).toList());
}
