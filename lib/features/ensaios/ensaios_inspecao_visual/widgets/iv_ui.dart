import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/foto_ensaio.dart';

/// Peças visuais da Inspeção Visual, iguais no app e no web app. Sem
/// dependência do kit desktop do web: o layout responde à largura
/// disponível (LayoutBuilder), então o mesmo arquivo serve aos dois.

const kIvTinta = Color(0xFF2E3033);
const kIvTexto = Color(0xFF4A4C4F);
const kIvSuave = Color(0xFF7A7C80);
const kIvBorda = Color(0xFFE6E6E6);
const kIvFundo = Color(0xFFF6F5F2);
const kIvLaranjaTexto = Color(0xFFA85A00);

/// Largura a partir da qual as telas usam colunas lado a lado.
const double kIvLarguraDuasColunas = 900;

// ---------------------------------------------------------------------------
// Faixas do G.U.T
// ---------------------------------------------------------------------------

/// Faixa de criticidade de uma pontuação G.U.T, só para leitura rápida
/// (cor + rótulo). A referência é o produto G×U×T de uma anomalia (1 a 125).
/// Os limites ficam aqui, num lugar só, para a equipe técnica ajustar.
class FaixaGut {
  final String rotulo;
  final Color cor;
  final Color fundo;

  const FaixaGut._(this.rotulo, this.cor, this.fundo);

  static const semRisco = FaixaGut._('Sem anomalias', Color(0xFF6B7280), Color(0xFFF1F2F4));
  static const baixa = FaixaGut._('Baixa', Color(0xFF2E7D32), Color(0xFFE8F5E9));
  static const moderada = FaixaGut._('Moderada', Color(0xFFB26A00), Color(0xFFFFF4E0));
  static const alta = FaixaGut._('Alta', Color(0xFFD84315), Color(0xFFFBE9E7));
  static const critica = FaixaGut._('Crítica', Color(0xFFB3261E), Color(0xFFFDECEA));

  static FaixaGut de(double gut) {
    if (gut <= 0) return semRisco;
    if (gut < 10) return baixa;
    if (gut < 40) return moderada;
    if (gut < 100) return alta;
    return critica;
  }
}

String formatarGut(double v) {
  if (v >= 1000) return v.toStringAsFixed(0);
  if (v >= 100) return v.toStringAsFixed(1);
  return v.toStringAsFixed(2);
}

/// Selo "G.U.T 18.00" colorido pela faixa.
class SeloGut extends StatelessWidget {
  final double valor;
  final bool grande;
  final bool mostrarFaixa;

  const SeloGut({super.key, required this.valor, this.grande = false, this.mostrarFaixa = false});

