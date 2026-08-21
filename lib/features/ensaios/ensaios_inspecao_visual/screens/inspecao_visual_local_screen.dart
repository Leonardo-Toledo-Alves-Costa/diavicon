import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import 'registro_inspecao_screen.dart';

// Provider dos Registros do Local
final pontosLocalProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, ({String inspecaoGeralId, String localId})>((ref, params) async {
  final supabase = Supabase.instance.client;
  
  final res = await supabase.from('ponto_inspecao_visual').select('''
    id, registro, descricao, 
    tipos_elemento (nome), 
    elementos_estruturais (nome),
    ponto_inspecao_visual_galeria (foto_url),
    ponto_inspecao_visual_anomalia (risco_maj, anomalias(nome))
  ''')
  .eq('id_ponto_geral', params.inspecaoGeralId)
  .eq('id_local', params.localId)
  .order('criado_em', ascending: false);

  return List<Map<String, dynamic>>.from(res);
});

// Provider dos Tipos de Elemento (Filtrados por Empresa)
final tiposElementoProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser!.id;
  final userRes = await supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
  
  var query = supabase.from('tipos_elemento').select('id, nome');
  if (userRes != null && userRes['empresa_id'] != null) {
    query = query.eq('empresa_id', userRes['empresa_id']);
  }
  final res = await query.order('nome');
  return List<Map<String, dynamic>>.from(res);
});

class InspecaoVisualLocalScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String estruturaId;
  final String inspecaoGeralId;
  final String projetoNome;
  final String estruturaNome;
  final String inspecaoNome;
  final String localId;
  final String localNome;

  const InspecaoVisualLocalScreen({
    super.key,
    required this.projetoId,
    required this.estruturaId,
    required this.inspecaoGeralId,
    required this.projetoNome,
    required this.estruturaNome,
    required this.inspecaoNome,
    required this.localId,
    required this.localNome,
  });

  @override
  ConsumerState<InspecaoVisualLocalScreen> createState() => _InspecaoVisualLocalScreenState();
}

class _InspecaoVisualLocalScreenState extends ConsumerState<InspecaoVisualLocalScreen> {
  String? _filtroTipoElementoNome; // Estado do Dropdown de filtro

