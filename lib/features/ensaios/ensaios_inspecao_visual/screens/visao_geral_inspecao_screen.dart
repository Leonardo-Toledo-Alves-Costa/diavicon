import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../utils/risco_gut_calculo.dart';
import 'analise_geral_inspecao_screen.dart';
import 'inspecao_visual_local_screen.dart';
import 'registro_inspecao_screen.dart';

final visaoGeralProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, String>((ref, inspecaoGeralId) async {
  final supabase = Supabase.instance.client;
  final res = await supabase.from('ponto_inspecao_visual').select('''id, id_local, estruturas_locais (nome), id_elemento, ponto_inspecao_visual_anomalia (risco_maj, area_afetada, anomalias(gravidade_valor, urgencia_valor, tendencia_valor))''').eq('id_ponto_geral', inspecaoGeralId);

  final List<dynamic> pontos = res;
  double totalGut = 0;
  final Set<String> locaisUnicos = {};
  final Set<String> elementosUnicos = {};
  final Map<String, Map<String, dynamic>> agrupamentoLocais = {};

  for (var ponto in pontos) {
    if (ponto['id_local'] != null) locaisUnicos.add(ponto['id_local']);
    if (ponto['id_elemento'] != null) elementosUnicos.add(ponto['id_elemento']);

    double gutPonto = 0;
    final anomalias = ponto['ponto_inspecao_visual_anomalia'] as List? ?? [];
    for (var a in anomalias) {
      final anomaliaCatalogo = a['anomalias'] as Map<String, dynamic>?;
      gutPonto += calcularPontuacaoRiscoGut(
        gravidadeValor: anomaliaCatalogo?['gravidade_valor'],
        urgenciaValor: anomaliaCatalogo?['urgencia_valor'],
        tendenciaValor: anomaliaCatalogo?['tendencia_valor'],
        majoracao: a['risco_maj'],
        areaAfetada: a['area_afetada'],
      );
    }
    totalGut += gutPonto;

    final localId = ponto['id_local'];
    if (localId != null) {
      final localNome = ponto['estruturas_locais']?['nome'] ?? 'Local Desconhecido';
      if (!agrupamentoLocais.containsKey(localId)) agrupamentoLocais[localId] = {'id': localId, 'nome': localNome, 'registros': 0, 'gut': 0.0};
      agrupamentoLocais[localId]!['registros'] += 1;
      agrupamentoLocais[localId]!['gut'] += gutPonto;
    }
  }

  return {
    'total_registros': pontos.length,
    'total_locais': locaisUnicos.length,
    'total_elementos': elementosUnicos.length,
    'gut_total': totalGut,
    'locais': agrupamentoLocais.values.toList()..sort((a, b) => a['nome'].toString().compareTo(b['nome'].toString())),
  };
});

class VisaoGeralInspecaoScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String estruturaId;
  final String inspecaoGeralId;
  final String inspecaoGeralNome;
  final String projetoNome;
  final String estruturaNome;
  final String descricaoInspecao;

  const VisaoGeralInspecaoScreen({
    super.key, required this.projetoId, required this.estruturaId, required this.inspecaoGeralId, required this.inspecaoGeralNome, required this.projetoNome, required this.estruturaNome, required this.descricaoInspecao,
  });

  @override
  ConsumerState<VisaoGeralInspecaoScreen> createState() => _VisaoGeralInspecaoScreenState();
}

class _VisaoGeralInspecaoScreenState extends ConsumerState<VisaoGeralInspecaoScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final asyncDados = ref.watch(visaoGeralProvider(widget.inspecaoGeralId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      //appBar: const CustomAppBar(title: 'Inspeção Visual\nVisão Geral', showBackButton: true),
      appBar: CustomAppBar(
        title: 'Painel',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: const Column(
          children: [
            //Text('Empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Inspeção Visual', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Visão geral', style: TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ),
        extraActions: [
          IconButton(
            icon: const Icon(Icons.insights, color: Colors.white),
            tooltip: 'Análise Geral',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AnaliseGeralInspecaoScreen(
                  projetoId: widget.projetoId,
                  estruturaId: widget.estruturaId,
                  inspecaoGeralId: widget.inspecaoGeralId,
                  inspecaoGeralNome: widget.inspecaoGeralNome,
                  projetoNome: widget.projetoNome,
                  estruturaNome: widget.estruturaNome,
                ),
              ),
            ),
          ),
        ],
      ),
      
      body: asyncDados.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Erro ao carregar dados: $e')),
        data: (dados) {
          final locais = dados['locais'] as List<Map<String, dynamic>>;
          final locaisFiltrados = locais.where((l) => _filtro.isEmpty || l['nome'].toString().toLowerCase().contains(_filtro)).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(widget.inspecaoGeralNome, style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)))), const Icon(Icons.edit_square, color: Color(0xFF3E3E3D))]),
                const SizedBox(height: 4),
                Text(widget.projetoNome, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade600)),
                Text(widget.estruturaNome, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniCard('Registros', dados['total_registros'].toString().padLeft(2, '0')),
                    _buildMiniCard('Locais', dados['total_locais'].toString().padLeft(2, '0')),
                    _buildMiniCard('Elementos', dados['total_elementos'].toString().padLeft(2, '0')),
                    _buildMiniCardGUT((dados['gut_total'] as double).toStringAsFixed(2)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Objetivo', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))), const SizedBox(height: 8), Text(widget.descricaoInspecao, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade600))]),
                ),
                const SizedBox(height: 32),
                Text('Locais Inspecionados', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _searchCtrl, onChanged: (val) => setState(() => _filtro = val.toLowerCase()), decoration: InputDecoration(hintText: 'Local', hintStyle: const TextStyle(color: Colors.grey, fontSize: 13), prefixIcon: const Icon(Icons.search, color: Colors.grey), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 0), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey.shade300)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey.shade300))))),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => RegistroInspecaoScreen(
                           projetoId: widget.projetoId, estruturaId: widget.estruturaId, inspecaoGeralId: widget.inspecaoGeralId, localPreSelecionadoId: null
                         ))).then((_) => ref.invalidate(visaoGeralProvider));
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 0),
                      child: const Text('Novo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (locaisFiltrados.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('Nenhum registro encontrado.', style: TextStyle(color: Colors.grey)))),
                ...locaisFiltrados.map((local) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => InspecaoVisualLocalScreen(
                        projetoId: widget.projetoId, estruturaId: widget.estruturaId, inspecaoGeralId: widget.inspecaoGeralId,
                        projetoNome: widget.projetoNome, estruturaNome: widget.estruturaNome, inspecaoNome: widget.inspecaoGeralNome,
                        localId: local['id'], localNome: local['nome'],
                      ))).then((_) => ref.invalidate(visaoGeralProvider));
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))]),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(local['nome'], style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))), const SizedBox(height: 4), Text('${local['registros']} registros', style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade500)), const SizedBox(height: 4), Text('Pontuação G.U.T ${(local['gut'] as double).toStringAsFixed(2)}', style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFFFFA726)))]),  //const Color(0xFFFFA726)
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniCard(String titulo, String valor) => Container(width: 75, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]), child: Column(children: [Text(titulo, style: GoogleFonts.lato(fontSize: 10, color: Colors.grey.shade600)), const SizedBox(height: 4), Text(valor, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)))]));
  Widget _buildMiniCardGUT(String valor) => Container(width: 85, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]), child: Column(children: [Text('G.U.T', style: GoogleFonts.lato(fontSize: 10, color: Colors.grey.shade600)), const SizedBox(height: 4), Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16), const SizedBox(width: 4), Text(valor, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)))])]));
}