  @override
  Widget build(BuildContext context) {
    final f = FaixaGut.de(valor);
    return Semantics(
      label: 'G.U.T ${formatarGut(valor)}, criticidade ${f.rotulo}',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: grande ? 12 : 8, vertical: grande ? 6 : 3),
        decoration: BoxDecoration(color: f.fundo, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: grande ? 16 : 12, color: f.cor),
            const SizedBox(width: 4),
            Text('G.U.T ', style: TextStyle(fontSize: grande ? 12 : 10, color: f.cor, fontWeight: FontWeight.w600)),
            Text(
              formatarGut(valor),
              style: TextStyle(fontSize: grande ? 16 : 11, color: f.cor, fontWeight: FontWeight.w800),
            ),
            if (mostrarFaixa) ...[
              const SizedBox(width: 6),
              Text('· ${f.rotulo}', style: TextStyle(fontSize: grande ? 12 : 10, color: f.cor, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Etiqueta cinza/colorida (tipo de elemento, elemento, anomalia...).
class EtiquetaIv extends StatelessWidget {
  final String texto;
  final IconData? icone;
  final Color cor;
  final Color fundo;

  const EtiquetaIv({
    super.key,
    required this.texto,
    this.icone,
    this.cor = kIvTexto,
    this.fundo = const Color(0xFFF1F1F1),
  });

  const EtiquetaIv.anomalia({super.key, required this.texto})
      : icone = Icons.report_gmailerrorred_outlined,
        cor = const Color(0xFFB3261E),
        fundo = const Color(0xFFFDECEA);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[Icon(icone, size: 12, color: cor), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cor),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

/// Corpo rolável com largura máxima e margens que crescem com a tela.
class CorpoIv extends StatelessWidget {
  final List<Widget> children;
  final double larguraMaxima;
  final EdgeInsets? preenchimento;
  final ScrollController? controller;

  const CorpoIv({super.key, required this.children, this.larguraMaxima = 1180, this.preenchimento, this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final lateral = c.maxWidth < 600 ? 16.0 : 24.0;
        final sobra = ((c.maxWidth - larguraMaxima) / 2).clamp(0.0, double.infinity);
        return SingleChildScrollView(
          controller: controller,
          padding: preenchimento ?? EdgeInsets.fromLTRB(lateral + sobra, 20, lateral + sobra, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        );
      },
    );
  }
}

/// Cabeçalho da tela: trilha (projeto › estrutura › ...), título e ações.
class CabecalhoIv extends StatelessWidget {
  final List<String> trilha;
  final String titulo;
  final String? subtitulo;
  final List<Widget> acoes;

  const CabecalhoIv({super.key, this.trilha = const [], required this.titulo, this.subtitulo, this.acoes = const []});

  @override
  Widget build(BuildContext context) {
    final trilhaVisivel = trilha.where((t) => t.trim().isNotEmpty).toList();
    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (trilhaVisivel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              trilhaVisivel.join('  ›  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: kIvSuave),
            ),
          ),
        Text(titulo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kIvTinta, height: 1.2)),
        if (subtitulo != null && subtitulo!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitulo!, style: const TextStyle(fontSize: 13, color: kIvSuave, height: 1.35)),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, c) {
        if (acoes.isEmpty) return textos;
        if (c.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [textos, const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: acoes)],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: textos),
            const SizedBox(width: 16),
            Wrap(spacing: 8, runSpacing: 8, children: acoes),
          ],
        );
      },
    );
  }
}

/// Botão de ação do cabeçalho (primário laranja ou contornado).
class BotaoIv extends StatelessWidget {
  final String rotulo;
  final IconData icone;
  final VoidCallback? aoTocar;
  final bool primario;
  final bool perigo;

  const BotaoIv({super.key, required this.rotulo, required this.icone, this.aoTocar, this.primario = false, this.perigo = false});

  @override
  Widget build(BuildContext context) {
    final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    const pad = EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    if (primario) {
      return FilledButton.icon(
        onPressed: aoTocar,
        style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: kIvTinta, shape: forma, padding: pad),
        icon: Icon(icone, size: 18),
        label: Text(rotulo, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
    }
    final cor = perigo ? const Color(0xFFB3261E) : kIvTinta;
    return OutlinedButton.icon(
      onPressed: aoTocar,
      style: OutlinedButton.styleFrom(
        foregroundColor: cor,
        backgroundColor: Colors.white,
        side: BorderSide(color: perigo ? const Color(0xFFF5C2C0) : kIvBorda),
        shape: forma,
        padding: pad,
      ),
      icon: Icon(icone, size: 18),
      label: Text(rotulo, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

/// Cartão branco com título opcional.
class SecaoIv extends StatelessWidget {
  final String? titulo;
  final String? descricao;
  final IconData? icone;
  final Widget? acao;
  final Widget child;
  final EdgeInsets preenchimento;

  const SecaoIv({
    super.key,
    this.titulo,
    this.descricao,
    this.icone,
    this.acao,
    required this.child,
    this.preenchimento = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: preenchimento,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kIvBorda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (titulo != null) ...[
            Row(
              children: [
                if (icone != null) ...[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icone, size: 16, color: kIvLaranjaTexto),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kIvTinta)),
                      if (descricao != null)
                        Text(descricao!, style: const TextStyle(fontSize: 12, color: kIvSuave, height: 1.35)),
                    ],
                  ),
                ),
                if (acao != null) acao!,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// Uma coluna em telas estreitas, duas lado a lado nas largas.
class DuasColunasIv extends StatelessWidget {
  final List<Widget> esquerda;
  final List<Widget> direita;
  final int flexEsquerda;
  final int flexDireita;

  const DuasColunasIv({super.key, required this.esquerda, required this.direita, this.flexEsquerda = 5, this.flexDireita = 6});

  @override
  Widget build(BuildContext context) {
    Widget coluna(List<Widget> itens) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (var i = 0; i < itens.length; i++) ...[if (i > 0) const SizedBox(height: 16), itens[i]]],
        );
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < kIvLarguraDuasColunas) return coluna([...esquerda, ...direita]);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: flexEsquerda, child: coluna(esquerda)),
            const SizedBox(width: 20),
            Expanded(flex: flexDireita, child: coluna(direita)),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Indicadores
// ---------------------------------------------------------------------------

class IndicadorIv {
  final IconData icone;
  final String rotulo;
  final String valor;
  final double? gut;

  const IndicadorIv({required this.icone, required this.rotulo, required this.valor}) : gut = null;

  /// Indicador de pontuação G.U.T, colorido pela faixa.
  IndicadorIv.gut(double this.gut, {this.rotulo = 'G.U.T'})
      : icone = Icons.warning_amber_rounded,
        valor = formatarGut(gut);
}

class IndicadoresIv extends StatelessWidget {
  final List<IndicadorIv> itens;

  const IndicadoresIv({super.key, required this.itens});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const espaco = 10.0;
        final porLinha = c.maxWidth >= 720 ? itens.length : (itens.length <= 2 ? itens.length : 2);
        final largura = (c.maxWidth - espaco * (porLinha - 1)) / porLinha;
        return Wrap(
          spacing: espaco,
          runSpacing: espaco,
          children: [for (final i in itens) SizedBox(width: largura, child: _CartaoIndicador(item: i))],
        );
      },
    );
  }
}

class _CartaoIndicador extends StatelessWidget {
  final IndicadorIv item;

