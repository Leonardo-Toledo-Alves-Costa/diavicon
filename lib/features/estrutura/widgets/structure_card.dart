import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:diavicon/features/estrutura/models/estrutura_model.dart';
import 'package:diavicon/features/estrutura/screens/estrutura_home.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ensaios/ensaios_geral/progresso/progresso_ensaios.dart';

class StructureCard extends StatelessWidget {
  final EstruturaModel estrutura;
  final String projetoId;

  const StructureCard({
    super.key,
    required this.estrutura,
    required this.projetoId,
  });

  Widget _buildImage() {
    const String defaultAsset = 'assets/images/sem_estrutura.png';

    if (estrutura.imageUrl == null || estrutura.imageUrl!.isEmpty) {
      return Image.asset(
        defaultAsset,
        height: 90,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return ImagemStorage.network(
      estrutura.imageUrl!,
      height: 90,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        defaultAsset,
        height: 90,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                EstruturaHomeScreen(estrutura: estrutura, projetoId: projetoId),
          ),
        );
      },
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 16),
        // Obriga o Container a "aparar" as pontas de tudo o que estiver lá dentro
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inputBorder.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                //  A imagem agora preenche 100% da largura.
                _buildImage(),

                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      estrutura.status ?? 'Em Andamento',
                      style: const TextStyle(
                        fontSize: 8,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    estrutura.nome ?? 'Sem nome',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    estrutura.tipoNome ?? 'Sem tipo',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.hintText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${estrutura.idadeCalculada} Anos  CAA ${estrutura.caa ?? '-'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.hintText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    estrutura.conjuntoNome ?? 'Sem setor vinculado',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.hintText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Progresso da estrutura no projeto (realizados ÷ contratados
                  // da empresa, por tipo de ensaio).
                  Consumer(
                    builder: (context, ref, _) {
                      final fracao = ref
                          .watch(progressoProjetoProvider(projetoId))
                          .value
                          ?.estrutura(estrutura.id)
                          .fracao;
                      return Tooltip(
                        message: fracao == null ? 'Sem ensaios contratados' : 'Progresso: ${textoProgresso(fracao)}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fracao ?? 0,
                            minHeight: 5,
                            backgroundColor: const Color(0xFFEEEEEE),
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    },
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
