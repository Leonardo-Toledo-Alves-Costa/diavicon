import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';

class EnsaioCarbonatacaoFormScreen extends StatefulWidget {
  final String pontoNome;
  final String elementoNome;
  final String tipoElemento;
  final String local;

  const EnsaioCarbonatacaoFormScreen({
    super.key,
    required this.pontoNome,
    required this.elementoNome,
    required this.tipoElemento,
    required this.local,
  });

  @override
  State<EnsaioCarbonatacaoFormScreen> createState() => _EnsaioCarbonatacaoFormScreenState();
}

class _EnsaioCarbonatacaoFormScreenState extends State<EnsaioCarbonatacaoFormScreen> {
  // Controladores para Armadura Principal
  final _cobPrincipalCtrl = TextEditingController(text: '26');
  final _bitPrincipalCtrl = TextEditingController(text: '12,5');

  // Controladores para Armadura Secundária
  final _cobSecundariaCtrl = TextEditingController(text: '23');
  final _bitSecundariaCtrl = TextEditingController(text: '6,3');

  // Controladores para as 6 Frentes de Carbonatação
  final List<TextEditingController> _frentesCtrls = [
    TextEditingController(text: '17'),
    TextEditingController(text: '20'),
    TextEditingController(text: '18'),
    TextEditingController(text: '18'),
    TextEditingController(text: '19'),
    TextEditingController(text: '16'),
  ];

  @override
  void dispose() {
    _cobPrincipalCtrl.dispose();
    _bitPrincipalCtrl.dispose();
    _cobSecundariaCtrl.dispose();
    _bitSecundariaCtrl.dispose();
    for (var ctrl in _frentesCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Projeto', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
            Text('Ensaio', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Ponto de ensaio', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CABEÇALHO DO PONTO
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.pontoNome} - ${widget.elementoNome}',
                  style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D)),
                ),
                const Icon(Icons.edit_square, color: AppColors.textDark, size: 24),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.tipoElemento,
              style: GoogleFonts.lato(fontSize: 14, color: const Color(0xFF686868)),
            ),
            const SizedBox(height: 2),
            Text(
              widget.local,
              style: GoogleFonts.lato(fontSize: 14, color: const Color(0xFF686868)),
            ),
            const SizedBox(height: 32),

            // FOTOS
            Row(
              children: [
                Expanded(
                  child: _buildPhotoCard(
                    title: 'Quebra do concreto',
                    imageUrl: 'https://img.freepik.com/fotos-gratis/velha-parede-de-concreto-lascada-e-rachada_1137-122.jpg', // Mock visual
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPhotoCard(
                    title: 'Aspersão do reagente',
                    imageUrl: 'https://st3.depositphotos.com/2645161/12863/i/450/depositphotos_128633732-stock-photo-phenolphthalein-ph-indicator-for-carbonation.jpg', // Mock visual
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ARMADURA PRINCIPAL
            Text(
              'Armadura principal',
              style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildInputField(label: 'Cob. (mm)', controller: _cobPrincipalCtrl)),
                const SizedBox(width: 16),
                Expanded(child: _buildInputField(label: 'Bit. (mm)', controller: _bitPrincipalCtrl)),
              ],
            ),
            const SizedBox(height: 24),

            // ARMADURA SECUNDÁRIA
            Text(
              'Armadura Secundária',
              style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildInputField(label: 'Cob. (mm)', controller: _cobSecundariaCtrl)),
                const SizedBox(width: 16),
                Expanded(child: _buildInputField(label: 'Bit. (mm)', controller: _bitSecundariaCtrl)),
              ],
            ),
            const SizedBox(height: 32),

            // MEDIÇÃO DAS FRENTES
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Medição das frentes de carbonatação',
                    style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.info_outline, size: 18, color: AppColors.greyMedium),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: (MediaQuery.of(context).size.width - 48 - 32) / 3, // Divide o espaço por 3 colunas
                  child: _buildInputField(
                    label: '${index + 1}ª Frente',
                    controller: _frentesCtrls[index],
                  ),
                );
              }),
            ),
            
            const SizedBox(height: 48), // Espaçamento extra no final para scroll
          ],
        ),
      ),
    );
  }

  // WIDGET REUTILIZÁVEL: CARD DE FOTO
  Widget _buildPhotoCard({required String title, required String imageUrl}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image, color: Colors.grey),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: const Icon(Icons.edit_square, size: 20, color: AppColors.textDark),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // WIDGET REUTILIZÁVEL: CAMPO DE TEXTO
  Widget _buildInputField({required String label, required TextEditingController controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.lato(fontSize: 14, color: const Color(0xFFA0A0A0)),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: GoogleFonts.lato(fontSize: 16, color: const Color(0xFF3E3E3D)),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}