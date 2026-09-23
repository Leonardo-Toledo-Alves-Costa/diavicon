import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart'
    show chaveGraficoBarraTensaoElementos, chaveGraficoBoxplotElementosEspecificos, chaveGraficoBoxplotLocal;
import '../../../../modelos_relatorios/models/quadro_model.dart';

// Catálogos de campos do compositor de relatório de Arrancamento em
// Argamassa — mesmo padrão de Carbonatação/Resistividade/Potencial, com os
// campos reais desse ensaio (pontos_ensaios_geral, ponto_ensaio_arrancamento,
// ponto_ensaio_arrancamento_leitura, ponto_ensaio_arrancamento_ruptura).

// "Leituras": bloco aninhado (sub-lista) dentro de cada Registro — um item
// por ponto de leitura (pastilha) da malha de arrancamento.
const List<CampoCatalogo> camposLeituraArrancamento = [
  CampoCatalogo('nome_leitura_arr', 'Nome', TipoCampoCatalogo.texto),
  CampoCatalogo('imagem_ensaio_leitura_arr', 'Imagem do ensaio', TipoCampoCatalogo.imagem),
  CampoCatalogo('imagem_ruptura_leitura_arr', 'Imagem da ruptura', TipoCampoCatalogo.imagem),
  CampoCatalogo('d1_leitura_arr', 'Diâmetro 1', TipoCampoCatalogo.texto),
  CampoCatalogo('d2_leitura_arr', 'Diâmetro 2', TipoCampoCatalogo.texto),
  CampoCatalogo('diametro_medio_leitura_arr', 'Diâmetro médio', TipoCampoCatalogo.texto),
  CampoCatalogo('area_leitura_arr', 'Área', TipoCampoCatalogo.texto),
  CampoCatalogo('carga_leitura_arr', 'Carga (KN)', TipoCampoCatalogo.texto),
  CampoCatalogo('tensao_leitura_arr', 'Tensão', TipoCampoCatalogo.texto),
  CampoCatalogo('ruptura_leitura_arr', 'Tipo de ruptura (porcentagem)', TipoCampoCatalogo.texto),
];

// "Registros Individuais": um bloco de campos por ponto de ensaio.
const List<CampoCatalogo> camposRegistroArrancamento = [
  CampoCatalogo('nome_elemento_arr', 'Nome do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_arr', 'Tipo do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('local_elemento_arr', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('revestimento_elemento_arr', 'Revestimento', TipoCampoCatalogo.texto),
  CampoCatalogo('marcacao_elemento_arr', 'Marcação do elemento em planta', TipoCampoCatalogo.imagem),
  CampoCatalogo('nome_ponto_arr', 'Nome do ponto', TipoCampoCatalogo.texto),
  CampoCatalogo('valor_resultado_arr', 'Resultado', TipoCampoCatalogo.texto),
  CampoCatalogo('imagem_regiao_arr', 'Região de ensaio', TipoCampoCatalogo.imagem),
  CampoCatalogo('imagem_colagem_arr', 'Pastilhas coladas', TipoCampoCatalogo.imagem),
  CampoCatalogo('temperatura_arr', 'Temperatura', TipoCampoCatalogo.texto),
  CampoCatalogo('umidade_arr', 'Umidade', TipoCampoCatalogo.texto),
  CampoCatalogo('idade_revestimento_arr', 'Idade do revestimento', TipoCampoCatalogo.texto),
  CampoCatalogo('cola_utilizada_arr', 'Cola utilizada', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_substrato_arr', 'Substrato', TipoCampoCatalogo.texto),
  CampoCatalogo('media_tensao_arr', 'Tensão média', TipoCampoCatalogo.texto),
  CampoCatalogo('maior_tensao_arr', 'Maior tensão', TipoCampoCatalogo.texto),
  CampoCatalogo('menor_tensao_arr', 'Menor tensão', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_tensao_arr', 'Coeficiente de variação', TipoCampoCatalogo.texto),
  CampoCatalogo('ruptura_tipos_arr', 'Tipos de ruptura (agrupados por %)', TipoCampoCatalogo.texto),
  CampoCatalogo('grafico_tensao_ruptura_arr', 'Gráfico de tensão por leitura (por tipo de ruptura)', TipoCampoCatalogo.imagem),
];

// "Registros agrupados": colunas estatísticas disponíveis pra tabela por
// grupo (Local, Tipo de elemento, ou os dois) — uma linha por grupo,
// agregando todas as leituras de todos os pontos do grupo (mesma ideia de
// Carbonatação/Resistividade/Potencial). Temperatura/umidade/idade/cola/
// substrato não são estatísticas — quando o grupo mistura pontos com
// valores diferentes, os valores distintos aparecem concatenados por vírgula.
const List<CampoCatalogo> camposEstatisticasArrancamento = [
  CampoCatalogo('local_grupo_arr', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_grupo_arr', 'Tipo de elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('temperatura_grupo_arr', 'Temperatura', TipoCampoCatalogo.texto),
  CampoCatalogo('umidade_grupo_arr', 'Umidade', TipoCampoCatalogo.texto),
  CampoCatalogo('idade_revestimento_grupo_arr', 'Idade do revestimento', TipoCampoCatalogo.texto),
  CampoCatalogo('cola_utilizada_grupo_arr', 'Cola utilizada', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_substrato_grupo_arr', 'Substrato', TipoCampoCatalogo.texto),
  CampoCatalogo('media_tensao_grupo_arr', 'Tensão média', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_tensao_grupo_arr', 'Coeficiente de variação', TipoCampoCatalogo.texto),
  CampoCatalogo('menor_tensao_grupo_arr', 'Tensão mínima', TipoCampoCatalogo.texto),
  CampoCatalogo('maior_tensao_grupo_arr', 'Tensão máxima', TipoCampoCatalogo.texto),
  CampoCatalogo('ruptura_predominante_grupo_arr', 'Ruptura predominante', TipoCampoCatalogo.texto),
];

// Gráficos-resumo disponíveis pra "Registros agrupados". Os dois primeiros
// (barra por elemento / boxplot por elementos específicos) NÃO seguem a
// hierarquia escolhida — sempre uma barra/caixa por elemento individual,
// igual às abas "Gráficos"/"Estatísticas" de `analise_todos_arrancamento_screen.dart`.
// `chaveGraficoBoxplotLocal` é o único que agrupa pela hierarquia (pooling
// por Local), reaproveitado dos outros ensaios.
const List<CampoCatalogo> camposGraficosAgrupadosArrancamento = [
  CampoCatalogo(chaveGraficoBarraTensaoElementos, 'Barra de tensão média por elemento (por tipo de ruptura)', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoBoxplotElementosEspecificos, 'Boxplot por elementos específicos', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoBoxplotLocal, 'Boxplot por local', TipoCampoCatalogo.imagem),
];

// "Tabela geral": uma linha por ponto de ensaio, achatada (sem fotos/gráficos/sub-lista).
final List<CampoCatalogo> _camposTabelaGeralArrancamento =
    camposRegistroArrancamento.where((c) => c.tipo == TipoCampoCatalogo.texto).toList();

final List<TabelaResumo> tabelasResumoArrancamento = [
  TabelaResumo('ponto_arrancamento', 'Ponto de ensaio', _camposTabelaGeralArrancamento),
];
