import 'package:flutter/material.dart';

import '../models/modelo_relatorio_schema.dart';
import '../models/paleta_cores.dart';
import '../models/quadro_model.dart';

// Renderização somente-leitura de um Quadro com dados de exemplo — usada na
// aba "Preview" da tela de edição do modelo.
class QuadroPreview extends StatelessWidget {
  final Quadro quadro;
  final Map<String, String> dados;
  final List<CampoCatalogo> catalogo;
  final DecoracaoGlobalConfig decoracao;
  final List<Map<String, String>> dadosAnomaliasExemplo;
  // Só usados quando o Quadro tem algum slot do tipo `subLista` (mesmo
  // mecanismo de anomalias, generalizado — ex: "Pontos de leitura").
  final List<Map<String, String>> dadosSubListaExemplo;
  final List<CampoCatalogo> catalogoSubLista;
  final Border? borda;

  const QuadroPreview({
    super.key,
    required this.quadro,
    required this.dados,
    required this.catalogo,
    required this.decoracao,
    this.dadosAnomaliasExemplo = const [],
    this.dadosSubListaExemplo = const [],
    this.catalogoSubLista = const [],
    this.borda,
  });

  @override
  Widget build(BuildContext context) {
    if (quadro.linhas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Nenhum conteúdo configurado.', style: TextStyle(fontSize: 12, color: Colors.black38)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final linha in quadro.linhas) _buildLinha(linha)],
    );
  }

  Widget _buildLinha(LinhaQuadro linha) {
    if (linha.ehBloco) {
      final conteudo = linha.divisoes.first.conteudo!;
      if (conteudo.tipo == TipoConteudoSlot.galeria) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: conteudo.colunas,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: conteudo.colunas, crossAxisSpacing: 6, mainAxisSpacing: 6, mainAxisExtent: conteudo.alturaImagem),
                itemBuilder: (context, index) => Container(
                  decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(6), border: borda),
                  child: const Center(child: Icon(Icons.image_outlined, color: Colors.black26, size: 18)),
                ),
              ),
              if (conteudo.mostrarDescricao) ...[
                const SizedBox(height: 6),
                Text('Legenda de exemplo da foto', style: TextStyle(fontSize: decoracao.tamanhoFonteRotulo, color: Colors.black45)),
              ],
            ],
          ),
        );
      }
      if (conteudo.tipo == TipoConteudoSlot.anomalias) {
        final quadroAninhado = conteudo.quadroAninhado;
        if (quadroAninhado == null || dadosAnomaliasExemplo.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (final dadosAnomalia in dadosAnomaliasExemplo)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF5F8FF), borderRadius: BorderRadius.circular(8)),
                child: QuadroPreview(
                  quadro: quadroAninhado,
                  dados: dadosAnomalia,
                  catalogo: camposAnomalia,
                  decoracao: decoracao,
                  borda: borda,
                ),
              ),
          ],
        );
      }
      if (conteudo.tipo == TipoConteudoSlot.subLista) {
        final quadroAninhado = conteudo.quadroAninhado;
        if (quadroAninhado == null || dadosSubListaExemplo.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (final dadosItem in dadosSubListaExemplo)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF5F8FF), borderRadius: BorderRadius.circular(8)),
                child: QuadroPreview(
                  quadro: quadroAninhado,
                  dados: dadosItem,
                  catalogo: catalogoSubLista,
                  decoracao: decoracao,
                  borda: borda,
                ),
              ),
          ],
        );
      }
      if (conteudo.tipo == TipoConteudoSlot.matriz) {
        final rotuloCampo = buscarCampo(catalogo, conteudo.campoVinculado)?.rotulo ?? 'Matriz';
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(6), border: borda),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.table_chart_outlined, color: Colors.black26, size: 18),
              const SizedBox(width: 8),
              Text(rotuloCampo, style: const TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var d = 0; d < linha.divisoes.length; d++) ...[
            if (d > 0) const SizedBox(width: 12),
            Expanded(
              flex: linha.divisoes[d].larguraPercentual.round().clamp(1, 100),
              child: _buildSlot(linha.divisoes[d].conteudo),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlot(ConteudoSlot? conteudo) {
    if (conteudo == null) return const SizedBox.shrink();

    Widget conteudoWidget;
    switch (conteudo.tipo) {
      case TipoConteudoSlot.texto:
        final valor = dados[conteudo.campoVinculado] ?? '';
        final rotuloCampo = buscarCampo(catalogo, conteudo.campoVinculado)?.rotulo ?? '';
        RegraCondicional? regraAplicada;
        for (final regra in conteudo.decoracaoCondicional) {
          final valorReferencia = dados[regra.campoReferencia] ?? '';
          if (regra.operador.avalia(valorReferencia, regra.valorComparacao)) {
            regraAplicada = regra;
            break;
          }
        }
        final corTexto = regraAplicada != null ? corDaPaleta(regraAplicada.corTexto) : Colors.black87;
        final pesoTexto = regraAplicada != null ? FontWeight.w600 : FontWeight.normal;

        final Widget textoValor = Text(valor, style: TextStyle(fontSize: decoracao.tamanhoFonteValor, fontWeight: pesoTexto, color: corTexto));

        Widget miolo;
        if (!decoracao.mostrarTituloCampos || rotuloCampo.isEmpty) {
          miolo = textoValor;
        } else if (decoracao.posicaoTituloCampo == PosicaoTituloCampo.acima) {
          miolo = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$rotuloCampo:', style: TextStyle(fontSize: decoracao.tamanhoFonteRotulo, fontWeight: FontWeight.bold, color: Colors.black54)),
              textoValor,
            ],
          );
        } else {
          miolo = RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '$rotuloCampo: ', style: TextStyle(fontSize: decoracao.tamanhoFonteRotulo, fontWeight: FontWeight.bold, color: Colors.black54)),
                TextSpan(text: valor, style: TextStyle(fontSize: decoracao.tamanhoFonteValor, fontWeight: pesoTexto, color: corTexto)),
              ],
            ),
          );
        }

        conteudoWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: regraAplicada != null
              ? BoxDecoration(color: corDaPaleta(regraAplicada.corFundo), borderRadius: BorderRadius.circular(4))
              : null,
          child: miolo,
        );
        break;
      case TipoConteudoSlot.imagem:
        conteudoWidget = Container(
          height: conteudo.alturaImagem,
          width: double.infinity,
          decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(6)),
          child: const Center(child: Icon(Icons.image_outlined, color: Colors.black26)),
        );
        break;
      case TipoConteudoSlot.galeria:
      case TipoConteudoSlot.anomalias:
      case TipoConteudoSlot.subLista:
      case TipoConteudoSlot.matriz:
        conteudoWidget = const SizedBox.shrink();
        break;
    }

    if (borda == null) return conteudoWidget;
    return Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: borda), child: conteudoWidget);
  }
}

