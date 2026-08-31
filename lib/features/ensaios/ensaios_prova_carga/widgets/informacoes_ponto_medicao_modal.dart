import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/compact_button.dart';
import '../../../../core/widgets/custom_dropdown_with_add.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../empresa/providers/campos_personalizaveis_provider.dart';
import '../../../empresa/providers/sistema_provider.dart';
import '../../ensaios_inspecao_visual/widgets/novo_tipo_elemento_modal.dart';
import '../models/ponto_medicao_model.dart';

class InformacoesPontoResult {
  final bool apagar;
  final String? tipoElemento;
  final int? deslocMax;
  final String? descricao;

  const InformacoesPontoResult.salvar({this.tipoElemento, this.deslocMax, this.descricao}) : apagar = false;
  const InformacoesPontoResult.apagar() : apagar = true, tipoElemento = null, deslocMax = null, descricao = null;
}

/// Sistema Habitacional (filtro) + Tipo de Elemento, deformação máxima
/// esperada e descrição de um ponto de medição. Último passo da cadeia de
/// criação/edição de um ponto.
///
/// O Sistema serve só para filtrar a lista de Tipos de Elemento (mesma
/// cascata usada na criação de elementos estruturais) — não existe coluna
/// própria para ele em `ponto_ensaio_prova_carga_ponto_medicao`, só
/// `tipo_elemento` (texto), que é o que de fato persiste.
class InformacoesPontoMedicaoModal extends ConsumerStatefulWidget {
  final PontoMedicaoModel? pontoExistente;

  const InformacoesPontoMedicaoModal({super.key, this.pontoExistente});

  @override
  ConsumerState<InformacoesPontoMedicaoModal> createState() => _InformacoesPontoMedicaoModalState();
}

class _InformacoesPontoMedicaoModalState extends ConsumerState<InformacoesPontoMedicaoModal> {
  String? _sistemaId;
  String? _tipoElemento;
  late final TextEditingController _deslocMaxController;
  late final TextEditingController _descricaoController;

  @override
  void initState() {
    super.initState();
    _tipoElemento = widget.pontoExistente?.tipoElemento;
    _deslocMaxController = TextEditingController(text: widget.pontoExistente?.deslocMax?.toString() ?? '');
    _descricaoController = TextEditingController(text: widget.pontoExistente?.descricao ?? '');
  }

  @override
  void dispose() {
    _deslocMaxController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _adicionarTipoElemento() async {
    final nome = await showDialog<String>(
      context: context,
      builder: (_) => const NovoTipoElementoModal(),
    );
    if (nome != null && mounted) setState(() => _tipoElemento = nome);
  }

  void _salvar() {
    Navigator.pop(
      context,
      InformacoesPontoResult.salvar(
        tipoElemento: _tipoElemento,
        deslocMax: int.tryParse(_deslocMaxController.text.trim()),
        descricao: _descricaoController.text.trim().isEmpty ? null : _descricaoController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empresaId = ref.watch(currentUserProvider)?.empresaId;

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
                children: [
                  Text('Informações do ponto', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF3E3E3D))),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: AppColors.greyMedium, size: 24)),
                ],
              ),
              const SizedBox(height: 24),

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
                          _tipoElemento = null;
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
                        var tiposFiltrados = _sistemaId == null ? tipos : tipos.where((t) => t.sistemaId == _sistemaId).toList();
                        if (_tipoElemento != null && !tiposFiltrados.any((t) => t.nome == _tipoElemento)) {
                          tiposFiltrados = [...tiposFiltrados, CampoItemModel(id: _tipoElemento!, nome: _tipoElemento!)];
                        }
                        return CustomDropdownWithAdd<String>(
                          label: 'Tipo de Elemento',
                          value: _tipoElemento,
                          items: tiposFiltrados.map((t) => DropdownMenuItem(value: t.nome, child: Text(t.nome, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) => setState(() => _tipoElemento = val),
                          onAddPressed: _adicionarTipoElemento,
                        );
                      },
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),

              CustomTextField(
                label: 'Deformação máxima esperada',
                hint: '(mm)',
                controller: _deslocMaxController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              CustomTextField(
                label: 'Descrição da região de ensaio',
                hint: 'Descrição',
                controller: _descricaoController,
                maxLines: 4,
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: CompactButton(
                      text: 'Apagar',
                      height: 48,
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.error,
                      borderColor: AppColors.error,
                      elevation: 0,
                      onPressed: () => Navigator.pop(context, const InformacoesPontoResult.apagar()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CompactButton(text: 'Salvar', height: 48, onPressed: _salvar),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
