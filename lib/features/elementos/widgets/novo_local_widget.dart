import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/features/elementos/widgets/bigger_custom_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NovoLocalModal extends StatefulWidget {
  const NovoLocalModal({super.key});

  @override
  State<NovoLocalModal> createState() => _NovoLocalModalState();
}

class _NovoLocalModalState extends State<NovoLocalModal> {
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();

  String? _tipologiaSelecionada;
  String? _condicaoSelecionada;

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    super.dispose();
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
                        child: const Icon(
                          Icons.close,
                          color: Colors.grey,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
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
                  _buildLabel('Tipologia do Local', required: true),
                  _buildCustomDropdownRow(
                    hint: 'Selecione',
                    value: _tipologiaSelecionada,
                    items: const [
                      DropdownMenuItem(value: '1', child: Text('Viga')),
                      DropdownMenuItem(value: '2', child: Text('Pilar')),
                      DropdownMenuItem(value: '3', child: Text('Laje')),
                    ],
                    onChanged: (val) =>
                        setState(() => _tipologiaSelecionada = val),
                    onAddPressed: () {},
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Condição de Exposição', required: true),
                  _buildCustomDropdownRow(
                    hint: 'Selecione',
                    value: _condicaoSelecionada,
                    items: const [
                      DropdownMenuItem(value: 'int', child: Text('Interna')),
                      DropdownMenuItem(value: 'ext', child: Text('Externa')),
                    ],
                    onChanged: (val) =>
                        setState(() => _condicaoSelecionada = val),
                    onAddPressed: () {},
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Descrição'),
                  TextFormField(
                    controller: _descricaoController,
                    maxLines: 4,
                    style: GoogleFonts.lato(color: AppColors.textDark),
                    decoration: _customInputDecoration('Descrição').copyWith(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: BiggerCustomButton(
                      width: 86,
                      height: 34,
                      text: 'Salvar',
                      onPressed: () {
                        Navigator.of(context).pop();
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
      hintStyle: GoogleFonts.lato(
        color: AppColors.hintText,
        fontWeight: FontWeight.w300,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

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
              decoration: _customInputDecoration(
                hint,
              ).copyWith(fillColor: Colors.white, filled: true),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.blackDark,
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
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x4D3A57E8),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
