import 'package:diavicon/features/ensaios/screens/ensaio_carbonatacao_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/compact_button.dart';
import '../../../core/widgets/compact_search_bar.dart';
import '../../../core/widgets/custom_appbar.dart'; 

// 🔥 Importando os widgets do novo menu padronizado
import '../../../core/widgets/menu_drawer_app_bar.dart';
import '../../../core/widgets/diavicon_menu_item.dart';

import '../widgets/incluir_elemento_estrutural_sheet.dart';
import '../providers/elemento_provider.dart';
import '../models/elemento_model.dart';
import 'elemento_form_screen.dart';

class ElementosHomeScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ElementosHomeScreen> createState() => _ElementosHomeScreenState();
}

class _ElementosHomeScreenState extends ConsumerState<ElementosHomeScreen> {
  // 🔥 GlobalKey do RightMenuBar foi removida! O Scaffold resolve isso agora.

  String? _tituloAtual;
  String? _tipoAtual;
  String? _localAtual;
  String? _imageUrlAtual;

  @override
  void initState() {
    super.initState();
    _tituloAtual = widget.titulo;
    _tipoAtual = widget.tipo;
    _localAtual = widget.local;
    _imageUrlAtual = widget.imageUrl;
  }

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
    if (_tituloAtual != null) 'titulo': _tituloAtual,
    if (_tipoAtual != null) 'tipo': _tipoAtual,
    if (_localAtual != null) 'local': _localAtual,
    if (_imageUrlAtual != null) 'imageUrl': _imageUrlAtual,
  };

  String? get _basePath {
    final estruturaId = widget.estruturaId;
    final elementoId = widget.elementoId;
    if (estruturaId == null || elementoId == null) return null;
    return '/estruturas/$estruturaId/elementos/$elementoId';
  }

  Future<void> _openInformacoes() async {
    if (widget.estruturaId == null || widget.projetoId == null || widget.elementoId == null) return;

    final elementos = ref.read(elementosPorEstruturaProvider(widget.estruturaId!)).value;
    ElementoModel? elementoCompleto;
    try {
      elementoCompleto = elementos?.firstWhere((e) => e.id == widget.elementoId);
    } catch (_) {}

    final elementoSalvo = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ElementoFormScreen(
          estruturaId: widget.estruturaId!,
          projetoId: widget.projetoId!,
          elemento: elementoCompleto,
        )
      )
    );

    if (elementoSalvo != null && elementoSalvo is ElementoModel) {
      setState(() {
        _tituloAtual = elementoSalvo.nome;
        
        final tipoParte = elementoSalvo.tipo ?? '';
        final tipologiaParte = elementoSalvo.tipologiaEstrutural ?? '';
        if (tipoParte.isNotEmpty && tipologiaParte.isNotEmpty) {
          _tipoAtual = '$tipoParte - $tipologiaParte';
        } else {
          _tipoAtual = tipoParte.isNotEmpty ? tipoParte : tipologiaParte;
        }

        _localAtual = elementoSalvo.local;
        
        if (elementoSalvo.fotos != null && elementoSalvo.fotos!.isNotEmpty) {
          _imageUrlAtual = elementoSalvo.fotos!.first;
        }
      });
    }
  }

  void _openRelatorios() {
    final basePath = _basePath;
    if (basePath == null) return;
    context.push('$basePath/relatorios', extra: _routeExtra);
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 O RightMenuBar foi removido e o Scaffold virou o pai principal de novo!
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      
      // 🔥 O Menu Padronizado entra aqui no endDrawer
      endDrawer: MenuDrawerAppBar(
        title: 'Menu do\nElemento',
        items: [
          DiaviconMenuItem(
            icon: Icons.info_outline,
            label: 'Informações',
            onTap: () {
              Navigator.pop(context); // Fecha o drawer primeiro
              if (widget.onOpenInformacoes != null) {
                widget.onOpenInformacoes!();
              } else {
                _openInformacoes();
              }
            },
          ),
          DiaviconMenuItem(
            icon: Icons.layers_outlined,
            label: 'Relatórios',
            onTap: () {
              Navigator.pop(context);
              if (widget.onOpenRelatorios != null) {
                widget.onOpenRelatorios!();
              } else {
                _openRelatorios();
              }
            },
          ),
          DiaviconMenuItem(
            icon: Icons.pie_chart_outline,
            label: 'Dashboard',
            onTap: () {
              Navigator.pop(context);
              // TODO: Ação de dashboard
            },
          ),
        ],
      ),

      // 🔥 CustomAppBar totalmente limpa e automática!
      appBar: CustomAppBar(
        title: 'Projeto\nElemento',
        showBackButton: true,
        onBackPressed: () => context.pop(), 
        // O showMenuButton já é true e cuida do endDrawer para nós
      ),

      body: SafeArea(
        top: false,
        bottom: true, 
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ElementoHero(imageUrl: _imageUrlAtual),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 40), 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ElementoHeader(
                      titulo: _tituloAtual,
                      tipo: _tipoAtual,
                      local: _localAtual,
                    ),
                    const SizedBox(height: 18),
                    const _ResumoStrip(),
                    const SizedBox(height: 32),
                    _SectionHeader(
                      onIncluirElemento: _openIncluirElementoSheet,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 220, 
                      child: CompactSearchBar(
                        hintText: 'Ensaio',
                        onChanged: widget.onSearchChanged,
                      ),
                    ),
                    const SizedBox(height: 24),

                    _EnsaioCard(
                      iconAsset: 'assets/images/ensaios/carbonatacao.png',
                      title: 'Frente de carbonatação',
                      subtitle: 'Ponto 01',
                      detail: 'Prof. 42 mm',
                      statusText: 'Risco Alto',
                      statusColor: const Color(0xFFE53935),
                      statusBgColor: const Color(0xFFFFEBEE),
                      mockAvatar: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EnsaioCarbonatacaoFormScreen(
                              pontoNome: 'Ponto 01',
                              elementoNome: _tituloAtual ?? 'V102',
                              tipoElemento: _tipoAtual ?? 'Viga - Concreto Armado',
                              local: _localAtual ?? '2ª Subsolo',
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
                      mockAvatar: true, 
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

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTES DE UI MANTIDOS
// ─────────────────────────────────────────────────────────────────────────────

class _ElementoHero extends StatelessWidget {
  const _ElementoHero({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const double heroHeight = 280; 

    final String? urlLocal = imageUrl;

    if (urlLocal != null && urlLocal.isNotEmpty) {
      return Image.network(
        urlLocal, 
        width: double.infinity,
        height: heroHeight,
        alignment: Alignment.center, 
        fit: BoxFit.cover, 
        errorBuilder: (_, __, ___) => _fallbackImage(heroHeight),
      );
    }

    return _fallbackImage(heroHeight);
  }

  Widget _fallbackImage(double height) {
    return Image.asset(
      'assets/images/frame_135.png',
      width: double.infinity,
      height: height,
      alignment: Alignment.center,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/images/elemento_info.png',
        width: double.infinity,
        height: height,
        alignment: Alignment.center,
        fit: BoxFit.cover,
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
            color: const Color(0xFF4A4A4A),
            fontSize: 26,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tipo ?? 'Viga - Concreto Armado',
          style: GoogleFonts.lato(
            color: const Color(0xFF757575),
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          local ?? '2ª Subsolo',
          style: GoogleFonts.lato(
            color: const Color(0xFF757575),
            fontSize: 14,
            fontWeight: FontWeight.w400,
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none, 
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 95,
            child: _ResumoCard(
              title: 'Frente de carbonatação',
              count: '01/04',
              borderColor: AppColors.primary,
            ),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 95,
            child: _ResumoCard(
              title: 'Potencial de corrosão',
              count: '02/02',
              borderColor: Color(0xFF20A862),
            ),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 95,
            child: _ResumoCard(
              title: 'Resistividade elet. sup.',
              count: '03/04',
              borderColor: AppColors.primary,
            ),
          ),
        ],
      ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.2),
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
                color: const Color(0xFF4A4A4A),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              count,
              style: GoogleFonts.lato(
                color: const Color(0xFF757575),
                fontSize: 13,
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
              color: const Color(0xFF4A4A4A),
              fontSize: 20,
              fontWeight: FontWeight.w500,
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
    this.statusText,
    this.statusColor,
    this.statusBgColor,
    this.mockAvatar = false,
    this.onTap,
  });

  final String iconAsset;
  final String title;
  final String subtitle;
  final String detail;
  final String? statusText;
  final Color? statusColor;
  final Color? statusBgColor;
  final bool mockAvatar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06), 
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap, 
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 42,
                  height: 42,
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
                          fontSize: 15,
                          fontWeight: FontWeight.bold, 
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lato(
                          color: const Color(0xFF8B8B8B),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8), 
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.lato(
                                color: const Color(0xFFA0A0A0),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                height: 1.1,
                              ),
                            ),
                          ),
                          if (statusText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                              decoration: BoxDecoration(
                                color: statusBgColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                statusText!,
                                style: GoogleFonts.lato(
                                  color: statusColor,
                                  fontSize: 11, 
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          
                          if (statusText != null && mockAvatar)
                            const SizedBox(width: 12), 

                          if (mockAvatar)
                            Container(
                              width: 32, 
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade200, width: 1.5), 
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              ),
                              child: ClipOval( 
                                child: Image.network(
                                  'https://ui-avatars.com/api/?name=Asimov&background=random&size=100', 
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.business, size: 16, color: Colors.grey),
                                ),
                              ),
                            ),
                        ],
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