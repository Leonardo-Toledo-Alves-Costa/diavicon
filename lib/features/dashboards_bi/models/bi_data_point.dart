/// Uma linha de dado já achatada, agnóstica de ensaio — todo "fetcher" de
/// campo (ver `campos_bi_catalogo.dart`) converte seus dados brutos pra essa
/// forma, e o motor de agregação/gráfico (ver `bi_chart_engine.dart`) só
/// enxerga isso daqui pra frente. Isola a heterogeneidade real de cada
/// ensaio (tabelas/joins/fórmulas bem diferentes entre si) da parte
/// genérica (agrupar, agregar, desenhar).
class BiDataPoint {
  final String elementoId;
  final String elementoNome;
  final String tipoElemento;
  final String local;
  // Nome da estrutura do elemento. Só varia num dashboard de PROJETO (que
  // reúne várias estruturas) — é o que permite agrupar por estrutura lá.
  final String estrutura;
  // Campo numérico bruto OU já resolvido como a estatística pedida (média/
  // desvio/CV) — quem resolve isso é o fetcher, não o motor de gráfico.
  final double? valor;
  // Campo categórico (ex: status, classificação, condição de clima).
  final String? categoria;
  // Só usado nas fontes com eixo temporal nativo (RDO, Monitoramento de
  // Fissuras) — permite gráfico de linha/barra ao longo do tempo.
  final DateTime? data;

  const BiDataPoint({
    required this.elementoId,
    required this.elementoNome,
    required this.tipoElemento,
    required this.local,
    this.estrutura = '',
    this.valor,
    this.categoria,
    this.data,
  });
}

/// Contexto de busca — o nível de aplicação do dashboard decide quais desses
/// campos vêm preenchidos (ver `NivelAplicacaoBi`), e quais filtros fazem
/// sentido (ver `bi_filtros_model.dart`). Toda lista de filtro vazia = sem
/// filtro nessa dimensão; não-vazia = múltipla seleção, "OU" entre os itens.
class BiContexto {
  final String empresaId;
  final String? projetoId;
  final String? estruturaId;
  final String? elementoId;

  final List<String> filtroLocal;
  final List<String> filtroTipoElemento;
  final List<String> filtroSistema;
  // Só usado no nível estrutura_multi_projeto — dentre os N projetos ligados
  // à estrutura, restringe a estes.
  final List<String> filtroProjeto;
  // Só usados no nível projeto — restringe a quais estruturas do projeto
  // (diretamente, ou por conjunto estrutural).
  final List<String> filtroConjuntoEstrutural;
  final List<String> filtroEstrutura;

  const BiContexto({
    required this.empresaId,
    this.projetoId,
    this.estruturaId,
    this.elementoId,
    this.filtroLocal = const [],
    this.filtroTipoElemento = const [],
    this.filtroSistema = const [],
    this.filtroProjeto = const [],
    this.filtroConjuntoEstrutural = const [],
    this.filtroEstrutura = const [],
  });
}
