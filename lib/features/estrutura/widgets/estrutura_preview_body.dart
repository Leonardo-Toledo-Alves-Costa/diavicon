import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/compact_button.dart';
import '../models/estrutura_model.dart';
import '../screens/estrutura_home.dart';

class EstruturaPreviewBody extends StatelessWidget {
  final EstruturaModel estrutura;

  const EstruturaPreviewBody({super.key, required this.estrutura});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              child: estrutura.imageUrl != null
                  ? Image.network(estrutura.imageUrl!, height: 160, width: double.infinity, fit: BoxFit.cover)
                  : Image.asset('assets/images/sem_estrutura.png', height: 160, width: double.infinity, fit: BoxFit.cover),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
                child: const Text('Projetos concluídos', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(estrutura.nome ?? 'Sem nome', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text('${estrutura.tipologiaNome ?? 'Sem tipologia'} - ${estrutura.tipoNome ?? 'Sem tipo'}', style: const TextStyle(fontSize: 14, color: AppColors.hintText)),
              const SizedBox(height: 4),
              Text('${estrutura.idadeCalculada} Anos   CAA ${estrutura.caa ?? '-'}', style: const TextStyle(fontSize: 12, color: AppColors.hintText)),
              const SizedBox(height: 2),
              Text(estrutura.conjuntoNome ?? 'Sem setor vinculado', style: const TextStyle(fontSize: 12, color: AppColors.hintText)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatBox('22', 'Elementos\nCadastrados'),
                  _buildStatBox('07', 'Projetos\nExecutados'),
                  _buildStatBox('21', 'Ensaios\nRealizados'),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: SizedBox(
                  width: 240, 
                  child: CompactButton(
                    text: 'Acessar Estrutura',
                    onPressed: () {
                      Navigator.pop(context); 
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EstruturaHomeScreen(
                            estrutura: estrutura,
                            projetoId: '',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildStatBox(String numero, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inputBorder.withValues(alpha: 0.5)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Column(
          children: [
            Text(numero, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.hintText, height: 1.2)),
          ],
        ),
      ),
    );
  }
}