// Dados de exemplo pra prévia (Inspeção Visual).
const Map<String, String> dadosExemploCabecalho = {
  'nome_empresa': 'Empresa Exemplo Ltda',
  'nome_projeto': 'Projeto Exemplo',
  'cliente': 'Cliente Fulano de Tal',
};

const List<Map<String, String>> dadosExemploEquipe = [
  {'nome_user_equipe': 'João Silva', 'funcao_user_equipe': 'Engenheiro Responsável'},
  {'nome_user_equipe': 'Maria Souza', 'funcao_user_equipe': 'Técnica de Inspeção'},
];

const List<Map<String, String>> dadosExemploEmpresasProjeto = [
  {'nome_empresa_projeto': 'Diavicon Engenharia', 'user_empresa_projeto': 'João Silva', 'funcao_user_empresa_projeto': 'Responsável Técnico'},
];

const List<Map<String, String>> dadosExemploEstruturasProjeto = [
  {
    'nome_estrutura_ip': 'Bloco A',
    'descricao_estrutura_ip': 'Edifício residencial de 12 pavimentos.',
    'proprietario_estrutura_ip': 'Condomínio Exemplo',
    'caa_estrutura_ip': 'CAA III',
    'ano_construcao_estrutura_ip': '1998 (27 anos)',
    'conjunto_estrutural_ip': 'Conjunto Residencial Exemplo',
    'utilizacao_estrutura_ip': 'Residencial',
    'tipo_estrutura_ip': 'Concreto Armado',
    'tipologia_estrutural_ip': 'Pilar-Viga-Laje',
    'endereco_estrutura_ip': 'Rua Exemplo, 123 — Belo Horizonte, MG — CEP 30000-000',
    'lat_long_estrutura_ip': '-19.916681, -43.934493',
    'mapa_estrutura_ip': 'https://static-maps.yandex.ru/1.x/?ll=-43.934493,-19.916681&z=15&l=map&size=500,300&pt=-43.934493,-19.916681,pm2rdl',
  },
];

