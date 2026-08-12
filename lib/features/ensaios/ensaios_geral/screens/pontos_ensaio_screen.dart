import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/compact_button.dart';
import '../../../../core/widgets/compact_search_bar.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';

// Providers e Modais
import '../providers/pontos_ensaio_provider.dart';
import '../widgets/novo_ponto_ensaio_modal.dart';
import 'central_relatorios_screen.dart';
import '../models/ensaios_routes_map.dart';


// Telas de destino
//import 'package:diavicon/features/ensaios/ensaios_carbonatacao/screens/ponto_ensaio_carbonatacao_screen.dart';
//import '../../ensaios_carbonatacao/screens/analise_ensaio_todos_screen.dart'; // IMPORTANTE: Ajuste o caminho conforme salvou a tela de análise

class PontosEnsaioScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String estruturaId;
  final String iconeEnsaio;
  final String tipoEnsaioId; 

  const PontosEnsaioScreen({
    super.key,
    required this.projetoId,
    required this.estruturaId,
    required this.iconeEnsaio,
    required this.tipoEnsaioId,
  });

  @override
  ConsumerState<PontosEnsaioScreen> createState() => _PontosEnsaioScreenState();
}

class _PontosEnsaioScreenState extends ConsumerState<PontosEnsaioScreen> {
  String _searchQuery = '';
  String _filtroStatus = 'Todos';

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

