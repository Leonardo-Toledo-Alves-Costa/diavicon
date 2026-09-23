import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/estrutura_model.dart';
import 'estrutura_preview_body.dart';

class EstruturaLargeCard extends StatelessWidget {
  final EstruturaModel estrutura;

  const EstruturaLargeCard({super.key, required this.estrutura});

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
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32), 
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), 
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  child: estrutura.imageUrl != null
                      ? ImagemStorage.network(estrutura.imageUrl!, height: 160, width: double.infinity, fit: BoxFit.cover)
                      : Image.asset('assets/images/sem_estrutura.png', height: 160, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                    child: const Text('2 Projetos Ativos', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    estrutura.nome ?? 'Sem nome',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark), 
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${estrutura.tipologiaNome ?? 'Sem tipologia'} - ${estrutura.tipoNome ?? 'Sem tipo'}',
                    style: const TextStyle(fontSize: 14, color: AppColors.hintText, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${estrutura.idadeCalculada} Anos   CAA ${estrutura.caa ?? '-'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.hintText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    estrutura.conjuntoNome ?? 'Sem setor vinculado',
                    style: const TextStyle(fontSize: 12, color: AppColors.hintText),
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