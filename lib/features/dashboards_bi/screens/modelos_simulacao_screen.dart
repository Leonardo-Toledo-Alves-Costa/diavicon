import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/diavicon_modal.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/diavicon_alerts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../models/monte_carlo_bi_model.dart';
import '../repositories/simulacao_bi_repository.dart';
import '../widgets/editor_config_monte_carlo.dart';
import '../widgets/bi_tema.dart';

/// "Padrões da empresa > Dashboard > Modelos de simulação" — simulações de
/// Monte Carlo prontas para usar nos dashboards ("Partir de um modelo" no
/// card). Modelos da DIAVICON são padrão, somente leitura, e se duplicam
/// para a empresa.
class ModelosSimulacaoScreen extends ConsumerWidget {
  final String empresaId;
  const ModelosSimulacaoScreen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelosAsync = ref.watch(simulacoesBiProvider(empresaId));

    return Scaffold(
      backgroundColor: kBiFundo,
      appBar: const CustomAppBar(
        title: 'Empresa',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            Text('Padrões da empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Modelos de simulação', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _criar(context, ref),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nova simulação', style: TextStyle(color: Colors.white)),
      ),
      body: modelosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Padding(padding: const EdgeInsets.all(24), child: Text('Erro ao carregar as simulações:\n$e', textAlign: TextAlign.center)),
        ),
        data: (modelos) {
          if (modelos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Nenhuma simulação cadastrada.\nCrie aqui ou use "Salvar como modelo" num card de Monte Carlo.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[600], height: 1.4),
                ),
              ),
            );
          }
          return ListView(
            padding: preenchimentoListaBi(context),
            children: [
              for (final m in modelos)
                _CardModelo(
                  modelo: m,
                  empresaId: empresaId,
                  ehPadraoDiavicon: m.empresaId == DIAVICON_EMPRESA_ID && m.empresaId != empresaId,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _criar(BuildContext context, WidgetRef ref) async {
    final r = await abrirEditorSimulacao(context);
    if (r == null) return;
    try {
      await ref.read(simulacaoBiRepositoryProvider).criar(SimulacaoBiModel(
            id: '',
            empresaId: empresaId,
            criadoPor: ref.read(currentUserProvider)?.id,
            nome: r.nome,
            descricao: r.descricao,
            configuracao: r.config,
          ));
      ref.invalidate(simulacoesBiProvider(empresaId));
    } catch (e) {
      if (context.mounted) DiaviconAlerts.show(context, 'Erro', 'Não foi possível salvar: $e', isErro: true);
    }
  }
}

class _CardModelo extends ConsumerWidget {
  const _CardModelo({required this.modelo, required this.empresaId, required this.ehPadraoDiavicon});

  final SimulacaoBiModel modelo;
  final String empresaId;
  final bool ehPadraoDiavicon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = modelo.configuracao;
    final series = cfg.series.map((s) => s.nome).join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _abrir(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBiBorda),
          ),
          child: Row(
            children: [
              const Icon(Icons.casino_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(modelo.nome, style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text(
                      cfg.analise == AnaliseMonteCarloBi.despassivacao ? cfg.analise.rotulo : '${cfg.analise.rotulo} · $series',
                      style: GoogleFonts.lato(fontSize: 11, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (ehPadraoDiavicon) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Padrão DIAVICON', style: TextStyle(fontSize: 9, color: Color(0xFFA85A00), fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  tooltip: 'Duplicar para minha empresa',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_outlined, color: Colors.grey, size: 18),
                  onPressed: () => _duplicar(context, ref),
                ),
              ] else
                IconButton(
                  tooltip: 'Excluir',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18),
                  onPressed: () => _excluir(context, ref),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrir(BuildContext context, WidgetRef ref) async {
    final r = await abrirEditorSimulacao(context, existente: modelo, somenteLeitura: ehPadraoDiavicon);
    if (r == null) return;
    try {
      await ref.read(simulacaoBiRepositoryProvider).atualizar(
            modelo.id,
            SimulacaoBiModel(
              id: modelo.id,
              empresaId: modelo.empresaId,
              criadoPor: modelo.criadoPor,
              nome: r.nome,
              descricao: r.descricao,
              configuracao: r.config,
              simulacaoOrigemId: modelo.simulacaoOrigemId,
            ),
          );
      ref.invalidate(simulacoesBiProvider(empresaId));
    } catch (e) {
      if (context.mounted) DiaviconAlerts.show(context, 'Erro', 'Não foi possível salvar: $e', isErro: true);
    }
  }

  Future<void> _duplicar(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(simulacaoBiRepositoryProvider).duplicar(modelo, empresaId: empresaId, criadoPor: ref.read(currentUserProvider)?.id);
      ref.invalidate(simulacoesBiProvider(empresaId));
    } catch (e) {
      if (context.mounted) DiaviconAlerts.show(context, 'Erro', 'Não foi possível duplicar: $e', isErro: true);
    }
  }

  Future<void> _excluir(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir simulação'),
        content: Text('Excluir "${modelo.nome}"? Os dashboards que partiram dele não mudam — eles guardam uma cópia.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(simulacaoBiRepositoryProvider).excluir(modelo.id);
      ref.invalidate(simulacoesBiProvider(empresaId));
    } catch (e) {
      if (context.mounted) DiaviconAlerts.show(context, 'Erro', 'Não foi possível excluir: $e', isErro: true);
    }
  }
}

// ── Editor ─────────────────────────────────────────────────────────────────

typedef ResultadoEditorSimulacao = ({String nome, String? descricao, ConfigMonteCarloBi config});

Future<ResultadoEditorSimulacao?> abrirEditorSimulacao(
  BuildContext context, {
  SimulacaoBiModel? existente,
  bool somenteLeitura = false,
}) {
  return showDiaviconModal<ResultadoEditorSimulacao>(
    context: context,
    title: existente == null ? 'Nova simulação' : (somenteLeitura ? existente.nome : 'Editar simulação'),
    isScrollable: false,
    body: _EditorSimulacao(existente: existente, somenteLeitura: somenteLeitura),
  );
}

class _EditorSimulacao extends StatefulWidget {
  const _EditorSimulacao({this.existente, required this.somenteLeitura});
  final SimulacaoBiModel? existente;
  final bool somenteLeitura;

  @override
  State<_EditorSimulacao> createState() => _EditorSimulacaoState();
}

class _EditorSimulacaoState extends State<_EditorSimulacao> {
  late final TextEditingController _nome = TextEditingController(text: widget.existente?.nome ?? '');
  late final TextEditingController _descricao = TextEditingController(text: widget.existente?.descricao ?? '');
  late ConfigMonteCarloBi _config = widget.existente?.configuracao ?? const ConfigMonteCarloBi();

  @override
  void dispose() {
    _nome.dispose();
    _descricao.dispose();
    super.dispose();
  }

  bool get _valido =>
      _nome.text.trim().isNotEmpty &&
      (_config.analise == AnaliseMonteCarloBi.despassivacao || _config.series.isNotEmpty) &&
      (_config.analise != AnaliseMonteCarloBi.probabilidade ||
          (_config.operandoA != null && (_config.operandoB?.trim().isNotEmpty ?? false)));

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              // Modelo DIAVICON: mostra tudo, mas não deixa mexer — para
              // alterar, duplique para a empresa.
              child: AbsorbPointer(
                absorbing: widget.somenteLeitura,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _nome,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Nome', isDense: true, border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descricao,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Descrição (opcional)', isDense: true, border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 18),
                    EditorConfigMonteCarlo(config: _config, onChanged: (c) => setState(() => _config = c)),
                  ],
                ),
              ),
            ),
          ),
          if (!widget.somenteLeitura) ...[
            const SizedBox(height: 10),
            CustomButton(
              text: 'Salvar',
              onPressed: _valido
                  ? () => Navigator.of(context).pop((
                        nome: _nome.text.trim(),
                        descricao: _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
                        config: _config,
                      ))
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
