import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../repositories/inspecao_visual_repository.dart';
import 'visao_geral_inspecao_screen.dart';

// Provider para buscar foto da empresa
final fotoEmpresaProvider = FutureProvider.family.autoDispose<String?, String?>((ref, criadoPorId) async {
  final supabase = Supabase.instance.client;
  final userId = criadoPorId ?? supabase.auth.currentUser?.id;
  if (userId == null) return null;

  try {
    final res = await supabase.from('usuarios').select('empresas(foto_url)').eq('id', userId).maybeSingle();
    if (res != null && res['empresas'] != null) return res['empresas']['foto_url'] as String?;
  } catch (e) {
    debugPrint('Erro ao buscar foto da empresa: $e');
  }
  return null;
});

// NOVO: Provider para buscar nomes dinamicamente pelos IDs
final nomesProjetoEstruturaProvider = FutureProvider.family.autoDispose<Map<String, String>, ({String projetoId, String estruturaId})>((ref, params) async {
  final supabase = Supabase.instance.client;
  
  final projF = supabase.from('projetos').select('nome').eq('id', params.projetoId).maybeSingle();
  final estF = supabase.from('estruturas').select('nome').eq('id', params.estruturaId).maybeSingle();
  
  final results = await Future.wait([projF, estF]);
  final proj = results[0];
  final est = results[1];
  
  return {
    'projetoNome': proj?['nome'] as String? ?? 'Projeto',
    'estruturaNome': est?['nome'] as String? ?? 'Estrutura',
  };
});

class InspecaoVisualListaScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String projetoNome;
  final String estruturaNome;
  final String estruturaId;
  final String iconeEnsaio;
 
  const InspecaoVisualListaScreen({
    super.key,
    required this.projetoId,
    required this.projetoNome,
    required this.estruturaNome,
    required this.estruturaId,
    required this.iconeEnsaio,
  });

  @override
  ConsumerState<InspecaoVisualListaScreen> createState() => _InspecaoVisualListaScreenState();
}

