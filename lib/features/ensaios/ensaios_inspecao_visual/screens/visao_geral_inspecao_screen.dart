import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/confirmar_exclusao_dialog.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../repositories/inspecao_visual_repository.dart';
import '../utils/risco_gut_calculo.dart';
import 'analise_geral_inspecao_screen.dart';
import 'inspecao_visual_local_screen.dart';
import 'registro_inspecao_screen.dart';
import 'relatorio_inspecao_screen.dart';
import '../widgets/iv_ui.dart';

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
  bool _ordenarPorGut = true;

  Future<void> _excluirInspecao() async {
    final navigator = Navigator.of(context);
    navigator.pop(); // fecha o drawer antes do diálogo

    int quantidade = ref.read(visaoGeralProvider(widget.inspecaoGeralId)).value?['total_registros'] as int? ?? 0;

    final confirmar = await showConfirmarExclusaoDialog(
      context: context,
      titulo: 'Excluir inspeção',
      mensagem: quantidade == 0
          ? 'A inspeção "${widget.inspecaoGeralNome}" não tem registros. Deseja mesmo assim excluí-la?'
          : 'Isso excluirá definitivamente a inspeção "${widget.inspecaoGeralNome}" e todos os $quantidade registro${quantidade == 1 ? '' : 's'} contidos nela (fotos, marcações e anomalias inclusas). Esta ação não poderá ser desfeita.',
    );
    if (confirmar != true || !mounted) return;

    try {
      await ref.read(inspecaoVisualRepoProvider).excluirInspecaoCompleta(widget.inspecaoGeralId);
      ref.invalidate(listaInspecoesGeraisProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspeção excluída com sucesso!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir inspeção: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncDados = ref.watch(visaoGeralProvider(widget.inspecaoGeralId));

    return Scaffold(
      backgroundColor: kIvFundo,
      endDrawer: MenuDrawerAppBar(
        title: 'Inspeção\nVisual',
        items: [
          DiaviconMenuItem(
            icon: Icons.insights,
            label: 'Análise Geral',
            onTap: () {
              Navigator.of(context).pop();
              _abrirAnaliseGeral();
            },
          ),
          DiaviconMenuItem(
            icon: Icons.assessment_outlined,
            label: 'Relatórios',
            onTap: () {
              Navigator.of(context).pop();
              _abrirRelatorios();
            },
          ),
          DiaviconMenuItem(
            icon: Icons.delete_outline,
            label: 'Excluir inspeção',
            onTap: _excluirInspecao,
          ),
        ],
      ),
      appBar: const CustomAppBar(
        title: 'Painel',
        showBackButton: true,
        showMenuButton: true,
        titleWidget: Column(
          children: [
            Text('Inspeção Visual', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Visão geral', style: TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ),
      ),
      body: asyncDados.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: EstadoVazioIv(
            icone: Icons.cloud_off_rounded,
            titulo: 'Não foi possível carregar a inspeção',
            texto: '$e',
            acao: TextButton.icon(
              onPressed: () => ref.invalidate(visaoGeralProvider(widget.inspecaoGeralId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ),
        ),
        data: (dados) {
          final locais = dados['locais'] as List<Map<String, dynamic>>;
          final locaisFiltrados = locais.where((l) => _filtro.isEmpty || l['nome'].toString().toLowerCase().contains(_filtro)).toList();
          if (_ordenarPorGut) {
            locaisFiltrados.sort((a, b) => (b['gut'] as double).compareTo(a['gut'] as double));
          }
          final maiorGut = locais.fold<double>(0, (m, l) => (l['gut'] as double) > m ? l['gut'] as double : m);
          final gutTotal = dados['gut_total'] as double;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.refresh(visaoGeralProvider(widget.inspecaoGeralId).future),
            child: CorpoIv(
              children: [
                CabecalhoIv(
                  trilha: [widget.projetoNome, widget.estruturaNome],
                  titulo: widget.inspecaoGeralNome,
                  subtitulo: 'Inspeção visual',
                  acoes: [
                    BotaoIv(rotulo: 'Análise geral', icone: Icons.insights, aoTocar: _abrirAnaliseGeral),
                    BotaoIv(rotulo: 'Relatórios', icone: Icons.assessment_outlined, aoTocar: _abrirRelatorios),
                    BotaoIv(rotulo: 'Novo registro', icone: Icons.add_a_photo_outlined, primario: true, aoTocar: _novoRegistro),
                  ],
                ),
                const SizedBox(height: 20),
                IndicadoresIv(
                  itens: [
                    IndicadorIv(icone: Icons.fact_check_outlined, rotulo: 'Registros', valor: '${dados['total_registros']}'),
                    IndicadorIv(icone: Icons.place_outlined, rotulo: 'Locais', valor: '${dados['total_locais']}'),
                    IndicadorIv(icone: Icons.view_in_ar_outlined, rotulo: 'Elementos', valor: '${dados['total_elementos']}'),
                    IndicadorIv.gut(gutTotal),
                  ],
                ),
                if (widget.descricaoInspecao.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SecaoIv(
                    titulo: 'Objetivo',
                    icone: Icons.flag_outlined,
                    child: Text(widget.descricaoInspecao, style: const TextStyle(fontSize: 14, color: kIvTexto, height: 1.45)),
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Locais inspecionados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kIvTinta)),
                    ),
                    Text(
                      locais.length == 1 ? '1 local' : '${locais.length} locais',
                      style: const TextStyle(fontSize: 13, color: kIvSuave),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, c) {
                    final busca = CampoBuscaIv(
                      controller: _searchCtrl,
                      dica: 'Buscar local',
                      aoMudar: (val) => setState(() => _filtro = val.toLowerCase()),
                    );
                    final ordem = PilulasIv<bool>(
                      opcoes: const [(true, 'Maior G.U.T'), (false, 'Nome')],
                      valor: _ordenarPorGut,
                      aoMudar: (v) => setState(() => _ordenarPorGut = v),
                    );
                    if (c.maxWidth < 640) {
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [busca, const SizedBox(height: 10), ordem]);
                    }
                    return Row(children: [Expanded(child: busca), const SizedBox(width: 16), ordem]);
                  },
                ),
                const SizedBox(height: 16),
                if (locais.isEmpty)
                  EstadoVazioIv(
                    icone: Icons.add_location_alt_outlined,
                    titulo: 'Nenhum registro nesta inspeção',
                    texto: 'Cada registro é feito em um local da estrutura, com fotos e anomalias.',
                    acao: BotaoIv(rotulo: 'Fazer o primeiro registro', icone: Icons.add_a_photo_outlined, primario: true, aoTocar: _novoRegistro),
                  )
                else if (locaisFiltrados.isEmpty)
                  const EstadoVazioIv(icone: Icons.search_off_rounded, titulo: 'Nenhum local encontrado')
                else
                  GradeIv(
                    larguraMinima: 380,
                    filhos: [
                      for (final local in locaisFiltrados)
                        CartaoLocalIv(
                          nome: local['nome'].toString(),
                          registros: local['registros'] as int,
                          gut: local['gut'] as double,
                          proporcaoGut: maiorGut <= 0 ? 0 : (local['gut'] as double) / maiorGut,
                          aoTocar: () => _abrirLocal(local),
                        ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _abrirAnaliseGeral() {
    Navigator.of(context).push(
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
    );
  }

  void _abrirRelatorios() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RelatorioInspecaoScreen(
          projetoId: widget.projetoId,
          estruturaId: widget.estruturaId,
          inspecaoGeralId: widget.inspecaoGeralId,
          inspecaoGeralNome: widget.inspecaoGeralNome,
          projetoNome: widget.projetoNome,
          estruturaNome: widget.estruturaNome,
        ),
      ),
    );
  }

  void _novoRegistro() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegistroInspecaoScreen(
          projetoId: widget.projetoId,
          estruturaId: widget.estruturaId,
          inspecaoGeralId: widget.inspecaoGeralId,
          localPreSelecionadoId: null,
        ),
      ),
    ).then((_) => ref.invalidate(visaoGeralProvider));
  }

  void _abrirLocal(Map<String, dynamic> local) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspecaoVisualLocalScreen(
          projetoId: widget.projetoId,
          estruturaId: widget.estruturaId,
          inspecaoGeralId: widget.inspecaoGeralId,
          projetoNome: widget.projetoNome,
          estruturaNome: widget.estruturaNome,
          inspecaoNome: widget.inspecaoGeralNome,
          localId: local['id'],
          localNome: local['nome'],
        ),
      ),
    ).then((_) => ref.invalidate(visaoGeralProvider));
  }

}
