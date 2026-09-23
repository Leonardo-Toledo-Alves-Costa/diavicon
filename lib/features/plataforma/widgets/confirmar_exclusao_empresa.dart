import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../repositories/empresas_plataforma_repository.dart';

String _normalizar(String texto) => texto.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Diálogo de exclusão definitiva de uma empresa. Só libera o botão depois de
/// a pessoa digitar o nome da empresa, e executa [aoConfirmar] ali mesmo,
/// mostrando o progresso e o erro sem fechar. Devolve `true` se apagou.
Future<bool> confirmarExclusaoEmpresa(
  BuildContext context, {
  required String nomeEmpresa,
  required String titulo,
  required List<String> consequencias,
  required Future<void> Function(String nomeDigitado) aoConfirmar,
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoExclusao(
      nomeEmpresa: nomeEmpresa,
      titulo: titulo,
      consequencias: consequencias,
      aoConfirmar: aoConfirmar,
    ),
  );
  return resultado == true;
}

class _DialogoExclusao extends StatefulWidget {
  final String nomeEmpresa;
  final String titulo;
  final List<String> consequencias;
  final Future<void> Function(String nomeDigitado) aoConfirmar;

  const _DialogoExclusao({
    required this.nomeEmpresa,
    required this.titulo,
    required this.consequencias,
    required this.aoConfirmar,
  });

  @override
  State<_DialogoExclusao> createState() => _DialogoExclusaoState();
}

class _DialogoExclusaoState extends State<_DialogoExclusao> {
  final _controller = TextEditingController();
  bool _excluindo = false;
  String? _erro;

  bool get _nomeConfere => _normalizar(_controller.text) == _normalizar(widget.nomeEmpresa);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _excluir() async {
    setState(() {
      _excluindo = true;
      _erro = null;
    });
    try {
      await widget.aoConfirmar(_controller.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _excluindo = false;
          _erro = mensagemErroOperacao(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 40),
      title: Text(widget.titulo, textAlign: TextAlign.center),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Esta ação é definitiva e não pode ser desfeita. Serão apagados:',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 10),
              for (final item in widget.consequencias)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(Icons.remove_circle_outline, size: 16, color: AppColors.error),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item, style: const TextStyle(fontSize: 13, height: 1.35))),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 13, height: 1.4),
                  children: [
                    const TextSpan(text: 'Para confirmar, digite o nome da empresa: '),
                    TextSpan(text: widget.nomeEmpresa, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                enabled: !_excluindo,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (_nomeConfere && !_excluindo) _excluir();
                },
                decoration: InputDecoration(
                  hintText: widget.nomeEmpresa,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 10),
                Text(_erro!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _excluindo ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _nomeConfere && !_excluindo ? _excluir : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
          icon: _excluindo
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.delete_forever_outlined, size: 18),
          label: Text(_excluindo ? 'Excluindo...' : 'Excluir definitivamente'),
        ),
      ],
    );
  }
}
