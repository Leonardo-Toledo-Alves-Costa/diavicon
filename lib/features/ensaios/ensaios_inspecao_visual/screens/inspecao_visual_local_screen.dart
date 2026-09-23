import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/confirmar_exclusao_dialog.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../../empresa/providers/campos_personalizaveis_provider.dart';
import '../repositories/inspecao_visual_repository.dart';
import '../utils/risco_gut_calculo.dart';
import 'inspecao_analise_screen.dart';
import 'registro_inspecao_screen.dart';
import 'visao_geral_inspecao_screen.dart';
import '../widgets/iv_ui.dart';

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
  bool _ordenarPorGut = true;

  Future<void> _excluirRegistro(String pontoInspecaoId) async {
    final confirmar = await showConfirmarExclusaoDialog(
      context: context,
      titulo: 'Excluir registro',
      mensagem: 'Este registro de inspeção será excluído definitivamente, com suas fotos, marcações e anomalias. Esta ação não poderá ser desfeita.',
    );
    if (confirmar != true || !mounted) return;

    try {
      await ref.read(inspecaoVisualRepoProvider).excluirRegistro(pontoInspecaoId);
      ref.invalidate(pontosLocalProvider);
      ref.invalidate(visaoGeralProvider(widget.inspecaoGeralId));
      ref.invalidate(listaInspecoesGeraisProvider((projetoId: widget.projetoId, estruturaId: widget.estruturaId)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro excluído com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir registro: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _excluirLocal() async {
    List<Map<String, dynamic>> pontos;
    try {
      pontos = await ref.read(pontosLocalProvider((inspecaoGeralId: widget.inspecaoGeralId, localId: widget.localId)).future);
    } catch (_) {
      pontos = const [];
    }
    if (!mounted) return;

    final quantidade = pontos.length;
    final confirmar = await showConfirmarExclusaoDialog(
      context: context,
      titulo: 'Excluir local',
      mensagem: quantidade == 0
          ? 'Este local não tem registros. Deseja mesmo assim removê-lo desta inspeção?'
          : 'Isso excluirá definitivamente ${widget.localNome} e todos os $quantidade registro${quantidade == 1 ? '' : 's'} de inspeção contidos nele (fotos, marcações e anomalias inclusas). Esta ação não poderá ser desfeita.',
    );
    if (confirmar != true || !mounted) return;

    try {
      await ref.read(inspecaoVisualRepoProvider).excluirRegistrosDoLocal(inspecaoGeralId: widget.inspecaoGeralId, localId: widget.localId);
      ref.invalidate(visaoGeralProvider(widget.inspecaoGeralId));
      ref.invalidate(listaInspecoesGeraisProvider((projetoId: widget.projetoId, estruturaId: widget.estruturaId)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local excluído com sucesso!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir local: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncPontos = ref.watch(pontosLocalProvider((inspecaoGeralId: widget.inspecaoGeralId, localId: widget.localId)));
    final asyncTipos = ref.watch(tiposElementoProvider);
    final asyncSistemas = ref.watch(sistemasHabitacionaisProvider);

    return Scaffold(
      backgroundColor: kIvFundo,
      endDrawer: MenuDrawerAppBar(
        title: 'Inspeção Visual\nLocal',
        items: [
          DiaviconMenuItem(
            icon: Icons.insights,
            label: 'Análise por Local',
            onTap: () {
              Navigator.of(context).pop();
              _abrirAnalise();
            },
          ),
          DiaviconMenuItem(
            icon: Icons.delete_outline,
            label: 'Excluir local',
            onTap: () {
              Navigator.of(context).pop(); // fecha o drawer antes do diálogo
              _excluirLocal();
            },
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
            Text('Local', style: TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ),
      ),
      body: asyncPontos.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: EstadoVazioIv(
            icone: Icons.cloud_off_rounded,
            titulo: 'Não foi possível carregar os registros',
            texto: '$e',
            acao: TextButton.icon(onPressed: () => ref.invalidate(pontosLocalProvider), icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
          ),
        ),
        data: (pontosData) {
          double gutTotal = 0;
          final Set<String> elementosUnicos = {};
          final gutPorPonto = <String, double>{};

          for (var p in pontosData) {
            if (p['elementos_estruturais'] != null && p['elementos_estruturais']['nome'] != null) {
              elementosUnicos.add(p['elementos_estruturais']['nome']);
            }
            double gutPonto = 0;
            final anomalias = p['ponto_inspecao_visual_anomalia'] as List? ?? [];
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
            gutPorPonto[p['id'].toString()] = gutPonto;
            gutTotal += gutPonto;
          }

          // Filtro por sistema e por tipo de elemento (por id, não por nome).
          final pontosVisiveis = pontosData.where((p) {
            final tipoElemento = _extrairTipoElemento(p['tipos_elemento']);
            if (_filtroSistemaId != null) {
              if (tipoElemento == null || tipoElemento['sistemas_id']?.toString() != _filtroSistemaId) return false;
            }
            if (_filtroTipoElementoId == null) return true;
            return tipoElemento != null && tipoElemento['id']?.toString() == _filtroTipoElementoId;
          }).toList();
          if (_ordenarPorGut) {
            pontosVisiveis.sort((a, b) => (gutPorPonto[b['id'].toString()] ?? 0).compareTo(gutPorPonto[a['id'].toString()] ?? 0));
          }
          final filtrando = _filtroSistemaId != null || _filtroTipoElementoId != null;

          final filtroSistema = asyncSistemas.when(
            loading: () => const LinearProgressIndicator(color: AppColors.primary),
            error: (_, _) => const Text('Erro ao carregar sistemas'),
            data: (sistemas) => _dropdownFiltro(
              icone: Icons.account_tree_outlined,
              dica: 'Todos os sistemas',
              valor: _filtroSistemaId,
              itens: [for (final s in sistemas) (s['id'].toString(), s['nome'].toString())],
              aoMudar: (val) => setState(() {
                _filtroSistemaId = val;
                _filtroTipoElementoId = null;
              }),
            ),
          );
          final filtroTipo = asyncTipos.when(
            loading: () => const LinearProgressIndicator(color: AppColors.primary),
            error: (_, _) => const Text('Erro ao carregar elementos'),
            data: (tipos) {
              final tiposFiltrados = _filtroSistemaId == null
                  ? tipos
                  : tipos.where((t) => t['sistemas_id']?.toString() == _filtroSistemaId).toList();
              final valorValido = _filtroTipoElementoId != null && tiposFiltrados.any((t) => t['id'].toString() == _filtroTipoElementoId);
              return _dropdownFiltro(
                icone: Icons.view_in_ar_outlined,
                dica: 'Todos os tipos de elemento',
                valor: valorValido ? _filtroTipoElementoId : null,
                itens: [for (final t in tiposFiltrados) (t['id'].toString(), t['nome'].toString())],
                aoMudar: (val) => setState(() => _filtroTipoElementoId = val),
              );
            },
          );

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.refresh(pontosLocalProvider((inspecaoGeralId: widget.inspecaoGeralId, localId: widget.localId)).future),
            child: CorpoIv(
              children: [
                CabecalhoIv(
                  trilha: [widget.projetoNome, widget.estruturaNome, widget.inspecaoNome],
                  titulo: widget.localNome,
                  subtitulo: 'Local inspecionado',
                  acoes: [
                    BotaoIv(rotulo: 'Análise do local', icone: Icons.insights, aoTocar: _abrirAnalise),
                    BotaoIv(rotulo: 'Novo registro', icone: Icons.add_a_photo_outlined, primario: true, aoTocar: _novoRegistro),
                  ],
                ),
                const SizedBox(height: 20),
                IndicadoresIv(
                  itens: [
                    IndicadorIv(icone: Icons.fact_check_outlined, rotulo: 'Registros', valor: '${pontosData.length}'),
                    IndicadorIv(icone: Icons.view_in_ar_outlined, rotulo: 'Elementos', valor: '${elementosUnicos.length}'),
                    IndicadorIv.gut(gutTotal),
                  ],
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, c) {
                    final ordem = PilulasIv<bool>(
                      opcoes: const [(true, 'Maior G.U.T'), (false, 'Mais recentes')],
                      valor: _ordenarPorGut,
                      aoMudar: (v) => setState(() => _ordenarPorGut = v),
                    );
                    if (c.maxWidth < 760) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [filtroSistema, const SizedBox(height: 10), filtroTipo, const SizedBox(height: 10), ordem],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: filtroSistema),
                        const SizedBox(width: 12),
                        Expanded(child: filtroTipo),
                        const SizedBox(width: 16),
                        ordem,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      filtrando
                          ? '${pontosVisiveis.length} de ${pontosData.length} registros'
                          : (pontosData.length == 1 ? '1 registro' : '${pontosData.length} registros'),
                      style: const TextStyle(fontSize: 13, color: kIvSuave),
                    ),
                    const Spacer(),
                    if (filtrando)
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _filtroSistemaId = null;
                          _filtroTipoElementoId = null;
                        }),
                        icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                        label: const Text('Limpar filtros'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (pontosData.isEmpty)
                  EstadoVazioIv(
                    icone: Icons.add_a_photo_outlined,
                    titulo: 'Nenhum registro neste local',
                    texto: 'Registre o elemento com fotos, a localização em planta e as anomalias encontradas.',
                    acao: BotaoIv(rotulo: 'Novo registro', icone: Icons.add_a_photo_outlined, primario: true, aoTocar: _novoRegistro),
                  )
                else if (pontosVisiveis.isEmpty)
                  const EstadoVazioIv(icone: Icons.filter_alt_off_outlined, titulo: 'Nenhum registro para este filtro')
                else
                  GradeIv(
                    larguraMinima: 460,
                    filhos: [
                      for (final p in pontosVisiveis) _cartaoRegistro(p, gutPorPonto[p['id'].toString()] ?? 0),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _cartaoRegistro(Map<String, dynamic> p, double gut) {
    final galeria = p['ponto_inspecao_visual_galeria'] as List? ?? [];
    final capaUrl = galeria.isNotEmpty ? galeria.first['foto_url']?.toString() : null;
    final tipoElemento = _extrairTipoElemento(p['tipos_elemento']);
    final elemento = p['elementos_estruturais'];
    final anomalias = (p['ponto_inspecao_visual_anomalia'] as List? ?? [])
        .map((a) => (a['anomalias'] as Map<String, dynamic>?)?['nome']?.toString())
        .whereType<String>()
        .toList();
    return CartaoRegistroIv(
      titulo: p['registro']?.toString() ?? 'Sem nome',
      descricao: p['descricao']?.toString(),
      capaUrl: capaUrl,
      qtdFotos: galeria.length,
      etiquetas: [
        if (tipoElemento?['nome'] != null) tipoElemento!['nome'].toString(),
        if (elemento is Map && elemento['nome'] != null) elemento['nome'].toString(),
      ],
      anomalias: anomalias,
      gut: gut,
      aoTocar: () => _abrirRegistro(p['id'].toString()),
      aoExcluir: () => _excluirRegistro(p['id'].toString()),
    );
  }

  Widget _dropdownFiltro({
    required IconData icone,
    required String dica,
    required String? valor,
    required List<(String, String)> itens,
    required ValueChanged<String?> aoMudar,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: valor != null ? AppColors.primary : kIvBorda, width: valor != null ? 1.5 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icone, size: 18, color: kIvSuave),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: valor,
                hint: Text(dica, style: const TextStyle(color: kIvSuave, fontSize: 14)),
                items: [
                  DropdownMenuItem<String>(value: null, child: Text(dica)),
                  for (final (id, nome) in itens) DropdownMenuItem(value: id, child: Text(nome, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: aoMudar,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirAnalise() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InspecaoVisualAnaliseScreen(
          localId: widget.localId,
          localNome: widget.localNome,
          projetoId: widget.projetoId,
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
          localPreSelecionadoId: widget.localId,
          pontoInspecaoId: null,
        ),
      ),
    ).then((_) => ref.invalidate(pontosLocalProvider));
  }

  void _abrirRegistro(String pontoId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegistroInspecaoScreen(
          projetoId: widget.projetoId,
          estruturaId: widget.estruturaId,
          inspecaoGeralId: widget.inspecaoGeralId,
          localPreSelecionadoId: widget.localId,
          pontoInspecaoId: pontoId,
        ),
      ),
    ).then((_) => ref.invalidate(pontosLocalProvider));
  }
}
