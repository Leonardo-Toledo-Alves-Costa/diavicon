/// Um item selecionável de filtro (id real do banco + nome pra mostrar).
class BiOpcaoFiltro {
  final String id;
  final String nome;
  const BiOpcaoFiltro(this.id, this.nome);
}

/// Opções disponíveis pra cada dimensão de filtro, já calculadas pro
/// contexto atual do dashboard — cada nível de aplicação usa só um
/// subconjunto (ver `DashboardBiRepository.buscarOpcoesFiltro` e o pedido
/// original: estrutura monitorada filtra Projeto/Local/Sistema/Tipo;
/// projeto filtra Conjunto/Estrutura/Local/Sistema/Tipo; estrutura filtra
/// só Local/Sistema/Tipo pelo que existe nela; elemento não filtra nada).
class BiOpcoesFiltro {
  final List<BiOpcaoFiltro> projetos;
  final List<BiOpcaoFiltro> conjuntosEstruturais;
  final List<BiOpcaoFiltro> estruturas;
  final List<String> locais;
  final List<String> tiposElemento;
  final List<BiOpcaoFiltro> sistemas;

  const BiOpcoesFiltro({
    this.projetos = const [],
    this.conjuntosEstruturais = const [],
    this.estruturas = const [],
    this.locais = const [],
    this.tiposElemento = const [],
    this.sistemas = const [],
  });

  bool get semFiltros => projetos.isEmpty && conjuntosEstruturais.isEmpty && estruturas.isEmpty && locais.isEmpty && tiposElemento.isEmpty && sistemas.isEmpty;
}

/// Seleção atual do usuário em cada dimensão — múltipla escolha, lista
/// vazia = sem filtro naquela dimensão.
class BiFiltrosSelecionados {
  final List<String> projetos;
  final List<String> conjuntosEstruturais;
  final List<String> estruturas;
  final List<String> locais;
  final List<String> tiposElemento;
  final List<String> sistemas;

  const BiFiltrosSelecionados({
    this.projetos = const [],
    this.conjuntosEstruturais = const [],
    this.estruturas = const [],
    this.locais = const [],
    this.tiposElemento = const [],
    this.sistemas = const [],
  });

  bool get algumFiltroAtivo => projetos.isNotEmpty || conjuntosEstruturais.isNotEmpty || estruturas.isNotEmpty || locais.isNotEmpty || tiposElemento.isNotEmpty || sistemas.isNotEmpty;

  BiFiltrosSelecionados copyWith({
    List<String>? projetos,
    List<String>? conjuntosEstruturais,
    List<String>? estruturas,
    List<String>? locais,
    List<String>? tiposElemento,
    List<String>? sistemas,
  }) {
    return BiFiltrosSelecionados(
      projetos: projetos ?? this.projetos,
      conjuntosEstruturais: conjuntosEstruturais ?? this.conjuntosEstruturais,
      estruturas: estruturas ?? this.estruturas,
      locais: locais ?? this.locais,
      tiposElemento: tiposElemento ?? this.tiposElemento,
      sistemas: sistemas ?? this.sistemas,
    );
  }
}
