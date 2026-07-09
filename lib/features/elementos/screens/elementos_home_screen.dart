import 'package:diavicon/features/ensaios/screens/pontos_ensaio_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // 🔥 Importação do SVG
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/compact_button.dart';
import '../../../core/widgets/compact_search_bar.dart';
import '../../../core/widgets/menu_app_bar.dart';
import '../widgets/incluir_elemento_estrutural_sheet.dart';
import '../widgets/right_menu_bar.dart';

class ElementosHomeScreen extends StatefulWidget {
  const ElementosHomeScreen({
    super.key,
    this.onOpenInformacoes,
    this.onOpenRelatorios,
    this.onNovoEnsaio,
    this.onSearchChanged,
    this.elementoId,
    this.estruturaId,
    this.projetoId,
    this.titulo,
    this.tipo,
    this.local,
    this.imageUrl,
  });

  final VoidCallback? onOpenInformacoes;
  final VoidCallback? onOpenRelatorios;
  final VoidCallback? onNovoEnsaio;
  final ValueChanged<String>? onSearchChanged;
  final String? elementoId;
  final String? estruturaId;
  final String? projetoId;
  final String? titulo;
  final String? tipo;
  final String? local;
  final String? imageUrl;

  @override
  State<ElementosHomeScreen> createState() => _ElementosHomeScreenState();
}

class _ElementosHomeScreenState extends State<ElementosHomeScreen> {
  final GlobalKey<RightMenuBarState> _rightMenuKey =
      GlobalKey<RightMenuBarState>();

  void _openIncluirElementoSheet() {
    if (widget.onNovoEnsaio != null) {
      widget.onNovoEnsaio!();
      return;
    }
    showIncluirElementoEstruturalSheet<void>(
      context: context,
      estruturaId: widget.estruturaId,
    );
  }

  Map<String, dynamic> get _routeExtra => <String, dynamic>{
    if (widget.projetoId != null) 'projetoId': widget.projetoId,
    if (widget.estruturaId != null) 'estruturaId': widget.estruturaId,
    if (widget.elementoId != null) 'elementoId': widget.elementoId,
    if (widget.titulo != null) 'titulo': widget.titulo,
    if (widget.tipo != null) 'tipo': widget.tipo,
    if (widget.local != null) 'local': widget.local,
    if (widget.imageUrl != null) 'imageUrl': widget.imageUrl,
  };

  String? get _basePath {
    final estruturaId = widget.estruturaId;
    final elementoId = widget.elementoId;
    if (estruturaId == null || elementoId == null) return null;
    return '/estruturas/$estruturaId/elementos/$elementoId';
  }

  void _openInformacoes() {
    final basePath = _basePath;
    if (basePath == null) return;
    context.push('$basePath/informacoes', extra: _routeExtra);
  }

  void _openRelatorios() {
    final basePath = _basePath;
    if (basePath == null) return;
    context.push('$basePath/relatorios', extra: _routeExtra);
  }

