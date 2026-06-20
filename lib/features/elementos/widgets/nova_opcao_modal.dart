import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/features/elementos/widgets/bigger_custom_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Abre um popup simples para criar uma nova opção de dropdown (texto livre).
///
/// Usado nos campos cujo "adicionar opção" é apenas um novo valor de texto
/// (tipo do elemento, tipologia estrutural, revestimento). Retorna o nome
/// digitado, ou `null` se o usuário cancelar/fechar.
Future<String?> showNovaOpcaoModal(
  BuildContext context, {
  required String titulo,
  String label = 'Nome',
  String hint = 'Nome',
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => NovaOpcaoModal(titulo: titulo, label: label, hint: hint),
  );
}

class NovaOpcaoModal extends StatefulWidget {
  const NovaOpcaoModal({
    super.key,
    required this.titulo,
    this.label = 'Nome',
    this.hint = 'Nome',
  });

  final String titulo;
  final String label;
  final String hint;

  @override
  State<NovaOpcaoModal> createState() => _NovaOpcaoModalState();
}

class _NovaOpcaoModalState extends State<NovaOpcaoModal> {
  final _controller = TextEditingController();
  bool _erro = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _salvar() {
    final nome = _controller.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = true);
      return;
    }
    Navigator.of(context).pop(nome);
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.titulo,
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
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: widget.label,
                        style: GoogleFonts.lato(
                          color: const Color(0xFF626365),
                          fontSize: 16,
                        ),
                      ),
                      TextSpan(
                        text: ' *',
                        style: GoogleFonts.lato(
                          color: const Color(0xFFF71D20),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextFormField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (_erro) setState(() => _erro = false);
                },
                onFieldSubmitted: (_) => _salvar(),
                style: GoogleFonts.lato(color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: GoogleFonts.lato(
                    color: AppColors.hintText,
                    fontWeight: FontWeight.w300,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  errorText: _erro ? 'Informe um nome' : null,
                  border: _border(AppColors.inputBorder),
                  enabledBorder: _border(AppColors.inputBorder),
                  focusedBorder: _border(AppColors.primary),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: BiggerCustomButton(
                  width: 86,
                  height: 34,
                  text: 'Salvar',
                  onPressed: _salvar,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color),
      );
}
