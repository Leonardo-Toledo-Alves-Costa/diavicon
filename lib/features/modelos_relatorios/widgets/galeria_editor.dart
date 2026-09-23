import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/modelo_relatorio_schema.dart';
import '../models/quadro_model.dart';

class GaleriaEditor extends StatelessWidget {
  final GaleriaConfig config;
  final ValueChanged<GaleriaConfig> onChanged;

  const GaleriaEditor({super.key, required this.config, required this.onChanged});

  static const int _minColunas = 2;
  static const int _maxColunas = 6;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Colunas na grade', style: TextStyle(fontSize: 13, color: Colors.black87)),
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: config.colunas > _minColunas ? () => onChanged(config.copyWith(colunas: config.colunas - 1)) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppColors.primary,
                ),
                Text(config.colunas.toString(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: config.colunas < _maxColunas ? () => onChanged(config.copyWith(colunas: config.colunas + 1)) : null,
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.primary,
          value: config.mostrarDescricao,
          title: const Text('Mostrar descrição junto às fotos', style: TextStyle(fontSize: 13)),
          onChanged: (v) => onChanged(config.copyWith(mostrarDescricao: v ?? false)),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Altura da foto (px)', style: TextStyle(fontSize: 13, color: Colors.black87)),
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: config.alturaImagem > 60 ? () => onChanged(config.copyWith(alturaImagem: config.alturaImagem - 20)) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppColors.primary,
                ),
                Text(config.alturaImagem.round().toString(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: config.alturaImagem < 400 ? () => onChanged(config.copyWith(alturaImagem: config.alturaImagem + 20)) : null,
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: AjusteImagem.values.map((a) {
            final ativo = a == config.ajusteImagem;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(a.rotulo),
                selected: ativo,
                onSelected: (_) => onChanged(config.copyWith(ajusteImagem: a)),
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: config.colunas,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: config.colunas,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            return Container(
              constraints: BoxConstraints(maxHeight: config.alturaImagem),
              decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(6)),
              child: const Center(child: Icon(Icons.image_outlined, color: Colors.black26)),
            );
          },
        ),
      ],
    );
  }
}
