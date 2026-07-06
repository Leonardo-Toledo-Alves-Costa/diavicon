import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:diavicon/features/elementos/widgets/bigger_custom_button.dart';
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

  // Lista dinâmica para Tipologia (inicia vazia)
  final List<String> _tipologiaOptions = [];
  String? _tipologiaSelecionada;
  
  String? _condicaoSelecionada;
  bool _isLoading = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  // Função para adicionar nova Tipologia
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

  Widget _buildLabel(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: text,
              style: GoogleFonts.lato(
                color: const Color(0xFF626365),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (required)
              TextSpan(
                text: '*',
                style: GoogleFonts.lato(
                  color: const Color(0xFFF71D20),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
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
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(0, 4),
              blurRadius: 12,
            ),
          ],
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
                          style: GoogleFonts.lato(
                            color: const Color(0xFF3E3E3D),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(Icons.close, color: Colors.grey, size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // --- Nome do Local ---
                  _buildLabel('Nome do Local', required: true),
                  SizedBox(
                    height: 44,
                    child: TextFormField(
                      controller: _nomeController,
                      style: GoogleFonts.lato(color: AppColors.textDark),
                      decoration: _customInputDecoration('Nome'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // --- Tipologia do Local (Dinâmico + Alerta) ---
                  _buildLabel('Tipologia do Local', required: true),
                  if (_tipologiaOptions.isEmpty)
                    _buildFakeDropdownRow(
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
                    )
                  else
                    _buildCustomDropdownRow(
                      hint: 'Selecione',
                      value: _tipologiaSelecionada,
                      items: _tipologiaOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setState(() => _tipologiaSelecionada = val),
                      onAddPressed: _adicionarTipologia,
                    ),
                  const SizedBox(height: 16),
                  
                  // --- Condição de Exposição (Estático Atualizado) ---
                  _buildLabel('Condição de Exposição', required: true),
                  _buildCustomDropdownRow(
                    hint: 'Selecione',
                    value: _condicaoSelecionada,
                    items: const [
                      DropdownMenuItem(value: 'Externo coberto', child: Text('Externo coberto')),
                      DropdownMenuItem(value: 'Externo descoberto', child: Text('Externo descoberto')),
                      DropdownMenuItem(value: 'Interno', child: Text('Interno')),
                    ],
                    onChanged: (val) => setState(() => _condicaoSelecionada = val),
                    onAddPressed: () {
                      // Se futuramente quiser deixar dinâmico, só chamar o showNovaOpcaoModal aqui também!
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // --- Descrição ---
                  _buildLabel('Descrição'),
                  TextFormField(
                    controller: _descricaoController,
                    maxLines: 4,
                    style: GoogleFonts.lato(color: AppColors.textDark),
                    decoration: _customInputDecoration('Descrição').copyWith(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // --- Botão Salvar ---
                  Center(
                    child: BiggerCustomButton(
                      width: 86,
                      height: 34,
                      text: _isLoading ? '...' : 'Salvar',
                      onPressed: _isLoading ? () {} : () async {
                        final nome = _nomeController.text.trim();
                        if (nome.isEmpty) {
                          DiaviconAlerts.show(context, 'Campo obrigatório', 'Informe o nome do local.', isErro: true);
                          return;
                        }

                        if (widget.estruturaId != null) {
                          setState(() => _isLoading = true);
                          try {
                            final repo = ref.read(localRepositoryProvider);
                            // Se o seu repo suportar salvar a tipologia e exposição depois, você passa as variáveis _tipologiaSelecionada e _condicaoSelecionada aqui!
                            await repo.criarLocal(widget.estruturaId!, nome);
                            
                            ref.invalidate(locaisPorEstruturaProvider(widget.estruturaId!));
                          } catch (e) {
                            if (mounted) {
                              DiaviconAlerts.show(context, 'Erro', 'Falha ao salvar local: $e', isErro: true);
                              setState(() => _isLoading = false);
                            }
                            return;
                          }
                        }
                        
                        if (mounted) Navigator.of(context).pop(nome);
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

  InputDecoration _customInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.lato(color: AppColors.hintText, fontWeight: FontWeight.w300),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
    );
  }

  // --- Widget para o Dropdown Normal ---
  Widget _buildCustomDropdownRow({
    required String hint,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required VoidCallback onAddPressed,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: DropdownButtonFormField<String>(
              value: value,
              items: items,
              onChanged: onChanged,
              style: GoogleFonts.lato(color: AppColors.textDark, fontSize: 16),
              decoration: _customInputDecoration(hint).copyWith(fillColor: Colors.white, filled: true),
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.blackDark),
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
              boxShadow: [BoxShadow(color: Color(0x4D3A57E8), blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // --- Widget para o Dropdown Falso (Vazio) ---
  Widget _buildFakeDropdownRow({
    required String hint,
    required VoidCallback onDropdownTap,
    required VoidCallback onAddPressed,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onDropdownTap,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.inputBorder),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(hint, style: GoogleFonts.lato(color: AppColors.hintText, fontSize: 16)),
                  const Icon(Icons.keyboard_arrow_down, color: AppColors.blackDark),
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
              boxShadow: [BoxShadow(color: Color(0x4D3A57E8), blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}