import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/empresa_model.dart';

class EmpresaInfoSection extends StatelessWidget {
  final EmpresaModel empresa;

  const EmpresaInfoSection({super.key, required this.empresa});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nome e Descrição Curta
        Text(
          empresa.nome,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          empresa.tipo ?? 'Empresa especializada',
          style: const TextStyle(fontSize: 14, color: AppColors.hintText),
        ),
        const SizedBox(height: 2),
        // Localização Mocada
        Text(
          (empresa.cidade != null && empresa.estado != null)
              ? '${empresa.cidade}, ${empresa.estado}' // 👈 Usa os dados reais do banco
              : 'Localização não informada',
          style: const TextStyle(fontSize: 12, color: AppColors.hintText),
        ),

        const SizedBox(height: 16),

        // Redes Sociais (Ícones Mocado)
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildSocialIcon('assets/images/linkedin.png'), // LinkedIn proxy
            _buildSocialIcon('assets/images/instagram.png'), // Insta proxy
            _buildSocialIcon('assets/images/youtube.png'), // YT proxy
            _buildSocialIcon('assets/images/internet.png'), // Web proxy
            _buildSocialIcon('assets/images/gmail.png'), // Email proxy
            _buildSocialIcon('assets/images/whatsapp.png'), // WPP proxy
          ],
        ),

        const SizedBox(height: 24),

        // Caixinhas Laranja de Estatísticas
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatBox('141', 'Estruturas\nMonitoradas'),
            _buildStatBox('215', 'Projetos\nRealizados'),
            _buildStatBox('10.000', 'Ensaios\nExecutados'),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialIcon(String imagePath) {
    return Padding(
      padding: const EdgeInsets.only(right: 25.0),
      // Envolvemos num GestureDetector caso queira adicionar o clique (link) futuramente
      child: GestureDetector(
        onTap: () {
          // Lógica para abrir o link no futuro
        },
        child: Image.asset(
          imagePath,
          width: 25, // Ajuste o tamanho para ficar harmonioso
          height: 25,
          fit: BoxFit.contain,
          // Se as suas imagens forem pretas/brancas e quiser forçar a cor padrão do app, 
          // basta descomentar a linha abaixo:
          // color: AppColors.textDark, 
        ),
      ),
    );
  }

  Widget _buildStatBox(String number, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              number,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
