import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../providers/estruturas_dropdown_provider.dart';

class NovoItemDropdownModal extends ConsumerStatefulWidget {
  final String titulo;
  final String nomeTabela;

  const NovoItemDropdownModal({
    super.key,
    required this.titulo,
    required this.nomeTabela,
  });

  @override
  ConsumerState<NovoItemDropdownModal> createState() => _NovoItemDropdownModalState();
}

class _NovoItemDropdownModalState extends ConsumerState<NovoItemDropdownModal> {
  final _nomeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _salvar() async {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(estruturaDropdownsControllerProvider);
      
      // Chama o backend para salvar
      final novoId = await controller.adicionarNovoItem(
        nomeTabela: widget.nomeTabela,
        nomeItem: nome,
      );

      if (mounted) {
        // Retorna o ID recém-criado para a tela anterior fechar o modal
        Navigator.of(context).pop(novoId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Novo ${widget.titulo}',
        style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Este item ficará salvo exclusivamente para a sua empresa.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Nome*',
            hint: 'Ex: Digite o nome...',
            controller: _nomeController,
            enabled: !_isLoading,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isLoading ? null : _salvar,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Salvar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}