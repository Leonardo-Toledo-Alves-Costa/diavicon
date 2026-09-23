import '../../ensaios/ensaio_chumbador/reports/modelo/chumbador_campos_catalogo.dart';
import '../../ensaios/ensaio_extracao_testemunho/reports/modelo/extracao_campos_catalogo.dart';
import '../../ensaios/ensaio_liquido_penetrante/reports/modelo/lp_campos_catalogo.dart';
import '../../ensaios/ensaio_monitoramento_fissura/reports/modelo/monitoramento_fissura_campos_catalogo.dart';
import '../../ensaios/ensaio_ultrassom/reports/modelo/ultrassom_campos_catalogo.dart';
import '../../ensaios/ensaios_arrancamento_argamassa/reports/modelo/arrancamento_campos_catalogo.dart';
import '../../ensaios/ensaios_arrancamento_ceramica/reports/modelo/arrancamento_ceramica_campos_catalogo.dart';
import '../../ensaios/ensaios_carbonatacao/reports/modelo/carbonatacao_campos_catalogo.dart';
import '../../ensaios/ensaios_esclerometria/reports/modelo/esclerometria_campos_catalogo.dart';
import '../../ensaios/ensaios_potencial_corrosao/reports/modelo/potencial_campos_catalogo.dart';
import '../../ensaios/ensaios_prova_carga/reports/modelo/prova_carga_campos_catalogo.dart';
import '../../ensaios/ensaios_resistividade/reports/modelo/resistividade_campos_catalogo.dart';
import 'quadro_model.dart';

// Generaliza o editor de modelos de relatório por tipo de ensaio: Cabeçalho,
// Informações iniciais, Referencial e a Decoração global não mudam entre
// ensaios (são conceitos de Projeto/Empresa/Estrutura/Local) — só "Registros"
// (individuais), "Registros agrupados" e a "Tabela geral" (Resumo) variam,
// porque dependem dos campos reais daquele ensaio.
class EnsaioModeloConfig {
  final List<CampoCatalogo> camposRegistro;
  final List<TipoConteudoSlot> tiposPermitidosRegistro;
  final String legendaRegistros;
  final bool suportaRegistrosAgrupados;
  // Catálogo/rótulo do bloco aninhado genérico (TipoConteudoSlot.subLista)
  // dentro de Registros — ex: "Pontos de leitura" da Resistividade. Vazio
  // pra ensaios que não usam esse mecanismo.
  final List<CampoCatalogo> camposSubListaRegistro;
  final String? rotuloSubListaRegistro;
  final List<CampoCatalogo> camposEstatisticasAgrupadas;
  // Catálogo dos gráficos-resumo fixos disponíveis pro Quadro de gráficos
  // de "Registros agrupados" (cada um é um campo do tipo imagem).
  final List<CampoCatalogo> camposGraficosAgrupados;
  // "GUT — Somatório de risco" (por Estrutura / por Local) — só faz sentido
  // pra Inspeção Visual, único ensaio com anomalias/GUT.
  final bool suportaGutSomatorio;
  // "Análise de Elementos" — uma linha por ELEMENTO estrutural (não por
  // ponto), com fck/Ed estimados; só faz sentido pra Ultrassonografia
  // (único ensaio com esse cálculo, ver UltrassomMath). Fica ANTES de
  // "Registros agrupados" no relatório.
  final bool suportaAnaliseElementos;
  final List<CampoCatalogo> camposAnaliseElementos;
  final List<TabelaResumo> tabelasResumo;
  // Catálogos de Referencial (ver `catalogosReferencial`) que fazem sentido
  // pra esse ensaio — evita o usuário configurar um catálogo cujos dados
  // nunca existem (ex: "Anomalias" não existe fora da Inspeção Visual;
  // Carbonatação não referencia as tabelas de Local/Sistema/Tipo de
  // elemento por FK, só campos de texto livre em `elementos_estruturais`).
  final List<String> catalogosReferencialPermitidos;
  // Dados de exemplo pra aba "Preview" do editor — evita que
  // ModeloRelatorioPreview precise conhecer os campos de cada ensaio.
  final Map<String, String> dadosExemploRegistro;
  final Map<String, String> dadosExemploAnaliseElemento;
  final Map<String, String> dadosExemploAgrupado;
  final List<Map<String, String>> dadosExemploSubLista;

  const EnsaioModeloConfig({
    required this.camposRegistro,
    required this.tiposPermitidosRegistro,
    required this.legendaRegistros,
    required this.suportaRegistrosAgrupados,
    this.camposSubListaRegistro = const [],
    this.rotuloSubListaRegistro,
    required this.camposEstatisticasAgrupadas,
    this.camposGraficosAgrupados = const [],
    this.suportaGutSomatorio = false,
    this.suportaAnaliseElementos = false,
    this.camposAnaliseElementos = const [],
    required this.tabelasResumo,
    required this.catalogosReferencialPermitidos,
    this.dadosExemploRegistro = const {},
    this.dadosExemploAnaliseElemento = const {},
    this.dadosExemploAgrupado = const {},
    this.dadosExemploSubLista = const [],
  });
}

