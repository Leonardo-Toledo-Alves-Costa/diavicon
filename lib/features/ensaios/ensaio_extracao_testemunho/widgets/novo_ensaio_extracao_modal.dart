import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/compact_button.dart';
import '../../../../core/widgets/custom_dropdown_with_add.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/diavicon_alerts.dart';
import '../../../elementos/models/planta_model.dart';
import '../../../elementos/providers/plantas_provider.dart';
import '../../../elementos/widgets/novo_arquivo_popup.dart';
import '../../../elementos/widgets/novo_local_widget.dart';
import '../../../estrutura/providers/local_provider.dart';
import '../repositories/extracao_repository.dart';
import '../screens/ponto_ensaio_extracao_screen.dart';

/// Passo 1 da criação do ensaio de Extração e Rompimento de Testemunho:
/// nome do ensaio, local e planta baixa onde os pontos serão marcados. Este
/// ensaio não se vincula a um elemento único (ver contexto do prompt
/// original) — cada testemunho escolhe seu próprio elemento depois, na tela
/// de coleta. Mesmo papel de `NovoEnsaioProvaCargaModal`, sem a cascata de
/// elemento.
class NovoEnsaioExtracaoModal extends ConsumerStatefulWidget {
  final String estruturaId;
  final String projetoId;
  final String tipoEnsaioId;

  const NovoEnsaioExtracaoModal({
    super.key,
    required this.estruturaId,
    required this.projetoId,
    required this.tipoEnsaioId,
  });

  @override
  ConsumerState<NovoEnsaioExtracaoModal> createState() => _NovoEnsaioExtracaoModalState();
}

class _NovoEnsaioExtracaoModalState extends ConsumerState<NovoEnsaioExtracaoModal> {
  final _nomeController = TextEditingController();
  String? _localId;
  String? _plantaId;
  String? _tituloPlantaAguardando;
  bool _salvando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _adicionarLocal() async {
    final novoLocal = await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => NovoLocalModal(estruturaId: widget.estruturaId),
    );
    if (novoLocal != null && mounted) {
      ref.invalidate(locaisPorEstruturaProvider(widget.estruturaId));
      setState(() {
        _localId = novoLocal.id;
        _plantaId = null;
        if (_nomeController.text.trim().isEmpty) _nomeController.text = 'Extração — ${novoLocal.nome}';
      });
    }
  }

  Future<void> _adicionarPlanta() async {
    if (_localId == null) {
      DiaviconAlerts.show(context, 'Selecione o local', 'Escolha o local antes de anexar a planta.', isAviso: true);
      return;
    }
    final result = await showNovoArquivoPopup(context, widget.estruturaId);
    if (result == null || !mounted) return;

    try {
      final arquivo = result.arquivo;
      await ref.read(plantaControllerProvider.notifier).salvarNovaPlanta(
            estruturaId: widget.estruturaId,
            titulo: result.nome,
            localVinculado: _localId!,
            caminhoLocal: arquivo.path!,
            extensao: arquivo.extension ?? 'pdf',
            tamanhoArquivo: '${(arquivo.size / (1024 * 1024)).toStringAsFixed(2)} MB',
          );
      setState(() => _tituloPlantaAguardando = result.nome);
    } catch (e) {
      if (mounted) DiaviconAlerts.show(context, 'Erro', 'Falha ao enviar a planta: $e', isErro: true);
    }
  }

  Future<void> _salvar() async {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) {
      DiaviconAlerts.show(context, 'Campo obrigatório', 'Informe o nome do ensaio.', isErro: true);
      return;
    }
    if (_localId == null) {
      DiaviconAlerts.show(context, 'Campo obrigatório', 'Selecione o local.', isErro: true);
      return;
    }
    if (_plantaId == null) {
      DiaviconAlerts.show(context, 'Campo obrigatório', 'Selecione a planta baixa.', isErro: true);
      return;
    }

    setState(() => _salvando = true);
    try {
      final res = await ref.read(extracaoRepositoryProvider).criarLocalInicial(
            projetoId: widget.projetoId,
            estruturaId: widget.estruturaId,
            tipoEnsaioId: widget.tipoEnsaioId,
            nome: nome,
            localId: _localId!,
            plantaId: _plantaId!,
          );
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => PontoEnsaioExtracaoScreen(pontoGeralId: res['pontoGeralId']!)));
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        DiaviconAlerts.show(context, 'Erro', e.toString().replaceAll('Exception: ', ''), isErro: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locaisAsync = ref.watch(locaisPorEstruturaProvider(widget.estruturaId));
    final plantasAsync = ref.watch(plantasPorEstruturaProvider(widget.estruturaId));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text('Nova extração de\ntestemunho', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF3E3E3D))),
                  ),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: AppColors.greyMedium, size: 24)),
                ],
              ),
              const SizedBox(height: 24),
              CustomTextField(label: 'Nome do ensaio', hint: 'Ex: Extração — Garagem', controller: _nomeController, isRequired: true),
              const SizedBox(height: 16),
              locaisAsync.when(
                loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
                error: (err, _) => Text('Erro ao carregar locais: $err', style: const TextStyle(color: Colors.red)),
                data: (locais) {
                  if (_localId != null && !locais.any((l) => l.id == _localId)) _localId = null;
                  return CustomDropdownWithAdd<String>(
                    label: 'Local',
                    value: _localId,
                    items: locais.map((l) => DropdownMenuItem(value: l.id, child: Text(l.nome, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) => setState(() {
                      _localId = val;
                      _plantaId = null;
                    }),
                    onAddPressed: _adicionarLocal,
                    isRequired: true,
                  );
                },
              ),
              const SizedBox(height: 16),
              plantasAsync.when(
                loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
                error: (err, _) => Text('Erro ao carregar plantas: $err', style: const TextStyle(color: Colors.red)),
                data: (plantas) {
                  final List<PlantaModel> plantasDoLocal = _localId == null ? const <PlantaModel>[] : plantas.where((p) => p.localVinculado == _localId).toList();

                  if (_tituloPlantaAguardando != null) {
                    final achada = plantasDoLocal.where((p) => p.titulo == _tituloPlantaAguardando);
                    if (achada.isNotEmpty) {
                      _plantaId = achada.first.id;
                      _tituloPlantaAguardando = null;
                    }
                  }
                  if (_plantaId != null && !plantasDoLocal.any((p) => p.id == _plantaId)) _plantaId = null;

                  return CustomDropdownWithAdd<String>(
                    label: 'Planta baixa',
                    hint: _localId == null ? 'Selecione um local' : (plantasDoLocal.isEmpty ? 'Nenhuma planta neste local' : 'Selecione'),
                    value: _plantaId,
                    items: plantasDoLocal.map((p) => DropdownMenuItem(value: p.id, child: Text(p.titulo, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: _localId == null ? null : (val) => setState(() => _plantaId = val),
                    onAddPressed: _adicionarPlanta,
                    isRequired: true,
                  );
                },
              ),
              const SizedBox(height: 32),
              Center(
                child: _salvando
                    ? const CircularProgressIndicator(color: AppColors.primary)
                    : CompactButton(text: 'Salvar', width: 140, height: 48, onPressed: _salvar),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
