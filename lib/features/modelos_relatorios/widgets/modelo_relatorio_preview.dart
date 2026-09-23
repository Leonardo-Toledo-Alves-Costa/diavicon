import 'package:flutter/material.dart';

import '../models/ensaio_modelo_config.dart';
import '../models/modelo_relatorio_schema.dart';
import '../models/paleta_cores.dart';
import '../models/quadro_model.dart';
import 'quadro_preview.dart';

// Prévia de ponta a ponta do modelo (só as seções ativas), com dados de
// exemplo — mostra como o relatório fica montado, sem precisar gerar um PDF.
// Já aplica a decoração global (bordas das células e título das seções). Os
// campos/dados de exemplo de "Registros" e "Registros agrupados" variam por
// tipo de ensaio — ver EnsaioModeloConfig.
class ModeloRelatorioPreview extends StatelessWidget {
  final ModeloRelatorioSchema schema;
  final String tipoEnsaioNome;

  const ModeloRelatorioPreview({super.key, required this.schema, required this.tipoEnsaioNome});

  EnsaioModeloConfig get _config => resolverEnsaioModeloConfig(tipoEnsaioNome) ?? ensaiosModeloConfig['Inspeção Visual']!;

  Border? get _borda {
    if (!schema.decoracao.bordaAtiva) return null;
    return Border.all(color: corDaPaleta(schema.decoracao.bordaCor), width: schema.decoracao.bordaEspessura.largura);
  }

