import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/estrutura_model.dart';
import 'estrutura_preview_body.dart';

class EstruturaCompactCard extends StatelessWidget {
  final EstruturaModel estrutura;

  const EstruturaCompactCard({super.key, required this.estrutura});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          useRootNavigator: true, 
          useSafeArea: false,
          builder: (_) => Dialog(
            alignment: Alignment.bottomCenter,
            insetPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 0),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            clipBehavior: Clip.antiAlias,
            child: EstruturaPreviewBody(estrutura: estrutura),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04), 
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: estrutura.imageUrl != null
                  ? Image.network(estrutura.imageUrl!, height: 70, width: 70, fit: BoxFit.cover)
                  : Image.asset('assets/images/sem_estrutura.png', height: 70, width: 70, fit: BoxFit.cover),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    estrutura.nome ?? 'Sem nome',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${estrutura.tipologiaNome ?? 'Sem tipologia'} - ${estrutura.tipoNome ?? 'Sem tipo'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.hintText),
                  ),
                  const SizedBox(height: 4),
                  Text('${estrutura.idadeCalculada} Anos   CAA ${estrutura.caa ?? '-'}', style: const TextStyle(fontSize: 11, color: AppColors.hintText)),
                  const SizedBox(height: 2),
                  Text(estrutura.conjuntoNome ?? 'Sem setor vinculado', style: const TextStyle(fontSize: 11, color: AppColors.hintText)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
                        child: const Text('Projetos concluídos', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
                        child: const Text('Monitorado', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}