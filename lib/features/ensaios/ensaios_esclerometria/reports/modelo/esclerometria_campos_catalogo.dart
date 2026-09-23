import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart'
    show chaveGraficoBarraPontosEsclerometria, chaveGraficoBoxplotElemento, chaveGraficoBoxplotLocal;
import '../../../../modelos_relatorios/models/quadro_model.dart';

// Catálogos de campos do compositor de relatório de Esclerometria — mesmo
// padrão dos demais ensaios, com os campos reais desse ensaio
// (pontos_ensaios_geral, ponto_ensaio_esclerometria,
// ponto_ensaio_esclerometria_leituras). A tabela de leituras
// (Leitura/Valor Q/Desvio %/Condição) não vira sub-lista — como todo campo
// dela é escalar (sem imagem por leitura), cabe inteira numa única Matriz
// (TipoConteudoSlot.matriz), sem precisar do mecanismo de bloco repetido.
const List<CampoCatalogo> camposRegistroEsclerometria = [
  CampoCatalogo('nome_elemento_esc', 'Nome do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_esc', 'Tipo do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('local_elemento_esc', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('revestimento_elemento_esc', 'Revestimento', TipoCampoCatalogo.texto),
  CampoCatalogo('marcacao_elemento_esc', 'Marcação do elemento em planta', TipoCampoCatalogo.imagem),
  CampoCatalogo('nome_ponto_esc', 'Nome do ponto', TipoCampoCatalogo.texto),
  CampoCatalogo('valor_resultado_esc', 'Resultado', TipoCampoCatalogo.texto),
  CampoCatalogo('imagem_marcacao_area_esc', 'Marcação da área (foto janela)', TipoCampoCatalogo.imagem),
  CampoCatalogo('imagem_realizacao_ensaio_esc', 'Realização do ensaio (foto ensaio)', TipoCampoCatalogo.imagem),
  CampoCatalogo('inclinacao_esc', 'Inclinação do impacto', TipoCampoCatalogo.texto),
  CampoCatalogo('direcao_impacto_esc', 'Direção do impacto', TipoCampoCatalogo.texto),
  CampoCatalogo('indice_k_esc', 'k (índice K)', TipoCampoCatalogo.texto),
  CampoCatalogo('correcao_inclinacao_esc', 'Correção de inclinação', TipoCampoCatalogo.texto),
  CampoCatalogo('media_valor_q_esc', 'Média Valor Q', TipoCampoCatalogo.texto),
  CampoCatalogo('leituras_validas_esc', 'Leituras válidas', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_esc', 'Coeficiente de variação', TipoCampoCatalogo.texto),
  CampoCatalogo('grafico_barras_leituras_esc', 'Gráfico de barras (índice esclerométrico por leitura)', TipoCampoCatalogo.imagem),
  CampoCatalogo('tabela_leituras_esc', 'Tabela de leituras (Leitura/Valor Q/Desvio %/Condição)', TipoCampoCatalogo.matriz),
  CampoCatalogo('boxplot_distribuicao_esc', 'Boxplot da distribuição de leituras', TipoCampoCatalogo.imagem),
];

// "Registros agrupados": colunas estatísticas disponíveis pra tabela por
// grupo (Local, Tipo de elemento, ou os dois) — pooling das leituras
// válidas de todos os pontos do grupo, mesmo padrão dos demais ensaios.
const List<CampoCatalogo> camposEstatisticasEsclerometria = [
  CampoCatalogo('local_grupo_esc', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_grupo_esc', 'Tipo de elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('indice_k_grupo_esc', 'k (índice K)', TipoCampoCatalogo.texto),
  CampoCatalogo('correcao_inclinacao_grupo_esc', 'Correção de inclinação', TipoCampoCatalogo.texto),
  CampoCatalogo('direcao_impacto_grupo_esc', 'Direção do impacto', TipoCampoCatalogo.texto),
  CampoCatalogo('media_valor_q_grupo_esc', 'Média do ponto', TipoCampoCatalogo.texto),
  CampoCatalogo('leituras_aprovadas_grupo_esc', 'Quantidade de leituras aprovadas', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_grupo_esc', 'Coeficiente de variação', TipoCampoCatalogo.texto),
];

// Gráficos-resumo disponíveis pra "Registros agrupados". A barra por ponto
// de ensaio NÃO segue a hierarquia (sempre um ponto por barra, igual à tela
// de análise global já existente); os boxplots reaproveitam as chaves
// genéricas já usadas por Carbonatação/Resistividade/Potencial (agrupam
// pela hierarquia escolhida).
const List<CampoCatalogo> camposGraficosAgrupadosEsclerometria = [
  CampoCatalogo(chaveGraficoBarraPontosEsclerometria, 'Barra com a Média Q por ponto de ensaio', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoBoxplotElemento, 'Boxplot por tipo de elemento', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoBoxplotLocal, 'Boxplot por local', TipoCampoCatalogo.imagem),
];

// "Tabela geral": uma linha por ponto de ensaio, achatada (sem fotos/gráficos/matriz).
final List<CampoCatalogo> _camposTabelaGeralEsclerometria =
    camposRegistroEsclerometria.where((c) => c.tipo == TipoCampoCatalogo.texto).toList();

final List<TabelaResumo> tabelasResumoEsclerometria = [
  TabelaResumo('ponto_esclerometria', 'Ponto de ensaio', _camposTabelaGeralEsclerometria),
];
