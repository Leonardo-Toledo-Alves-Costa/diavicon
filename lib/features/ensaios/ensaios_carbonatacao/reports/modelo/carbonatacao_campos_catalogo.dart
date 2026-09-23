import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart'
    show
        chaveGraficoAvancoFrente,
        chaveGraficoProbabilidade,
        chaveGraficoBoxplotElemento,
        chaveGraficoBoxplotLocal,
        chaveGraficoAvancoFrentePorElemento,
        chaveGraficoAvancoFrentePorLocal,
        chaveGraficoProbabilidadePorElemento,
        chaveGraficoProbabilidadePorLocal;
import '../../../../modelos_relatorios/models/quadro_model.dart';

// Catálogos de campos do compositor de relatório de Carbonatação — espelham
// `camposRegistro`/`tabelasResumo` da Inspeção Visual
// (`lib/features/modelos_relatorios/models/quadro_model.dart`), só que com os
// campos reais desse ensaio (ver pesquisa no plano: elementos_estruturais,
// pontos_ensaios_geral, ponto_ensaio_carb, ponto_ensaio_carb_frentes).

// "Registros Individuais": um bloco de campos por ponto de ensaio.
const List<CampoCatalogo> camposRegistroCarbonatacao = [
  CampoCatalogo('nome_elemento_carb', 'Nome do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_carb', 'Tipo do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('local_elemento_carb', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('revestimento_elemento_carb', 'Revestimento', TipoCampoCatalogo.texto),
  CampoCatalogo('marcacao_elemento_carb', 'Marcação em planta', TipoCampoCatalogo.imagem),
  CampoCatalogo('nome_ponto_carb', 'Nome do ponto', TipoCampoCatalogo.texto),
  CampoCatalogo('valor_resultado_carb', 'Resultado', TipoCampoCatalogo.texto),
  CampoCatalogo('cob_arm_p_carb', 'Cobrimento armadura principal', TipoCampoCatalogo.texto),
  CampoCatalogo('cob_arm_s_carb', 'Cobrimento armadura secundária', TipoCampoCatalogo.texto),
  CampoCatalogo('bit_arm_p_carb', 'Bitola armadura principal', TipoCampoCatalogo.texto),
  CampoCatalogo('bit_arm_s_carb', 'Bitola armadura secundária', TipoCampoCatalogo.texto),
  CampoCatalogo('media_frente_carb', 'Média da frente de carbonatação', TipoCampoCatalogo.texto),
  CampoCatalogo('desvio_padrao_frente_carb', 'Desvio padrão da frente', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_frente_carb', 'Coeficiente de variação da frente', TipoCampoCatalogo.texto),
  CampoCatalogo('coef_carbonatacao_carb', 'Coeficiente de carbonatação', TipoCampoCatalogo.texto),
  CampoCatalogo('tempo_despassivacao_carb', 'Tempo para despassivação', TipoCampoCatalogo.texto),
  CampoCatalogo('grafico_avanco_frente_carb', 'Gráfico de avanço da frente', TipoCampoCatalogo.imagem),
];

// "Registros agrupados": colunas estatísticas disponíveis pra tabela por
// grupo (Local, Tipo de elemento, ou os dois — ver HierarquiaAgrupamento).
const List<CampoCatalogo> camposEstatisticasCarbonatacao = [
  CampoCatalogo('local_grupo_carb', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_grupo_carb', 'Tipo de elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('media_cob_p_grupo_carb', 'Média cobrimento armadura principal', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_cob_p_grupo_carb', 'Coef. variação cobrimento armadura principal', TipoCampoCatalogo.texto),
  CampoCatalogo('dp_cob_p_grupo_carb', 'Desvio padrão cobrimento armadura principal', TipoCampoCatalogo.texto),
  CampoCatalogo('media_cob_s_grupo_carb', 'Média cobrimento armadura secundária', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_cob_s_grupo_carb', 'Coef. variação cobrimento armadura secundária', TipoCampoCatalogo.texto),
  CampoCatalogo('dp_cob_s_grupo_carb', 'Desvio padrão cobrimento armadura secundária', TipoCampoCatalogo.texto),
  CampoCatalogo('media_frente_grupo_carb', 'Média frente de carbonatação', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_frente_grupo_carb', 'Coef. variação frente de carbonatação', TipoCampoCatalogo.texto),
  CampoCatalogo('dp_frente_grupo_carb', 'Desvio padrão frente de carbonatação', TipoCampoCatalogo.texto),
  CampoCatalogo('coef_carbonatacao_grupo_carb', 'Coeficiente de carbonatação', TipoCampoCatalogo.texto),
  CampoCatalogo('tempo_despassivacao_grupo_carb', 'Tempo para despassivação', TipoCampoCatalogo.texto),
  CampoCatalogo('risco_grupo_carb', 'Risco', TipoCampoCatalogo.texto),
  CampoCatalogo('prob_20_grupo_carb', 'Tempo até 20% de probabilidade de despassivação', TipoCampoCatalogo.texto),
  CampoCatalogo('prob_40_grupo_carb', 'Tempo até 40% de probabilidade de despassivação', TipoCampoCatalogo.texto),
  CampoCatalogo('prob_60_grupo_carb', 'Tempo até 60% de probabilidade de despassivação', TipoCampoCatalogo.texto),
  CampoCatalogo('prob_80_grupo_carb', 'Tempo até 80% de probabilidade de despassivação', TipoCampoCatalogo.texto),
];

// Gráficos-resumo disponíveis pra "Registros agrupados": cada um resume
// todos os grupos de uma vez (uma curva ou um boxplot com uma série por
// grupo), então entram no Quadro como campos do tipo imagem normais — o
// usuário monta a linha/divisão e escolhe qual gráfico aparece em cada slot.
const List<CampoCatalogo> camposGraficosAgrupadosCarbonatacao = [
  CampoCatalogo(chaveGraficoAvancoFrente, 'Avanço da frente de carbonatação', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoAvancoFrentePorElemento, 'Avanço da frente por tipo de elemento', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoAvancoFrentePorLocal, 'Avanço da frente por local', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoProbabilidade, 'Estimativa da probabilidade de despassivação', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoProbabilidadePorElemento, 'Probabilidade de despassivação por tipo de elemento', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoProbabilidadePorLocal, 'Probabilidade de despassivação por local', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoBoxplotElemento, 'Boxplot dos resultados por elemento', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoBoxplotLocal, 'Boxplot dos resultados por local', TipoCampoCatalogo.imagem),
];

// "Tabela geral": uma linha por ponto de ensaio, achatada (sem fotos).
final List<CampoCatalogo> _camposTabelaGeralCarbonatacao =
    camposRegistroCarbonatacao.where((c) => c.tipo != TipoCampoCatalogo.imagem).toList();

final List<TabelaResumo> tabelasResumoCarbonatacao = [
  TabelaResumo('ponto_carbonatacao', 'Ponto de ensaio', _camposTabelaGeralCarbonatacao),
];