// Chave = nome do tipo de ensaio (`tipos_ensaio.nome`), mesmo padrão já usado
// por `buscarIdTipoEnsaioProvider('Inspeção Visual')` em outros lugares do
// app. Cada novo compositor de relatório (Resistividade, Potencial de
// Corrosão...) só precisa adicionar uma entrada aqui.
final Map<String, EnsaioModeloConfig> ensaiosModeloConfig = {
  'Inspeção Visual': EnsaioModeloConfig(
    camposRegistro: camposRegistro,
    tiposPermitidosRegistro: const [
      TipoConteudoSlot.texto,
      TipoConteudoSlot.imagem,
      TipoConteudoSlot.galeria,
      TipoConteudoSlot.anomalias,
    ],
    legendaRegistros: 'Repete automaticamente por registro',
    suportaRegistrosAgrupados: false,
    camposEstatisticasAgrupadas: [],
    suportaGutSomatorio: true,
    tabelasResumo: tabelasResumo,
    catalogosReferencialPermitidos: catalogosReferencial.map((c) => c.chave).toList(),
    dadosExemploRegistro: const {
      'nome_registro': 'Registro 01',
      'descricao_registro': 'Fissura ativa observada na fachada norte.',
      'estrutura': 'Bloco A',
      'local': 'Térreo',
      'sistema': 'Sistema Estrutural',
      'tipo_elemento': 'Pilar',
      'elemento': 'P101',
    },
  ),
  'Carbonatação': EnsaioModeloConfig(
    camposRegistro: camposRegistroCarbonatacao,
    tiposPermitidosRegistro: const [TipoConteudoSlot.texto, TipoConteudoSlot.imagem, TipoConteudoSlot.galeria],
    legendaRegistros: 'Repete automaticamente por ponto de ensaio',
    suportaRegistrosAgrupados: true,
    camposEstatisticasAgrupadas: camposEstatisticasCarbonatacao,
    camposGraficosAgrupados: camposGraficosAgrupadosCarbonatacao,
    tabelasResumo: tabelasResumoCarbonatacao,
    // Só o que existe de verdade nos dados de Carbonatação: Estrutura é a
    // mesma tabela de sempre; Tipologia/Revestimento de elemento casam por
    // texto com `elementos_estruturais`. Local/Sistema/Tipos de elemento
    // (tabelas de catálogo) e Anomalias não têm nenhuma ligação com os
    // dados desse ensaio (ver comentário em EnsaioModeloConfig).
    catalogosReferencialPermitidos: const [
      'tipos_estrutura',
      'tipologias_estrutura',
      'utilizacoes_estrutura',
      'tipologias_elemento',
      'revestimentos_elemento',
    ],
    dadosExemploRegistro: const {
      'nome_elemento_carb': 'Pilar P101',
      'tipo_elemento_carb': 'Pilar',
      'local_elemento_carb': 'Térreo',
      'revestimento_elemento_carb': 'Pintura',
      'nome_ponto_carb': 'PT-01',
      'valor_resultado_carb': 'Risco Moderado',
      'cob_arm_p_carb': '25 mm',
      'cob_arm_s_carb': '20 mm',
      'bit_arm_p_carb': '10 mm',
      'bit_arm_s_carb': '8 mm',
      'media_frente_carb': '12,4 mm',
      'desvio_padrao_frente_carb': '1,8 mm',
      'cv_frente_carb': '14,5%',
      'coef_carbonatacao_carb': '3,2 mm/ano^0.5',
      'tempo_despassivacao_carb': '18 anos',
    },
    dadosExemploAgrupado: const {
      'local_grupo_carb': 'Térreo',
      'tipo_elemento_grupo_carb': 'Pilar',
      'media_cob_p_grupo_carb': '25 mm',
      'cv_cob_p_grupo_carb': '10%',
      'dp_cob_p_grupo_carb': '2,5 mm',
      'media_cob_s_grupo_carb': '20 mm',
      'cv_cob_s_grupo_carb': '12%',
      'dp_cob_s_grupo_carb': '2,4 mm',
      'media_frente_grupo_carb': '12,4 mm',
      'cv_frente_grupo_carb': '14,5%',
      'dp_frente_grupo_carb': '1,8 mm',
      'coef_carbonatacao_grupo_carb': '3,2 mm/ano^0.5',
      'tempo_despassivacao_grupo_carb': '18 anos',
      'risco_grupo_carb': 'Risco Moderado',
      'prob_20_grupo_carb': '12 anos',
      'prob_40_grupo_carb': '18 anos',
      'prob_60_grupo_carb': '25 anos',
      'prob_80_grupo_carb': '> 40 anos',
    },
  ),
  'Resistividade': EnsaioModeloConfig(
    camposRegistro: camposRegistroResistividade,
    tiposPermitidosRegistro: const [TipoConteudoSlot.texto, TipoConteudoSlot.imagem, TipoConteudoSlot.galeria, TipoConteudoSlot.subLista],
    legendaRegistros: 'Repete automaticamente por ponto de ensaio',
    camposSubListaRegistro: camposLeituraResistividade,
    rotuloSubListaRegistro: 'Pontos de leitura',
    suportaRegistrosAgrupados: true,
    camposEstatisticasAgrupadas: camposEstatisticasResistividade,
    camposGraficosAgrupados: camposGraficosAgrupadosResistividade,
    tabelasResumo: tabelasResumoResistividade,
    // Igual Carbonatação: Estrutura via FK; Tipologia/Revestimento de
    // elemento casam por texto com `elementos_estruturais`.
    catalogosReferencialPermitidos: const [
      'tipos_estrutura',
      'tipologias_estrutura',
      'utilizacoes_estrutura',
      'tipologias_elemento',
      'revestimentos_elemento',
    ],
    dadosExemploRegistro: const {
      'nome_elemento_resist': 'Pilar P101',
      'tipo_elemento_resist': 'Pilar',
      'local_elemento_resist': 'Térreo',
      'revestimento_elemento_resist': 'Pintura',
      'nome_ponto_resist': 'PT-01',
      'valor_resultado_resist': '42.3 KΩ.cm',
      'menor_resistividade_resist': '38.1 KΩ.cm',
      'maior_resistividade_resist': '47.6 KΩ.cm',
      'media_resistividade_resist': '42.3 KΩ.cm',
      'cv_resistividade_resist': '9.2%',
      'risco_corrosao_resist': 'Moderado',
      'taxa_corrosao_resist': 'Baixo',
      'permissividade_resist': 'Baixo',
    },
    dadosExemploSubLista: const [
      {'nome_leitura_resist': 'Ponto 1', 'menor_leitura_resist': '38.1 KΩ.cm'},
      {'nome_leitura_resist': 'Ponto 2', 'menor_leitura_resist': '41.5 KΩ.cm'},
    ],
    dadosExemploAgrupado: const {
      'local_grupo_resist': 'Térreo',
      'tipo_elemento_grupo_resist': 'Pilar',
      'media_resistividade_grupo_resist': '42.3 KΩ.cm',
      'cv_resistividade_grupo_resist': '9.2%',
      'maior_resistividade_grupo_resist': '47.6 KΩ.cm',
      'menor_resistividade_grupo_resist': '38.1 KΩ.cm',
      'risco_corrosao_grupo_resist': 'Moderado',
      'taxa_corrosao_grupo_resist': 'Baixo',
      'permissividade_grupo_resist': 'Baixo',
    },
  ),
  'Potencial': EnsaioModeloConfig(
    camposRegistro: camposRegistroPotencial,
    tiposPermitidosRegistro: const [TipoConteudoSlot.texto, TipoConteudoSlot.imagem, TipoConteudoSlot.galeria, TipoConteudoSlot.matriz],
    legendaRegistros: 'Repete automaticamente por ponto de ensaio',
    suportaRegistrosAgrupados: true,
    camposEstatisticasAgrupadas: camposEstatisticasPotencial,
    camposGraficosAgrupados: camposGraficosAgrupadosPotencial,
    tabelasResumo: tabelasResumoPotencial,
    // Igual Carbonatação/Resistividade: Estrutura via FK; Tipologia/
    // Revestimento de elemento casam por texto com `elementos_estruturais`.
    catalogosReferencialPermitidos: const [
      'tipos_estrutura',
      'tipologias_estrutura',
      'utilizacoes_estrutura',
      'tipologias_elemento',
      'revestimentos_elemento',
    ],
    dadosExemploRegistro: const {
      'nome_elemento_pot': 'Pilar P101',
      'tipo_elemento_pot': 'Pilar',
      'local_elemento_pot': 'Térreo',
      'revestimento_elemento_pot': 'Pintura',
      'nome_ponto_pot': 'PT-01',
      'valor_resultado_pot': '-320 mV',
      'eletrodo_pot': 'Sulfato de Cobre',
      'tempo_saturacao_pot': '5 min',
      'temperatura_pot': '25°C',
      'media_potencial_pot': '-320 mV',
      'cv_potencial_pot': '8.5%',
      'menor_potencial_pot': '-410 mV',
      'maior_potencial_pot': '-250 mV',
    },
    dadosExemploAgrupado: const {
      'local_grupo_pot': 'Térreo',
      'tipo_elemento_grupo_pot': 'Pilar',
      'eletrodo_grupo_pot': 'Sulfato de Cobre',
      'tempo_saturacao_grupo_pot': '5 min',
      'temperatura_grupo_pot': '25°C',
      'media_potencial_grupo_pot': '-320 mV',
      'cv_potencial_grupo_pot': '8.5%',
      'maior_potencial_grupo_pot': '-250 mV',
      'menor_potencial_grupo_pot': '-410 mV',
    },
  ),
  'Arrancamento em Argamassa': EnsaioModeloConfig(
    camposRegistro: camposRegistroArrancamento,
    tiposPermitidosRegistro: const [TipoConteudoSlot.texto, TipoConteudoSlot.imagem, TipoConteudoSlot.galeria, TipoConteudoSlot.subLista],
    legendaRegistros: 'Repete automaticamente por ponto de ensaio',
    camposSubListaRegistro: camposLeituraArrancamento,
    rotuloSubListaRegistro: 'Leituras',
    suportaRegistrosAgrupados: true,
    camposEstatisticasAgrupadas: camposEstatisticasArrancamento,
    camposGraficosAgrupados: camposGraficosAgrupadosArrancamento,
    tabelasResumo: tabelasResumoArrancamento,
    // Igual Carbonatação/Resistividade/Potencial: Estrutura via FK;
    // Tipologia/Revestimento de elemento casam por texto com `elementos_estruturais`.
    catalogosReferencialPermitidos: const [
      'tipos_estrutura',
      'tipologias_estrutura',
      'utilizacoes_estrutura',
      'tipologias_elemento',
      'revestimentos_elemento',
    ],
    dadosExemploRegistro: const {
      'nome_elemento_arr': 'Pilar P101',
      'tipo_elemento_arr': 'Pilar',
      'local_elemento_arr': 'Térreo',
      'revestimento_elemento_arr': 'Reboco',
      'nome_ponto_arr': 'PT-01',
      'valor_resultado_arr': '0.35 MPa',
      'temperatura_arr': '24°C',
      'umidade_arr': '60%',
      'idade_revestimento_arr': '90 dias',
      'cola_utilizada_arr': 'Epóxi',
      'tipo_substrato_arr': 'Concreto',
      'media_tensao_arr': '0.35 MPa',
      'maior_tensao_arr': '0.42 MPa',
      'menor_tensao_arr': '0.28 MPa',
      'cv_tensao_arr': '12.5%',
      'ruptura_tipos_arr': '65% Argamassa | 35% Substrato',
    },
    dadosExemploSubLista: const [
      {
        'nome_leitura_arr': 'P1',
        'd1_leitura_arr': '50.0 mm',
        'd2_leitura_arr': '50.2 mm',
        'diametro_medio_leitura_arr': '50.1 mm',
        'area_leitura_arr': '1971.4 mm²',
        'carga_leitura_arr': '0.69 KN',
        'tensao_leitura_arr': '0.35 MPa',
        'ruptura_leitura_arr': '70% Argamassa | 30% Substrato',
      },
      {
        'nome_leitura_arr': 'P2',
        'd1_leitura_arr': '50.0 mm',
        'd2_leitura_arr': '50.0 mm',
        'diametro_medio_leitura_arr': '50.0 mm',
        'area_leitura_arr': '1963.5 mm²',
        'carga_leitura_arr': '0.82 KN',
        'tensao_leitura_arr': '0.42 MPa',
        'ruptura_leitura_arr': '100% Substrato',
      },
    ],
    dadosExemploAgrupado: const {
      'local_grupo_arr': 'Térreo',
      'tipo_elemento_grupo_arr': 'Pilar',
      'temperatura_grupo_arr': '24°C',
      'umidade_grupo_arr': '60%',
      'idade_revestimento_grupo_arr': '90 dias',
      'cola_utilizada_grupo_arr': 'Epóxi',
      'tipo_substrato_grupo_arr': 'Concreto',
      'media_tensao_grupo_arr': '0.35 MPa',
      'cv_tensao_grupo_arr': '12.5%',
      'menor_tensao_grupo_arr': '0.28 MPa',
      'maior_tensao_grupo_arr': '0.42 MPa',
      'ruptura_predominante_grupo_arr': 'Substrato',
    },
  ),
  'Arrancamento em Placa Cerâmica': EnsaioModeloConfig(
    camposRegistro: camposRegistroArrancamentoCeramica,
    tiposPermitidosRegistro: const [TipoConteudoSlot.texto, TipoConteudoSlot.imagem, TipoConteudoSlot.galeria, TipoConteudoSlot.subLista],
    legendaRegistros: 'Repete automaticamente por ponto de ensaio',
    camposSubListaRegistro: camposLeituraArrancamentoCeramica,
    rotuloSubListaRegistro: 'Leituras',
    suportaRegistrosAgrupados: true,
    camposEstatisticasAgrupadas: camposEstatisticasArrancamentoCeramica,
    camposGraficosAgrupados: camposGraficosAgrupadosArrancamentoCeramica,
    tabelasResumo: tabelasResumoArrancamentoCeramica,
    catalogosReferencialPermitidos: const [
      'tipos_estrutura',
      'tipologias_estrutura',
      'utilizacoes_estrutura',
      'tipologias_elemento',
      'revestimentos_elemento',
    ],
    dadosExemploRegistro: const {
      'nome_elemento_cer': 'Fachada F01',
      'tipo_elemento_cer': 'Fachada',
      'local_elemento_cer': 'Térreo',
      'revestimento_elemento_cer': 'Placa cerâmica',
      'nome_ponto_cer': 'PT-01',
      'valor_resultado_cer': '0.30 MPa',
      'temperatura_cer': '24°C',
      'umidade_cer': '60%',
      'idade_revestimento_cer': '180 dias',
      'cola_utilizada_cer': 'Argamassa colante AC-III',
      'media_tensao_cer': '0.30 MPa',
      'maior_tensao_cer': '0.36 MPa',
      'menor_tensao_cer': '0.24 MPa',
      'cv_tensao_cer': '11.0%',
      'ruptura_tipos_cer': '80% Cerâmica | 20% Argamassa',
    },
    dadosExemploSubLista: const [
      {
        'nome_leitura_cer': 'P1',
        'area_leitura_cer': '2500.0 mm²',
        'carga_leitura_cer': '0.75 KN',
        'tensao_leitura_cer': '0.30 MPa',
        'ruptura_leitura_cer': '60% Cerâmica | 40% Argamassa',
      },
      {
        'nome_leitura_cer': 'P2',
        'area_leitura_cer': '2500.0 mm²',
        'carga_leitura_cer': '0.90 KN',
        'tensao_leitura_cer': '0.36 MPa',
        'ruptura_leitura_cer': '100% Cerâmica',
      },
    ],
    dadosExemploAgrupado: const {
      'local_grupo_cer': 'Térreo',
      'tipo_elemento_grupo_cer': 'Fachada',
      'temperatura_grupo_cer': '24°C',
      'umidade_grupo_cer': '60%',
      'idade_revestimento_grupo_cer': '180 dias',
      'cola_utilizada_grupo_cer': 'Argamassa colante AC-III',
      'media_tensao_grupo_cer': '0.30 MPa',
      'cv_tensao_grupo_cer': '11.0%',
      'menor_tensao_grupo_cer': '0.24 MPa',
      'maior_tensao_grupo_cer': '0.36 MPa',
      'ruptura_predominante_grupo_cer': 'Cerâmica',
    },
  ),
  'Prova de Carga Estática': EnsaioModeloConfig(
    camposRegistro: camposRegistroProvaCarga,
    tiposPermitidosRegistro: const [TipoConteudoSlot.texto, TipoConteudoSlot.imagem, TipoConteudoSlot.galeria, TipoConteudoSlot.subLista],
    legendaRegistros: 'Repete automaticamente por ponto de ensaio',
    camposSubListaRegistro: camposPontoMedicaoProvaCarga,
    rotuloSubListaRegistro: 'Pontos de medição',
    // Este ensaio não suporta Registros agrupados (pedido explícito do
    // usuário) — os valores calculados só fazem sentido por ponto de
    // medição, não por grupo de Local/Tipo de elemento.
    suportaRegistrosAgrupados: false,
    camposEstatisticasAgrupadas: const [],
    tabelasResumo: tabelasResumoProvaCarga,
    // Elemento estrutural é OPCIONAL nesse ensaio (ver
    // `ProvaCargaModeloReportData`) — mesmos catálogos de referencial que
    // fazem sentido quando o elemento existe.
    catalogosReferencialPermitidos: const [
      'tipos_estrutura',
      'tipologias_estrutura',
      'utilizacoes_estrutura',
      'tipologias_elemento',
      'revestimentos_elemento',
    ],
    dadosExemploRegistro: const {
      'nome_elemento_pc': 'Laje L01',
      'tipo_elemento_pc': 'Laje',
      'local_elemento_pc': 'Térreo',
      'revestimento_elemento_pc': 'Concreto aparente',
      'nome_ponto_pc': 'PT-01',
      'valor_resultado_pc': 'Concluído',
      'carga_total_pc': '5000 kg',
      'carregamento_pc': '500 kg/m²',
      'etapa_carregamento_pc': '5 etapas',
      'etapa_descarregamento_pc': '3 etapas',
    },
    dadosExemploSubLista: const [
      {
        'nome_ponto_medicao_pc': 'Ponto de Medição 1',
        'desloc_max_pc': '10 mm',
        'descricao_pc': 'Centro do vão',
        'tipo_elemento_medicao_pc': 'Laje',
        'condicao_pc': 'Dentro do limite',
        'residual_maximo_pc': '1 mm',
        'duracao_total_pc': '2h30min',
      },
      {
        'nome_ponto_medicao_pc': 'Ponto de Medição 2',
        'desloc_max_pc': '10 mm',
        'descricao_pc': 'Apoio',
        'tipo_elemento_medicao_pc': 'Laje',
        'condicao_pc': 'Excedido',
        'residual_maximo_pc': '3 mm',
        'duracao_total_pc': '2h30min',
      },
    ],
  ),
  'Esclerometria': EnsaioModeloConfig(
    camposRegistro: camposRegistroEsclerometria,
    // Sem sub-lista: a tabela de leituras é um campo Matriz único (todo o
    // dado de leitura é escalar, sem imagem por leitura) — ver comentário
    // em `esclerometria_campos_catalogo.dart`.
    tiposPermitidosRegistro: const [TipoConteudoSlot.texto, TipoConteudoSlot.imagem, TipoConteudoSlot.galeria, TipoConteudoSlot.matriz],
    legendaRegistros: 'Repete automaticamente por ponto de ensaio',
    suportaRegistrosAgrupados: true,
    camposEstatisticasAgrupadas: camposEstatisticasEsclerometria,
    camposGraficosAgrupados: camposGraficosAgrupadosEsclerometria,
    tabelasResumo: tabelasResumoEsclerometria,
    catalogosReferencialPermitidos: const [
      'tipos_estrutura',
      'tipologias_estrutura',
      'utilizacoes_estrutura',
      'tipologias_elemento',
      'revestimentos_elemento',
    ],
    dadosExemploRegistro: const {
      'nome_elemento_esc': 'Pilar P101',
      'tipo_elemento_esc': 'Pilar',
      'local_elemento_esc': 'Térreo',
      'revestimento_elemento_esc': 'Concreto aparente',
      'nome_ponto_esc': 'PT-01',
      'valor_resultado_esc': '38.5',
      'inclinacao_esc': '0°',
      'direcao_impacto_esc': 'Horizontal',
      'indice_k_esc': '1',
      'correcao_inclinacao_esc': '0',
      'media_valor_q_esc': '38.5',
      'leituras_validas_esc': '8',
      'cv_esc': '6.2%',
    },
    dadosExemploAgrupado: const {
      'local_grupo_esc': 'Térreo',
      'tipo_elemento_grupo_esc': 'Pilar',
      'indice_k_grupo_esc': '1',
      'correcao_inclinacao_grupo_esc': '0',
      'direcao_impacto_grupo_esc': 'Horizontal',
      'media_valor_q_grupo_esc': '38.5',
      'leituras_aprovadas_grupo_esc': '24',
      'cv_grupo_esc': '6.2%',
    },
  ),
  'Ultrassonografia': EnsaioModeloConfig(
    camposRegistro: camposRegistroUltrassom,
    tiposPermitidosRegistro: const [
      TipoConteudoSlot.texto,
      TipoConteudoSlot.imagem,
      TipoConteudoSlot.galeria,
      TipoConteudoSlot.matriz,
      TipoConteudoSlot.subLista,
    ],
    legendaRegistros: 'Repete automaticamente por ponto de ensaio (Direto, Indireto ou Mapeamento)',
    camposSubListaRegistro: camposMedicaoUltrassom,
    rotuloSubListaRegistro: 'Pontos de medição (Direto/Indireto)',
    suportaRegistrosAgrupados: true,
    camposEstatisticasAgrupadas: camposEstatisticasUltrassom,
    camposGraficosAgrupados: camposGraficosAgrupadosUltrassom,
    suportaAnaliseElementos: true,
    camposAnaliseElementos: camposAnaliseElementoUltrassom,
    tabelasResumo: tabelasResumoUltrassom,
    catalogosReferencialPermitidos: const [
      'tipos_estrutura',
      'tipologias_estrutura',
      'utilizacoes_estrutura',
      'tipologias_elemento',
      'revestimentos_elemento',
    ],
    dadosExemploRegistro: const {
      'nome_elemento_us': 'Pilar P101',
      'tipo_elemento_us': 'Pilar',
      'local_elemento_us': 'Térreo',
      'revestimento_elemento_us': 'Concreto aparente',
      'alfa_e_us': '1.00',
      'densidade_us': '2400',
      'nome_ponto_us': 'PT-01',
      'modo_us': 'Direto',
      'pulso_us': 'Longitudinal',
      'valor_resultado_us': '4323 m/s',
      'media_velocidade_us': '4323 m/s',
      'cv_us': '6.2%',
      'classificacao_us': 'Excelente',
    },
    dadosExemploSubLista: const [
      {'nome_ponto_medicao_us': 'Ponto 1', 'distancia_medicao_us': '20 cm', 'velocidade_medicao_us': '4323 m/s', 'classificacao_medicao_us': 'Excelente'},
      {'nome_ponto_medicao_us': 'Ponto 2', 'distancia_medicao_us': '25 cm', 'velocidade_medicao_us': '4180 m/s', 'classificacao_medicao_us': 'Excelente'},
    ],
    dadosExemploAnaliseElemento: const {
      'nome_elemento_analise_us': 'Pilar P101',
      'tipo_elemento_analise_us': 'Pilar',
      'local_elemento_analise_us': 'Térreo',
      'alfa_e_analise_us': '1.00',
      'densidade_analise_us': '2400',
      'velocidade_longitudinal_analise_us': '4323 m/s',
      'velocidade_transversal_analise_us': '2052 m/s',
      'poisson_analise_us': '0.22',
      'modulo_elasticidade_analise_us': '27.9 GPa',
      'fck_analise_us': '24.8 MPa',
    },
    dadosExemploAgrupado: const {
      'local_grupo_us': 'Térreo',
      'tipo_elemento_grupo_us': 'Pilar',
      'media_longitudinal_grupo_us': '4323 m/s',
      'cv_longitudinal_grupo_us': '6.2%',
      'classificacao_longitudinal_grupo_us': 'Excelente',
      'media_transversal_grupo_us': '2052 m/s',
      'cv_transversal_grupo_us': '5.8%',
    },
  ),
  'Monitoramento de Fissuras': EnsaioModeloConfig(
    camposRegistro: camposRegistroMonitoramentoFissura,
    tiposPermitidosRegistro: const [TipoConteudoSlot.texto, TipoConteudoSlot.imagem, TipoConteudoSlot.galeria, TipoConteudoSlot.subLista],
    legendaRegistros: 'Repete automaticamente por ponto de ensaio',
    camposSubListaRegistro: camposLeituraMonitoramentoFissura,
    rotuloSubListaRegistro: 'Leituras',
    // "Registros agrupados" só traz contagem por status (ver comentário em
    // `monitoramento_fissura_campos_catalogo.dart`) — sem gráficos-resumo,
    // já que os valores de deslocamento (X/Y) de fissuras diferentes não são
    // comparáveis entre si.
    suportaRegistrosAgrupados: true,
    camposEstatisticasAgrupadas: camposEstatisticasMonitoramentoFissura,
    tabelasResumo: tabelasResumoMonitoramentoFissura,
    catalogosReferencialPermitidos: const [
      'tipos_estrutura',
      'tipologias_estrutura',
      'utilizacoes_estrutura',
      'tipologias_elemento',
      'revestimentos_elemento',
    ],
    dadosExemploRegistro: const {
      'nome_elemento_mf': 'Viga V101',
      'tipo_elemento_mf': 'Viga',
      'local_elemento_mf': 'Térreo',
      'revestimento_elemento_mf': 'Concreto aparente',
      'nome_ponto_mf': 'PT-01',
      'data_instalacao_mf': '10/01/2026',
      'tipo_selo_mf': 'Selo de Gesso',
      'temperatura_instalacao_mf': '24°C',
      'umidade_instalacao_mf': '60%',
      'status_atual_mf': 'Leve',
    },
    dadosExemploSubLista: const [
      {
        'data_hora_leitura_mf': '10/01/2026 09:00',
        'temperatura_leitura_mf': '24°C',
        'umidade_leitura_mf': '60%',
        'medida_x_leitura_mf': '0.00 mm',
        'medida_y_leitura_mf': '0.00 mm',
        'status_leitura_mf': 'Estável',
      },
      {
        'data_hora_leitura_mf': '17/01/2026 09:00',
        'temperatura_leitura_mf': '26°C',
        'umidade_leitura_mf': '55%',
        'medida_x_leitura_mf': '0.15 mm',
        'medida_y_leitura_mf': '0.05 mm',
        'status_leitura_mf': 'Leve',
      },
    ],
    dadosExemploAgrupado: const {
      'local_grupo_mf': 'Térreo',
      'tipo_elemento_grupo_mf': 'Viga',
      'total_pontos_grupo_mf': '4',
      'estaveis_grupo_mf': '2',
      'leves_grupo_mf': '1',
      'alertas_grupo_mf': '1',
      'rompidos_grupo_mf': '0',
    },
  ),
  'Tração em elemento chumbado': EnsaioModeloConfig(
    camposRegistro: camposRegistroChumbador,
    tiposPermitidosRegistro: const [TipoConteudoSlot.texto, TipoConteudoSlot.imagem, TipoConteudoSlot.galeria, TipoConteudoSlot.subLista],
    legendaRegistros: 'Repete automaticamente por ponto de ensaio (1 chumbador testado)',
    camposSubListaRegistro: camposLeituraChumbador,
    rotuloSubListaRegistro: 'Leituras',
    suportaRegistrosAgrupados: true,
    camposEstatisticasAgrupadas: camposEstatisticasChumbador,
    camposGraficosAgrupados: camposGraficosAgrupadosChumbador,
    tabelasResumo: tabelasResumoChumbador,
    catalogosReferencialPermitidos: const [
      'tipos_estrutura',
      'tipologias_estrutura',
      'utilizacoes_estrutura',
      'tipologias_elemento',
      'revestimentos_elemento',
    ],
    dadosExemploRegistro: const {
      'nome_elemento_ch': 'Chumbador CH-01',
      'tipo_elemento_ch': 'Fixação',
      'local_elemento_ch': 'Fachada',
      'revestimento_elemento_ch': 'Concreto aparente',
      'nome_ponto_ch': 'PT-01',
      'ocorrencias_gerais_ch': 'Fixação em concreto C30, sem fissuras aparentes antes do ensaio',
      'carga_maxima_ch': '92,4 kN',
      'deslocamento_maximo_ch': '2,3 mm',
      'condicao_avaliacao_ch': 'Aprovado',
    },
    dadosExemploSubLista: const [
      {'etapa_leitura_ch': 'Carregamento', 'forca_leitura_ch': '45,0 kN', 'deslocamento_leitura_ch': '1,0 mm', 'ocorrencia_leitura_ch': 'Sem ocorrências'},
      {'etapa_leitura_ch': 'Carregamento', 'forca_leitura_ch': '92,4 kN', 'deslocamento_leitura_ch': '2,3 mm', 'ocorrencia_leitura_ch': 'Carga máxima atingida, leve ruído no chumbador'},
    ],
    dadosExemploAgrupado: const {
      'local_grupo_ch': 'Fachada',
      'tipo_elemento_grupo_ch': 'Fixação',
      'total_pontos_grupo_ch': '4',
      'media_carga_grupo_ch': '88,2 kN',
      'cv_carga_grupo_ch': '9,5%',
      'maior_carga_grupo_ch': '95,1 kN',
      'menor_carga_grupo_ch': '80,4 kN',
      'aprovados_grupo_ch': '3',
      'reprovados_grupo_ch': '0',
      'cabe_analise_grupo_ch': '1',
    },
  ),
  'Extração e rompimento de testemunhos': EnsaioModeloConfig(
    camposRegistro: camposRegistroExtracao,
    tiposPermitidosRegistro: const [TipoConteudoSlot.texto, TipoConteudoSlot.imagem, TipoConteudoSlot.galeria, TipoConteudoSlot.subLista],
    // Diferente dos demais ensaios: cada Registro aqui é 1 LOCAL, não 1
    // elemento — os pontos de extração (cada um com seu próprio elemento)
    // repetem como sub-lista.
    legendaRegistros: 'Repete automaticamente por Local ensaiado',
    camposSubListaRegistro: camposLeituraExtracao,
    rotuloSubListaRegistro: 'Pontos de extração e rompimento',
    suportaRegistrosAgrupados: true,
    camposEstatisticasAgrupadas: camposEstatisticasExtracao,
    camposGraficosAgrupados: camposGraficosAgrupadosExtracao,
    tabelasResumo: tabelasResumoExtracao,
    // Sem "revestimentos_elemento": este ensaio não captura revestimento
    // por testemunho (só nome/tipo do elemento vinculado).
    catalogosReferencialPermitidos: const [
      'tipos_estrutura',
      'tipologias_estrutura',
      'utilizacoes_estrutura',
      'tipologias_elemento',
    ],
    dadosExemploRegistro: const {
      'nome_local_ext': 'Extração — Garagem',
      'local_ext': 'Garagem — Subsolo 1',
      'total_pontos_ext': '3',
    },
    dadosExemploSubLista: const [
      {
        'nome_testemunho_ext': 'P1',
        'elemento_leitura_ext': 'Pilar P04',
        'tipo_elemento_leitura_ext': 'Pilar',
        'direcao_leitura_ext': 'Perpendicular',
        'relacao_hd_leitura_ext': '2.00',
        'diametro_leitura_ext': '100 mm',
        'umidade_leitura_ext': 'Seco ao ar',
        'resistencia_sem_correcao_leitura_ext': '28,0 MPa',
        'resistencia_corrigida_leitura_ext': '31,2 MPa',
      },
      {
        'nome_testemunho_ext': 'P2',
        'elemento_leitura_ext': 'Laje L02',
        'tipo_elemento_leitura_ext': 'Laje',
        'direcao_leitura_ext': 'Paralelo',
        'relacao_hd_leitura_ext': '1.75',
        'diametro_leitura_ext': '75 mm',
        'umidade_leitura_ext': 'Saturado',
        'resistencia_sem_correcao_leitura_ext': '26,5 MPa',
        'resistencia_corrigida_leitura_ext': '27,8 MPa',
      },
    ],
    dadosExemploAgrupado: const {
      'local_grupo_ext': 'Garagem — Subsolo 1',
      'tipo_elemento_grupo_ext': 'Pilar',
      'total_pontos_grupo_ext': '3',
      'media_resistencia_grupo_ext': '30,1 MPa',
      'cv_resistencia_grupo_ext': '8,4%',
      'maior_resistencia_grupo_ext': '34,5 MPa',
      'menor_resistencia_grupo_ext': '27,8 MPa',
      'fck_grupo_ext': '25,7 MPa',
    },
  ),
  'Líquido penetrante': EnsaioModeloConfig(
    camposRegistro: camposRegistroLP,
    tiposPermitidosRegistro: const [TipoConteudoSlot.texto, TipoConteudoSlot.imagem, TipoConteudoSlot.galeria, TipoConteudoSlot.subLista],
    // Cada Registro é 1 ELEMENTO metálico ensaiado; os pontos de LP
    // (cordões/juntas) repetem como sub-lista dentro dele.
    legendaRegistros: 'Repete automaticamente por elemento ensaiado',
    camposSubListaRegistro: camposPontoLP,
    rotuloSubListaRegistro: 'Pontos de LP',
    suportaRegistrosAgrupados: true,
    camposEstatisticasAgrupadas: camposEstatisticasLP,
    camposGraficosAgrupados: camposGraficosAgrupadosLP,
    tabelasResumo: tabelasResumoLP,
    catalogosReferencialPermitidos: const ['tipos_estrutura', 'tipologias_estrutura', 'utilizacoes_estrutura'],
    dadosExemploRegistro: const {
      'nome_elemento_lp': 'Viga V07',
      'tipo_elemento_lp': 'Viga metálica',
      'local_elemento_lp': 'Cobertura',
      'nome_ensaio_lp': 'LP - Viga V07',
      'total_pontos_lp': '3',
      'aprovados_lp': '1',
      'reprovados_lp': '1',
      'cabe_analise_lp': '1',
      'resultado_lp': '1 aprov. · 1 reprov. · 1 análise',
    },
    dadosExemploSubLista: const [
      {'nome_ponto_lp': 'Cordão C-01', 'status_ponto_lp': 'Aprovado', 'tamanho_ponto_lp': '15 cm', 'tempo_ponto_lp': '15 min', 'descricao_ponto_lp': 'Sem indicações relevantes'},
      {'nome_ponto_lp': 'Cordão C-02', 'status_ponto_lp': 'Reprovado', 'tamanho_ponto_lp': '22 cm', 'tempo_ponto_lp': '15 min', 'descricao_ponto_lp': 'Indicação linear de 8 mm'},
    ],
    dadosExemploAgrupado: const {
      'local_grupo_lp': 'Cobertura',
      'tipo_elemento_grupo_lp': 'Viga metálica',
      'total_elementos_grupo_lp': '4',
      'total_pontos_grupo_lp': '12',
      'aprovados_grupo_lp': '9',
      'reprovados_grupo_lp': '2',
      'cabe_analise_grupo_lp': '1',
    },
  ),
};

