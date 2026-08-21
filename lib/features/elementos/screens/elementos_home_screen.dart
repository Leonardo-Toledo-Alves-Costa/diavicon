import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/compact_button.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/diavicon_menu_item.dart';
import '../../../core/widgets/menu_drawer_app_bar.dart';
import '../../ensaios/ensaios_geral/providers/ensaios_provider.dart';
import '../../ensaios/ensaios_geral/screens/pontos_ensaio_screen.dart';
import '../../ensaios/ensaios_geral/widgets/novo_ponto_ensaio_modal.dart';
//imports de ensaios
import '../../ensaios/ensaios_geral/widgets/selecionar_tipo_ensaio_modal.dart';
import '../models/elemento_model.dart';
import '../providers/elemento_provider.dart';
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
    this.marcacaoImagemUrl,
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
  final String? marcacaoImagemUrl;

  @override
  ConsumerState<ElementosHomeScreen> createState() =>
      _ElementosHomeScreenState();
}

class _ElementosHomeScreenState extends ConsumerState<ElementosHomeScreen> {
  String? _tituloAtual;
  String? _tipoAtual;
  String? _localAtual;
  String? _imageUrlAtual;
  String? _marcacaoImagemUrlAtual;

  @override
  void initState() {
    super.initState();
    _tituloAtual = widget.titulo;
    _tipoAtual = widget.tipo;
    _localAtual = widget.local;
    _imageUrlAtual = widget.imageUrl;
    _marcacaoImagemUrlAtual = widget.marcacaoImagemUrl;
  }

  void _openNovoEnsaioModal() async {
    if (widget.projetoId == null || widget.estruturaId == null) return;

    final ensaioEscolhido = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SelecionarTipoEnsaioModal(),
    );

