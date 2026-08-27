import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../empresa/providers/campos_personalizaveis_provider.dart';
import '../utils/risco_gut_calculo.dart';
import 'inspecao_analise_screen.dart';
import 'registro_inspecao_screen.dart';

// Provider dos Registros do Local
final pontosLocalProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, ({String inspecaoGeralId, String localId})>((ref, params) async {
  final supabase = Supabase.instance.client;

  final res = await supabase.from('ponto_inspecao_visual').select('''
    id, registro, descricao,
    tipos_elemento (id, nome, sistemas_id),
    elementos_estruturais (nome),
    ponto_inspecao_visual_galeria (foto_url),
    ponto_inspecao_visual_anomalia (risco_maj, area_afetada, anomalias(nome, gravidade_valor, urgencia_valor, tendencia_valor))
  ''')
  .eq('id_ponto_geral', params.inspecaoGeralId)
  .eq('id_local', params.localId)
  .order('criado_em', ascending: false);

  return List<Map<String, dynamic>>.from(res);
});

// Provider dos Tipos de Elemento (empresa do usuário + padrão Diavicon)
final tiposElementoProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  String? empresaId;
  if (userId != null) {
    final userRes = await supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
    empresaId = userRes?['empresa_id']?.toString();
  }

  var query = supabase.from('tipos_elemento').select('id, nome, sistemas_id');
  final res = empresaId != null
      ? await query.inFilter('empresa_id', [empresaId, DIAVICON_EMPRESA_ID]).order('nome')
      : await query.eq('empresa_id', DIAVICON_EMPRESA_ID).order('nome');
  return List<Map<String, dynamic>>.from(res);
});

// Provider dos Sistemas Habitacionais (empresa do usuário + padrão Diavicon)
final sistemasHabitacionaisProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  final userRes = await supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
  final empresaId = userRes?['empresa_id']?.toString();
  if (empresaId == null) return [];

  final res = await supabase
      .from('sistemas_habitacionais')
      .select('id, nome')
      .inFilter('empresa_id', [empresaId, DIAVICON_EMPRESA_ID])
      .order('nome');
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

/// A relação `tipos_elemento` embutida no ponto às vezes vem como Map
/// (relação para-um) e às vezes o Supabase pode devolver como List — essa
/// função normaliza os dois formatos pra evitar erro de cast/comparação.
Map<String, dynamic>? _extrairTipoElemento(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is List && raw.isNotEmpty && raw.first is Map<String, dynamic>) {
    return raw.first as Map<String, dynamic>;
  }
  return null;
}

class _InspecaoVisualLocalScreenState extends ConsumerState<InspecaoVisualLocalScreen> {
  // Filtra por ID (não por nome): o mesmo nome de tipo pode existir em mais
  // de um sistema habitacional (ex: "Viga" cadastrada pela empresa e também
  // como padrão Diavicon), então comparar só pelo nome é ambíguo.
  String? _filtroTipoElementoId;
  String? _filtroSistemaId;

