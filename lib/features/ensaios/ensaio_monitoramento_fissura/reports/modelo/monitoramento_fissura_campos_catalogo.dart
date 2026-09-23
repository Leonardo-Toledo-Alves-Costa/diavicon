import '../../../../modelos_relatorios/models/quadro_model.dart';

// Catálogos de campos do compositor de relatório de Monitoramento de
// Fissuras — mesmo padrão dos demais ensaios (ver
// `resistividade_campos_catalogo.dart`), com os campos reais desse ensaio
// (ponto_ensaio_monitoramento_fissura + _leitura).

// "Leituras": bloco aninhado (sub-lista) dentro de cada Registro — um item
// por medição (`ponto_ensaio_monitoramento_fissura_leitura`).
const List<CampoCatalogo> camposLeituraMonitoramentoFissura = [
  CampoCatalogo('data_hora_leitura_mf', 'Data/hora da leitura', TipoCampoCatalogo.texto),
  CampoCatalogo('temperatura_leitura_mf', 'Temperatura', TipoCampoCatalogo.texto),
  CampoCatalogo('umidade_leitura_mf', 'Umidade', TipoCampoCatalogo.texto),
  CampoCatalogo('medida_x_leitura_mf', 'Medida eixo X', TipoCampoCatalogo.texto),
  CampoCatalogo('medida_y_leitura_mf', 'Medida eixo Y', TipoCampoCatalogo.texto),
  CampoCatalogo('status_leitura_mf', 'Status da leitura', TipoCampoCatalogo.texto),
  CampoCatalogo('descricao_leitura_mf', 'Observações da leitura', TipoCampoCatalogo.texto),
  CampoCatalogo('foto_leitura_mf', 'Foto da leitura', TipoCampoCatalogo.imagem),
];

// "Registros Individuais": um bloco de campos por ponto de ensaio
// (instalação + todas as suas leituras, via Bloco de repetição acima).
const List<CampoCatalogo> camposRegistroMonitoramentoFissura = [
  CampoCatalogo('nome_elemento_mf', 'Nome do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_mf', 'Tipo do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('local_elemento_mf', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('revestimento_elemento_mf', 'Revestimento', TipoCampoCatalogo.texto),
  CampoCatalogo('marcacao_elemento_mf', 'Marcação em planta', TipoCampoCatalogo.imagem),
  CampoCatalogo('nome_ponto_mf', 'Nome do ponto', TipoCampoCatalogo.texto),
  CampoCatalogo('data_instalacao_mf', 'Data de instalação do selo', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_selo_mf', 'Tipo de selo', TipoCampoCatalogo.texto),
  CampoCatalogo('temperatura_instalacao_mf', 'Temperatura na instalação', TipoCampoCatalogo.texto),
  CampoCatalogo('umidade_instalacao_mf', 'Umidade na instalação', TipoCampoCatalogo.texto),
  CampoCatalogo('foto_instalacao_1_mf', 'Foto da instalação 1', TipoCampoCatalogo.imagem),
  CampoCatalogo('foto_instalacao_2_mf', 'Foto da instalação 2', TipoCampoCatalogo.imagem),
  CampoCatalogo('status_atual_mf', 'Status atual', TipoCampoCatalogo.texto),
  CampoCatalogo('foto_rompimento_mf', 'Foto do selo rompido', TipoCampoCatalogo.imagem),
  CampoCatalogo('grafico_movimento_xy_mf', 'Gráfico de movimento em torno do 0', TipoCampoCatalogo.imagem),
  CampoCatalogo('grafico_eixo_x_tempo_mf', 'Gráfico do eixo X ao longo do tempo', TipoCampoCatalogo.imagem),
  CampoCatalogo('grafico_eixo_y_tempo_mf', 'Gráfico do eixo Y ao longo do tempo', TipoCampoCatalogo.imagem),
];

// "Registros agrupados": só uma contagem por status (Local/Tipo de
// elemento) — os valores de deslocamento (X/Y) de fissuras diferentes não
// são estatisticamente comparáveis entre si (cada fissura tem sua própria
// escala/origem), então não há médias/boxplot aqui, diferente dos demais
// ensaios. Sem gráficos-resumo (`camposGraficosAgrupadosMonitoramentoFissura`
// fica vazio) pelo mesmo motivo.
const List<CampoCatalogo> camposEstatisticasMonitoramentoFissura = [
  CampoCatalogo('local_grupo_mf', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_grupo_mf', 'Tipo de elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('total_pontos_grupo_mf', 'Total de pontos', TipoCampoCatalogo.texto),
  CampoCatalogo('estaveis_grupo_mf', 'Estáveis', TipoCampoCatalogo.texto),
  CampoCatalogo('leves_grupo_mf', 'Leves', TipoCampoCatalogo.texto),
  CampoCatalogo('alertas_grupo_mf', 'Alertas', TipoCampoCatalogo.texto),
  CampoCatalogo('rompidos_grupo_mf', 'Rompidos', TipoCampoCatalogo.texto),
];

// "Tabela geral": uma linha por ponto de ensaio, achatada (sem fotos/gráficos).
final List<CampoCatalogo> _camposTabelaGeralMonitoramentoFissura =
    camposRegistroMonitoramentoFissura.where((c) => c.tipo != TipoCampoCatalogo.imagem).toList();

final List<TabelaResumo> tabelasResumoMonitoramentoFissura = [
  TabelaResumo('ponto_monitoramento_fissura', 'Ponto de ensaio', _camposTabelaGeralMonitoramentoFissura),
];
