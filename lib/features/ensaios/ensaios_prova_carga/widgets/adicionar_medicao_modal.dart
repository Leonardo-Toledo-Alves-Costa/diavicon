import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../../../core/constants/app_colors.dart';
import '../models/leitura_prova_carga_model.dart';

class AdicionarMedicaoResult {
  final bool apagar;
  final int deslocamento;
  final int carregamento;
  final String etapa;
  final String horario;

  const AdicionarMedicaoResult.salvar({
    required this.deslocamento,
    required this.carregamento,
    required this.etapa,
    required this.horario,
  }) : apagar = false;

  const AdicionarMedicaoResult.apagar()
      : apagar = true,
        deslocamento = 0,
        carregamento = 0,
        etapa = '',
        horario = '';
}

/// Deslocamento/Carga/Etapa/Hora de uma medição individual do ponto
/// selecionado. Espelha `_abrirModalLeitura` da resistividade.
Future<AdicionarMedicaoResult?> showAdicionarMedicaoModal(
  BuildContext context, {
  LeituraProvaCargaModel? leituraExistente,
  String etapaPadrao = 'Carregamento',
  required String pontoNome,
}) {
  return showDialog<AdicionarMedicaoResult>(
    context: context,
    builder: (context) => _AdicionarMedicaoDialog(
      leituraExistente: leituraExistente,
      etapaPadrao: etapaPadrao,
      pontoNome: pontoNome,
    ),
  );
}

class _AdicionarMedicaoDialog extends StatefulWidget {
  final LeituraProvaCargaModel? leituraExistente;
  final String etapaPadrao;
  final String pontoNome;

  const _AdicionarMedicaoDialog({this.leituraExistente, required this.etapaPadrao, required this.pontoNome});

  @override
  State<_AdicionarMedicaoDialog> createState() => _AdicionarMedicaoDialogState();
}

class _AdicionarMedicaoDialogState extends State<_AdicionarMedicaoDialog> {
  late final TextEditingController _deslocCtrl;
  late final TextEditingController _cargaCtrl;
  late final TextEditingController _horaCtrl;
  late String _etapa;

  @override
  void initState() {
    super.initState();
    final l = widget.leituraExistente;
    _deslocCtrl = TextEditingController(text: l?.deslocamento.toString() ?? '');
    _cargaCtrl = TextEditingController(text: l?.carregamento.toString() ?? '');
    _horaCtrl = TextEditingController(text: l?.horario ?? '');
    _etapa = l?.etapa ?? widget.etapaPadrao;
  }

  @override
  void dispose() {
    _deslocCtrl.dispose();
    _cargaCtrl.dispose();
    _horaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeFormatter = MaskTextInputFormatter(mask: '##:##', filter: {"#": RegExp(r'[0-9]')});
    final isEdicao = widget.leituraExistente != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(isEdicao ? 'Editar Medição' : 'Adicionar Medição', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.pontoNome, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _campo('Deslocamento (mm)', _deslocCtrl, isNumero: true)),
              const SizedBox(width: 8),
              Expanded(child: _campo('Carga (kg)', _cargaCtrl, isNumero: true)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Etapa', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _etapa,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'Carregamento', child: Text('Carregamento')),
                            DropdownMenuItem(value: 'Descarregamento', child: Text('Descarregamento')),
                          ],
                          onChanged: (val) => setState(() => _etapa = val ?? _etapa),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _campo('Hora', _horaCtrl, formatters: [timeFormatter])),
            ],
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        if (isEdicao)
          OutlinedButton(
            onPressed: () => Navigator.pop(context, const AdicionarMedicaoResult.apagar()),
            child: const Text('Apagar', style: TextStyle(color: AppColors.error)),
          )
        else
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () {
            Navigator.pop(
              context,
              AdicionarMedicaoResult.salvar(
                deslocamento: int.tryParse(_deslocCtrl.text.trim()) ?? 0,
                carregamento: int.tryParse(_cargaCtrl.text.trim()) ?? 0,
                etapa: _etapa,
                horario: _horaCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Salvar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _campo(String label, TextEditingController controller, {List<TextInputFormatter>? formatters, bool isNumero = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: isNumero ? TextInputType.number : TextInputType.text,
          inputFormatters: formatters,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            isDense: true,
            hintText: isNumero ? '000' : '00:00',
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
