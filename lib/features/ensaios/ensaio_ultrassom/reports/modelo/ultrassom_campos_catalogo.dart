import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart'
    show
        chaveGraficoBarraLongitudinal,
        chaveGraficoBarraTransversal,
        chaveGraficoBarraResistencia,
        chaveGraficoBarraModuloElasticidade,
        chaveGraficoDistribuicaoFck,
        chaveGraficoBoxplotLongitudinal,
        chaveGraficoBoxplotTransversal;
import '../../../../modelos_relatorios/models/quadro_model.dart';

// Catálogos de campos do compositor de relatório de Ultrassonografia — mesmo
// padrão dos demais ensaios. Um "registro" é um PONTO de ensaio (repete um
// por ponto, igual aos outros ensaios — os campos de elemento/αE/densidade
// vêm junto em cada um, não deduplicados num nível acima), mas o ponto pode
// ter vindo de um dos 3 modos de coleta (ver `ponto_ensaio_ultrassom.modo`):
// - Direto/Indireto usam o mesmo "Box repetição" (sub-lista
//   `camposMedicaoUltrassom`) pros pontos de medição — Indireto só não
//   preenche `distancia_medicao_us` (não existe nesse nível pra ele).
// - Mapeamento usa `grid_leituras_mapeamento_us` (Matriz, a malha inteira).
// Cada ponto só preenche os campos do SEU modo; os das outras 3 famílias
// (imagens/matriz/sub-lista específicas) ficam vazios nesse registro —
// mesma ideia de campo condicional já usada em outros ensaios (ex:
// Prova de Carga com elemento opcional).
const List<CampoCatalogo> camposRegistroUltrassom = [
  CampoCatalogo('nome_elemento_us', 'Nome do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_us', 'Tipo do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('local_elemento_us', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('revestimento_elemento_us', 'Revestimento', TipoCampoCatalogo.texto),
  CampoCatalogo('marcacao_elemento_us', 'Marcação do elemento em planta', TipoCampoCatalogo.imagem),
  CampoCatalogo('alfa_e_us', 'αE (fator de agregado)', TipoCampoCatalogo.texto),
  CampoCatalogo('densidade_us', 'Densidade do concreto (kg/m³)', TipoCampoCatalogo.texto),
  CampoCatalogo('nome_ponto_us', 'Nome do ponto', TipoCampoCatalogo.texto),
  CampoCatalogo('modo_us', 'Método de coleta', TipoCampoCatalogo.texto),
  CampoCatalogo('pulso_us', 'Pulso ultrassônico', TipoCampoCatalogo.texto),
  CampoCatalogo('valor_resultado_us', 'Resultado', TipoCampoCatalogo.texto),
  CampoCatalogo('imagem_marcacao_area_us', 'Marcação da área', TipoCampoCatalogo.imagem),
  CampoCatalogo('imagem_realizacao_ensaio_us', 'Realização do ensaio', TipoCampoCatalogo.imagem),
  CampoCatalogo('media_velocidade_us', 'Velocidade média', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_us', 'Coeficiente de variação', TipoCampoCatalogo.texto),
  CampoCatalogo('classificacao_us', 'Classificação (Whitehurst — só Longitudinal)', TipoCampoCatalogo.texto),
  CampoCatalogo('imagem_pontos_marcados_us', 'Pontos de leitura marcados (só método Direto)', TipoCampoCatalogo.imagem),
  CampoCatalogo(
      'grafico_tempo_propagacao_us', 'Gráfico de tempo de propagação do pulso (só método Indireto)', TipoCampoCatalogo.imagem),
  CampoCatalogo('mapa_calor_us', 'Foto do elemento com o mapa de calor (só método Mapeamento)', TipoCampoCatalogo.imagem),
  CampoCatalogo('grid_leituras_mapeamento_us', 'Malha de leituras (só método Mapeamento)', TipoCampoCatalogo.matriz),
];

// "Box repetição" — um bloco por ponto de medição, usado pelos métodos
// Direto e Indireto (Mapeamento não usa, tem sua própria malha em
// `grid_leituras_mapeamento_us`). Indireto não tem "distância" nesse nível
// (cada leitura dele tem sua própria distância, usada só na regressão) —
// fica em branco nas linhas dele.
const List<CampoCatalogo> camposMedicaoUltrassom = [
  CampoCatalogo('nome_ponto_medicao_us', 'Nome do ponto de medição', TipoCampoCatalogo.texto),
  CampoCatalogo('distancia_medicao_us', 'Distância (cm) — só Direto', TipoCampoCatalogo.texto),
  CampoCatalogo('velocidade_medicao_us', 'Velocidade (m/s)', TipoCampoCatalogo.texto),
  CampoCatalogo('classificacao_medicao_us', 'Classificação (se Longitudinal)', TipoCampoCatalogo.texto),
];

// "Análise de Elementos" — uma linha por ELEMENTO estrutural (não por
// ponto), só pros que têm resultado Longitudinal E Transversal (únicos com
// Ed/fck calculáveis — ver `ElementoUltrassomBruto`). Fica ANTES de
// "Registros agrupados". Sufixo `_analise_us` pra não colidir com as chaves
// por-ponto de `camposRegistroUltrassom` no seletor de campos do editor.
const List<CampoCatalogo> camposAnaliseElementoUltrassom = [
  CampoCatalogo('nome_elemento_analise_us', 'Nome do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_analise_us', 'Tipo do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('local_elemento_analise_us', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('alfa_e_analise_us', 'αE (fator de agregado)', TipoCampoCatalogo.texto),
  CampoCatalogo('densidade_analise_us', 'Densidade do concreto (kg/m³)', TipoCampoCatalogo.texto),
  CampoCatalogo('velocidade_longitudinal_analise_us', 'Velocidade média — Longitudinal', TipoCampoCatalogo.texto),
  CampoCatalogo('velocidade_transversal_analise_us', 'Velocidade média — Transversal', TipoCampoCatalogo.texto),
  CampoCatalogo('poisson_analise_us', 'Coeficiente de Poisson (ν)', TipoCampoCatalogo.texto),
  CampoCatalogo('modulo_elasticidade_analise_us', 'Módulo de elasticidade estimado (Ed)', TipoCampoCatalogo.texto),
  CampoCatalogo('fck_analise_us', 'Resistência à compressão estimada (fck)', TipoCampoCatalogo.texto),
];

// "Registros agrupados": estatísticas por Local/Tipo de elemento — separadas
// por pulso (Longitudinal e Transversal têm escalas/significados
// diferentes, não faz sentido poolar as duas juntas numa média só).
const List<CampoCatalogo> camposEstatisticasUltrassom = [
  CampoCatalogo('local_grupo_us', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_grupo_us', 'Tipo de elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('media_longitudinal_grupo_us', 'Velocidade média — Longitudinal', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_longitudinal_grupo_us', 'Coef. variação — Longitudinal', TipoCampoCatalogo.texto),
  CampoCatalogo('classificacao_longitudinal_grupo_us', 'Classificação — Longitudinal', TipoCampoCatalogo.texto),
  CampoCatalogo('media_transversal_grupo_us', 'Velocidade média — Transversal', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_transversal_grupo_us', 'Coef. variação — Transversal', TipoCampoCatalogo.texto),
];

// Gráficos-resumo — mesma análise já existente em
// `AnaliseTodosUltrassomScreen` (não agrupam pela hierarquia escolhida pra
// tabela acima; ver comentário nas chaves em modelo_relatorio_schema.dart).
const List<CampoCatalogo> camposGraficosAgrupadosUltrassom = [
  CampoCatalogo(chaveGraficoBarraLongitudinal, 'Barra por elemento — Pulso Longitudinal', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoBarraTransversal, 'Barra por elemento — Pulso Transversal', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoBarraResistencia, 'Barra por elemento — Resistência à compressão estimada', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoBarraModuloElasticidade, 'Barra por elemento — Módulo de elasticidade estimado', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoDistribuicaoFck, 'Distribuição de fck (Gauss)', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoBoxplotLongitudinal, 'Boxplot por elemento/local — Pulso Longitudinal', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoBoxplotTransversal, 'Boxplot por elemento/local — Pulso Transversal', TipoCampoCatalogo.imagem),
];

// "Tabela geral": uma linha por ponto de ensaio, achatada (sem fotos/matriz).
final List<CampoCatalogo> _camposTabelaGeralUltrassom =
    camposRegistroUltrassom.where((c) => c.tipo == TipoCampoCatalogo.texto).toList();

final List<TabelaResumo> tabelasResumoUltrassom = [
  TabelaResumo('ponto_ultrassom', 'Ponto de ensaio', _camposTabelaGeralUltrassom),
];
