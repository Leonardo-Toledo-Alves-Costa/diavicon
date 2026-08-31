import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/compact_button.dart';
import '../../../core/widgets/confirmar_exclusao_dialog.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/diavicon_menu_item.dart';
import '../../../core/widgets/menu_drawer_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../ensaios/ensaios_geral/providers/ensaios_provider.dart';
import '../../ensaios/ensaios_geral/screens/pontos_ensaio_screen.dart';
import '../../ensaios/ensaios_geral/widgets/novo_ponto_ensaio_modal.dart';
import '../../ensaios/ensaios_geral/widgets/selecionar_tipo_ensaio_modal.dart';
import '../../projetos/providers/projetos_provider.dart';
import '../models/elemento_model.dart';
import '../providers/elemento_provider.dart';
import 'elemento_form_screen.dart';

// =========================================================================
// PROVIDER DE PROGRESSO (Mapeamento de Realizados vs Contratados por Região)
// =========================================================================
typedef ProgressoEnsaiosParams = ({String elementoId, String estruturaId, String? projetoId});

class ProgressoEnsaio {
  final String tipoId;
  final String nome;
  final String elementoId;
  final int contratados;
  final int realizados;

  ProgressoEnsaio({
    required this.tipoId,
    required this.nome,
    required this.elementoId,
    required this.contratados,
    required this.realizados,
  });
}

final progressoEnsaiosProvider = FutureProvider.family.autoDispose<List<ProgressoEnsaio>, ProgressoEnsaiosParams>((ref, params) async {
  final supabase = Supabase.instance.client;

  try {
    // 1. Busca TODAS as regiões vinculadas a este elemento específico
    final resRegioes = await supabase
        .from('regioes_ensaio')
        .select('id')
        .eq('elemento_id', params.elementoId);

    // Extrai apenas os IDs das regiões para usarmos como filtro
    final List<String> regioesIds = resRegioes.map((r) => r['id'].toString()).toList();

    List<Map<String, dynamic>> resContratados = [];

    // 2. Busca os ensaios contratados atrelados a essas regiões (usando inFilter)
    if (regioesIds.isNotEmpty) {
      final res = await supabase
          .from('ensaios_contratados')
          .select('tipo_ensaio_id, quantidade, tipos_ensaio(id, nome)')
          .inFilter('regiao_id', regioesIds);
          
      resContratados = List<Map<String, dynamic>>.from(res);
    }

    // 3. Busca os ensaios já realizados fisicamente no elemento
    final pontosRealizados = await ref.watch(ensaiosDoElementoProvider(params.elementoId).future);

    final map = <String, ProgressoEnsaio>{};

    // 4. Agrupa e soma as quantidades contratadas
    for (var row in resContratados) {
      final tipoId = row['tipo_ensaio_id']?.toString() ?? '';
      if (tipoId.isEmpty) continue;

      final qtdContratada = (row['quantidade'] as num?)?.toInt() ?? 0;
      final nome = (row['tipos_ensaio'] != null && row['tipos_ensaio'] is Map)
          ? row['tipos_ensaio']['nome']?.toString() ?? 'Desconhecido'
          : 'Desconhecido';

      if (map.containsKey(tipoId)) {
        map[tipoId] = ProgressoEnsaio(
          tipoId: tipoId,
          nome: map[tipoId]!.nome,
          elementoId: params.elementoId,
          contratados: map[tipoId]!.contratados + qtdContratada,
          realizados: map[tipoId]!.realizados, 
        );
      } else {
        map[tipoId] = ProgressoEnsaio(
          tipoId: tipoId,
          nome: nome,
          elementoId: params.elementoId,
          contratados: qtdContratada,
          realizados: 0,
        );
      }
    }

    // 5. Agrupa e soma os ensaios que já foram realizados
    for (var ponto in pontosRealizados) {
      final tipoEnsaio = ponto['tipos_ensaio'];
      if (tipoEnsaio == null) continue;

      final tipoId = tipoEnsaio['id']?.toString() ?? '';
      final nome = tipoEnsaio['nome']?.toString() ?? 'Desconhecido';
      if (tipoId.isEmpty) continue;

      if (map.containsKey(tipoId)) {
        map[tipoId] = ProgressoEnsaio(
          tipoId: tipoId,
          nome: map[tipoId]!.nome,
          elementoId: params.elementoId,
          contratados: map[tipoId]!.contratados,
          realizados: map[tipoId]!.realizados + 1,
        );
      } else {
        // Exibe também os ensaios que foram realizados "avulsos" (sem contrato na região)
        map[tipoId] = ProgressoEnsaio(
          tipoId: tipoId,
          nome: nome,
          elementoId: params.elementoId,
          contratados: 0,
          realizados: 1,
        );
      }
    }

    // Ordenação alfabética para exibição dos gráficos
    final lista = map.values.toList();
    lista.sort((a, b) => a.nome.compareTo(b.nome)); 
    return lista;

  } on PostgrestException catch (e) {
    throw Exception('Erro no banco de dados ao buscar progresso: ${e.message}');
  } on AuthException catch (e) {
    throw Exception('Erro de autenticação: ${e.message}');
  } catch (e) {
    throw Exception('Erro inesperado: $e');
  }
});

