import 'package:flutter/material.dart';

// Paleta fixa de cores pra decoração condicional e bordas — chips, nunca um
// color picker livre, pra manter consistência visual.
const Map<String, Color> paletaCoresDecoracao = {
  'preto': Colors.black,
  'branco': Colors.white,
  'cinza': Color(0xFF9E9E9E),
  'verde': Color(0xFF4CAF50),
  'ambar': Color(0xFFFF9800),
  'vermelho': Color(0xFFF44336),
  'azul': Color(0xFF2196F3),
  'laranja': Color(0xFFF9A232),
};

Color corDaPaleta(String chave) => paletaCoresDecoracao[chave] ?? Colors.black;

class SeletorCorChips extends StatelessWidget {
  final String selecionada;
  final ValueChanged<String> onSelecionada;

  const SeletorCorChips({super.key, required this.selecionada, required this.onSelecionada});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: paletaCoresDecoracao.entries.map((e) {
        final ativo = e.key == selecionada;
        return GestureDetector(
          onTap: () => onSelecionada(e.key),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: e.value,
              shape: BoxShape.circle,
              border: Border.all(color: ativo ? const Color(0xFFF9A232) : Colors.black26, width: ativo ? 3 : 1),
            ),
          ),
        );
      }).toList(),
    );
  }
}