  void _mostrarModalNovoEnsaio(BuildContext context, String estruturaId, String tipoEnsaioNome) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => NovoPontoEnsaioModal(
        estruturaId: estruturaId, 
        tipoEnsaioNome: tipoEnsaioNome, 
        tipoEnsaioId: widget.tipoEnsaioId, // 👈 Repassando o ID para o Modal salvar corretamente
        projetoId: widget.projetoId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Busca nome dinâmico
    final nomeEnsaioAsync = ref.watch(tipoEnsaioNomeProvider(widget.tipoEnsaioId));
    final tipoEnsaioNomeUI = nomeEnsaioAsync.value ?? 'Carregando...';

    // 2. Busca pontos e header
    final pontosAsync = ref.watch(pontosEnsaioProvider((
      projetoId: widget.projetoId,
      estruturaId: widget.estruturaId,
      tipoEnsaioId: widget.tipoEnsaioId,
    )));

    final nomesAsync = ref.watch(nomesHeaderProvider((
      projetoId: widget.projetoId,
      estruturaId: widget.estruturaId,
    )));

    final projetoNomeUI = nomesAsync.value?['projetoNome'] ?? 'Carregando...';
    final estruturaNomeUI = nomesAsync.value?['estruturaNome'] ?? 'Carregando...';

    final bool temDados = pontosAsync.value != null && pontosAsync.value!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: MenuDrawerAppBar(
        title: 'Menu do\nEnsaio',
        items: [
          if (temDados)
            DiaviconMenuItem(
              icon: Icons.menu_book_outlined,
              label: 'Informações',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tela de Informações em desenvolvimento.')));
              },
            )
          else
            Opacity(opacity: 0.4, child: DiaviconMenuItem(icon: Icons.menu_book_outlined, label: 'Informações', onTap: () {})),

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
                );

                if (telaAnalise != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => telaAnalise));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dashboard de Análise ainda não implementado para este ensaio.'), backgroundColor: Colors.orange)
                  );
                }
              },
            )
          else
            Opacity(opacity: 0.4, child: DiaviconMenuItem(icon: Icons.show_chart_rounded, label: 'Análises', onTap: () {})),

            DiaviconMenuItem(
              icon: Icons.assessment_outlined,
              label: 'Relatórios',
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop(context);
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) => CentralRelatoriosScreen(
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
            Text('Projeto', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
            Text('Ensaio', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: pontosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('Erro ao carregar pontos: $err')),
        data: (pontos) {
          final pontosFiltrados = pontos.where((p) {
            final matchesBusca = p.nome.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                p.elementoNome.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                p.local.toLowerCase().contains(_searchQuery.toLowerCase());
            bool matchesStatus = true;
            if (_filtroStatus == 'Concluídos') matchesStatus = p.textoRisco.toLowerCase() != 'pendente';
            else if (_filtroStatus == 'Pendentes') matchesStatus = p.textoRisco.toLowerCase() == 'pendente';
            return matchesBusca && matchesStatus;
          }).toList();

          final total = pontos.length;
          final concluidos = pontos.where((p) => p.textoRisco.toLowerCase() != 'pendente').length;
          final progresso = total > 0 ? concluidos / total : 0.0;
          final progressoPercent = (progresso * 100).toInt();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  children: [
                    SizedBox(width: 56, height: 56, child: Image.asset(widget.iconeEnsaio, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.science_outlined, color: AppColors.textDark, size: 36))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tipoEnsaioNomeUI, style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D))),
                          const SizedBox(height: 4),
                          Text(projetoNomeUI, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
                          Text(estruturaNomeUI, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
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
                  decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Progresso no projeto', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF3E3E3D))),
                          Text('${concluidos.toString().padLeft(2, '0')}/${total.toString().padLeft(2, '0')}', style: GoogleFonts.lato(fontSize: 14, color: const Color(0xFF686868))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progresso, minHeight: 8, backgroundColor: const Color(0xFFFFE0B2), valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary)))),
                          const SizedBox(width: 12),
                          Text('$progressoPercent%', style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                        ],
                      ),
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
                    Text('Pontos de Ensaio', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D))),
                    CompactButton(text: 'Novo', width: 80, onPressed: () => _mostrarModalNovoEnsaio(context, widget.estruturaId, tipoEnsaioNomeUI)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: CompactSearchBar(hintText: 'Local', onChanged: (val) => setState(() => _searchQuery = val))),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Container(
                        height: 38, padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFD9D9D9)), borderRadius: BorderRadius.circular(20)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true, value: _filtroStatus, icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                            style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF3E3E3D)),
                            items: ['Todos', 'Concluídos', 'Pendentes'].map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                            onChanged: (val) { if (val != null) setState(() => _filtroStatus = val); },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: pontosFiltrados.isEmpty
                    ? const Center(child: Text('Nenhum ponto encontrado.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        itemCount: pontosFiltrados.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final ponto = pontosFiltrados[index];
                          Color corRisco = _hexToColor(ponto.corFundoRisco, Colors.grey.shade200);
                          Color corTextoRisco = _hexToColor(ponto.corTextoRisco, Colors.grey.shade700);

                          return GestureDetector(
                            onTap: () async {
                              final Widget? telaFormulario = EnsaioRoutesMap.getFormularioScreen(
                                tipoEnsaio: tipoEnsaioNomeUI, 
                                projetoId: widget.projetoId,
                                pontoNome: ponto.nome,
                                elementoNome: estruturaNomeUI,
                                tipoElemento: ponto.tipoElemento,
                                local: ponto.local,
                                elementoId: ponto.elementoId,
                                pontoGeralId: ponto.id,
                                tipoEnsaioId: widget.tipoEnsaioId,
                              );

                              if (telaFormulario != null) {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => telaFormulario,
                                  ),
                                );

                                ref.invalidate(
                                  pontosEnsaioProvider((
                                    projetoId: widget.projetoId,
                                    estruturaId: widget.estruturaId,
                                    tipoEnsaioId: widget.tipoEnsaioId,
                                  )),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Formulário não implementado para este ensaio.'))
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 60, height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle, color: Colors.grey.shade200,
                                      image: ponto.fotoElementoUrl.isNotEmpty && ponto.fotoElementoUrl != 'https://via.placeholder.com/150'
                                          ? DecorationImage(image: NetworkImage(ponto.fotoElementoUrl), fit: BoxFit.cover) : null,
                                    ),
                                    child: (ponto.fotoElementoUrl.isEmpty || ponto.fotoElementoUrl == 'https://via.placeholder.com/150') ? const Icon(Icons.architecture, color: Colors.grey) : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(ponto.elementoNome, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF3E3E3D))),
                                            CircleAvatar(radius: 12, backgroundColor: Colors.transparent, backgroundImage: NetworkImage(ponto.avatarEmpresaUrl)),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(ponto.nome, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF3E3E3D))),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(ponto.local , style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(ponto.tipoElemento, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(color: corRisco, borderRadius: BorderRadius.circular(12)),
                                              child: Text(ponto.textoRisco, style: GoogleFonts.lato(color: corTextoRisco, fontSize: 10, fontWeight: FontWeight.w800)),
                                            ),
                                          ],
                                        ),
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
          );
        },
      ),
    );
  }
}