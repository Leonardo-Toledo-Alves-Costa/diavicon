import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/monte_carlo.dart';
import '../../../core/widgets/custom_dropdown.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/monte_carlo_bi_model.dart';
import '../models/variavel_bi_model.dart';
import '../repositories/simulacao_bi_repository.dart';
import '../repositories/variavel_bi_repository.dart';
import 'editores_series_bi.dart';
import '../utils/cores_bi.dart';

/// Configuração de uma simulação de Monte Carlo: tipo de análise, séries
/// (base e derivadas) e operandos da probabilidade.
///
/// Usado em dois lugares: no card do dashboard e na biblioteca (Padrões da
/// empresa > Dashboard > Modelos de simulação). Com [comBiblioteca], ganha
/// "Partir de um modelo" e "Salvar como modelo" — só faz sentido no card.
class EditorConfigMonteCarlo extends ConsumerStatefulWidget {
  const EditorConfigMonteCarlo({super.key, required this.config, required this.onChanged, this.comBiblioteca = false});

  final ConfigMonteCarloBi config;
  final ValueChanged<ConfigMonteCarloBi> onChanged;
  final bool comBiblioteca;

  @override
  ConsumerState<EditorConfigMonteCarlo> createState() => _EditorConfigMonteCarloState();
}

class _EditorConfigMonteCarloState extends ConsumerState<EditorConfigMonteCarlo> {
  final TextEditingController _operandoBCtrl = TextEditingController();
  int _contadorIds = 0;

  ConfigMonteCarloBi get _mc => widget.config;
  void _mudar(ConfigMonteCarloBi c) => widget.onChanged(c);

  @override
  void initState() {
    super.initState();
    _sincronizarOperandoB();
  }

  @override
  void didUpdateWidget(covariant EditorConfigMonteCarlo old) {
    super.didUpdateWidget(old);
    // Trocou a configuração inteira (ex.: "partir de um modelo").
    if (old.config.operandoB != widget.config.operandoB && double.tryParse((widget.config.operandoB ?? '').replaceAll(',', '.')) != null) {
      if (_operandoBCtrl.text != widget.config.operandoB) _operandoBCtrl.text = widget.config.operandoB!;
    }
  }

  void _sincronizarOperandoB() {
    if (double.tryParse((_mc.operandoB ?? '').replaceAll(',', '.')) != null) _operandoBCtrl.text = _mc.operandoB!;
  }

  @override
  void dispose() {
    _operandoBCtrl.dispose();
    super.dispose();
  }

  String _novoId() => 'mc_${DateTime.now().microsecondsSinceEpoch}_${_contadorIds++}';

