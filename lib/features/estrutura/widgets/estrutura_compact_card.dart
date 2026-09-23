import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/badge_status.dart';
import '../../projetos/models/projeto_model.dart';
import '../models/estrutura_model.dart';
import '../providers/estrutura_provider.dart';
import 'estrutura_preview_body.dart';

/// Card de uma estrutura na visão "Monitoradas" da aba Estruturas. Tocar abre
/// o preview, que leva aos projetos em que a estrutura está sendo trabalhada.
class EstruturaCompactCard extends ConsumerWidget {
  final EstruturaModel estrutura;

  const EstruturaCompactCard({super.key, required this.estrutura});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projetos = ref.watch(projetosPorEstruturaProvider(estrutura.id)).value;

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
              color: Colors.black.withValues(alpha: 0.04), 
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
                  ? ImagemStorage.network(estrutura.imageUrl!, height: 70, width: 70, fit: BoxFit.cover)
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
                  // Os dois badges eram texto fixo ("Projetos concluídos" e
                  // "Monitorado" em todo card, independente do dado). Agora
                  // saem da estrutura e dos projetos vinculados a ela.
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // Some enquanto carrega, em vez de piscar um estado
                      // que pode estar errado.
                      if (projetos != null) _badgeProjetos(projetos),
                      if (estrutura.monitorada)
                        _badge('Monitorada', _verdeFundo, _verdeTexto),
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

  static const _verdeFundo = Color(0xFFE8F5E9);
  static const _verdeTexto = Colors.green;
  static const _laranjaFundo = Color(0xFFFFF1E0);

  /// "Sem projetos", "NN projetos ativos" ou "Projetos concluídos" — as
  /// três situações do layout. Projeto cancelado não conta como ativo.
  Widget _badgeProjetos(List<ProjetoModel> projetos) {
    if (projetos.isEmpty) return _badge('Sem projetos', _verdeFundo, _verdeTexto);

    final ativos = projetos.where((p) => p.statusBadge == BadgeStatus.emAndamento).length;
    if (ativos > 0) {
      final n = ativos.toString().padLeft(2, '0');
      return _badge(ativos == 1 ? '$n projeto ativo' : '$n projetos ativos', _laranjaFundo, AppColors.primary);
    }
    return _badge('Projetos concluídos', _verdeFundo, _verdeTexto);
  }

  Widget _badge(String texto, Color fundo, Color cor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(12)),
        child: Text(texto, style: TextStyle(color: cor, fontSize: 9, fontWeight: FontWeight.bold)),
      );
}
