import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/models/autor_exibicao.dart';
import '../../../../core/repositories/autores_repository.dart';
import '../../../../core/widgets/autoria_badge.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../repositories/inspecao_visual_repository.dart';
import 'visao_geral_inspecao_screen.dart';
import '../widgets/iv_ui.dart';

// Autoria da inspeção — mesmo mecanismo dos demais ensaios (ver
// AutoriaBadge / autores_para_exibicao).
//
// Antes isto era um select direto em `usuarios` com dois defeitos: caía em
// `auth.currentUser` quando a inspeção não tinha autor (mostrando o logo de
// QUEM ESTAVA OLHANDO, não o da empresa que criou a inspeção), e mesmo com
// autor a policy auth_users_select_own só deixa ler a própria linha, então
// inspeções de colegas caíam no escudo genérico.
//
// Sem autor conhecido não há logo a mostrar: devolve null e o selo some, em
// vez de inventar uma empresa.
final autorInspecaoProvider = FutureProvider.family.autoDispose<AutorExibicao?, String?>(
  (ref, criadoPorId) async {
    if (criadoPorId == null || criadoPorId.isEmpty) return null;
    final autores = await AutoresRepository(Supabase.instance.client).buscarPorIds([criadoPorId]);
    return autores[criadoPorId];
  },
  retry: (_, _) => null,
);

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
      backgroundColor: kIvFundo,
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
      body: asyncInspecoes.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(
          child: EstadoVazioIv(
            icone: Icons.cloud_off_rounded,
            titulo: 'Não foi possível carregar as inspeções',
            texto: err.toString().replaceFirst('Exception: ', ''),
            acao: OutlinedButton(onPressed: () => ref.invalidate(listaInspecoesGeraisProvider), child: const Text('Tentar de novo')),
          ),
        ),
        data: (lista) {
          final listaFiltrada = lista.where((insp) {
            if (_filtro.isEmpty) return true;
            return insp.nome.toLowerCase().contains(_filtro) ||
                insp.locaisAtendidos.any((local) => local.toLowerCase().contains(_filtro));
          }).toList();

          listaFiltrada.sort((a, b) {
            final dataA = a.criadoEm ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dataB = b.criadoEm ?? DateTime.fromMillisecondsSinceEpoch(0);
            return _sortAscending ? dataA.compareTo(dataB) : dataB.compareTo(dataA);
          });

          final totalRegistros = lista.fold<int>(0, (t, i) => t + i.totalRegistros);

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.refresh(listaInspecoesGeraisProvider((projetoId: widget.projetoId, estruturaId: widget.estruturaId)).future),
            child: CorpoIv(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kIvBorda)),
                      child: Image.asset(
                        widget.iconeEnsaio,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(Icons.image_search_outlined, color: kIvLaranjaTexto, size: 30),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: CabecalhoIv(
                        trilha: [projetoNomeUI, estruturaNomeUI],
                        titulo: 'Inspeção Visual',
                        subtitulo: lista.isEmpty
                            ? 'Nenhuma inspeção ainda'
                            : '${lista.length} ${lista.length == 1 ? 'inspeção' : 'inspeções'} · $totalRegistros ${totalRegistros == 1 ? 'registro' : 'registros'}',
                        acoes: [
                          BotaoIv(rotulo: 'Nova inspeção', icone: Icons.add, primario: true, aoTocar: _abrirModalNovaInspecao),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: CampoBuscaIv(
                        controller: _searchCtrl,
                        dica: 'Buscar por nome ou local',
                        aoMudar: (val) => setState(() => _filtro = val.toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Tooltip(
                      message: _sortAscending ? 'Mais antigas primeiro' : 'Mais recentes primeiro',
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _sortAscending = !_sortAscending),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: kIvTinta,
                          side: const BorderSide(color: kIvBorda),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 18, color: kIvLaranjaTexto),
                        label: Text(_sortAscending ? 'Antigas' : 'Recentes'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (lista.isEmpty)
                  EstadoVazioIv(
                    icone: Icons.image_search_outlined,
                    titulo: 'Nenhuma inspeção visual nesta estrutura',
                    texto: 'Crie uma inspeção (preliminar, rotineira ou especial) e registre os locais, elementos e anomalias.',
                    acao: BotaoIv(rotulo: 'Nova inspeção', icone: Icons.add, primario: true, aoTocar: _abrirModalNovaInspecao),
                  )
                else if (listaFiltrada.isEmpty)
                  const EstadoVazioIv(icone: Icons.search_off_rounded, titulo: 'Nenhuma inspeção encontrada')
                else
                  GradeIv(
                    larguraMinima: 420,
                    filhos: [
                      for (final insp in listaFiltrada)
                        _CartaoInspecao(
                          nome: insp.nome,
                          tipo: insp.tipo,
                          registros: insp.totalRegistros,
                          locais: insp.locaisAtendidos,
                          criadoEm: insp.criadoEm,
                          criadoPor: insp.criadoPor,
                          aoTocar: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => VisaoGeralInspecaoScreen(
                              inspecaoGeralId: insp.id,
                              inspecaoGeralNome: insp.nome,
                              descricaoInspecao: insp.descricao ?? '',
                              projetoId: widget.projetoId,
                              projetoNome: projetoNomeUI,
                              estruturaId: widget.estruturaId,
                              estruturaNome: estruturaNomeUI,
                            ))).then((_) => ref.invalidate(listaInspecoesGeraisProvider));
                          },
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
}

class _CartaoInspecao extends StatelessWidget {
  final String nome;
  final String tipo;
  final int registros;
  final List<String> locais;
  final DateTime? criadoEm;
  final String? criadoPor;
  final VoidCallback aoTocar;

  const _CartaoInspecao({
    required this.nome,
    required this.tipo,
    required this.registros,
    required this.locais,
    required this.criadoEm,
    required this.criadoPor,
    required this.aoTocar,
  });

  String _data(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: aoTocar,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kIvBorda)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kIvTinta)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            EtiquetaIv(texto: tipo, icone: Icons.category_outlined, cor: kIvLaranjaTexto, fundo: const Color(0xFFFFF3E0)),
                            EtiquetaIv(texto: registros == 1 ? '1 registro' : '$registros registros', icone: Icons.fact_check_outlined),
                            if (criadoEm != null) EtiquetaIv(texto: _data(criadoEm!), icone: Icons.event_outlined),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final autor = ref.watch(autorInspecaoProvider(criadoPor)).value;
                      return AutoriaBadge(autor: autor, raioEmpresa: 16);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 16, color: kIvSuave),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      locais.isEmpty ? 'Nenhum local registrado' : locais.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: kIvSuave),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: kIvSuave),
                ],
              ),
            ],
          ),
        ),
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
    // Trava síncrona de reentrância — o botão só fica desabilitado
    // (`onPressed: _salvando ? null : _salvar`) a partir do PRÓXIMO
    // rebuild/frame. Num toque duplo rápido, a segunda chamada ainda acha o
    // botão habilitado e entra aqui de novo antes do rebuild acontecer. Este
    // método sempre faz um INSERT em `pontos_ensaios_geral` e
    // `ponto_inspecao_visual_geral` (não há ramo de UPDATE — é sempre uma
    // inspeção nova), então as duas chamadas criariam duas inspeções
    // duplicadas. Setar `_salvando` aqui é síncrono (setState muda o campo
    // na hora, só o rebuild é adiado), então a segunda chamada já vê
    // `_salvando == true` e sai antes de inserir de novo.
    if (_salvando) return;
    // Antes saía em silêncio: sem nome ou sem tipo, "Salvar" não fazia nada
    // e parecia que o app não criava a inspeção.
    final faltando = [
      if (_nomeCtrl.text.trim().isEmpty) 'o nome',
      if (_tipoSelecionado == 'Selecione') 'o tipo de inspeção',
    ];
    if (faltando.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preencha ${faltando.join(' e ')}.'), backgroundColor: Colors.orange),
      );
      return;
    }
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
      debugPrint('[InspecaoVisual] falha ao criar inspeção: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red, duration: const Duration(seconds: 8)),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const tipos = [
      ('Inspeção preliminar', 'Primeira vistoria, para conhecer a estrutura e planejar os ensaios.'),
      ('Inspeção rotineira', 'Acompanhamento periódico do estado da estrutura.'),
      ('Inspeção especial', 'Investigação detalhada de um problema ou evento específico.'),
    ];
    InputDecoration deco(String dica) => InputDecoration(
          hintText: dica,
          hintStyle: const TextStyle(color: kIvSuave, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kIvBorda)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kIvBorda)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        );
    Widget rotulo(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kIvTexto)),
        );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Nova inspeção visual', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kIvTinta)),
                  ),
                  IconButton(tooltip: 'Fechar', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: kIvSuave)),
                ],
              ),
              const SizedBox(height: 16),
              rotulo('Nome da inspeção'),
              TextField(controller: _nomeCtrl, textCapitalization: TextCapitalization.sentences, decoration: deco('Ex.: Inspeção da casa de máquinas')),
              const SizedBox(height: 16),
              rotulo('Tipo de inspeção'),
              for (final (tipo, explicacao) in tipos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: _tipoSelecionado == tipo ? const Color(0xFFFFF3E0) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _tipoSelecionado = tipo),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _tipoSelecionado == tipo ? AppColors.primary : kIvBorda, width: _tipoSelecionado == tipo ? 1.5 : 1),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _tipoSelecionado == tipo ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: _tipoSelecionado == tipo ? kIvLaranjaTexto : kIvSuave,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tipo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kIvTinta)),
                                  Text(explicacao, style: const TextStyle(fontSize: 12, color: kIvSuave, height: 1.3)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              rotulo('Objetivo da inspeção'),
              TextField(controller: _objetivoCtrl, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: deco('O que se quer avaliar com esta inspeção?')),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _salvando ? null : _salvar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: kIvTinta,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _salvando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: kIvTinta, strokeWidth: 2))
                    : const Text('Criar inspeção', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
