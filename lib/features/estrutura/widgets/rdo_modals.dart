import 'package:flutter/material.dart';

class RdoConfirmDialogs {
  static const Color corLaranja = Color(0xFFF9A232);
  static const Color corVermelho = Color(0xFFF71D21);
  static const Color corTexto = Color(0xFF3E3E3D);

  static Future<void> mostrarSalvo(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => _DialogoBase(
        mensagem: 'Relatório Diário de Obra\nsalvo com sucesso!',
        botoes: (ctx) => [],
      ),
    );
  }

  static Future<bool> mostrarConfirmarExclusao(BuildContext context) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoBase(
        mensagem: 'Deseja apagar este\nRelatório Diário de Obra?',
        botoes: (ctx) => [
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: corVermelho,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                elevation: 0,
              ),
              child: const Text(
                'Apagar',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: corLaranja,
                side: const BorderSide(color: corLaranja),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text('Manter', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  static Future<void> mostrarApagado(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => _DialogoBase(
        mensagem: 'Relatório Diário de Obra\napagado com sucesso!',
        botoes: (ctx) => [],
      ),
    );
  }
}

class _DialogoBase extends StatelessWidget {
  final String mensagem;
  final List<Widget> Function(BuildContext context) botoes;

  const _DialogoBase({required this.mensagem, required this.botoes});

  @override
  Widget build(BuildContext context) {
    final botoesConstruidos = botoes(context);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 13, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey.withValues(alpha: 0.4)),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: RdoConfirmDialogs.corLaranja,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 13),
            Container(width: 200, height: 1, color: const Color(0xFFDFDFDF)),
            const SizedBox(height: 16),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: RdoConfirmDialogs.corTexto,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            if (botoesConstruidos.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(children: botoesConstruidos),
            ],
          ],
        ),
      ),
    );
  }
}