  @override
  Widget build(BuildContext context) {
    final borda = _borda;
    final secoes = <Widget>[];

    if (schema.cabecalho.ativo) {
      secoes.add(_buildCartao(
        'Cabeçalho',
        QuadroPreview(
          quadro: schema.cabecalho.quadro,
          dados: dadosExemploCabecalho,
          catalogo: camposCabecalho,
          decoracao: schema.decoracao,
          borda: borda,
        ),
      ));
    }
    if (schema.informacoesIniciais.ativo) {
      secoes.add(_buildCartao(
        'Informações iniciais',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBlocoRepetido('Informação da equipe', schema.informacoesIniciais.equipe, camposEquipe, dadosExemploEquipe, borda),
            const SizedBox(height: 16),
            _buildBlocoRepetido(
                'Informação de empresas no projeto', schema.informacoesIniciais.empresas, camposEmpresasProjeto, dadosExemploEmpresasProjeto, borda),
            const SizedBox(height: 16),
            _buildBlocoRepetido(
                'Estruturas no projeto', schema.informacoesIniciais.estruturas, camposEstruturasProjeto, dadosExemploEstruturasProjeto, borda),
            const SizedBox(height: 16),
            _buildBlocoRepetido('Locais da estrutura', schema.informacoesIniciais.locais, camposLocal, dadosExemploLocais, borda),
          ],
        ),
      ));
    }
    if (schema.referencial.ativo && schema.referencial.blocos.isNotEmpty) {
      secoes.add(_buildCartao(
        'Referencial',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final bloco in schema.referencial.blocos) ...[
              _buildBlocoReferencial(bloco, borda),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ));
    }
    if (schema.registros.ativo) {
      secoes.add(_buildCartao(
        'Registros (exemplo de 1 registro)',
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
          child: QuadroPreview(
            quadro: schema.registros.quadro,
            dados: _config.dadosExemploRegistro,
            catalogo: _config.camposRegistro,
            decoracao: schema.decoracao,
            dadosAnomaliasExemplo: tipoEnsaioNome == 'Inspeção Visual' ? dadosExemploAnomalias : const [],
            dadosSubListaExemplo: _config.dadosExemploSubLista,
            catalogoSubLista: _config.camposSubListaRegistro,
            borda: borda,
          ),
        ),
      ));
    }
    if (_config.suportaAnaliseElementos && schema.analiseElementos.ativo) {
      secoes.add(_buildCartao(
        'Análise de Elementos (exemplo de 1 elemento)',
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
          child: QuadroPreview(
            quadro: schema.analiseElementos.quadro,
            dados: _config.dadosExemploAnaliseElemento,
            catalogo: _config.camposAnaliseElementos,
            decoracao: schema.decoracao,
            borda: borda,
          ),
        ),
      ));
    }
    if (_config.suportaRegistrosAgrupados && schema.registrosAgrupados.ativo) {
      secoes.add(_buildCartao('Registros agrupados (exemplo de 1 grupo)', _buildRegistrosAgrupadosPreview(borda)));
    }
    if (schema.galeria.ativo) {
      secoes.add(_buildCartao('Galeria', _buildGaleriaPreview(borda)));
    }
    if (schema.resumo.ativo) {
      secoes.add(_buildCartao('Tabela resumo de registros', _buildResumoPreview()));
    }

    if (secoes.isEmpty) {
      return const Center(child: Text('Nenhuma seção ativa.', style: TextStyle(color: Colors.grey)));
    }

    return ListView(padding: const EdgeInsets.all(16), children: secoes);
  }

  Widget _buildBlocoRepetido(
    String titulo,
    Quadro quadro,
    List<CampoCatalogo> catalogo,
    List<Map<String, String>> repeticoesExemplo,
    Border? borda,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: TextStyle(fontSize: schema.decoracao.tamanhoFonteRotulo, fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 6),
        for (final dados in repeticoesExemplo)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
            child: QuadroPreview(quadro: quadro, dados: dados, catalogo: catalogo, decoracao: schema.decoracao, borda: borda),
          ),
      ],
    );
  }

  Widget _buildRegistrosAgrupadosPreview(Border? borda) {
    final config = schema.registrosAgrupados;
    final decoracao = schema.decoracao;
    final dados = _config.dadosExemploAgrupado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Agrupado por: ${config.hierarquia.rotulo}', style: TextStyle(fontSize: decoracao.tamanhoFonteRotulo, color: Colors.black54)),
        const SizedBox(height: 8),
        if (config.colunas.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 32,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 32,
              columns: [
                for (final c in config.colunas)
                  DataColumn(label: Text(c.rotulo, style: TextStyle(fontSize: decoracao.tamanhoFonteRotulo, fontWeight: FontWeight.bold))),
              ],
              rows: [
                DataRow(cells: [
                  for (final c in config.colunas)
                    DataCell(Text(dados[c.campoVinculado] ?? '-', style: TextStyle(fontSize: decoracao.tamanhoFonteValor))),
                ]),
              ],
            ),
          ),
        if (config.graficos.linhas.isNotEmpty) ...[
          const SizedBox(height: 12),
          QuadroPreview(
            quadro: config.graficos,
            dados: const {},
            catalogo: _config.camposGraficosAgrupados,
            decoracao: decoracao,
            borda: borda,
          ),
        ],
      ],
    );
  }

  Widget _buildBlocoReferencial(ReferencialBlocoConfig bloco, Border? borda) {
    final catalogo = buscarCatalogoReferencial(bloco.catalogo);
    if (catalogo == null) return const SizedBox.shrink();
    final dadosExemplo = dadosExemploReferencialPorCatalogo[bloco.catalogo] ?? const [];
    return _buildBlocoRepetido(catalogo.rotulo, bloco.quadro, catalogo.campos, dadosExemplo, borda);
  }

  Widget _buildCartao(String titulo, Widget conteudo) {
    final decoracao = schema.decoracao;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
      child: Column(
        crossAxisAlignment: _crossAxisPara(decoracao.alinhamentoTitulo),
        children: [
          if (decoracao.mostrarTitulos) ...[
            Text(
              titulo,
              textAlign: _textAlignPara(decoracao.alinhamentoTitulo),
              style: TextStyle(fontSize: decoracao.tamanhoFonteTitulo, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.3),
            ),
            const SizedBox(height: 10),
          ],
          conteudo,
        ],
      ),
    );
  }

  CrossAxisAlignment _crossAxisPara(AlinhamentoTitulo a) {
    switch (a) {
      case AlinhamentoTitulo.esquerda:
      case AlinhamentoTitulo.justificado:
        return CrossAxisAlignment.start;
      case AlinhamentoTitulo.centro:
        return CrossAxisAlignment.center;
      case AlinhamentoTitulo.direita:
        return CrossAxisAlignment.end;
    }
  }

  TextAlign _textAlignPara(AlinhamentoTitulo a) {
    switch (a) {
      case AlinhamentoTitulo.esquerda:
        return TextAlign.left;
      case AlinhamentoTitulo.centro:
        return TextAlign.center;
      case AlinhamentoTitulo.direita:
        return TextAlign.right;
      case AlinhamentoTitulo.justificado:
        return TextAlign.justify;
    }
  }

  Widget _buildGaleriaPreview(Border? borda) {
    final decoracao = schema.decoracao;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: schema.galeria.colunas,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: schema.galeria.colunas,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            mainAxisExtent: schema.galeria.alturaImagem,
          ),
          itemBuilder: (context, index) => Container(
            decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(6), border: borda),
            child: const Center(child: Icon(Icons.image_outlined, color: Colors.black26)),
          ),
        ),
        if (schema.galeria.mostrarDescricao) ...[
          const SizedBox(height: 6),
          Text('Legenda de exemplo da foto', style: TextStyle(fontSize: decoracao.tamanhoFonteRotulo, color: Colors.black45)),
        ],
      ],
    );
  }

  Widget _buildResumoPreview() {
    if (schema.resumo.colunas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Nenhuma coluna configurada.', style: TextStyle(fontSize: 12, color: Colors.black38)),
      );
    }

    const linhasExemplo = [
      {'local': 'Térreo', 'classe_risco': 'Alto', 'quantidade': '3'},
      {'local': '1º Pavimento', 'classe_risco': 'Médio', 'quantidade': '5'},
    ];
    final decoracao = schema.decoracao;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 32,
        columns: [
          for (final c in schema.resumo.colunas)
            DataColumn(label: Text(c.rotulo, style: TextStyle(fontSize: decoracao.tamanhoFonteRotulo, fontWeight: FontWeight.bold))),
        ],
        rows: [
          for (final linha in linhasExemplo)
            DataRow(cells: [
              for (final c in schema.resumo.colunas)
                DataCell(Text(linha[c.campoVinculado ?? 'quantidade'] ?? '-', style: TextStyle(fontSize: decoracao.tamanhoFonteValor))),
            ]),
        ],
      ),
    );
  }
}