// =========================================================================
// TELA PRINCIPAL
// =========================================================================

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
  ConsumerState<ElementosHomeScreen> createState() => _ElementosHomeScreenState();
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

      // Precisa aguardar: o modal empurra a tela de coleta do ensaio por
      // cima de si mesmo (Navigator.push dentro do NovoPontoEnsaioModal),
      // então só sabemos que o fluxo terminou quando essa cadeia inteira
      // fecha e devolve o controle aqui.
      await showModalBottomSheet(
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
          //elementoId: widget.elementoId,
        ),
      );

      // Sem isso, o card do ensaio recém-criado (ou uma nova leitura
      // salva nele) só aparecia em "Ensaios Realizados" depois de sair e
      // voltar pra tela — o provider ficava com o valor antigo em cache.
      if (mounted && widget.elementoId != null && widget.estruturaId != null) {
        ref.invalidate(ensaiosDoElementoProvider(widget.elementoId!));
        ref.invalidate(progressoEnsaiosProvider((
          elementoId: widget.elementoId!,
          estruturaId: widget.estruturaId!,
          projetoId: widget.projetoId,
        )));
      }
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
        widget.elementoId == null) {
      return;
    }

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

  Future<void> _excluirElemento() async {
    if (widget.elementoId == null) return;

    final confirmar = await showConfirmarExclusaoDialog(
      context: context,
      titulo: 'Excluir Elemento',
      mensagem: 'Deseja realmente excluir "${_tituloAtual ?? 'este elemento'}" e todos os ensaios vinculados a ele? Esta ação não poderá ser desfeita.',
    );
    if (confirmar != true || !mounted) return;

    try {
      await ref.read(elementoRepositoryProvider).excluirElemento(widget.elementoId!);
      if (widget.estruturaId != null) {
        ref.invalidate(elementosPorEstruturaProvider(widget.estruturaId!));
        ref.invalidate(todosElementosPorEstruturaProvider(widget.estruturaId!));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Elemento excluído com sucesso!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir elemento: $e'), backgroundColor: AppColors.error),
        );
      }
    }
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
          if (widget.projetoId != null && widget.elementoId != null)
            Consumer(
              builder: (context, ref, _) {
                final isAdminEmpresa = ref.watch(currentUserProvider)?.isAdminEmpresa == true;
                if (!isAdminEmpresa) return const SizedBox.shrink();

                final projetoAsync = ref.watch(projectDetailProvider(widget.projetoId!));
                final empresaIdAsync = ref.watch(loggedUserCompanyIdProvider);
                final podeExcluir = projetoAsync.value != null &&
                    empresaIdAsync.value != null &&
                    projetoAsync.value!.empresaGestoraId == empresaIdAsync.value;

                if (!podeExcluir) return const SizedBox.shrink();

                return DiaviconMenuItem(
                  icon: Icons.delete_outline,
                  label: 'Excluir',
                  onTap: () {
                    Navigator.pop(context);
                    _excluirElemento();
                  },
                );
              },
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
                color: Colors.white.withValues(alpha: 0.8),
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
                    
                    if (widget.elementoId != null && widget.estruturaId != null)
                      _ResumoStrip(
                        elementoId: widget.elementoId!,
                        estruturaId: widget.estruturaId!,
                        projetoId: widget.projetoId,
                      ),
                    
                    const SizedBox(height: 32),

                    _SectionHeader(onIncluirElemento: _openNovoEnsaioModal),
                    const SizedBox(height: 16),
                    
                    const SizedBox(width: 220), 

                    Consumer(
                      builder: (context, ref, child) {
                        if (widget.elementoId == null) {
                          return const SizedBox.shrink();
                        }

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
                                  'nome': tipoEnsaio['nome'] ?? 'Ensaio Desconhecido',
                                  'icone': tipoEnsaio['icone_path'] ?? 'assets/images/ensaios/carbonatacao.png',
                                  'quantidade': 0,
                                };
                              }
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
                                    subtitle: '${grupo['quantidade']} ponto(s) neste elemento',
                                    detail: 'Ver todos os pontos na estrutura',
                                    statusText: 'Acessar',
                                    statusColor: AppColors.primary,
                                    statusBgColor: AppColors.primary.withValues(alpha: 0.1),
                                    mockAvatar: false,
                                    onTap: () {
                                      if (widget.projetoId == null || widget.estruturaId == null) {
                                        return;
                                      }

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              PontosEnsaioScreen(
                                                projetoId: widget.projetoId!,
                                                estruturaId: widget.estruturaId!,
                                                iconeEnsaio: grupo['icone'],
                                                tipoEnsaioId: grupo['id'],
                                                elementoId: widget.elementoId,
                                              ),
                                        ),
                                      ).then((_) {
                                        ref.refresh(ensaiosDoElementoProvider(widget.elementoId!));
                                        ref.refresh(progressoEnsaiosProvider((elementoId: widget.elementoId!, estruturaId: widget.estruturaId!, projetoId: widget.projetoId)));
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
// COMPONENTES DE UI
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

class _ResumoStrip extends ConsumerWidget {
  final String elementoId;
  final String estruturaId;
  final String? projetoId;

  const _ResumoStrip({
    required this.elementoId,
    required this.estruturaId,
    this.projetoId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (elementoId: elementoId, estruturaId: estruturaId, projetoId: projetoId);
    final progressoAsync = ref.watch(progressoEnsaiosProvider(params));

    return progressoAsync.when(
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Text('Erro ao carregar gráficos: $e', style: const TextStyle(color: Colors.red)),
      data: (progressos) {
        // Se a lista estiver vazia (sem contratos vinculados à região do elemento E sem ensaios realizados), a UI é ocultada
        if (progressos.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progresso dos ensaios',
              style: GoogleFonts.lato(
                color: const Color(0xFF263238), 
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: progressos.map((prog) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: _ResumoCard(
                      title: prog.nome,
                      realizados: prog.realizados,
                      contratados: prog.contratados,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ResumoCard extends StatelessWidget {
  const _ResumoCard({
    required this.title,
    required this.realizados,
    required this.contratados,
  });

  final String title;
  final int realizados;
  final int contratados;

  @override
  Widget build(BuildContext context) {
    final isComplete = realizados >= contratados && contratados > 0;
    final double progressValue = contratados == 0 ? 1.0 : (realizados / contratados).clamp(0.0, 1.0);
    final Color progressColor = isComplete ? const Color(0xFF20A862) : const Color(0xFFE87B1D);

    return Container(
      width: 115,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 52,
            width: 52,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progressValue,
                  strokeWidth: 5.5,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: isComplete
                      ? Icon(Icons.check, color: progressColor, size: 28)
                      : Text(
                          '$realizados/$contratados',
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF333333),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lato(
              color: const Color(0xFF4A4A4A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
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
            color: Colors.black.withValues(alpha: 0.06),
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