// Um exemplo por catálogo de Referencial (ver `catalogosReferencial`).
const Map<String, List<Map<String, String>>> dadosExemploReferencialPorCatalogo = {
  'tipos_estrutura': [
    {'nome': 'Concreto Armado', 'descricao': 'Estrutura composta por concreto e armadura de aço.'},
  ],
  'tipologias_estrutura': [
    {'nome': 'Pilar-Viga-Laje', 'descricao': 'Sistema estrutural convencional em pórticos.'},
  ],
  'utilizacoes_estrutura': [
    {'nome': 'Residencial', 'descricao': 'Uso destinado a moradia.'},
  ],
  'condicoes_local': [
    {'nome': 'Exposição a intempéries', 'descricao': 'Local sujeito à ação direta do clima.'},
  ],
  'tipologias_local': [
    {'nome': 'Garagem', 'descricao': 'Área de circulação e estacionamento de veículos.'},
  ],
  'tipos_elemento': [
    {'nome': 'Pilar', 'descricao': 'Elemento estrutural vertical de sustentação.', 'sistema': 'Sistema Estrutural'},
  ],
  'tipologias_elemento': [
    {'nome': 'Concreto Armado', 'descricao': 'Elemento em concreto com armadura de aço.'},
  ],
  'sistemas_habitacionais': [
    {'nome': 'Sistema Estrutural', 'descricao': 'Conjunto de elementos responsáveis pela estabilidade da edificação.'},
  ],
  'revestimentos_elemento': [
    {'nome': 'Pintura', 'descricao': 'Revestimento de acabamento em tinta.'},
  ],
  'anomalias': [
    {
      'nome': 'Fissura',
      'descricao': 'Abertura linear na superfície do concreto.',
      'categoria': 'integridade',
      'sistema_construtivo': 'Estrutural',
      'gravidade_valor': '4',
      'gravidade_descricao': 'Grave',
      'urgencia_valor': '3',
      'urgencia_descricao': 'Pouco urgente',
      'tendencia_valor': '3',
      'tendencia_descricao': 'Piora em médio prazo',
      'risco_tipo': 'Estrutural',
      'risco_descricao': 'Risco de propagação.',
      'risco_valor': 'Alto',
      'risco_major': '10%',
    },
  ],
};

const List<Map<String, String>> dadosExemploLocais = [
  {
    'nome_local': 'Térreo',
    'tipologia_local': 'Garagem',
    'condicao_local': 'Exposição a intempéries',
    'descricao_local': 'Área de circulação de veículos.',
  },
  {
    'nome_local': '1º Pavimento',
    'tipologia_local': 'Residencial',
    'condicao_local': 'Ambiente interno',
    'descricao_local': 'Apartamentos tipo.',
  },
];

const Map<String, String> dadosExemploRegistro = {
  'nome_registro': 'Registro 01',
  'descricao_registro': 'Fissura ativa observada na fachada norte.',
  'estrutura': 'Bloco A',
  'local': 'Térreo',
  'condicao_exposicao_registro': 'Exposição a intempéries',
  'sistema': 'Sistema Estrutural',
  'tipo_elemento': 'Pilar',
  'elemento': 'P101',
  'tipologia_elemento': 'Concreto Armado',
};

const List<Map<String, String>> dadosExemploAnomalias = [
  {
    'nome_anomalia': 'Fissura',
    'area_afetada': '30%',
    'majoracao': '10%',
    'gut': '68',
    'descricao_anomalia': 'Fissura ativa no concreto.',
    'tipo_risco': 'Estrutural',
    'classe_risco': 'Alto',
    'descricao_risco': 'Risco de propagação.',
  },
  {
    'nome_anomalia': 'Corrosão',
    'area_afetada': '15%',
    'majoracao': '5%',
    'gut': '42',
    'descricao_anomalia': 'Corrosão da armadura.',
    'tipo_risco': 'Durabilidade',
    'classe_risco': 'Médio',
    'descricao_risco': 'Perda de seção.',
  },
];