// Resolve o config pelo NOME do tipo de ensaio usando correspondência por
// substring (case-insensitive) em vez de igualdade exata — mesmo padrão já
// usado em `ensaios_routes_map.dart` (`tipo.contains('carbonatação')`),
// porque o nome cadastrado em `tipos_ensaio.nome` pode variar (ex: "Frente
// de Carbonatação" em vez de só "Carbonatação"). Usar isso em vez de indexar
// `ensaiosModeloConfig` direto pelo nome exato.
EnsaioModeloConfig? resolverEnsaioModeloConfig(String tipoEnsaioNome) {
  final nome = tipoEnsaioNome.toLowerCase();
  if (nome.contains('inspeção visual') || nome.contains('inspecao visual')) {
    return ensaiosModeloConfig['Inspeção Visual'];
  }
  if (nome.contains('carbonatação') || nome.contains('carbonatacao')) {
    return ensaiosModeloConfig['Carbonatação'];
  }
  if (nome.contains('resistividade')) {
    return ensaiosModeloConfig['Resistividade'];
  }
  if (nome.contains('potencial')) {
    return ensaiosModeloConfig['Potencial'];
  }
  if (nome.contains('arrancamento em argamassa')) {
    return ensaiosModeloConfig['Arrancamento em Argamassa'];
  }
  if (nome.contains('arrancamento em placa cerâmica') || nome.contains('arrancamento em placa ceramica')) {
    return ensaiosModeloConfig['Arrancamento em Placa Cerâmica'];
  }
  if (nome.contains('prova de carga')) {
    return ensaiosModeloConfig['Prova de Carga Estática'];
  }
  if (nome.contains('esclerometria')) {
    return ensaiosModeloConfig['Esclerometria'];
  }
  if (nome.contains('ultrassom') || nome.contains('ultrasson')) {
    return ensaiosModeloConfig['Ultrassonografia'];
  }
  if (nome.contains('monitoramento') && nome.contains('fissura')) {
    return ensaiosModeloConfig['Monitoramento de Fissuras'];
  }
  if (nome.contains('chumbad')) {
    return ensaiosModeloConfig['Tração em elemento chumbado'];
  }
  if (nome.contains('testemunho')) {
    return ensaiosModeloConfig['Extração e rompimento de testemunhos'];
  }
  if (nome.contains('penetrante')) {
    return ensaiosModeloConfig['Líquido penetrante'];
  }
  return null;
}
