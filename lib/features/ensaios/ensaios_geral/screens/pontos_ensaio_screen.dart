import 'package:diavicon/core/widgets/imagem_storage.dart';
import '../../../../core/widgets/autoria_badge.dart';
import 'package:diavicon/features/planos/acesso_plano.dart';
import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../ensaios_prova_carga_dinamica/pcd_tipo_ensaio.dart';
import '../../../../core/routing/route_observer.dart';
import '../../../../core/widgets/compact_button.dart';
import '../../../../core/widgets/compact_search_bar.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../models/ensaios_routes_map.dart';
// Providers e Modais
import '../progresso/progresso_ensaios.dart';
import '../providers/pontos_ensaio_provider.dart';
import '../widgets/novo_ponto_ensaio_modal.dart';
import 'central_relatorios_screen.dart';
import '../../ensaios_prova_carga/widgets/novo_ensaio_prova_carga_modal.dart';
import '../../ensaio_extracao_testemunho/widgets/novo_ensaio_extracao_modal.dart';

class PontosEnsaioScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String estruturaId;
  final String iconeEnsaio;
  final String tipoEnsaioId;
  final String? elementoId;

  const PontosEnsaioScreen({
    super.key,
    required this.projetoId,
    required this.estruturaId,
    required this.iconeEnsaio,
    required this.tipoEnsaioId,
    this.elementoId,
  });

  @override
  ConsumerState<PontosEnsaioScreen> createState() => _PontosEnsaioScreenState();
}

class _PontosEnsaioScreenState extends ConsumerState<PontosEnsaioScreen> with RouteAware {
  String _searchQuery = '';
  final String _filtroStatus = 'Todos';

  // Controle de ordenação (False = Mais recentes primeiro)
  bool _isAscending = false;
  bool _verificandoEspaco = false;

  void _recarregarLista() {
    ref.invalidate(pontosEnsaioProvider((
      projetoId: widget.projetoId,
      estruturaId: widget.estruturaId,
      tipoEnsaioId: widget.tipoEnsaioId,
      elementoId: widget.elementoId,
    )));
    // A barra de progresso também precisa refletir pontos novos/excluídos.
    ref.invalidate(progressoProjetoProvider(widget.projetoId));
  }

