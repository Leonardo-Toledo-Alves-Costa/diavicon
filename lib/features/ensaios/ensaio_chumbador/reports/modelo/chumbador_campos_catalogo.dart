import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart' show chaveGraficoBoxplotLocalTipoChumbador;
import '../../../../modelos_relatorios/models/quadro_model.dart';

// Catálogos de campos do compositor de relatório de Tração em Chumbador —
// mesmo padrão dos demais ensaios (ver `resistividade_campos_catalogo.dart`).

// "Leituras": bloco aninhado (sub-lista) dentro de cada Registro — um item
// por leitura (`ponto_ensaio_tracao_leitura`), na ordem de inserção (a
// tabela real não tem um número de leitura manual).
const List<CampoCatalogo> camposLeituraChumbador = [
  CampoCatalogo('etapa_leitura_ch', 'Etapa (carregamento/descarregamento)', TipoCampoCatalogo.texto),
  CampoCatalogo('forca_leitura_ch', 'Força (kN)', TipoCampoCatalogo.texto),
  CampoCatalogo('deslocamento_leitura_ch', 'Deslocamento (mm)', TipoCampoCatalogo.texto),
  CampoCatalogo('ocorrencia_leitura_ch', 'Ocorrência', TipoCampoCatalogo.texto),
  CampoCatalogo('foto_leitura_ch', 'Foto da leitura', TipoCampoCatalogo.imagem),
];

// "Registros Individuais": um bloco de campos por ponto de ensaio (1
// chumbador testado).
const List<CampoCatalogo> camposRegistroChumbador = [
  CampoCatalogo('nome_elemento_ch', 'Nome do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_ch', 'Tipo do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('local_elemento_ch', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('revestimento_elemento_ch', 'Revestimento', TipoCampoCatalogo.texto),
  CampoCatalogo('marcacao_elemento_ch', 'Marcação em planta', TipoCampoCatalogo.imagem),
  CampoCatalogo('nome_ponto_ch', 'Nome do ponto', TipoCampoCatalogo.texto),
  CampoCatalogo('foto_chumbador_ch', 'Foto do chumbador', TipoCampoCatalogo.imagem),
  CampoCatalogo('foto_durante_ch', 'Foto durante o ensaio', TipoCampoCatalogo.imagem),
  CampoCatalogo('foto_apos_ch', 'Foto após o ensaio', TipoCampoCatalogo.imagem),
  CampoCatalogo('ocorrencias_gerais_ch', 'Ocorrências gerais', TipoCampoCatalogo.texto),
  CampoCatalogo('carga_maxima_ch', 'Carga máxima', TipoCampoCatalogo.texto),
  CampoCatalogo('deslocamento_maximo_ch', 'Deslocamento máximo', TipoCampoCatalogo.texto),
  CampoCatalogo('condicao_avaliacao_ch', 'Condição de avaliação', TipoCampoCatalogo.texto),
  CampoCatalogo('grafico_forca_deslocamento_ch', 'Gráfico força × deslocamento', TipoCampoCatalogo.imagem),
];

// "Registros agrupados": colunas estatísticas disponíveis pra tabela por
// grupo (Local, Tipo de elemento, ou os dois).
const List<CampoCatalogo> camposEstatisticasChumbador = [
  CampoCatalogo('local_grupo_ch', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_grupo_ch', 'Tipo de elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('total_pontos_grupo_ch', 'Total de pontos', TipoCampoCatalogo.texto),
  CampoCatalogo('media_carga_grupo_ch', 'Média da carga máxima', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_carga_grupo_ch', 'Coeficiente de variação', TipoCampoCatalogo.texto),
  CampoCatalogo('maior_carga_grupo_ch', 'Maior carga máxima', TipoCampoCatalogo.texto),
  CampoCatalogo('menor_carga_grupo_ch', 'Menor carga máxima', TipoCampoCatalogo.texto),
  CampoCatalogo('aprovados_grupo_ch', 'Aprovados', TipoCampoCatalogo.texto),
  CampoCatalogo('reprovados_grupo_ch', 'Reprovados', TipoCampoCatalogo.texto),
  CampoCatalogo('cabe_analise_grupo_ch', 'Cabe análise', TipoCampoCatalogo.texto),
];

// Gráfico-resumo disponível pra "Registros agrupados": um único boxplot com
// uma caixa por combinação Local + Tipo de elemento (ver comentário em
// `modelo_relatorio_schema.dart`).
const List<CampoCatalogo> camposGraficosAgrupadosChumbador = [
  CampoCatalogo(chaveGraficoBoxplotLocalTipoChumbador, 'Boxplot da carga máxima por Local + Tipo de elemento', TipoCampoCatalogo.imagem),
];

// "Tabela geral": uma linha por ponto de ensaio, achatada (sem fotos/gráficos).
final List<CampoCatalogo> _camposTabelaGeralChumbador =
    camposRegistroChumbador.where((c) => c.tipo != TipoCampoCatalogo.imagem).toList();

final List<TabelaResumo> tabelasResumoChumbador = [
  TabelaResumo('ponto_chumbador', 'Ponto de ensaio', _camposTabelaGeralChumbador),
];
