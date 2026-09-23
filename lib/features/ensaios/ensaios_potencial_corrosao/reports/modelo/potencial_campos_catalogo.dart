import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart' show chaveGraficoBoxplotElemento, chaveGraficoBoxplotLocal;
import '../../../../modelos_relatorios/models/quadro_model.dart';

// Catálogos de campos do compositor de relatório de Potencial de Corrosão —
// mesmo padrão de Carbonatação/Resistividade
// (`ensaios_carbonatacao/reports/modelo/carbonatacao_campos_catalogo.dart`),
// com os campos reais desse ensaio (pontos_ensaios_geral,
// ponto_ensaio_potencial, ponto_ensaio_potencial_leitura).

// "Registros Individuais": um bloco de campos por ponto de ensaio.
const List<CampoCatalogo> camposRegistroPotencial = [
  CampoCatalogo('nome_elemento_pot', 'Nome do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_pot', 'Tipo do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('local_elemento_pot', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('revestimento_elemento_pot', 'Revestimento', TipoCampoCatalogo.texto),
  CampoCatalogo('marcacao_elemento_pot', 'Marcação do elemento em planta', TipoCampoCatalogo.imagem),
  CampoCatalogo('nome_ponto_pot', 'Nome do ponto', TipoCampoCatalogo.texto),
  CampoCatalogo('valor_resultado_pot', 'Resultado', TipoCampoCatalogo.texto),
  CampoCatalogo('eletrodo_pot', 'Eletrodo', TipoCampoCatalogo.texto),
  CampoCatalogo('tempo_saturacao_pot', 'Tempo de saturação', TipoCampoCatalogo.texto),
  CampoCatalogo('temperatura_pot', 'Temperatura', TipoCampoCatalogo.texto),
  CampoCatalogo('imagem_elemento_pot', 'Imagem do elemento', TipoCampoCatalogo.imagem),
  CampoCatalogo('imagem_ensaio_pot', 'Imagem do ensaio', TipoCampoCatalogo.imagem),
  CampoCatalogo('imagem_elemento_mapa_pot', 'Imagem do elemento com mapa de calor', TipoCampoCatalogo.imagem),
  CampoCatalogo('matriz_leituras_pot', 'Matriz de leituras (posição x potencial_mv)', TipoCampoCatalogo.matriz),
  CampoCatalogo('media_potencial_pot', 'Média', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_potencial_pot', 'Coeficiente de variação', TipoCampoCatalogo.texto),
  CampoCatalogo('menor_potencial_pot', 'Menor valor', TipoCampoCatalogo.texto),
  CampoCatalogo('maior_potencial_pot', 'Maior valor', TipoCampoCatalogo.texto),
  CampoCatalogo('boxplot_potencial_pot', 'Boxplot das leituras do ponto', TipoCampoCatalogo.imagem),
];

// "Registros agrupados": colunas estatísticas disponíveis pra tabela por
// grupo (Local, Tipo de elemento, ou os dois). Eletrodo/tempo de
// saturação/temperatura não são estatísticas (são config do ensaio, não um
// valor medido) — quando o grupo mistura pontos com valores diferentes, os
// valores distintos aparecem concatenados por vírgula.
const List<CampoCatalogo> camposEstatisticasPotencial = [
  CampoCatalogo('local_grupo_pot', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_grupo_pot', 'Tipo de elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('eletrodo_grupo_pot', 'Eletrodo', TipoCampoCatalogo.texto),
  CampoCatalogo('tempo_saturacao_grupo_pot', 'Tempo de saturação', TipoCampoCatalogo.texto),
  CampoCatalogo('temperatura_grupo_pot', 'Temperatura', TipoCampoCatalogo.texto),
  CampoCatalogo('media_potencial_grupo_pot', 'Média', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_potencial_grupo_pot', 'Coeficiente de variação', TipoCampoCatalogo.texto),
  CampoCatalogo('maior_potencial_grupo_pot', 'Maior valor', TipoCampoCatalogo.texto),
  CampoCatalogo('menor_potencial_grupo_pot', 'Menor valor', TipoCampoCatalogo.texto),
];

// Gráficos-resumo disponíveis pra "Registros agrupados" — reaproveita as
// mesmas chaves genéricas de boxplot já usadas por Carbonatação/Resistividade.
const List<CampoCatalogo> camposGraficosAgrupadosPotencial = [
  CampoCatalogo(chaveGraficoBoxplotElemento, 'Boxplot dos resultados por elemento', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoBoxplotLocal, 'Boxplot dos resultados por local', TipoCampoCatalogo.imagem),
];

// "Tabela geral": uma linha por ponto de ensaio, achatada (sem fotos/gráficos/matriz).
final List<CampoCatalogo> _camposTabelaGeralPotencial =
    camposRegistroPotencial.where((c) => c.tipo == TipoCampoCatalogo.texto).toList();

final List<TabelaResumo> tabelasResumoPotencial = [
  TabelaResumo('ponto_potencial', 'Ponto de ensaio', _camposTabelaGeralPotencial),
];