  @override
  void initState() {
    super.initState();
    // Força o Riverpod a recarregar a query no Supabase sempre que a tela for montada/aberta
    Future.microtask(_recarregarLista);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  // Chamado pelo RouteObserver quando a rota empurrada por cima desta (ex: a
  // tela de coleta de um ponto de ensaio, aberta via Navigator.push a partir
  // do NovoPontoEnsaioModal) é fechada e esta tela volta a ficar visível —
  // sem isso, um ponto recém-salvo só aparecia depois de sair e reentrar no
  // tipo de ensaio, porque `initState` não roda de novo num simples "voltar".
  @override
  void didPopNext() => _recarregarLista();

  Color _hexToColor(String hexString, Color fallback) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return fallback;
    }
  }

  void _mostrarModalNovoEnsaio(
    BuildContext context,
    String estruturaId,
    String tipoEnsaioNome,
  ) {
    // A prova de carga estática não se vincula a um elemento estrutural
    // (usa Local + Planta), então tem seu próprio modal de criação.
    // Prova de carga dinâmica: o ensaio é criado no computador.
    if (ehProvaCargaDinamica(tipoEnsaioId: widget.tipoEnsaioId, nomeTipoEnsaio: tipoEnsaioNome)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A prova de carga dinâmica é criada no aplicativo de computador.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (tipoEnsaioNome.toLowerCase().contains('prova de carga')) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => NovoEnsaioProvaCargaModal(
          estruturaId: estruturaId,
          projetoId: widget.projetoId,
          tipoEnsaioId: widget.tipoEnsaioId,
        ),
      );
      return;
    }

    // Extração e Rompimento de Testemunho: 1 ensaio por Local (não por
    // elemento) — mesma ideia da prova de carga, com seu próprio modal.
    if (tipoEnsaioNome.toLowerCase().contains('testemunho')) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => NovoEnsaioExtracaoModal(
          estruturaId: estruturaId,
          projetoId: widget.projetoId,
          tipoEnsaioId: widget.tipoEnsaioId,
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
        estruturaId: estruturaId,
        tipoEnsaioNome: tipoEnsaioNome,
        tipoEnsaioId: widget.tipoEnsaioId,
        projetoId: widget.projetoId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nomeEnsaioAsync = ref.watch(
      tipoEnsaioNomeProvider(widget.tipoEnsaioId),
    );
    final tipoEnsaioNomeUI = nomeEnsaioAsync.value ?? 'Carregando...';

    final pontosAsync = ref.watch(
      pontosEnsaioProvider((
        projetoId: widget.projetoId,
        estruturaId: widget.estruturaId,
        tipoEnsaioId: widget.tipoEnsaioId,
        elementoId: widget.elementoId,
      )),
    );

    final nomesAsync = ref.watch(
      nomesHeaderProvider((
        projetoId: widget.projetoId,
        estruturaId: widget.estruturaId,
      )),
    );

    final projetoNomeUI = nomesAsync.value?['projetoNome'] ?? 'Carregando...';
    final estruturaNomeUI =
        nomesAsync.value?['estruturaNome'] ?? 'Carregando...';

    final bool temDados =
        pontosAsync.value != null && pontosAsync.value!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: MenuDrawerAppBar(
        title: 'Menu do\nEnsaio',
        items: [
          if (temDados)
            Opacity(
              opacity: 0.4,
              child: DiaviconMenuItem(
                icon: Icons.menu_book_outlined,
                label: 'Informações',
                onTap: () {
                  DiaviconAlerts.show(
                    context,
                    'Em desenvolvimento',
                    'Esta funcionalidade estará disponível em breve!',
                    isAviso: true,
                  );
                },
              ),
            )
          else
            Opacity(
              opacity: 0.4,
              child: DiaviconMenuItem(
                icon: Icons.menu_book_outlined,
                label: 'Informações',
                onTap: () {},
              ),
            ),

          if (temDados)
            DiaviconMenuItem(
              icon: Icons.show_chart_rounded,
              label: 'Análises',
              onTap: () {
                Navigator.pop(context);
                final Widget? telaAnalise = EnsaioRoutesMap.getAnaliseScreen(
                  tipoEnsaio: tipoEnsaioNomeUI,
                  projetoId: widget.projetoId,
                  estruturaId: widget.estruturaId,
                  tipoEnsaioNome: tipoEnsaioNomeUI,
                  projetoNome: projetoNomeUI,
                  estruturaNome: estruturaNomeUI,
                  tipoEnsaioId: widget.tipoEnsaioId,
                );

                if (telaAnalise != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => telaAnalise),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Dashboard de Análise ainda não implementado para este ensaio.',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            )
          else
            Opacity(
              opacity: 0.4,
              child: DiaviconMenuItem(
                icon: Icons.show_chart_rounded,
                label: 'Análises',
                onTap: () {},
              ),
            ),

          DiaviconMenuItem(
            icon: Icons.assessment_outlined,
            label: 'Relatórios',
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop(context);
              // Ensaios com compositor "por modelo" próprio (mesmo padrão da
              // Inspeção Visual — ver EnsaioRoutesMap.getRelatorioScreen)
              // usam a tela deles; os demais caem na Central de Relatórios
              // genérica de sempre.
              final telaRelatorio = EnsaioRoutesMap.getRelatorioScreen(
                tipoEnsaio: tipoEnsaioNomeUI,
                projetoId: widget.projetoId,
                estruturaId: widget.estruturaId,
                projetoNome: projetoNomeUI,
                estruturaNome: estruturaNomeUI,
              );
              navigator.push(
                MaterialPageRoute(
                  builder: (context) => telaRelatorio ??
                      CentralRelatoriosScreen(
                        projetoId: widget.projetoId,
                        estruturaId: widget.estruturaId,
                        tipoEnsaioId: widget.tipoEnsaioId,
                        tipoEnsaioNome: tipoEnsaioNomeUI,
                        projetoNome: projetoNomeUI,
                        estruturaNome: estruturaNomeUI,
                      ),
                ),
              );
            },
          ),
        ],
      ),
      appBar: const CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Projeto',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Ensaio',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: pontosAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) => Center(child: Text('Erro ao carregar pontos: $err')),
        data: (pontos) {
          // Filtro textual e por status
          final pontosFiltrados = pontos.where((p) {
            final matchesBusca =
                p.nome.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                p.elementoNome.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                p.local.toLowerCase().contains(_searchQuery.toLowerCase());
            bool matchesStatus = true;
            if (_filtroStatus == 'Concluídos') {
              matchesStatus = p.textoRisco.toLowerCase() != 'pendente';
            } else if (_filtroStatus == 'Pendentes') {
              matchesStatus = p.textoRisco.toLowerCase() == 'pendente';
            }
            return matchesBusca && matchesStatus;
          }).toList();

          // Lógica de Ordenação por Data de Criação
          pontosFiltrados.sort((a, b) {
            if (_isAscending) {
              return a.criadoEm.compareTo(b.criadoEm); // Mais antigos primeiro
            } else {
              return b.criadoEm.compareTo(a.criadoEm); // Mais recentes primeiro
            }
          });

          // Progresso deste tipo de ensaio na estrutura: realizados ÷ pontos
          // contratados para a empresa (regra em progresso_ensaios.dart).
          final progressoTipo = ref
              .watch(progressoProjetoProvider(widget.projetoId))
              .value
              ?.estrutura(widget.estruturaId)
              .tipo(widget.tipoEnsaioId);
          final progresso = progressoTipo?.fracao;

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: Colors.white,
            // Função ativada ao fazer Pull-to-Refresh
            onRefresh: () async {
              ref.invalidate(pontosEnsaioProvider((
                projetoId: widget.projetoId,
                estruturaId: widget.estruturaId,
                tipoEnsaioId: widget.tipoEnsaioId,
                elementoId: widget.elementoId,
              )));
              ref.invalidate(progressoProjetoProvider(widget.projetoId));
              // Aguarda o provedor terminar a requisição para esconder o loading
              try {
                await ref.read(pontosEnsaioProvider((
                  projetoId: widget.projetoId,
                  estruturaId: widget.estruturaId,
                  tipoEnsaioId: widget.tipoEnsaioId,
                  elementoId: widget.elementoId,
                )).future);
              } catch (_) {}
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: Image.asset(
                          widget.iconeEnsaio,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.science_outlined,
                            color: AppColors.textDark,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tipoEnsaioNomeUI,
                              style: GoogleFonts.lato(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF3E3E3D),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              projetoNomeUI,
                              style: GoogleFonts.lato(
                                fontSize: 13,
                                color: const Color(0xFF686868),
                              ),
                            ),
                            Text(
                              estruturaNomeUI,
                              style: GoogleFonts.lato(
                                fontSize: 13,
                                color: const Color(0xFF686868),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progresso na estrutura',
                              style: GoogleFonts.lato(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF3E3E3D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progresso ?? 0,
                                  minHeight: 8,
                                  backgroundColor: const Color(0xFFFFE0B2),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              textoProgresso(progresso),
                              style: GoogleFonts.lato(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF3E3E3D),
                              ),
                            ),
                          ],
                        ),
                        if (progressoTipo != null) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              progressoTipo.contratados > 0
                                  ? '${progressoTipo.realizados} de ${progressoTipo.contratados} pontos contratados realizados'
                                  : 'Sem pontos contratados para a sua empresa neste ensaio',
                              style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF686868)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pontos de Ensaio',
                        style: GoogleFonts.lato(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF3E3E3D),
                        ),
                      ),
                      Row(
                        children: [
                          // Ícone de ordenação temporal (Asc/Desc)
                          IconButton(
                            icon: Icon(
                              _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                              color: const Color(0xFF3E3E3D),
                              size: 20,
                            ),
                            tooltip: _isAscending ? 'Mais antigos primeiro' : 'Mais recentes primeiro',
                            onPressed: () {
                              setState(() {
                                _isAscending = !_isAscending;
                              });
                            },
                          ),
                          CompactButton(
                            text: 'Novo',
                            width: 80,
                            onPressed: () async {
                              // Plano sem espaço: não abre um ponto novo (o servidor também recusa).
                              if (_verificandoEspaco) return;
                              _verificandoEspaco = true;
                              final bool temEspaco;
                              try {
                                temEspaco = await verificarArmazenamento(context, ref);
                              } finally {
                                _verificandoEspaco = false;
                              }
                              if (!temEspaco || !context.mounted) return;
                              _mostrarModalNovoEnsaio(
                                context,
                                widget.estruturaId,
                                tipoEnsaioNomeUI,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: CompactSearchBar(
                          hintText: 'Buscar local...',
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Lista de Pontos 
                Expanded(
                  child: pontosFiltrados.isEmpty
                      ? ListView(
                          // ListView com shrinkWrap falso ajuda o RefreshIndicator a funcionar 
                          // mesmo quando a lista está vazia
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 50),
                            Center(child: Text('Nenhum ponto encontrado.')),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          itemCount: pontosFiltrados.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final ponto = pontosFiltrados[index];
                            Color corRisco = _hexToColor(ponto.corFundoRisco, Colors.grey.shade200);
                            Color corTextoRisco = _hexToColor(ponto.corTextoRisco, Colors.grey.shade700);

                            return GestureDetector(
                              onTap: () async {
                                // Ultrassonografia tem 3 telas distintas por modo
                                // (Direto/Indireto/Mapeamento) — ao reabrir um ponto
                                // já salvo, o modo (e o pulso ultrassônico) precisam
                                // vir do banco (não dá pra supor 'Direta'/
                                // 'Longitudinal' como quando o ponto é novo).
                                String? tipoMedicaoUltrassom;
                                String? pulsoUltrassomico;
                                final tipoLower = tipoEnsaioNomeUI.toLowerCase();
                                if (tipoLower.contains('ultrassom') || tipoLower.contains('ultrasson')) {
                                  final modo = await EnsaioRoutesMap.resolverModoUltrassom(ponto.id);
                                  tipoMedicaoUltrassom = modo.tipoMedicao;
                                  pulsoUltrassomico = modo.pulsoUltrassonico;
                                }

                                if (!context.mounted) return;
                                final Widget? telaFormulario =
                                    EnsaioRoutesMap.getFormularioScreen(
                                      tipoEnsaio: tipoEnsaioNomeUI,
                                      projetoId: widget.projetoId,
                                      pontoNome: ponto.nome,
                                      elementoNome: ponto.elementoNome,
                                      tipoElemento: ponto.tipoElemento,
                                      local: ponto.local,
                                      elementoId: ponto.elementoId,
                                      pontoGeralId: ponto.id,
                                      tipoEnsaioId: widget.tipoEnsaioId,
                                      tipoMedicao: tipoMedicaoUltrassom,
                                      pulsoUltrassonico: pulsoUltrassomico,
                                    );

                                if (telaFormulario != null) {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => telaFormulario),
                                  );

                                  // Refresh automático garantido ao retornar do formulário
                                  ref.invalidate(
                                    pontosEnsaioProvider((
                                      projetoId: widget.projetoId,
                                      estruturaId: widget.estruturaId,
                                      tipoEnsaioId: widget.tipoEnsaioId,
                                      elementoId: widget.elementoId,
                                    )),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Formulário não implementado para este ensaio.'),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.grey.shade200,
                                        image: ponto.fotoElementoUrl.isNotEmpty &&
                                                ponto.fotoElementoUrl != 'https://via.placeholder.com/150'
                                            ? DecorationImage(
                                                image: StorageNetworkImage(ponto.fotoElementoUrl),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      // Sem foto do elemento (caso dos ensaios
                                      // que não se ligam a um), o card mostra
                                      // o ícone do próprio ensaio.
                                      child: (ponto.fotoElementoUrl.isEmpty ||
                                              ponto.fotoElementoUrl == 'https://via.placeholder.com/150')
                                          ? Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Image.asset(
                                                widget.iconeEnsaio,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, _, _) =>
                                                    const Icon(Icons.architecture, color: Colors.grey),
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                ponto.elementoNome,
                                                style: GoogleFonts.lato(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF3E3E3D),
                                                ),
                                              ),
                                              AutoriaBadge(autor: ponto.autor),
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                ponto.nome,
                                                style: GoogleFonts.lato(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF3E3E3D),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            ponto.local,
                                            style: GoogleFonts.lato(
                                              fontSize: 13,
                                              color: const Color(0xFF686868),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                ponto.tipoElemento,
                                                style: GoogleFonts.lato(
                                                  fontSize: 13,
                                                  color: const Color(0xFF686868),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: corRisco,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  ponto.textoRisco,
                                                  style: GoogleFonts.lato(
                                                    color: corTextoRisco,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (ponto.modoUltrassom != null) ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                _buildBadgeUltrassom(_rotuloModoUltrassom(ponto.modoUltrassom!), Icons.settings_input_antenna_outlined),
                                                if (ponto.pulsoUltrassonico != null && ponto.pulsoUltrassonico!.isNotEmpty) ...[
                                                  const SizedBox(width: 6),
                                                  _buildBadgeUltrassom(ponto.pulsoUltrassonico!, Icons.graphic_eq),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _rotuloModoUltrassom(String modo) {
    switch (modo.toLowerCase()) {
      case 'direto':
        return 'Direto';
      case 'indireto':
        return 'Indireto';
      case 'mapeamento':
        return 'Mapeamento';
      default:
        return modo;
    }
  }

  Widget _buildBadgeUltrassom(String texto, IconData icone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 11, color: AppColors.primary),
          const SizedBox(width: 3),
          Text(texto, style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ],
      ),
    );
  }
}