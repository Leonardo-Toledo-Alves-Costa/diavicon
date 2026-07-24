import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_button.dart';

class NovaEstruturaModalBody extends StatelessWidget {
  const NovaEstruturaModalBody({super.key});

  @override
  Widget build(BuildContext context) {
    // Como o showDiaviconModal já tem scroll interno, retornamos apenas uma Column limpa
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. FOTO DA ESTRUTURA
        GestureDetector(
          onTap: () {}, 
          child: Container(
            height: 140, 
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0), 
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.black54),
                SizedBox(height: 8),
                Text(
                  'Adicionar capa',
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 2. CAMPO DE NOME
        CustomTextField(
          label: 'Nome da estrutura*',
          hint: 'Ex: Galpão de Distribuição Norte',
          controller: TextEditingController(), 
          isRequired: true,
        ),
        const SizedBox(height: 16),

        // 3. SECÇÃO DO PROPRIETÁRIO
        const Text(
          'Proprietário da estrutura', 
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)
        ),
        const SizedBox(height: 2), 
        const Text(
          'O proprietário da estrutura é responsável pela gestão e compartilhamento dos dados',
          style: TextStyle(fontSize: 11, color: AppColors.hintText, height: 1.2), 
        ),
        const SizedBox(height: 12),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Icon(Icons.domain, size: 32, color: Colors.grey[400]), 
            ),
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Proprietário da Estrutura*', style: TextStyle(fontSize: 11, color: AppColors.hintText)),
                  const SizedBox(height: 4),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.inputBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Selecione', style: TextStyle(color: AppColors.textDark, fontSize: 13)),
                        Icon(Icons.keyboard_arrow_down, color: AppColors.textDark, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE), 
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Não Vinculado', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                      
                      const Spacer(), 
                      
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                          minimumSize: const Size(0, 28), 
                        ),
                        onPressed: () {}, 
                        child: const Text('Vincular', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 4. BOTÃO CRIAR
        CustomButton(
          text: 'Criar',
          showArrow: false,
          onPressed: () {}, 
        ),
      ],
    );
  }
}