  @override
  Widget build(BuildContext context) {
    return RightMenuBar(
      key: _rightMenuKey,
      onInformacoesPressed: widget.onOpenInformacoes ?? _openInformacoes,
      onRelatoriosPressed: widget.onOpenRelatorios ?? _openRelatorios,
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        appBar: MenuAppBar(
          topTitle: 'Projeto',
          title: 'Elemento',
          onMenuPressed: () => _rightMenuKey.currentState?.toggle(),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ElementoHero(imageUrl: widget.imageUrl),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ElementoHeader(
                        titulo: widget.titulo,
                        tipo: widget.tipo,
                        local: widget.local,
                      ),
                      const SizedBox(height: 18),
                      const _ResumoStrip(),
                      const SizedBox(height: 29),
                      _SectionHeader(
                        onIncluirElemento: _openIncluirElementoSheet,
                      ),
                      const SizedBox(height: 13),
                      SizedBox(
                        width: 196,
                        child: CompactSearchBar(
                          hintText: 'Ensaio',
                          onChanged: widget.onSearchChanged,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Substitua a chamada dos cards por isto:
                      _EnsaioCard(
                        iconAsset: 'assets/images/ensaios/carbonatacao.png',
                        title: 'Frente de carbonatação',
                        subtitle: 'Ponto 01',
                        detail: 'Prof. 42 mm',
                        onTap: () {
                          // 🔥 NAVEGAÇÃO PRONTA COM PNG
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PontosEnsaioScreen(
                                elementoNome: 'V102',
                                tipoEnsaioNome: 'Frente de carbonatação',
                                iconeEnsaio: 'assets/images/ensaios/carbonatacao.png',
                                projetoNome: '0233_Proj. Ensaios Estruturais', 
                                localElemento: '2ª Subsolo',
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      const _EnsaioCard(
                        iconAsset: 'assets/images/ensaios/potencial_corrosao.png',
                        title: 'Potencial de Corrosão',
                        subtitle: 'Ponto 01',
                        detail: 'Alta probabilidade de corrosão',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ElementoHero extends StatelessWidget {
  const _ElementoHero({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final imageUrl = this.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.asset(
        imageUrl,
        width: double.infinity,
        height: 210,
        alignment: Alignment.bottomCenter,
        fit: BoxFit.fitWidth,
        errorBuilder: (_, __, ___) => _fallbackImage(),
      );
    }

    return _fallbackImage();
  }

  Widget _fallbackImage() {
    return Image.asset(
      'assets/images/frame_135.png',
      width: double.infinity,
      height: 210,
      alignment: Alignment.bottomCenter,
      fit: BoxFit.fitWidth,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/images/elemento_info.png',
        width: double.infinity,
        height: 210,
        alignment: Alignment.bottomCenter,
        fit: BoxFit.fitWidth,
      ),
    );
  }
}

class _ElementoHeader extends StatelessWidget {
  const _ElementoHeader({this.titulo, this.tipo, this.local});

  final String? titulo;
  final String? tipo;
  final String? local;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo ?? 'V102',
          style: GoogleFonts.lato(
            color: const Color(0xFF3E3E3D),
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tipo ?? 'Viga - Concreto Armado',
          style: GoogleFonts.lato(
            color: const Color(0xFF686868),
            fontSize: 14,
            fontWeight: FontWeight.w300,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          local ?? '2ª Subsolo',
          style: GoogleFonts.lato(
            color: const Color(0xFF686868),
            fontSize: 14,
            fontWeight: FontWeight.w300,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _ResumoStrip extends StatelessWidget {
  const _ResumoStrip();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 88,
          child: _ResumoCard(
            title: 'Frente de carbonatação',
            count: '01/04',
            borderColor: AppColors.primary,
          ),
        ),
        SizedBox(width: 14),
        SizedBox(
          width: 88,
          child: _ResumoCard(
            title: 'Potencial de corrosão',
            count: '02/02',
            borderColor: Color(0xFF20A862),
          ),
        ),
        SizedBox(width: 14),
        SizedBox(
          width: 88,
          child: _ResumoCard(
            title: 'Resistividade elet. sup.',
            count: '03/04',
            borderColor: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _ResumoCard extends StatelessWidget {
  const _ResumoCard({
    required this.title,
    required this.count,
    required this.borderColor,
  });

  final String title;
  final String count;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFAFAFA),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.35),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                color: AppColors.textDark,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              count,
              style: GoogleFonts.lato(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({this.onIncluirElemento});

  final VoidCallback? onIncluirElemento;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Ensaios Realizados',
            style: GoogleFonts.lato(
              color: const Color(0xFF3E3E3D),
              fontSize: 22,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ),
        CompactButton(text: 'Novo', onPressed: onIncluirElemento ?? () {}),
      ],
    );
  }
}

class _EnsaioCard extends StatelessWidget {
  const _EnsaioCard({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.detail,
    this.onTap,
  });

  final String iconAsset;
  final String title;
  final String subtitle;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFAFAFA),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.25),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap, // 🔥 CLICÁVEL AQUI
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 20, 14),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                height: 42,
                // 🔥 VOLTOU PARA IMAGE.ASSET
                child: Image.asset(
                  iconAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.science_outlined, color: AppColors.textDark, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lato(
                        color: const Color(0xFF3E3E3D),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lato(
                        color: const Color(0xFF686868),
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lato(
                        color: const Color(0xFFA0A0A0),
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}