    if (ensaioEscolhido != null && mounted) {
      final realTipoId = await ref.read(
        buscarIdTipoEnsaioProvider(ensaioEscolhido['nome']).future,
      );

      if (!mounted) return;

      if (realTipoId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Este tipo de ensaio não está cadastrado no banco de dados!',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => NovoPontoEnsaioModal(
          projetoId: widget.projetoId!,
          estruturaId: widget.estruturaId!,
          tipoEnsaioNome: ensaioEscolhido['nome'],
          tipoEnsaioId: realTipoId,
        ),
      );
    }
  }

  Map<String, dynamic> get _routeExtra => <String, dynamic>{
    if (widget.projetoId != null) 'projetoId': widget.projetoId,
    if (widget.estruturaId != null) 'estruturaId': widget.estruturaId,
    if (widget.elementoId != null) 'elementoId': widget.elementoId,
    if (_tituloAtual != null) 'titulo': _tituloAtual,
    if (_tipoAtual != null) 'tipo': _tipoAtual,
    if (_localAtual != null) 'local': _localAtual,
    if (_imageUrlAtual != null) 'imageUrl': _imageUrlAtual,
    if (_marcacaoImagemUrlAtual != null)
      'marcacaoImagemUrl': _marcacaoImagemUrlAtual,
  };

  String? get _basePath {
    final estruturaId = widget.estruturaId;
    final elementoId = widget.elementoId;
    if (estruturaId == null || elementoId == null) return null;
    return '/estruturas/$estruturaId/elementos/$elementoId';
  }

  Future<void> _openInformacoes() async {
    if (widget.estruturaId == null ||
        widget.projetoId == null ||
        widget.elementoId == null)
      return;

    ElementoModel? elementoCompleto;
    try {
      final repo = ref.read(elementoRepositoryProvider);
      final lista = await repo.buscarElementosPorEstrutura(widget.estruturaId!);
      elementoCompleto = lista.firstWhere((e) => e.id == widget.elementoId);
    } catch (e) {
      debugPrint('Erro ao buscar elemento: $e');
    }

    final elementoSalvo = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ElementoFormScreen(
          estruturaId: widget.estruturaId!,
          projetoId: widget.projetoId!,
          elemento: elementoCompleto,
        ),
      ),
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
        _marcacaoImagemUrlAtual = elementoSalvo.marcacaoImagemUrl;

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
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,

      endDrawer: MenuDrawerAppBar(
        title: 'Menu do\nElemento',
        items: [
          DiaviconMenuItem(
            icon: Icons.info_outline,
            label: 'Informações',
            onTap: () {
              Navigator.pop(context);
              if (widget.onOpenInformacoes != null) {
                widget.onOpenInformacoes!();
              } else {
                _openInformacoes();
              }
            },
          ),
          Opacity(
            opacity: 0.4,
            child: DiaviconMenuItem(
              icon: Icons.layers_outlined,
              label: 'Relatórios',
              onTap: () {
                DiaviconAlerts.show(
                  context,
                  'Em desenvolvimento',
                  'Esta funcionalidade estará disponível em breve!',
                  isAviso: true,
                );
                // Navigator.pop(context);
                // if (widget.onOpenRelatorios != null) {
                //   widget.onOpenRelatorios!();
                // } else {
                //   _openRelatorios();
                // }
              },
            ),
          ),
          Opacity(
            opacity: 0.4,
            child: DiaviconMenuItem(
              icon: Icons.pie_chart_outline,
              label: 'Dashboard',
              onTap: () {
                DiaviconAlerts.show(
                  context,
                  'Em desenvolvimento',
                  'Esta funcionalidade estará disponível em breve!',
                  isAviso: true,
                );
              },
            ),
          ),
        ],
      ),

      appBar: CustomAppBar(
        title: '',
        showBackButton: true,
        showMenuButton: true,
        showNotificationButton: true,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Projeto',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Elemento',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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

                    _SectionHeader(onIncluirElemento: _openNovoEnsaioModal),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: 220,
                      // child: CompactSearchBar(
                      //   hintText: 'Ensaio',
                      //   onChanged: widget.onSearchChanged,
                      // ),
                    ),

                    // const SizedBox(height: 24),

                    // const SizedBox(height: 24),
                    Consumer(
                      builder: (context, ref, child) {
                        if (widget.elementoId == null)
                          return const SizedBox.shrink();

                        final ensaiosAsync = ref.watch(
                          ensaiosDoElementoProvider(widget.elementoId!),
                        );

                        return ensaiosAsync.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                          error: (err, _) => Text(
                            'Erro ao carregar: $err',
                            style: const TextStyle(color: Colors.red),
                          ),
                          data: (pontos) {
                            if (pontos.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 32.0),
                                child: Center(
                                  child: Text(
                                    'Nenhum ensaio realizado neste elemento.',
                                    style: TextStyle(
                                      color: AppColors.greyMedium,
                                    ),
                                  ),
                                ),
                              );
                            }

                            // 1. AGRUPA OS PONTOS POR TIPO DE ENSAIO
                            final Map<String, Map<String, dynamic>>
                            ensaiosAgrupados = {};

                            for (var ponto in pontos) {
                              final tipoEnsaio = ponto['tipos_ensaio'];
                              if (tipoEnsaio == null) continue;

                              final tipoId = tipoEnsaio['id'];

                              if (!ensaiosAgrupados.containsKey(tipoId)) {
                                ensaiosAgrupados[tipoId] = {
                                  'id': tipoId,
                                  'nome':
                                      tipoEnsaio['nome'] ??
                                      'Ensaio Desconhecido',
                                  'icone':
                                      tipoEnsaio['icone_path'] ??
                                      'assets/images/ensaios/carbonatacao.png',
                                  'quantidade': 0,
                                };
                              }
                              // Soma +1 ponto a este tipo de ensaio
                              ensaiosAgrupados[tipoId]!['quantidade'] += 1;
                            }

                            // 2. DESENHA UM CARD PARA CADA TIPO DE ENSAIO ENCONTRADO
                            return Column(
                              children: ensaiosAgrupados.values.map((grupo) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: _EnsaioCard(
                                    iconAsset: grupo['icone'],
                                    title: grupo['nome'],
                                    subtitle:
                                        '${grupo['quantidade']} ponto(s) neste elemento',
                                    detail: 'Ver todos os pontos na estrutura',
                                    statusText: 'Acessar',
                                    statusColor: AppColors.primary,
                                    statusBgColor: AppColors.primary
                                        .withOpacity(0.1),
                                    mockAvatar: false, // Desliga o avatar falso
                                    onTap: () {
                                      // 👇 3. ROTA PARA A TELA GERAL DE PONTOS (Protótipo image_73209d)
                                      if (widget.projetoId == null ||
                                          widget.estruturaId == null)
                                        return;

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              PontosEnsaioScreen(
                                                projetoId: widget.projetoId!,
                                                estruturaId:
                                                    widget.estruturaId!,
                                                iconeEnsaio: grupo['icone'],
                                                tipoEnsaioId: grupo['id'],
                                              ),
                                        ),
                                      ).then((_) {
                                        // Atualiza a lista ao voltar
                                        ref.refresh(
                                          ensaiosDoElementoProvider(
                                            widget.elementoId!,
                                          ),
                                        );
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        );
                      },
                    ),
                    // const SizedBox(height: 16),
                    // const SizedBox(height: 16),
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
        errorBuilder: (_, _, _) => _fallbackImage(heroHeight),
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
      errorBuilder: (_, _, _) => Image.asset(
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
        // children: const [
        //   SizedBox(
        //     width: 95,
        //     child: _ResumoCard(
        //       title: 'Frente de carbonatação',
        //       count: '01/04',
        //       borderColor: AppColors.primary,
        //     ),
        //   ),
        //   SizedBox(width: 12),
        //   SizedBox(
        //     width: 95,
        //     child: _ResumoCard(
        //       title: 'Potencial de corrosão',
        //       count: '02/02',
        //       borderColor: Color(0xFF20A862),
        //     ),
        //   ),
        //   SizedBox(width: 12),
        //   SizedBox(
        //     width: 95,
        //     child: _ResumoCard(
        //       title: 'Resistividade elet. sup.',
        //       count: '03/04',
        //       borderColor: AppColors.primary,
        //     ),
        //   ),
        // ],
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
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.science_outlined,
                      color: AppColors.textDark,
                      size: 28,
                    ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
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
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.network(
                                  'https://ui-avatars.com/api/?name=Asimov&background=random&size=100',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.business,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
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
