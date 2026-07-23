import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/compact_button.dart';
import '../../../core/widgets/diavicon_alerts.dart';

class ConfigurarQtdEnsaioModal extends StatefulWidget {
  final String nomeEnsaio;
  final String iconeEnsaio;
  final int? qtdInicial; // Se vier preenchido, é EDIÇÃO. Se for null, é CRIAÇÃO.

  const ConfigurarQtdEnsaioModal({
    super.key,
    required this.nomeEnsaio,
    required this.iconeEnsaio,
    this.qtdInicial,
  });

  @override
  State<ConfigurarQtdEnsaioModal> createState() => _ConfigurarQtdEnsaioModalState();
}

class _ConfigurarQtdEnsaioModalState extends State<ConfigurarQtdEnsaioModal> {
  late final TextEditingController _qtdController;
  bool get _isEdicao => widget.qtdInicial != null;

  @override
  void initState() {
    super.initState();
    // 🔥 Agora sim, inicializando o controller e usando a variável certa (qtdInicial)
    _qtdController = TextEditingController(
      text: widget.qtdInicial?.toString() ?? '1',
    );
  }

  @override
  void dispose() {
    _qtdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // CABEÇALHO COM ÍCONE E NOME
            Row(
              children: [
                Image.asset(
                  widget.iconeEnsaio,
                  width: 36,
                  height: 36,
                  errorBuilder: (_, __, ___) => const Icon(Icons.science_outlined, size: 36, color: AppColors.textDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEdicao ? 'Editar Ensaio' : 'Novo Ensaio',
                        style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.greyMedium),
                      ),
                      Text(
                        widget.nomeEnsaio,
                        style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF3E3E3D)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: AppColors.greyMedium),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // CAMPO DE QUANTIDADE CENTRALIZADO E BEM VISÍVEL
            Text(
              'Quantidade *',
              style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.greyMedium),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Center(
              child: SizedBox(
                width: 120,
                child: TextField(
                  controller: _qtdController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  autofocus: true, // Já abre com o teclado na tela pra agilizar!
                  style: GoogleFonts.lato(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
                  decoration: InputDecoration(
                    // 🔥 Adeus hintText '00'! Fica tudo limpo agora.
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // BOTÕES DINÂMICOS (MUDAM SE É CRIAÇÃO OU EDIÇÃO)
            Row(
              children: [
                Expanded(
                  child: CompactButton(
                    text: _isEdicao ? 'Apagar' : 'Cancelar',
                    height: 52,
                    backgroundColor: Colors.white,
                    foregroundColor: _isEdicao ? AppColors.error : AppColors.greyMedium,
                    borderColor: _isEdicao ? AppColors.error : AppColors.inputBorder,
                    elevation: 0,
                    onPressed: () {
                      if (_isEdicao) {
                        // Devolve instrução para apagar
                        Navigator.pop(context, {'acao': 'apagar'});
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CompactButton(
                    text: _isEdicao ? 'Salvar' : 'Adicionar',
                    height: 52,
                    backgroundColor: AppColors.primary,
                    onPressed: () {
                      final qtd = int.tryParse(_qtdController.text);
                      if (qtd == null || qtd <= 0) {
                        DiaviconAlerts.show(context, 'Atenção', 'Digite uma quantidade válida maior que zero.', isAviso: true);
                        return;
                      }

                      // Devolve instrução para salvar/adicionar com o número
                      Navigator.pop(context, {
                        'acao': 'salvar',
                        'qtd': qtd,
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}