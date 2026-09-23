import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/foto_ensaio.dart';
import '../models/bi_data_point.dart';
import '../models/campos_bi_catalogo.dart';
import '../models/dashboard_card_model.dart';
import '../utils/classificadores_bi.dart';
import 'bi_badge_card.dart';
import 'bi_chart_engine.dart';
import 'bi_grafico_personalizado.dart';
import 'bi_monte_carlo_card.dart';
import 'bi_tabela_card.dart';
import 'bi_tema.dart';

/// Um card do grid, já com dados resolvidos — usado tanto no modo leitura
/// quanto no modo edição (que mostra o menu do card no cabeçalho).
class DashboardCardView extends StatelessWidget {
  final DashboardCardModel card;
  final List<BiDataPoint>? pontos;
  final List<BiDataPoint>? pontosSecundarios;

  /// Cards de varias series (grafico personalizado, tabela, badge).
  final Map<String, List<BiDataPoint>>? series;
  final List<Map<String, String?>>? fotosGaleria;
  final bool carregando;
  final bool modoEdicao;
  final VoidCallback? onAbrirMenu;

  const DashboardCardView({
    super.key,
    required this.card,
    this.pontos,
    this.pontosSecundarios,
    this.series,
    this.fotosGaleria,
    this.carregando = false,
    this.modoEdicao = false,
    this.onAbrirMenu,
  });

  /// (título, subtítulo). O subtítulo diz de onde vem o dado (o ensaio) —
  /// antes ia tudo numa linha só, cortada no meio.
  (String, String?) get _titulos {
    switch (card.tipo) {
      case TipoCardBi.texto:
      case TipoCardBi.espaco:
        return ('', null);
      case TipoCardBi.badge:
        return (buscarClassificadorBi(card.classificacaoId)?.rotulo ?? 'Classificação', 'Classificação qualitativa');
      case TipoCardBi.tabela:
        return ('Tabela', '${card.colunas.length} ${card.colunas.length == 1 ? 'coluna' : 'colunas'}');
      case TipoCardBi.monteCarlo:
        return ('Monte Carlo', card.monteCarlo?.analise.rotulo);
      case TipoCardBi.galeria:
        final fonte = card.galeriaFonteChave != null ? buscarFonteBi(card.galeriaFonteChave!) : null;
        return ('Galeria', fonte?.rotulo ?? 'Geral');
      case TipoCardBi.grafico:
        if (card.tipoGrafico == TipoGraficoBi.personalizado) {
          return (card.series.map((s) => s.nome.isEmpty ? s.valor.rotuloPadrao() : s.nome).join(' · '), 'Gráfico personalizado');
        }
        final campo = card.fonteChave != null && card.campoX != null ? buscarCampoBi(card.fonteChave!, card.campoX!) : null;
        final fonte = card.fonteChave != null ? buscarFonteBi(card.fonteChave!) : null;
        if (campo == null || fonte == null) return (card.tipoGrafico?.rotulo ?? 'Gráfico', null);
        final campoY = card.campoY != null ? buscarCampoBi(card.fonteChave!, card.campoY!) : null;
        final titulo = campoY != null && card.tipoGrafico == TipoGraficoBi.barraLinha2Eixos ? '${campo.rotulo} × ${campoY.rotulo}' : campo.rotulo;
        return (titulo, fonte.rotulo);
    }
  }

  IconData get _icone => switch (card.tipo) {
        TipoCardBi.badge => Icons.verified_outlined,
        TipoCardBi.tabela => Icons.table_chart_outlined,
        TipoCardBi.monteCarlo => Icons.casino_outlined,
        TipoCardBi.galeria => Icons.photo_library_outlined,
        TipoCardBi.texto => Icons.notes_rounded,
        TipoCardBi.espaco => Icons.crop_free,
        TipoCardBi.grafico => switch (card.tipoGrafico) {
            TipoGraficoBi.pizza => Icons.pie_chart_outline_rounded,
            TipoGraficoBi.linhas => Icons.show_chart_rounded,
            TipoGraficoBi.boxplot => Icons.candlestick_chart_outlined,
            TipoGraficoBi.gauss => Icons.stacked_line_chart_rounded,
            TipoGraficoBi.barraLinha2Eixos => Icons.multiline_chart_rounded,
            _ => Icons.bar_chart_rounded,
          },
      };

  static const _carregandoWidget = Center(
    child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
  );