  const _CartaoIndicador({required this.item});

  @override
  Widget build(BuildContext context) {
    final faixa = item.gut != null ? FaixaGut.de(item.gut!) : null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: faixa?.fundo ?? Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: faixa != null ? faixa.cor.withValues(alpha: 0.25) : kIvBorda),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: faixa != null ? Colors.white : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icone, size: 20, color: faixa?.cor ?? kIvLaranjaTexto),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.valor,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: faixa?.cor ?? kIvTinta),
                  ),
                ),
                Text(
                  faixa != null ? '${item.rotulo} · ${faixa.rotulo}' : item.rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kIvSuave),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Busca e estados
// ---------------------------------------------------------------------------

class CampoBuscaIv extends StatelessWidget {
  final TextEditingController controller;
  final String dica;
  final ValueChanged<String> aoMudar;

  const CampoBuscaIv({super.key, required this.controller, required this.dica, required this.aoMudar});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: aoMudar,
      decoration: InputDecoration(
        hintText: dica,
        hintStyle: const TextStyle(color: kIvSuave, fontSize: 14),
        prefixIcon: const Icon(Icons.search, color: kIvSuave),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpar',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  controller.clear();
                  aoMudar('');
                },
              ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kIvBorda)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kIvBorda)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
  }
}

class EstadoVazioIv extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String? texto;
  final Widget? acao;

  const EstadoVazioIv({super.key, required this.icone, required this.titulo, this.texto, this.acao});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kIvBorda),
      ),
      child: Column(
        children: [
          Icon(icone, size: 40, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kIvTinta)),
          if (texto != null) ...[
            const SizedBox(height: 4),
            Text(texto!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: kIvSuave, height: 1.4)),
          ],
          if (acao != null) ...[const SizedBox(height: 14), acao!],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cartões de lista
// ---------------------------------------------------------------------------

/// Local inspecionado, com barra da participação no G.U.T da inspeção.
class CartaoLocalIv extends StatelessWidget {
  final String nome;
  final int registros;
  final double gut;

  /// 0 a 1: G.U.T do local em relação ao maior local da inspeção.
  final double proporcaoGut;
  final VoidCallback aoTocar;

  const CartaoLocalIv({
    super.key,
    required this.nome,
    required this.registros,
    required this.gut,
    required this.proporcaoGut,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    final f = FaixaGut.de(gut);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: aoTocar,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kIvBorda)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.place_outlined, size: 20, color: kIvLaranjaTexto),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kIvTinta)),
                        Text(
                          registros == 1 ? '1 registro' : '$registros registros',
                          style: const TextStyle(fontSize: 12, color: kIvSuave),
                        ),
                      ],
                    ),
                  ),
                  SeloGut(valor: gut),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: kIvSuave),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: proporcaoGut.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF1F1F1),
                  color: f.cor,
                  semanticsLabel: 'Participação no G.U.T da inspeção',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Registro de inspeção (ponto) com foto de capa, elemento, anomalias e G.U.T.