  @override
  Widget build(BuildContext context) {
    final asyncPontos = ref.watch(pontosLocalProvider((inspecaoGeralId: widget.inspecaoGeralId, localId: widget.localId)));
    final asyncTipos = ref.watch(tiposElementoProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(title: 'Inspeção Visual\nLocal', showBackButton: true),
      body: asyncPontos.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (pontosData) {
          int gutTotal = 0;
          final Set<String> elementosUnicos = {};

          for (var p in pontosData) {
            if (p['elementos_estruturais'] != null && p['elementos_estruturais']['nome'] != null) {
               elementosUnicos.add(p['elementos_estruturais']['nome']);
            }
            final anomalias = p['ponto_inspecao_visual_anomalia'] as List? ?? [];
            for (var a in anomalias) {
              gutTotal += (a['risco_maj'] as num?)?.toInt() ?? 0;
            }
          }

          // APLICA O FILTRO DA LISTA BASEADO NO DROPDOWN DE ELEMENTOS
          final pontosVisiveis = pontosData.where((p) {
            if (_filtroTipoElementoNome == null || _filtroTipoElementoNome == 'Todos') return true;
            return p['tipos_elemento'] != null && p['tipos_elemento']['nome'] == _filtroTipoElementoNome;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Local inspecionado', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(widget.localNome, style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                        const Icon(Icons.edit_square, color: Color(0xFF3E3E3D)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(widget.projetoNome, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade600)),
                    Text(widget.estruturaNome, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade600)),
                    Text(widget.inspecaoNome, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMiniCard('Registros', pontosData.length.toString().padLeft(2, '0')),
                        _buildMiniCard('Elementos', elementosUnicos.length.toString().padLeft(2, '0')),
                        _buildMiniCardGUT(gutTotal.toString()),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // DROPDOWN DE FILTRO E BOTÃO NOVO
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(24)),
                            child: DropdownButtonHideUnderline(
                              child: asyncTipos.when(
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (_, _) => const Text('Erro'),
                                data: (tipos) {
                                  // Adiciona a opção "Todos" no topo
                                  final items = [
                                    const DropdownMenuItem(value: 'Todos', child: Text('Todos os Elementos')),
                                    ...tipos.map((t) => DropdownMenuItem(value: t['nome'].toString(), child: Text(t['nome'].toString(), overflow: TextOverflow.ellipsis)))
                                  ];
                                  return DropdownButton<String>(
                                    isExpanded: true,
                                    hint: Text('Elementos', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                                    value: _filtroTipoElementoNome,
                                    items: items,
                                    onChanged: (val) {
                                      setState(() {
                                        _filtroTipoElementoNome = val == 'Todos' ? null : val;
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => RegistroInspecaoScreen(
                              projetoId: widget.projetoId,
                              estruturaId: widget.estruturaId,
                              inspecaoGeralId: widget.inspecaoGeralId,
                              localPreSelecionadoId: widget.localId, 
                              pontoInspecaoId: null, 
                            ))).then((_) => ref.invalidate(pontosLocalProvider));
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 0),
                          child: const Text('Novo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: pontosVisiveis.isEmpty 
                  ? const Center(child: Text('Nenhum registro para este filtro.', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: pontosVisiveis.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final p = pontosVisiveis[index];
                    
                    final galeria = p['ponto_inspecao_visual_galeria'] as List? ?? [];
                    final capaUrl = galeria.isNotEmpty ? galeria.first['foto_url'] : null;
                    
                    final anomalias = p['ponto_inspecao_visual_anomalia'] as List? ?? [];
                    int gutCard = 0;
                    List<String> tagsAnomalia = [];
                    for (var a in anomalias) {
                      gutCard += (a['risco_maj'] as num?)?.toInt() ?? 0;
                      if (a['anomalias'] != null) tagsAnomalia.add(a['anomalias']['nome']);
                    }

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => RegistroInspecaoScreen(
                          projetoId: widget.projetoId, estruturaId: widget.estruturaId, inspecaoGeralId: widget.inspecaoGeralId,
                          localPreSelecionadoId: widget.localId,
                          pontoInspecaoId: p['id'], 
                        ))).then((_) => ref.invalidate(pontosLocalProvider));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))]),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12), image: capaUrl != null ? DecorationImage(image: NetworkImage(capaUrl), fit: BoxFit.cover) : null),
                              child: capaUrl == null ? const Icon(Icons.image, color: Colors.grey) : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['registro'] ?? 'Sem Registro', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text(p['descricao'] ?? '', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade500), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      if (p['tipos_elemento'] != null)
                                        Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)), child: Text(p['tipos_elemento']['nome'] ?? '', style: GoogleFonts.lato(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                                      if (p['elementos_estruturais'] != null)
                                        Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)), child: Text(p['elementos_estruturais']['nome'] ?? '', style: GoogleFonts.lato(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text('+ ${galeria.length} fotos', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600)),
                                      const Spacer(),
                                      if (tagsAnomalia.isNotEmpty)
                                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)), child: Text(tagsAnomalia.first, style: GoogleFonts.lato(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red))),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                                        child: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 10), const SizedBox(width: 2), Text('G.U.T $gutCard', style: GoogleFonts.lato(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade800))]),
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

  Widget _buildMiniCard(String titulo, String valor) => Container(width: 85, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]), child: Column(children: [Text(titulo, style: GoogleFonts.lato(fontSize: 10, color: Colors.grey.shade600)), const SizedBox(height: 4), Text(valor, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)))]));
  Widget _buildMiniCardGUT(String valor) => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]), child: Column(children: [Text('Pontuação G.U.T', style: GoogleFonts.lato(fontSize: 10, color: Colors.grey.shade600)), const SizedBox(height: 4), Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16), const SizedBox(width: 4), Text(valor, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)))])]));
}