  @override
  Widget build(BuildContext context) {
    if (card.tipo == TipoCardBi.espaco) {
      return modoEdicao
          ? _moldura(
              context,
              const VazioBi(texto: 'Espaço vazio', icone: Icons.crop_free),
              tracejada: true,
            )
          : const SizedBox.shrink();
    }

    Widget conteudo;
    switch (card.tipo) {
      case TipoCardBi.texto:
        final texto = (card.textoConteudo ?? '').trim();
        conteudo = texto.isEmpty
            ? const VazioBi(texto: 'Texto vazio', icone: Icons.notes_rounded)
            : SingleChildScrollView(
                child: Text(texto, style: const TextStyle(fontSize: 14, color: kBiTexto, height: 1.5)),
              );
        break;
      case TipoCardBi.galeria:
        conteudo = _buildGaleria(context);
        break;
      case TipoCardBi.badge:
        final classificador = buscarClassificadorBi(card.classificacaoId);
        conteudo = carregando
            ? _carregandoWidget
            : classificador == null
                ? const VazioBi(texto: 'Classificação não encontrada', icone: Icons.help_outline)
                : BiBadgeCard(classificador: classificador, series: series ?? const {});
        break;
      case TipoCardBi.monteCarlo:
        conteudo = carregando ? _carregandoWidget : BiMonteCarloCard(card: card, series: series ?? const {});
        break;
      case TipoCardBi.tabela:
        conteudo = carregando ? _carregandoWidget : BiTabelaCard(card: card, series: series ?? const {});
        break;
      case TipoCardBi.grafico:
      case TipoCardBi.espaco:
        conteudo = carregando
            ? _carregandoWidget
            : card.tipoGrafico == TipoGraficoBi.personalizado
                ? BiGraficoPersonalizado(card: card, series: series ?? const {})
                : BiChartWidget(card: card, pontos: pontos ?? const [], pontosSecundarios: pontosSecundarios ?? const []);
        break;
    }

    final (titulo, subtitulo) = _titulos;
    final temCabecalho = titulo.isNotEmpty || (modoEdicao && onAbrirMenu != null);

    return _moldura(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (temCabecalho)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (titulo.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(7)),
                      child: Icon(_icone, size: 14, color: const Color(0xFFA85A00)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (titulo.isNotEmpty)
                          Tooltip(
                            message: titulo,
                            waitDuration: const Duration(milliseconds: 500),
                            child: Text(
                              titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kBiTinta),
                            ),
                          ),
                        if (subtitulo != null && subtitulo.isNotEmpty)
                          Text(
                            subtitulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: kBiSuave),
                          ),
                      ],
                    ),
                  ),
                  if (modoEdicao && onAbrirMenu != null)
                    IconButton(
                      tooltip: 'Opções do card',
                      visualDensity: VisualDensity.compact,
                      onPressed: onAbrirMenu,
                      icon: const Icon(Icons.more_vert, size: 18, color: kBiTexto),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, temCabecalho ? 0 : 10, 8, 8),
              child: conteudo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGaleria(BuildContext context) {
    final fotos = (fotosGaleria ?? const []).where((f) => (f['url'] ?? '').isNotEmpty).toList();
    if (carregando) return _carregandoWidget;
    if (fotos.isEmpty) return const VazioBi(texto: 'Sem fotos', icone: Icons.photo_library_outlined);
    final ampliadas = [for (final f in fotos) ResizeImage(StorageNetworkImage(f['url']!), width: 1800, policy: ResizeImagePolicy.fit)];
    final legendas = [for (final f in fotos) f['legenda'] ?? f['descricao'] ?? f['titulo']];
    final conter = card.galeriaAjuste == AjusteImagemBi.conter;
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: card.galeriaColunas, crossAxisSpacing: 6, mainAxisSpacing: 6),
      itemCount: fotos.length,
      itemBuilder: (context, i) => Material(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => abrirFotoTelaCheia(context, ampliadas, inicial: i, legendas: legendas),
          child: Image(
            image: ResizeImage(StorageNetworkImage(fotos[i]['url']!), width: 480),
            fit: conter ? BoxFit.contain : BoxFit.cover,
            errorBuilder: (c, e, s) => const Icon(Icons.broken_image_outlined, color: kBiSuave, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _moldura(BuildContext context, Widget child, {bool tracejada = false}) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tracejada ? Colors.transparent : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: modoEdicao ? AppColors.primary.withValues(alpha: 0.45) : kBiBorda,
          width: modoEdicao ? 1.5 : 1,
        ),
      ),
      child: child,
    );
  }
}
