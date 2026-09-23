import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart'
    show chaveGraficoBarraTensaoElementos, chaveGraficoBoxplotElementosEspecificos, chaveGraficoBoxplotLocal;
import '../../../../modelos_relatorios/models/quadro_model.dart';

// Catálogos de campos do compositor de relatório de Arrancamento em Placa
// Cerâmica — praticamente idêntico ao de Arrancamento em Argamassa
// (`ensaios_arrancamento_argamassa/reports/modelo/arrancamento_campos_catalogo.dart`),
// já que as duas variantes de arrancamento compartilham as MESMAS tabelas
// (`ponto_ensaio_arrancamento*`), só diferenciadas por `tipo_ensaio_id`.
// Diferenças reais dessa variante (ver `ponto_arrancamento_ceramica_model.dart`):
// não tem diâmetro (d1/d2) — a leitura só grava `area` diretamente — e não
// tem campo de substrato.

// "Leituras": bloco aninhado (sub-lista) dentro de cada Registro — um item
// por pastilha cerâmica ensaiada.
const List<CampoCatalogo> camposLeituraArrancamentoCeramica = [
  CampoCatalogo('nome_leitura_cer', 'Nome', TipoCampoCatalogo.texto),
  CampoCatalogo('imagem_ensaio_leitura_cer', 'Imagem do ensaio', TipoCampoCatalogo.imagem),
  CampoCatalogo('imagem_ruptura_leitura_cer', 'Imagem da ruptura', TipoCampoCatalogo.imagem),
  CampoCatalogo('area_leitura_cer', 'Área', TipoCampoCatalogo.texto),
  CampoCatalogo('carga_leitura_cer', 'Carga (KN)', TipoCampoCatalogo.texto),
  CampoCatalogo('tensao_leitura_cer', 'Tensão', TipoCampoCatalogo.texto),
  CampoCatalogo('ruptura_leitura_cer', 'Tipo de ruptura (porcentagem)', TipoCampoCatalogo.texto),
];

// "Registros Individuais": um bloco de campos por ponto de ensaio.
const List<CampoCatalogo> camposRegistroArrancamentoCeramica = [
  CampoCatalogo('nome_elemento_cer', 'Nome do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_cer', 'Tipo do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('local_elemento_cer', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('revestimento_elemento_cer', 'Revestimento', TipoCampoCatalogo.texto),
  CampoCatalogo('marcacao_elemento_cer', 'Marcação do elemento em planta', TipoCampoCatalogo.imagem),
  CampoCatalogo('nome_ponto_cer', 'Nome do ponto', TipoCampoCatalogo.texto),
  CampoCatalogo('valor_resultado_cer', 'Resultado', TipoCampoCatalogo.texto),
  CampoCatalogo('imagem_regiao_cer', 'Região de ensaio', TipoCampoCatalogo.imagem),
  CampoCatalogo('imagem_colagem_cer', 'Pastilhas coladas', TipoCampoCatalogo.imagem),
  CampoCatalogo('temperatura_cer', 'Temperatura', TipoCampoCatalogo.texto),
  CampoCatalogo('umidade_cer', 'Umidade', TipoCampoCatalogo.texto),
  CampoCatalogo('idade_revestimento_cer', 'Idade do revestimento', TipoCampoCatalogo.texto),
  CampoCatalogo('cola_utilizada_cer', 'Cola utilizada', TipoCampoCatalogo.texto),
  CampoCatalogo('media_tensao_cer', 'Tensão média', TipoCampoCatalogo.texto),
  CampoCatalogo('maior_tensao_cer', 'Maior tensão', TipoCampoCatalogo.texto),
  CampoCatalogo('menor_tensao_cer', 'Menor tensão', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_tensao_cer', 'Coeficiente de variação', TipoCampoCatalogo.texto),
  CampoCatalogo('ruptura_tipos_cer', 'Tipos de ruptura (agrupados por %)', TipoCampoCatalogo.texto),
  CampoCatalogo('grafico_tensao_ruptura_cer', 'Gráfico de tensão por leitura (por tipo de ruptura)', TipoCampoCatalogo.imagem),
];

// "Registros agrupados": colunas estatísticas disponíveis pra tabela por
// grupo (Local, Tipo de elemento, ou os dois).
const List<CampoCatalogo> camposEstatisticasArrancamentoCeramica = [
  CampoCatalogo('local_grupo_cer', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_grupo_cer', 'Tipo de elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('temperatura_grupo_cer', 'Temperatura', TipoCampoCatalogo.texto),
  CampoCatalogo('umidade_grupo_cer', 'Umidade', TipoCampoCatalogo.texto),
  CampoCatalogo('idade_revestimento_grupo_cer', 'Idade do revestimento', TipoCampoCatalogo.texto),
  CampoCatalogo('cola_utilizada_grupo_cer', 'Cola utilizada', TipoCampoCatalogo.texto),
  CampoCatalogo('media_tensao_grupo_cer', 'Tensão média', TipoCampoCatalogo.texto),
  CampoCatalogo('cv_tensao_grupo_cer', 'Coeficiente de variação', TipoCampoCatalogo.texto),
  CampoCatalogo('menor_tensao_grupo_cer', 'Tensão mínima', TipoCampoCatalogo.texto),
  CampoCatalogo('maior_tensao_grupo_cer', 'Tensão máxima', TipoCampoCatalogo.texto),
  CampoCatalogo('ruptura_predominante_grupo_cer', 'Ruptura predominante', TipoCampoCatalogo.texto),
];

// Gráficos-resumo disponíveis pra "Registros agrupados" — mesmas chaves
// genéricas já criadas pra Arrancamento em Argamassa (barra/boxplot por
// elemento não seguem a hierarquia; boxplot por local segue).
const List<CampoCatalogo> camposGraficosAgrupadosArrancamentoCeramica = [
  CampoCatalogo(chaveGraficoBarraTensaoElementos, 'Barra de tensão média por elemento (por tipo de ruptura)', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoBoxplotElementosEspecificos, 'Boxplot por elementos específicos', TipoCampoCatalogo.imagem),
  CampoCatalogo(chaveGraficoBoxplotLocal, 'Boxplot por local', TipoCampoCatalogo.imagem),
];

// "Tabela geral": uma linha por ponto de ensaio, achatada (sem fotos/gráficos/sub-lista).
final List<CampoCatalogo> _camposTabelaGeralArrancamentoCeramica =
    camposRegistroArrancamentoCeramica.where((c) => c.tipo == TipoCampoCatalogo.texto).toList();

final List<TabelaResumo> tabelasResumoArrancamentoCeramica = [
  TabelaResumo('ponto_arrancamento_ceramica', 'Ponto de ensaio', _camposTabelaGeralArrancamentoCeramica),
];
