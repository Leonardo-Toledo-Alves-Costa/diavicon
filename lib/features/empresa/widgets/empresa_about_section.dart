import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/empresa_model.dart';

class EmpresaAboutSection extends StatelessWidget {
  final EmpresaModel empresa;

  const EmpresaAboutSection({super.key, required this.empresa});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sobre a empresa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 12),
          Text(
            empresa.descricao ?? 'Nenhuma descrição fornecida pela empresa.',
            style: const TextStyle(fontSize: 13, color: AppColors.hintText, height: 1.5),
          ),
        ],
      ),
    );
  }
}