  @override
  Widget build(BuildContext context) {
    final asyncPontos = ref.watch(pontosLocalProvider((inspecaoGeralId: widget.inspecaoGeralId, localId: widget.localId)));
    final asyncTipos = ref.watch(tiposElementoProvider);
    final asyncSistemas = ref.watch(sistemasHabitacionaisProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: CustomAppBar(
        title: 'Painel',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: const Column(
          children: [
            //Text('Empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Inspeção Visual', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Local', style: TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ),
        extraActions: [
          IconButton(
            icon: const Icon(Icons.insights, color: Colors.white),
            tooltip: 'Análise por Local',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InspecaoVisualAnaliseScreen(
                  localId: widget.localId,
                  localNome: widget.localNome,
                  projetoId: widget.projetoId,
                ),
              ),
            ),
          ),
        ],
      ),
      body: asyncPontos.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (pontosData) {
          double gutTotal = 0;
          final Set<String> elementosUnicos = {};

          for (var p in pontosData) {
            if (p['elementos_estruturais'] != null && p['elementos_estruturais']['nome'] != null) {
               elementosUnicos.add(p['elementos_estruturais']['nome']);
            }
            final anomalias = p['ponto_inspecao_visual_anomalia'] as List? ?? [];
            for (var a in anomalias) {
              final anomaliaCatalogo = a['anomalias'] as Map<String, dynamic>?;
              gutTotal += calcularPontuacaoRiscoGut(
                gravidadeValor: anomaliaCatalogo?['gravidade_valor'],
                urgenciaValor: anomaliaCatalogo?['urgencia_valor'],
                tendenciaValor: anomaliaCatalogo?['tendencia_valor'],
                majoracao: a['risco_maj'],
                areaAfetada: a['area_afetada'],
              );
            }
          }

          // APLICA O FILTRO DA LISTA BASEADO NO SISTEMA E NO TIPO DE ELEMENTO
          final pontosVisiveis = pontosData.where((p) {
            final tipoElemento = _extrairTipoElemento(p['tipos_elemento']);

            if (_filtroSistemaId != null) {
              if (tipoElemento == null || tipoElemento['sistemas_id']?.toString() != _filtroSistemaId) {
                return false;
              }
            }

            if (_filtroTipoElementoId == null) return true;
            return tipoElemento != null && tipoElemento['id']?.toString() == _filtroTipoElementoId;
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
                        _buildMiniCardGUT(gutTotal.toStringAsFixed(2)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // DROPDOWN DE SISTEMA HABITACIONAL
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(24)),
                            child: DropdownButtonHideUnderline(
                              child: asyncSistemas.when(
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (_, _) => const Text('Erro'),
                                data: (sistemas) {
                                  final items = [
                                    const DropdownMenuItem(value: 'Todos', child: Text('Todos os Sistemas')),
                                    ...sistemas.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['nome'].toString(), overflow: TextOverflow.ellipsis))),
                                  ];
                                  return DropdownButton<String>(
                                    isExpanded: true,
                                    hint: Text('Sistema', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                                    value: _filtroSistemaId,
                                    items: items,
                                    onChanged: (val) {
                                      setState(() {
                                        _filtroSistemaId = val == 'Todos' ? null : val;
                                        _filtroTipoElementoId = null;
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

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
                                  final tiposFiltrados = _filtroSistemaId == null
                                      ? tipos
                                      : tipos.where((t) => t['sistemas_id']?.toString() == _filtroSistemaId).toList();
                                  // Adiciona a opção "Todos" no topo. Valor = id (não nome),
                                  // já que o mesmo nome pode existir em mais de um sistema.
                                  final items = [
                                    const DropdownMenuItem(value: 'Todos', child: Text('Todos os Elementos')),
                                    ...tiposFiltrados.map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text(t['nome'].toString(), overflow: TextOverflow.ellipsis)))
                                  ];
                                  final valorValido = _filtroTipoElementoId != null &&
                                      tiposFiltrados.any((t) => t['id'].toString() == _filtroTipoElementoId);
                                  return DropdownButton<String>(
                                    isExpanded: true,
                                    hint: Text('Elementos', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                                    value: valorValido ? _filtroTipoElementoId : null,
                                    items: items,
                                    onChanged: (val) {
                                      setState(() {
                                        _filtroTipoElementoId = val == 'Todos' ? null : val;
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
                    final tipoElementoCard = _extrairTipoElemento(p['tipos_elemento']);

                    final anomalias = p['ponto_inspecao_visual_anomalia'] as List? ?? [];
                    double gutCard = 0;
                    List<String> tagsAnomalia = [];
                    for (var a in anomalias) {
                      final anomaliaCatalogo = a['anomalias'] as Map<String, dynamic>?;
                      gutCard += calcularPontuacaoRiscoGut(
                        gravidadeValor: anomaliaCatalogo?['gravidade_valor'],
                        urgenciaValor: anomaliaCatalogo?['urgencia_valor'],
                        tendenciaValor: anomaliaCatalogo?['tendencia_valor'],
                        majoracao: a['risco_maj'],
                        areaAfetada: a['area_afetada'],
                      );
                      if (anomaliaCatalogo != null) tagsAnomalia.add(anomaliaCatalogo['nome']);
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
                                      if (tipoElementoCard != null)
                                        Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)), child: Text(tipoElementoCard['nome'] ?? '', style: GoogleFonts.lato(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                                      if (p['elementos_estruturais'] != null)
                                        Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)), child: Text(p['elementos_estruturais']['nome'] ?? '', style: GoogleFonts.lato(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      if (tagsAnomalia.isNotEmpty)
                                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)), child: Text(tagsAnomalia.first, style: GoogleFonts.lato(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red))),
                                    ],
                                  ),

                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text('+ ${galeria.length} fotos', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600)),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                                        child: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 10), const SizedBox(width: 2), Text('G.U.T ${gutCard.toStringAsFixed(2)}', style: GoogleFonts.lato(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade800))]),  //GoogleFonts.lato(fontSize: 11, color: const Color(0xFFFFA726), fontWeight: FontWeight.bold)),
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