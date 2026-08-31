import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/compact_button.dart';
import '../../../../core/widgets/custom_dropdown_with_add.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/diavicon_alerts.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../elementos/models/planta_model.dart';
import '../../../elementos/providers/plantas_provider.dart';
import '../../../elementos/screens/novo_elem_estrutural_screen.dart';
import '../../../elementos/widgets/novo_arquivo_popup.dart';
import '../../../elementos/widgets/novo_local_widget.dart';
import '../../../empresa/providers/sistema_provider.dart';
import '../../../estrutura/providers/local_provider.dart';
import '../../ensaios_inspecao_visual/widgets/novo_tipo_elemento_modal.dart';
import '../providers/prova_carga_providers.dart';
import 'selecionar_area_ensaio_modal.dart';

/// Passo 1 da criação de um ensaio de prova de carga estática: nome da área,
/// local, planta baixa onde ela será marcada, e o elemento estrutural
/// vinculado (cascata Sistema > Tipo de Elemento > Elemento, igual aos
/// outros ensaios). Ao salvar, encadeia para [SelecionarAreaEnsaioModal]
/// (marcação do retângulo na planta).
class NovoEnsaioProvaCargaModal extends ConsumerStatefulWidget {
  final String estruturaId;
  final String projetoId;
  final String tipoEnsaioId;

  const NovoEnsaioProvaCargaModal({
    super.key,
    required this.estruturaId,
    required this.projetoId,
    required this.tipoEnsaioId,
  });

  @override
  ConsumerState<NovoEnsaioProvaCargaModal> createState() => _NovoEnsaioProvaCargaModalState();
}

class _NovoEnsaioProvaCargaModalState extends ConsumerState<NovoEnsaioProvaCargaModal> {
  final _nomeController = TextEditingController();
  String? _localId;
  String? _plantaId;
  String? _tituloPlantaAguardando;
  String? _sistemaId;
  String? _tipoElementoNome;
  String? _elementoId;

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
        _elementoId = null;
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

  Future<void> _adicionarTipoElemento() async {
    final nome = await showDialog<String>(context: context, builder: (_) => const NovoTipoElementoModal());
    if (nome != null && mounted) setState(() => _tipoElementoNome = nome);
  }

  Future<void> _adicionarElemento(String? localNome) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovoElemEstruturalScreen(estruturaId: widget.estruturaId, initialLocalElemento: localNome),
      ),
    );
    ref.invalidate(elementosPorLocalProvaCargaProvider);
  }

  void _salvar() {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) {
      DiaviconAlerts.show(context, 'Campo obrigatório', 'Informe o nome da área de ensaio.', isErro: true);
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
    if (_elementoId == null) {
      DiaviconAlerts.show(context, 'Campo obrigatório', 'Selecione o elemento estrutural.', isErro: true);
      return;
    }

    final plantas = ref.read(plantasPorEstruturaProvider(widget.estruturaId)).value ?? [];
    final plantasEncontradas = plantas.where((p) => p.id == _plantaId);
    final planta = plantasEncontradas.isEmpty ? null : plantasEncontradas.first;
    if (planta == null) {
      DiaviconAlerts.show(context, 'Erro', 'Planta selecionada não encontrada.', isErro: true);
      return;
    }

    Navigator.pop(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelecionarAreaEnsaioModal(
        estruturaId: widget.estruturaId,
        projetoId: widget.projetoId,
        tipoEnsaioId: widget.tipoEnsaioId,
        nomeInicial: nome,
        plantaUrl: planta.arquivoUrl,
        elementoId: _elementoId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locaisAsync = ref.watch(locaisPorEstruturaProvider(widget.estruturaId));
    final plantasAsync = ref.watch(plantasPorEstruturaProvider(widget.estruturaId));
    final empresaId = ref.watch(currentUserProvider)?.empresaId;

    final locaisValue = locaisAsync.value ?? const [];
    final localSelecionado = locaisValue.where((l) => l.id == _localId);
    final localNome = localSelecionado.isEmpty ? null : localSelecionado.first.nome;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
                    child: Text(
                      'Nova área de prova de\ncarga estática',
                      style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF3E3E3D)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: AppColors.greyMedium, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              CustomTextField(
                label: 'Nome da área de ensaio',
                hint: 'Nome',
                controller: _nomeController,
                isRequired: true,
              ),
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
                      _elementoId = null;
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
                  final List<PlantaModel> plantasDoLocal = _localId == null
                      ? const <PlantaModel>[]
                      : plantas.where((p) => p.localVinculado == _localId).toList();

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
              const SizedBox(height: 16),

              if (empresaId == null)
                const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              else ...[
                Consumer(
                  builder: (context, ref, _) {
                    final sistemasAsync = ref.watch(sistemasDropdownProvider(empresaId));
                    return sistemasAsync.when(
                      loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
                      error: (err, _) => Text('Erro ao carregar sistemas: $err', style: const TextStyle(color: Colors.red)),
                      data: (sistemas) => CustomDropdownWithAdd<String>(
                        label: 'Sistema Habitacional',
                        value: _sistemaId,
                        items: sistemas.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nome, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() {
                          _sistemaId = val;
                          _tipoElementoNome = null;
                          _elementoId = null;
                        }),
                        onAddPressed: () {},
                        isAddEnabled: false,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                Consumer(
                  builder: (context, ref, _) {
                    final tiposAsync = ref.watch(tiposElementoDropdownProvider(empresaId));
                    return tiposAsync.when(
                      loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
                      error: (err, _) => Text('Erro ao carregar tipos de elemento: $err', style: const TextStyle(color: Colors.red)),
                      data: (tipos) {
                        final tiposFiltrados = _sistemaId == null ? tipos : tipos.where((t) => t.sistemaId == _sistemaId).toList();
                        return CustomDropdownWithAdd<String>(
                          label: 'Tipo de Elemento',
                          value: _tipoElementoNome,
                          items: tiposFiltrados.map((t) => DropdownMenuItem(value: t.nome, child: Text(t.nome, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) => setState(() {
                            _tipoElementoNome = val;
                            _elementoId = null;
                          }),
                          onAddPressed: _adicionarTipoElemento,
                          isRequired: true,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                Consumer(
                  builder: (context, ref, _) {
                    final elementosAsync = ref.watch(
                      elementosPorLocalProvaCargaProvider((estruturaId: widget.estruturaId, local: localNome, tipoNome: _tipoElementoNome)),
                    );
                    return elementosAsync.when(
                      loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
                      error: (err, _) => Text('Erro ao carregar elementos: $err', style: const TextStyle(color: Colors.red)),
                      data: (elementos) {
                        if (_elementoId != null && !elementos.any((e) => e['id'] == _elementoId)) _elementoId = null;
                        return CustomDropdownWithAdd<String>(
                          label: 'Elemento Estrutural',
                          hint: _tipoElementoNome == null ? 'Selecione o tipo de elemento' : (elementos.isEmpty ? 'Nenhum elemento neste local' : 'Selecione'),
                          value: _elementoId,
                          items: elementos.map((e) => DropdownMenuItem(value: e['id'].toString(), child: Text(e['nome'] ?? 'Sem nome', overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: _tipoElementoNome == null ? null : (val) => setState(() => _elementoId = val),
                          onAddPressed: () => _adicionarElemento(localNome),
                          isRequired: true,
                        );
                      },
                    );
                  },
                ),
              ],
              const SizedBox(height: 32),

              Center(
                child: CompactButton(text: 'Salvar', width: 140, height: 48, onPressed: _salvar),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
