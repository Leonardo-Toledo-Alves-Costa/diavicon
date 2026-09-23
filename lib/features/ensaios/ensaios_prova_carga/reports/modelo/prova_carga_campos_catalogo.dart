import '../../../../modelos_relatorios/models/quadro_model.dart';

// Catálogos de campos do compositor de relatório de Prova de Carga Estática.
// Diferente dos demais ensaios (Carbonatação/Resistividade/Potencial/
// Arrancamento): não tem "Registros agrupados" (pedido explícito do
// usuário) e o elemento estrutural é OPCIONAL (`pontos_ensaios_geral.
// elemento_estrutural_id` pode ser nulo — ver comentário em
// `ensaios_routes_map.dart`: "não se vincula a um elemento estrutural").

// "Registros Individuais": campos do ensaio (1:1 — `ponto_ensaio_prova_carga`
// não se repete por ponto, é uma Área de Ensaio só por registro).
const List<CampoCatalogo> camposRegistroProvaCarga = [
  CampoCatalogo('nome_elemento_pc', 'Nome do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_pc', 'Tipo do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('local_elemento_pc', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('revestimento_elemento_pc', 'Revestimento', TipoCampoCatalogo.texto),
  CampoCatalogo('marcacao_elemento_pc', 'Marcação do elemento em planta', TipoCampoCatalogo.imagem),
  CampoCatalogo('nome_ponto_pc', 'Nome do ponto', TipoCampoCatalogo.texto),
  CampoCatalogo('valor_resultado_pc', 'Resultado', TipoCampoCatalogo.texto),
  CampoCatalogo('carga_total_pc', 'Carga total (kg)', TipoCampoCatalogo.texto),
  CampoCatalogo('carregamento_pc', 'Carregamento (kg/m²)', TipoCampoCatalogo.texto),
  CampoCatalogo('etapa_carregamento_pc', 'Etapas de carregamento', TipoCampoCatalogo.texto),
  CampoCatalogo('etapa_descarregamento_pc', 'Etapas de descarregamento', TipoCampoCatalogo.texto),
  CampoCatalogo('imagem_planta_pc', 'Imagem da planta', TipoCampoCatalogo.imagem),
];

// "Pontos de medição": bloco aninhado (sub-lista) dentro de cada Registro —
// um item por transdutor de deslocamento. A tabela de leituras
// (`ponto_ensaio_prova_carga_ponto_leitura`, N por medição) não vira uma
// segunda sub-lista aninhada (o Quadro só suporta um nível de sub-lista) —
// vem pré-montada como HTML de tabela (`TipoConteudoSlot.matriz`), igual à
// matriz de leituras da Potencial de Corrosão.
const List<CampoCatalogo> camposPontoMedicaoProvaCarga = [
  CampoCatalogo('nome_ponto_medicao_pc', 'Nome do ponto', TipoCampoCatalogo.texto),
  CampoCatalogo('desloc_max_pc', 'Deslocamento admissível', TipoCampoCatalogo.texto),
  CampoCatalogo('descricao_pc', 'Descrição', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_medicao_pc', 'Tipo de elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('grafico_deslocamento_carga_pc', 'Gráfico de deslocamento ao longo da carga', TipoCampoCatalogo.imagem),
  CampoCatalogo('condicao_pc', 'Condição (excedido ou não)', TipoCampoCatalogo.texto),
  CampoCatalogo('residual_maximo_pc', 'Residual máximo', TipoCampoCatalogo.texto),
  CampoCatalogo('duracao_total_pc', 'Duração total do ensaio', TipoCampoCatalogo.texto),
  CampoCatalogo('tabela_leituras_pc', 'Tabela de leituras (Desloc./Carga/Etapa/Hora)', TipoCampoCatalogo.matriz),
];

// "Tabela geral": aqui uma linha é por PONTO DE MEDIÇÃO (não por registro/
// ensaio, já que um ensaio pode ter N pontos de medição e os valores
// calculados — Condição/Residual/Duração — só existem nesse nível). Cada
// linha junta os campos do registro (contexto) + do ponto de medição +
// calculados, pedido explícito do usuário ("todos os dados, mais os
// calculados"). Reaproveita as MESMAS chaves dos catálogos acima.
const List<CampoCatalogo> _camposTabelaGeralProvaCarga = [
  ...camposRegistroProvaCarga,
  CampoCatalogo('nome_ponto_medicao_pc', 'Nome do ponto de medição', TipoCampoCatalogo.texto),
  CampoCatalogo('desloc_max_pc', 'Deslocamento admissível', TipoCampoCatalogo.texto),
  CampoCatalogo('descricao_pc', 'Descrição', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_medicao_pc', 'Tipo de elemento (medição)', TipoCampoCatalogo.texto),
  CampoCatalogo('condicao_pc', 'Condição (excedido ou não)', TipoCampoCatalogo.texto),
  CampoCatalogo('residual_maximo_pc', 'Residual máximo', TipoCampoCatalogo.texto),
  CampoCatalogo('duracao_total_pc', 'Duração total do ensaio', TipoCampoCatalogo.texto),
];

final List<CampoCatalogo> _camposTabelaGeralProvaCargaTexto =
    _camposTabelaGeralProvaCarga.where((c) => c.tipo == TipoCampoCatalogo.texto).toList();

final List<TabelaResumo> tabelasResumoProvaCarga = [
  TabelaResumo('ponto_medicao_prova_carga', 'Ponto de medição', _camposTabelaGeralProvaCargaTexto),
];
