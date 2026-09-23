import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart' show chaveGraficoStatusLocalTipoLP;
import '../../../../modelos_relatorios/models/quadro_model.dart';

// Catálogos do compositor de relatório de Líquido penetrante.
//
// "Registros" repete por ELEMENTO ensaiado; dentro dele, o bloco aninhado
// "Pontos de LP" (TipoConteudoSlot.subLista) repete por ponto (cordão/junta).

const List<CampoCatalogo> camposPontoLP = [
  CampoCatalogo('nome_ponto_lp', 'Identificação do cordão / junta', TipoCampoCatalogo.texto),
  CampoCatalogo('status_ponto_lp', 'Status', TipoCampoCatalogo.texto),
  CampoCatalogo('tamanho_ponto_lp', 'Tamanho analisado', TipoCampoCatalogo.texto),
  CampoCatalogo('tempo_ponto_lp', 'Tempo de penetração', TipoCampoCatalogo.texto),
  CampoCatalogo('descricao_ponto_lp', 'Descrição', TipoCampoCatalogo.texto),
  CampoCatalogo('foto_solda_lp', 'Foto da solda', TipoCampoCatalogo.imagem),
  CampoCatalogo('foto_penetrante_lp', 'Foto com penetrante', TipoCampoCatalogo.imagem),
  CampoCatalogo('foto_resultado_lp', 'Foto do resultado', TipoCampoCatalogo.imagem),
];

const List<CampoCatalogo> camposRegistroLP = [
  CampoCatalogo('nome_elemento_lp', 'Nome do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_lp', 'Tipo do elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('local_elemento_lp', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('marcacao_elemento_lp', 'Marcação em planta', TipoCampoCatalogo.imagem),
  CampoCatalogo('nome_ensaio_lp', 'Nome do ensaio', TipoCampoCatalogo.texto),
  CampoCatalogo('total_pontos_lp', 'Total de pontos', TipoCampoCatalogo.texto),
  CampoCatalogo('aprovados_lp', 'Aprovados', TipoCampoCatalogo.texto),
  CampoCatalogo('reprovados_lp', 'Reprovados', TipoCampoCatalogo.texto),
  CampoCatalogo('cabe_analise_lp', 'Cabe análise', TipoCampoCatalogo.texto),
  CampoCatalogo('resultado_lp', 'Resultado (contagem)', TipoCampoCatalogo.texto),
];

const List<CampoCatalogo> camposEstatisticasLP = [
  CampoCatalogo('local_grupo_lp', 'Local', TipoCampoCatalogo.texto),
  CampoCatalogo('tipo_elemento_grupo_lp', 'Tipo de elemento', TipoCampoCatalogo.texto),
  CampoCatalogo('total_elementos_grupo_lp', 'Elementos ensaiados', TipoCampoCatalogo.texto),
  CampoCatalogo('total_pontos_grupo_lp', 'Total de pontos', TipoCampoCatalogo.texto),
  CampoCatalogo('aprovados_grupo_lp', 'Aprovados', TipoCampoCatalogo.texto),
  CampoCatalogo('reprovados_grupo_lp', 'Reprovados', TipoCampoCatalogo.texto),
  CampoCatalogo('cabe_analise_grupo_lp', 'Cabe análise', TipoCampoCatalogo.texto),
];

const List<CampoCatalogo> camposGraficosAgrupadosLP = [
  CampoCatalogo(chaveGraficoStatusLocalTipoLP, 'Pontos por status (Local + Tipo de elemento)', TipoCampoCatalogo.imagem),
];

// "Tabela geral": uma linha por elemento, sem imagens.
final List<CampoCatalogo> _camposTabelaGeralLP = camposRegistroLP.where((c) => c.tipo != TipoCampoCatalogo.imagem).toList();

final List<TabelaResumo> tabelasResumoLP = [
  TabelaResumo('elemento_lp', 'Elemento ensaiado', _camposTabelaGeralLP),
];