class CartaoRegistroIv extends StatelessWidget {
  final String titulo;
  final String? descricao;
  final String? capaUrl;
  final int qtdFotos;
  final List<String> etiquetas;
  final List<String> anomalias;
  final double gut;
  final VoidCallback aoTocar;
  final VoidCallback? aoExcluir;

  const CartaoRegistroIv({
    super.key,
    required this.titulo,
    this.descricao,
    this.capaUrl,
    this.qtdFotos = 0,
    this.etiquetas = const [],
    this.anomalias = const [],
    required this.gut,
    required this.aoTocar,
    this.aoExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final f = FaixaGut.de(gut);
    final capa = capaUrl != null && capaUrl!.isNotEmpty ? ResizeImage(StorageNetworkImage(capaUrl!), width: 480) : null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: aoTocar,
        onLongPress: aoExcluir,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kIvBorda),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Faixa lateral na cor da criticidade: dá para varrer a lista
                // e achar os registros graves sem ler número por número.
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: f.cor,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FotoEnsaio(imagem: capa, proporcao: 1, larguraMaxima: null, raio: 10, ampliarAoTocar: false, aoTocar: aoTocar),
                        if (qtdFotos > 1)
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.photo_library_outlined, size: 11, color: Colors.white),
                                  const SizedBox(width: 3),
                                  Text('$qtdFotos', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                titulo,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kIvTinta),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SeloGut(valor: gut),
                          ],
                        ),
                        if (descricao != null && descricao!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(descricao!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: kIvSuave, height: 1.35)),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final e in etiquetas) EtiquetaIv(texto: e, icone: Icons.view_in_ar_outlined),
                            for (final a in anomalias.take(2)) EtiquetaIv.anomalia(texto: a),
                            if (anomalias.length > 2) EtiquetaIv(texto: '+${anomalias.length - 2} anomalias'),
                            if (anomalias.isEmpty) const EtiquetaIv(texto: 'Sem anomalias', icone: Icons.check_circle_outline, cor: Color(0xFF2E7D32), fundo: Color(0xFFE8F5E9)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (aoExcluir != null)
                  PopupMenuButton<String>(
                    tooltip: 'Mais ações',
                    icon: const Icon(Icons.more_vert, color: kIvSuave),
                    onSelected: (v) {
                      if (v == 'abrir') aoTocar();
                      if (v == 'excluir') aoExcluir!();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'abrir', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Abrir / editar'), contentPadding: EdgeInsets.zero)),
                      PopupMenuItem(
                        value: 'excluir',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: Color(0xFFB3261E)),
                          title: Text('Excluir registro', style: TextStyle(color: Color(0xFFB3261E))),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grade responsiva de cartões (1 coluna no celular, 2 ou 3 em telas largas).
class GradeIv extends StatelessWidget {
  final List<Widget> filhos;
  final double larguraMinima;

  const GradeIv({super.key, required this.filhos, this.larguraMinima = 420});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const espaco = 12.0;
        final colunas = ((c.maxWidth + espaco) / (larguraMinima + espaco)).floor().clamp(1, 3);
        final largura = (c.maxWidth - espaco * (colunas - 1)) / colunas;
        return Wrap(
          spacing: espaco,
          runSpacing: espaco,
          children: [for (final f in filhos) SizedBox(width: largura, child: f)],
        );
      },
    );
  }
}

/// Seletor segmentado em "pílulas" (tipo e classe do risco, ordenação...).
class PilulasIv<T> extends StatelessWidget {
  final List<(T, String)> opcoes;
  final T valor;
  final ValueChanged<T> aoMudar;
  final Color Function(T)? corDe;

  const PilulasIv({super.key, required this.opcoes, required this.valor, required this.aoMudar, this.corDe});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (v, rotulo) in opcoes)
          ChoiceChip(
            label: Text(rotulo),
            selected: v == valor,
            onSelected: (_) => aoMudar(v),
            showCheckmark: false,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: v == valor ? Colors.white : kIvTexto,
            ),
            selectedColor: corDe?.call(v) ?? AppColors.primary,
            backgroundColor: Colors.white,
            side: BorderSide(color: v == valor ? Colors.transparent : kIvBorda),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
      ],
    );
  }
}