  @override
  Widget build(BuildContext context) {
    final nomes = _mc.series.map((x) => x.nome).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.comBiblioteca) ...[
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _partirDeModelo,
                icon: const Icon(Icons.library_books_outlined, size: 18, color: AppColors.primary),
                label: const Text('Partir de um modelo', style: TextStyle(color: AppColors.primary)),
              ),
              OutlinedButton.icon(
                onPressed: _salvarComoModelo,
                icon: const Icon(Icons.bookmark_add_outlined, size: 18, color: AppColors.primary),
                label: const Text('Salvar como modelo', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        _titulo('Análise'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AnaliseMonteCarloBi.values
              .map((a) => ChoiceChip(
                    label: Text(a.rotulo, style: GoogleFonts.lato(fontSize: 12)),
                    selected: _mc.analise == a,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    onSelected: (_) => _mudar(_mc.copyWith(analise: a)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        if (_mc.analise == AnaliseMonteCarloBi.despassivacao)
          Text(
            'Usa automaticamente os dados de carbonatação do contexto: todas as leituras de frente '
            '(k = frente/√idade de cada estrutura), o menor cobrimento médio e o desvio dele. '
            'Mostra a probabilidade de a frente ultrapassar o cobrimento ao longo do tempo — o mesmo '
            'cálculo do relatório de carbonatação.',
            style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
          )
        else ...[
          _titulo('Séries simuladas'),
          Text(
            'Variável de ensaio: média + z·σ da variável no contexto, sorteada ${MonteCarlo.iteracoes} vezes. '
            'Calculada: uma equação entre essas séries (ex.: SonReb a partir de V e R), '
            'feita em cada amostra.',
            style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _mc.series.length; i++)
            _itemLista(
              cor: Color(corBiNormalizada(_mc.series[i].cor)),
              titulo: _mc.series[i].nome,
              subtitulo: _mc.series[i].derivada ? '= ${_mc.series[i].expressao}' : _mc.series[i].valor!.rotuloPadrao(),
              onEditar: () async {
                final atual = _mc.series[i];
                final editada = await abrirEditorSerieMC(
                  context,
                  existente: atual,
                  outrosNomes: nomes.where((n) => n != atual.nome).toSet(),
                );
                if (editada != null) _mudar(_mc.copyWith(series: [..._mc.series]..[i] = editada));
              },
              onRemover: () => _mudar(_mc.copyWith(series: [..._mc.series]..removeAt(i))),
            ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final nova = await abrirEditorSerieMC(context, outrosNomes: nomes.toSet(), indice: _mc.series.length);
                  if (nova != null) _mudar(_mc.copyWith(series: [..._mc.series, nova]));
                },
                icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                label: const Text('Nova série', style: TextStyle(color: AppColors.primary)),
              ),
              OutlinedButton.icon(
                onPressed: _importarEquacao,
                icon: const Icon(Icons.functions, size: 18, color: AppColors.primary),
                label: const Text('Importar equação', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
          if (nomes.isNotEmpty && _mc.analise == AnaliseMonteCarloBi.distribuicao) ...[
            const SizedBox(height: 16),
            _titulo('Distribuição de'),
            CustomDropdown<String>(
              label: '',
              value: nomes.contains(_mc.serieExibida) ? _mc.serieExibida : nomes.last,
              items: nomes.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
              onChanged: (v) => _mudar(_mc.copyWith(serieExibida: v)),
            ),
          ],
          if (nomes.isNotEmpty && _mc.analise == AnaliseMonteCarloBi.probabilidade) ...[
            const SizedBox(height: 16),
            _titulo('Probabilidade de'),
            CustomDropdown<String>(
              label: 'Série',
              value: nomes.contains(_mc.operandoA) ? _mc.operandoA : null,
              items: nomes.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
              onChanged: (v) => _mudar(_mc.copyWith(operandoA: v)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: ComparacaoMC.values
                  .map((c) => ChoiceChip(
                        label: Text(c.simbolo, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w800)),
                        selected: _mc.comparacao == c,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (_) => _mudar(_mc.copyWith(comparacao: c)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            _seletorOperandoB(nomes),
          ],
        ],
      ],
    );
  }

  /// O segundo operando é outra série ou um valor fixo (ex.: fck de projeto).
  Widget _seletorOperandoB(List<String> nomes) {
    final ehSerie = nomes.contains(_mc.operandoB);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Valor fixo')),
            ButtonSegment(value: true, label: Text('Outra série')),
          ],
          selected: {ehSerie},
          showSelectedIcon: false,
          onSelectionChanged: (sel) => _mudar(_mc.copyWith(operandoB: sel.first ? nomes.first : _operandoBCtrl.text.trim())),
        ),
        const SizedBox(height: 8),
        if (ehSerie)
          CustomDropdown<String>(
            label: '',
            value: _mc.operandoB,
            items: nomes.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
            onChanged: (v) => _mudar(_mc.copyWith(operandoB: v)),
          )
        else
          TextField(
            controller: _operandoBCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: 'Ex.: 25'),
            onChanged: (v) => _mudar(_mc.copyWith(operandoB: v.trim())),
          ),
      ],
    );
  }

  Future<void> _importarEquacao() async {
    final empresaId = ref.read(currentUserProvider)?.empresaId;
    if (empresaId == null) return;
    final variaveis = await ref.read(variaveisBiProvider(empresaId).future);
    if (!mounted) return;
    if (variaveis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma equação cadastrada nos padrões da empresa.')));
      return;
    }
    final escolhida = await _escolher<VariavelBiModel>('Importar equação', variaveis, (v) => (v.nome, v.expressao));
    if (escolhida == null || !mounted) return;
    final r = importarEquacaoMC(escolhida, _mc.series, novoId: _novoId);
    _mudar(_mc.copyWith(
      series: r.series,
      serieExibida: _mc.serieExibida ?? r.resultado,
      operandoA: _mc.operandoA ?? r.resultado,
    ));
  }

  /// Copia a configuração de um modelo da biblioteca para o card. É cópia,
  /// não vínculo: mudar ou excluir o modelo depois não mexe no dashboard.
  Future<void> _partirDeModelo() async {
    final empresaId = ref.read(currentUserProvider)?.empresaId;
    if (empresaId == null) return;
    final modelos = await ref.read(simulacoesBiProvider(empresaId).future);
    if (!mounted) return;
    if (modelos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum modelo de simulação cadastrado ainda.')));
      return;
    }
    final escolhido = await _escolher<SimulacaoBiModel>(
      'Partir de um modelo',
      modelos,
      (m) => (m.nome, m.descricao ?? m.configuracao.analise.rotulo),
    );
    if (escolhido == null) return;
    _mudar(escolhido.configuracao);
  }

  Future<void> _salvarComoModelo() async {
    final usuario = ref.read(currentUserProvider);
    final empresaId = usuario?.empresaId;
    if (empresaId == null) return;
    final nomeCtrl = TextEditingController();
    final nome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salvar como modelo'),
        content: TextField(controller: nomeCtrl, autofocus: true, decoration: const InputDecoration(hintText: 'Nome do modelo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, nomeCtrl.text.trim()), child: const Text('Salvar')),
        ],
      ),
    );
    // Descartado só depois de o diálogo sair da árvore — descartar logo após
    // o `await` travava a tela (o TextField ainda anima a saída).
    WidgetsBinding.instance.addPostFrameCallback((_) => nomeCtrl.dispose());
    if (nome == null || nome.isEmpty || !mounted) return;
    try {
      await ref.read(simulacaoBiRepositoryProvider).criar(
            SimulacaoBiModel(id: '', empresaId: empresaId, criadoPor: usuario?.id, nome: nome, configuracao: _mc),
          );
      ref.invalidate(simulacoesBiProvider(empresaId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Modelo "$nome" salvo nos padrões da empresa.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível salvar: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<T?> _escolher<T>(String titulo, List<T> itens, (String, String) Function(T) rotulo) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(titulo),
        children: [
          for (final item in itens)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rotulo(item).$1, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(rotulo(item).$2, style: GoogleFonts.robotoMono(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
      );

  Widget _itemLista({
    Color? cor,
    required String titulo,
    required String subtitulo,
    required VoidCallback onEditar,
    required VoidCallback onRemover,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(border: Border.all(color: AppColors.inputBorder), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          if (cor != null) ...[
            Container(width: 12, height: 12, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                Text(subtitulo, style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEditar),
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: onRemover),
        ],
      ),
    );
  }
}
