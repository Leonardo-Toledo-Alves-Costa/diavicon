import 'package:diavicon/features/modelos_relatorios/models/modelo_relatorio_schema.dart';
import 'package:diavicon/features/modelos_relatorios/models/paleta_cores.dart';
import 'package:diavicon/features/modelos_relatorios/models/quadro_model.dart';
import 'package:diavicon/features/modelos_relatorios/widgets/quadro_preview.dart';
import 'package:flutter/material.dart';

import '../models/campos_registro_rdo.dart';
import '../models/modelo_rdo_schema.dart';

/// Prévia de ponta a ponta de um modelo de RDO, com dados de exemplo — mesmo
/// desenho de `ModeloRelatorioPreview`, só que sem Referencial/Registros
/// agrupados/Tabela resumo (RDO não tem essas seções).
class ModeloRdoPreview extends StatelessWidget {
  final ModeloRdoSchema schema;

  const ModeloRdoPreview({super.key, required this.schema});

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
            _buildBlocoRepetido('Equipe', schema.informacoesIniciais.equipe, camposEquipe, dadosExemploEquipe, borda),
            const SizedBox(height: 16),
            _buildBlocoRepetido(
                'Empresas no projeto', schema.informacoesIniciais.empresas, camposEmpresasProjeto, dadosExemploEmpresasProjeto, borda),
            const SizedBox(height: 16),
            _buildBlocoRepetido(
                'Estruturas do projeto', schema.informacoesIniciais.estruturas, camposEstruturasProjeto, dadosExemploEstruturasProjeto, borda),
          ],
        ),
      ));
    }

    if (schema.registros.ativo) {
      secoes.add(_buildCartao(
        'Registros (exemplo de 1 RDO)',
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
          child: QuadroPreview(
            quadro: schema.registros.quadro,
            dados: dadosExemploRegistroRdo,
            catalogo: camposRegistroRdo,
            decoracao: schema.decoracao,
            dadosSubListaExemplo: dadosExemploTurnosRdo,
            catalogoSubLista: camposTurnoRdo,
            borda: borda,
          ),
        ),
      ));
    }

    if (schema.galeria.ativo) {
      secoes.add(_buildCartao('Galeria', _buildGaleriaPreview()));
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

  Widget _buildGaleriaPreview() {
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
            decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(6), border: _borda),
            child: const Center(child: Icon(Icons.image_outlined, color: Colors.black26)),
          ),
        ),
        if (schema.galeria.mostrarDescricao) ...[
          const SizedBox(height: 6),
          Text('Descrição de exemplo da foto', style: TextStyle(fontSize: decoracao.tamanhoFonteRotulo, color: Colors.black45)),
        ],
      ],
    );
  }
}
