import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:diavicon/core/widgets/compact_button.dart';
import 'package:diavicon/core/widgets/custom_text_field.dart';
import 'package:diavicon/core/widgets/custom_dropdown_with_add.dart';
import 'package:diavicon/features/estrutura/providers/local_provider.dart';
import 'package:diavicon/features/elementos/widgets/nova_opcao_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class NovoLocalModal extends ConsumerStatefulWidget {
  final String? estruturaId;
  const NovoLocalModal({super.key, this.estruturaId});

  @override
  ConsumerState<NovoLocalModal> createState() => _NovoLocalModalState();
}

class _NovoLocalModalState extends ConsumerState<NovoLocalModal> {
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();

  final List<String> _tipologiaOptions = [];
  String? _tipologiaSelecionada;
  
  final List<String> _condicoesOptions = ['Externo coberto', 'Externo descoberto', 'Interno'];
  String? _condicaoSelecionada;
  
  bool _isLoading = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _adicionarTipologia() async {
    final novaOpcao = await showNovaOpcaoModal(
      context,
      titulo: 'Nova Tipologia do Local',
      label: 'Nome da Tipologia',
    );

    if (novaOpcao != null && novaOpcao.trim().isNotEmpty) {
      final opcaoFormatada = novaOpcao.trim();
      setState(() {
        if (!_tipologiaOptions.contains(opcaoFormatada)) {
          _tipologiaOptions.add(opcaoFormatada);
        }
        _tipologiaSelecionada = opcaoFormatada;
      });
    }
  }

  Future<void> _adicionarCondicao() async {
    final novaOpcao = await showNovaOpcaoModal(
      context,
      titulo: 'Nova Condição de Exposição',
      label: 'Nome da Condição',
    );

    if (novaOpcao != null && novaOpcao.trim().isNotEmpty) {
      final opcaoFormatada = novaOpcao.trim();
      setState(() {
        if (!_condicoesOptions.contains(opcaoFormatada)) {
          _condicoesOptions.add(opcaoFormatada);
        }
        _condicaoSelecionada = opcaoFormatada;
      });
    }
  }

  // 🔥 CRIAMOS UM COMPONENTE FALSO COM O MESMO VISUAL PARA DISPARAR O ALERTA!
  Widget _buildFakeDropdownRow({
    required String label,
    required String hint,
    required VoidCallback onDropdownTap,
    required VoidCallback onAddPressed,
    required String tooltip,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: TextSpan(
                text: label,
                style: GoogleFonts.lato(color: AppColors.textDark, fontSize: 20, fontWeight: FontWeight.w300, height: 1),
                children: const [
                  TextSpan(text: ' *', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: tooltip,
              triggerMode: TooltipTriggerMode.tap,
              preferBelow: false,
              showDuration: const Duration(seconds: 3),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              textStyle: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.info_outline, size: 16, color: AppColors.greyLight),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onDropdownTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.inputBorder),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(hint, style: GoogleFonts.lato(color: AppColors.hintText, fontSize: 18, fontWeight: FontWeight.w300, height: 1, letterSpacing: 0.54)),
                      const Icon(Icons.keyboard_arrow_down, color: Color(0xFF313144)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: onAddPressed,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x4D3A57E8), offset: Offset(0, 2), blurRadius: 4)],
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 12)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Novo Local na Estrutura',
                          style: GoogleFonts.lato(color: const Color(0xFF3E3E3D), fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(Icons.close, color: AppColors.greyMedium, size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  CustomTextField(
                    label: 'Nome do Local',
                    hint: 'Ex: Garagem Subsolo',
                    controller: _nomeController,
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),
                  
                  // 🔥 RESTAURAMOS A LÓGICA DO ALERTA AQUI!
                  if (_tipologiaOptions.isEmpty)
                    _buildFakeDropdownRow(
                      label: 'Tipologia do Local',
                      hint: 'Nenhuma tipologia',
                      onDropdownTap: () {
                        DiaviconAlerts.show(
                          context,
                          'Nenhuma tipologia cadastrada',
                          'Você precisa cadastrar uma tipologia clicando no botão "+" ao lado.',
                          isAviso: true,
                        );
                      },
                      onAddPressed: _adicionarTipologia,
                      tooltip: 'Adicione ou selecione o tipo do local (Ex: Sala, Quarto, Garagem).',
                    )
                  else
                    CustomDropdownWithAdd<String>(
                      label: 'Tipologia do Local',
                      hint: 'Selecione',
                      value: _tipologiaSelecionada,
                      items: _tipologiaOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) => setState(() => _tipologiaSelecionada = val), 
                      onAddPressed: _adicionarTipologia,
                      isRequired: true,
                      tooltip: 'Adicione ou selecione o tipo do local (Ex: Sala, Quarto, Garagem).',
                    ),
                  const SizedBox(height: 16),
                  
                  CustomDropdownWithAdd<String>(
                    label: 'Condição de Exposição',
                    hint: 'Selecione',
                    value: _condicaoSelecionada,
                    items: _condicoesOptions.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) => setState(() => _condicaoSelecionada = val),
                    onAddPressed: _adicionarCondicao,
                    isRequired: true,
                    tooltip: 'Adicione ou selecione a condição de exposição do ambiente.',
                  ),
                  const SizedBox(height: 16),
                  
                  CustomTextField(
                    label: 'Descrição',
                    hint: 'Adicione uma descrição (opcional)',
                    controller: _descricaoController,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 32),
                  
                  Center(
                    child: _isLoading
                        ? const CircularProgressIndicator(color: AppColors.primary)
                        : CompactButton(
                            width: 120,
                            text: 'Salvar',
                            onPressed: () async {
                              final nome = _nomeController.text.trim();
                              
                              if (nome.isEmpty) {
                                DiaviconAlerts.show(context, 'Campo obrigatório', 'Informe o nome do local.', isErro: true);
                                return;
                              }
                              if (_tipologiaSelecionada == null) {
                                DiaviconAlerts.show(context, 'Campo obrigatório', 'Selecione a tipologia.', isErro: true);
                                return;
                              }
                              if (_condicaoSelecionada == null) {
                                DiaviconAlerts.show(context, 'Campo obrigatório', 'Selecione a condição de exposição.', isErro: true);
                                return;
                              }

                              if (widget.estruturaId != null) {
                                setState(() => _isLoading = true);
                                try {
                                  final repo = ref.read(localRepositoryProvider);
                                  
                                  final localCriado = await repo.criarLocal(
                                    estruturaId: widget.estruturaId!, 
                                    nome: nome,
                                    tipologia: _tipologiaSelecionada,
                                    condicao: _condicaoSelecionada,
                                    descricao: _descricaoController.text.trim(),
                                  );
                                  
                                  ref.invalidate(locaisPorEstruturaProvider(widget.estruturaId!));
                                  
                                  if (!context.mounted) return;
                                  Navigator.of(context).pop(localCriado.id);
                                  
                                } catch (e) {
                                  if (!context.mounted) return;
                                  DiaviconAlerts.show(context, 'Erro', 'Falha ao salvar local: $e', isErro: true);
                                  setState(() => _isLoading = false);
                                }
                              }
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}