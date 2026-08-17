import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_search_bar.dart';

class EmpresaServicesSection extends StatelessWidget {
  const EmpresaServicesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Catálogo de Serviços', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: CustomSearchBar(hintText: 'Buscar por serviço', onChanged: (val) {}),
        ),
        const SizedBox(height: 20),
        
        // Cards Mocados
        _buildServiceCard('Ensaio', 'Ensaio de Esclerometria', 'Ensaio não destrutivo', 'assets/images/servico_ensaio.png'),
        _buildServiceCard('Execução', 'Tratamento de Corrosão', 'Recuperação Estrutural', 'assets/images/servico_ensaio.png'),
      ],
    );
  }

  Widget _buildServiceCard(String tag, String title, String subtitle, String imagePath) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Image.asset(
                  imagePath,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                  child: Text(tag, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.hintText)),
                const SizedBox(height: 8),
                const Text(
                  'Lorem Ipsum is simply dummy text of the printing and typesetting industry...',
                  style: TextStyle(fontSize: 12, color: AppColors.hintText, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}