class _InspecaoVisualListaScreenState extends ConsumerState<InspecaoVisualListaScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filtro = '';
  bool _sortAscending = false; // Controle de Ordenação

  void _abrirModalNovaInspecao() {
    showDialog(
      context: context, 
      builder: (context) => ModalNovaInspecao(
        projetoId: widget.projetoId, 
        estruturaId: widget.estruturaId
      )
    ).then((_) => ref.invalidate(listaInspecoesGeraisProvider));
  }

  @override
  Widget build(BuildContext context) {
    final asyncInspecoes = ref.watch(listaInspecoesGeraisProvider((
      projetoId: widget.projetoId, 
      estruturaId: widget.estruturaId
    )));

    // Busca os nomes do BD
    final nomesAsync = ref.watch(nomesProjetoEstruturaProvider((
      projetoId: widget.projetoId, 
      estruturaId: widget.estruturaId
    )));

    final projetoNomeUI = nomesAsync.value?['projetoNome'] ?? widget.projetoNome;
    final estruturaNomeUI = nomesAsync.value?['estruturaNome'] ?? widget.estruturaNome;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Projeto', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
            Text('Inspeção Visual', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white, padding: const EdgeInsets.all(24),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Inspeção Visual', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                    Text(projetoNomeUI, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
                    Text(estruturaNomeUI, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Inspeções Realizadas', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                ElevatedButton(onPressed: _abrirModalNovaInspecao, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), padding: const EdgeInsets.symmetric(horizontal: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 0), child: const Text('Novo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          // BARRA DE PESQUISA + ÍCONE DE ORDENAÇÃO
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl, 
                    onChanged: (val) => setState(() => _filtro = val.toLowerCase()), 
                    decoration: InputDecoration(
                      hintText: 'Local', hintStyle: const TextStyle(color: Colors.grey, fontSize: 13), 
                      prefixIcon: const Icon(Icons.search, color: Colors.grey), 
                      filled: true, fillColor: Colors.white, 
                      contentPadding: const EdgeInsets.symmetric(vertical: 0), 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey.shade300)), 
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey.shade300)), 
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFFFA726)))
                    )
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade300)),
                  child: IconButton(
                    onPressed: () => setState(() => _sortAscending = !_sortAscending),
                    icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, color: const Color(0xFFFFA726)),
                    tooltip: 'Ordenar por Data',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: asyncInspecoes.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, _) => Center(child: Text('Erro: $err', style: const TextStyle(color: Colors.red))),
              data: (lista) {
                var listaFiltrada = lista.where((insp) => _filtro.isEmpty || insp.locaisAtendidos.any((local) => local.toLowerCase().contains(_filtro))).toList();
                
                listaFiltrada.sort((a, b) {
                  final dataA = a.criadoEm ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final dataB = b.criadoEm ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return _sortAscending ? dataA.compareTo(dataB) : dataB.compareTo(dataA);
                });

                if (listaFiltrada.isEmpty) return const Center(child: Text('Nenhuma inspeção encontrada.', style: TextStyle(color: Colors.grey)));

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: listaFiltrada.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final insp = listaFiltrada[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => VisaoGeralInspecaoScreen(
                          inspecaoGeralId: insp.id,
                          inspecaoGeralNome: insp.nome,
                          descricaoInspecao: insp.descricao ?? 'Sem descrição',
                          projetoId: widget.projetoId,
                          projetoNome: projetoNomeUI,
                          estruturaId: widget.estruturaId,
                          estruturaNome: estruturaNomeUI,
                        )));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))]),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(insp.nome, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                                  const SizedBox(height: 4),
                                  //Text('$projetoNomeUI • $estruturaNomeUI', style: GoogleFonts.lato(fontSize: 11, color: const Color(0xFFFFA726), fontWeight: FontWeight.bold)),
                                  //const SizedBox(height: 4),
                                  Text('${insp.tipo} - ${insp.totalRegistros} registros', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
                                  const SizedBox(height: 8),
                                  Text(insp.locaisAtendidos.isEmpty ? 'Nenhum local registrado' : insp.locaisAtendidos.join(' | '), style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade400)),
                                ],
                              ),
                            ),
                            Consumer(
                              builder: (context, ref, child) {
                                final fotoAsync = ref.watch(fotoEmpresaProvider(insp.criadoPor));
                                return CircleAvatar(
                                  backgroundColor: Colors.grey.shade100, radius: 16,
                                  backgroundImage: fotoAsync.when(
                                    data: (url) => url != null && url.isNotEmpty ? NetworkImage(url) : const AssetImage('assets/images/escudo_diavicon.png') as ImageProvider,
                                    loading: () => const AssetImage('assets/images/escudo_diavicon.png'),
                                    error: (_, _) => const AssetImage('assets/images/escudo_diavicon.png'),
                                  ),
                                );
                              },
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ModalNovaInspecao extends ConsumerStatefulWidget {
  final String projetoId;
  final String estruturaId;

  const ModalNovaInspecao({super.key, required this.projetoId, required this.estruturaId});

  @override
  ConsumerState<ModalNovaInspecao> createState() => _ModalNovaInspecaoState();
}

class _ModalNovaInspecaoState extends ConsumerState<ModalNovaInspecao> {
  final _nomeCtrl = TextEditingController();
  final _objetivoCtrl = TextEditingController();
  String _tipoSelecionado = 'Selecione';
  bool _salvando = false;

  Future<void> _salvar() async {
    if (_nomeCtrl.text.isEmpty || _tipoSelecionado == 'Selecione') return;
    setState(() => _salvando = true);
    try {
      await ref.read(inspecaoVisualRepoProvider).criarNovaInspecao(
        nome: _nomeCtrl.text, 
        tipo: _tipoSelecionado, 
        descricao: _objetivoCtrl.text, 
        projetoId: widget.projetoId,
        estruturaId: widget.estruturaId,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Nova Inspeção Visual', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))), GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.grey))]),
            const SizedBox(height: 24),
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('Nome da Inspeção', style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade600))),
            TextField(controller: _nomeCtrl, decoration: InputDecoration(hintText: 'Nome', hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFFA726))))),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('Tipo de Inspeção', style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade600))),
            Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, value: _tipoSelecionado, items: ['Selecione', 'Inspeção preliminar', 'Inspeção rotineira', 'Inspeção especial'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (val) => setState(() => _tipoSelecionado = val!)))),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('Objetivo da Inspeção', style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade600))),
            TextField(controller: _objetivoCtrl, maxLines: 3, decoration: InputDecoration(hintText: 'Descrição da Inspeção', hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFFA726))))),
            const SizedBox(height: 20),
            Center(child: ElevatedButton(onPressed: _salvando ? null : _salvar, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 0), child: _salvando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}