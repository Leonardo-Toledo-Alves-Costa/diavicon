import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart'
    show chaveGraficoBoxplotElemento, chaveGraficoBoxplotLocal, chaveGraficoDistribuicaoRiscoElemento, chaveGraficoDistribuicaoRiscoLocal;
import '../../../../modelos_relatorios/models/quadro_model.dart';

// Catálogos de campos do compositor de relatório de Resistividade Elétrica
// Superficial — mesmo padrão do de Carbonatação
// (`ensaios_carbonatacao/reports/modelo/carbonatacao_campos_catalogo.dart`),
// com os campos reais desse ensaio (pontos_ensaios_geral,
// ponto_ensaio_resistividade_leitura, galeria_ponto_ensaio_resistividade).

// "Ponto de resistividade": bloco aninhado (sub-lista) dentro de cada
// Registro — um item por ponto de leitura (`nome_leitura`) na grade.
const List<CampoCatalogo> camposLeituraResistividade = [
  CampoCatalogo('nome_leitura_resist', 'Nome do ponto de leitura', TipoCampoCatalogo.texto),
  CampoCatalogo('menor_leitura_resist', 'Menor resistividade para aquele ponto', TipoCampoCatalogo.texto),
];

// "Registros Individuais": um bloco de campos por ponto de ensaio.
const List<CampoCatalogo> camposRegistroResistividade = [
  CampoCatalogo('nome_elemento_resist', 'Nome do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_resist', 'Tipo do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('local_elemento_resist', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('revestimento_elemento_resist', 'Revestimento', TipoCampoCatalogo.texto),
  CampoCatalogo('nome_ponto_resist', 'Nome do ponto', TipoCampoCatalogo.texto),
  CampoCatalogo('valor_resultado_resist', 'Resultado', TipoCampoCatalogo.texto),
  CampoCatalogo('menor_resistividade_resist', 'Menor resistividade (entre os últimos valores)', TipoCampoCatalogo.texto),
  CampoCatalogo('maior_resistividade_resist', 'Maior resistividade (entre os últimos valores)', TipoCampoCatalogo.texto),
  CampoCatalogo('media_resistividade_resist', 'Média dos últimos valores dos pontos de leitura', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_resistividade_resist', 'Coef. de variação dos últimos valores', TipoCampoCatalogo.texto),
  CampoCatalogo('grafico_resistividade_tempo_resist', 'Gráfico da resistividade ao longo do tempo', TipoCampoCatalogo.imagem),
  CampoCatalogo('marcacao_elemento_resist', 'Marcação em planta', TipoCampoCatalogo.imagem),
  CampoCatalogo('marcacao_leitura_resist', 'Marcação dos pontos de leitura na imagem', TipoCampoCatalogo.imagem),
  CampoCatalogo('risco_corrosao_resist', 'Risco de corrosão', TipoCampoCatalogo.texto),
  CampoCatalogo('taxa_corrosao_resist', 'Taxa de corrosão', TipoCampoCatalogo.texto),
  CampoCatalogo('permissividade_resist', 'Permissividade iônica', TipoCampoCatalogo.texto),
];

// "Registros agrupados": colunas estatísticas disponíveis pra tabela por
// grupo (Local, Tipo de elemento, ou os dois).
const List<CampoCatalogo> camposEstatisticasResistividade = [
  CampoCatalogo('local_grupo_resist', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_grupo_resist', 'Tipo de elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('media_resistividade_grupo_resist', 'Média da resistividade (dos últimos)', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_resistividade_grupo_resist', 'Coeficiente de variação', TipoCampoCatalogo.texto),
  CampoCatalogo('maior_resistividade_grupo_resist', 'Maior valor (entre os últimos)', TipoCampoCatalogo.texto),
  CampoCatalogo('menor_resistividade_grupo_resist', 'Menor valor (entre os últimos)', TipoCampoCatalogo.texto),
  CampoCatalogo('risco_corrosao_grupo_resist', 'Risco de corrosão', TipoCampoCatalogo.texto),
  CampoCatalogo('taxa_corrosao_grupo_resist', 'Taxa de corrosão', TipoCampoCatalogo.texto),
  CampoCatalogo('permissividade_grupo_resist', 'Permissividade iônica', TipoCampoCatalogo.texto),
];

// Gráficos-resumo disponíveis pra "Registros agrupados".
const List<CampoCatalogo> camposGraficosAgrupadosResistividade = [
  CampoCatalogo(chaveGraficoDistribuicaoRiscoElemento, 'Distribuição por risco de corrosão (por tipo de elemento)', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoDistribuicaoRiscoLocal, 'Distribuição por risco de corrosão (por local)', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoBoxplotElemento, 'Boxplot dos resultados por elemento', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoBoxplotLocal, 'Boxplot dos resultados por local', TipoCampoCatalogo.imagem),
];

// "Tabela geral": uma linha por ponto de ensaio, achatada (sem fotos/gráficos).
final List<CampoCatalogo> _camposTabelaGeralResistividade =
    camposRegistroResistividade.where((c) => c.tipo != TipoCampoCatalogo.imagem).toList();

final List<TabelaResumo> tabelasResumoResistividade = [
  TabelaResumo('ponto_resistividade', 'Ponto de ensaio', _camposTabelaGeralResistividade),
];
