import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart'
    show chaveGraficoResistenciaElementoExt, chaveGraficoResistenciaLocalExt, chaveGraficoFckElementoExt, chaveGraficoFckLocalExt;
import '../../../../modelos_relatorios/models/quadro_model.dart';

// Catálogos de campos do compositor de relatório de Extração e Rompimento
// de Testemunho — mesmo padrão dos demais ensaios (ver
// `chumbador_campos_catalogo.dart`), com uma diferença estrutural: aqui
// cada REGISTRO é 1 Local (`ponto_ensaio_extracao_local`), não 1 elemento —
// os testemunhos (com seu próprio elemento cada) entram como Bloco de
// repetição, igual pedido pelo usuário.

// "Pontos de extração e rompimento": bloco aninhado (sub-lista) dentro de
// cada Registro — um item por testemunho (`ponto_ensaio_extracao_leituras`).
const List<CampoCatalogo> camposLeituraExtracao = [
  CampoCatalogo('nome_testemunho_ext', 'Nome do ponto', TipoCampoCatalogo.texto),
  CampoCatalogo('elemento_leitura_ext', 'Elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_leitura_ext', 'Tipo de elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('direcao_leitura_ext', 'Direção da extração (k3)', TipoCampoCatalogo.texto),
  CampoCatalogo('relacao_hd_leitura_ext', 'Relação h/d (k1)', TipoCampoCatalogo.texto),
  CampoCatalogo('diametro_leitura_ext', 'Diâmetro do testemunho, k2 (mm)', TipoCampoCatalogo.texto),
  CampoCatalogo('umidade_leitura_ext', 'Condição de umidade (k4)', TipoCampoCatalogo.texto),
  CampoCatalogo('resistencia_sem_correcao_leitura_ext', 'Resistência sem correção', TipoCampoCatalogo.texto),
  CampoCatalogo('resistencia_corrigida_leitura_ext', 'Resistência corrigida', TipoCampoCatalogo.texto),
  CampoCatalogo('foto_extraindo_leitura_ext', 'Foto extraindo', TipoCampoCatalogo.imagem),
  CampoCatalogo('foto_extracao_leitura_ext', 'Foto do corpo de prova extraído', TipoCampoCatalogo.imagem),
  CampoCatalogo('foto_recomposicao_leitura_ext', 'Foto da recomposição', TipoCampoCatalogo.imagem),
  CampoCatalogo('foto_planta_leitura_ext', 'Planta marcada (esse ponto)', TipoCampoCatalogo.imagem),
];

// "Registros Individuais": um bloco de campos por Local ensaiado.
const List<CampoCatalogo> camposRegistroExtracao = [
  CampoCatalogo('nome_local_ext', 'Nome do ensaio', TipoCampoCatalogo.texto),
  CampoCatalogo('local_ext', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('total_pontos_ext', 'Total de pontos de extração', TipoCampoCatalogo.texto),
];

// "Registros agrupados": colunas estatísticas disponíveis pra tabela por
// grupo (Local, Tipo de elemento, ou os dois) — agrupa TODOS os testemunhos
// de todos os Locais do relatório.
const List<CampoCatalogo> camposEstatisticasExtracao = [
  CampoCatalogo('local_grupo_ext', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_grupo_ext', 'Tipo de elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('total_pontos_grupo_ext', 'Total de pontos', TipoCampoCatalogo.texto),
  CampoCatalogo('media_resistencia_grupo_ext', 'Média da resistência corrigida', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_resistencia_grupo_ext', 'Coeficiente de variação', TipoCampoCatalogo.texto),
  CampoCatalogo('maior_resistencia_grupo_ext', 'Maior resistência corrigida', TipoCampoCatalogo.texto),
  CampoCatalogo('menor_resistencia_grupo_ext', 'Menor resistência corrigida', TipoCampoCatalogo.texto),
  CampoCatalogo('fck_grupo_ext', 'fck estimado', TipoCampoCatalogo.texto),
];

// Gráficos-resumo disponíveis pra "Registros agrupados": resistência
// corrigida média e fck estimado, cada um por Tipo de elemento e por Local
// (chaves separadas, mesmo padrão de chaveGraficoBoxplotElemento/Local).
const List<CampoCatalogo> camposGraficosAgrupadosExtracao = [
  CampoCatalogo(chaveGraficoResistenciaElementoExt, 'Resistência corrigida média por Tipo de elemento', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoResistenciaLocalExt, 'Resistência corrigida média por Local', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoFckElementoExt, 'fck estimado por Tipo de elemento', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoFckLocalExt, 'fck estimado por Local', TipoCampoCatalogo.imagem),
];

// "Tabela geral": uma linha por Local ensaiado, achatada (sem fotos).
final List<CampoCatalogo> _camposTabelaGeralExtracao = camposRegistroExtracao.where((c) => c.tipo != TipoCampoCatalogo.imagem).toList();

final List<TabelaResumo> tabelasResumoExtracao = [
  TabelaResumo('local_extracao', 'Local ensaiado', _camposTabelaGeralExtracao),
];
