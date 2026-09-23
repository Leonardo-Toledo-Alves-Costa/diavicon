import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../models/estrutura_model.dart';
import '../providers/estrutura_provider.dart';
import 'estrutura_preview_body.dart';

// Card de uma estrutura dentro da tela de um Conjunto Estrutural aberto (ver
// estruturas_tab_screen.dart).
//
// Tocar abre o preview da estrutura (mesmo painel de EstruturaCompactCard/
// EstruturaLargeCard), que por sua vez leva aos PROJETOS em que ela está
// sendo trabalhada — e de lá se abre cada projeto. Esse caminho existia
// inteiro, mas ficou inalcançável quando a aba passou a renderizar este card
// no lugar dos outros dois: ele não tinha ação de toque.
class ConjuntoEstruturalCard extends ConsumerWidget {
  final EstruturaModel estrutura;

  const ConjuntoEstruturalCard({super.key, required this.estrutura});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estatisticas = ref.watch(estruturaEstatisticasProvider(estrutura.id));
    final qtdElementos = estatisticas.whenOrNull(data: (e) => e.elementos);

    final cidadeEstado = [
      if ((estrutura.cidade ?? '').trim().isNotEmpty) estrutura.cidade!.trim(),
      if ((estrutura.uf ?? '').trim().isNotEmpty) estrutura.uf!.trim(),
    ].join(' - ');

    return GestureDetector(
      onTap: () => showDialog(
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
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    estrutura.nome ?? 'Sem nome',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _BadgeMonitorada(monitorada: estrutura.monitorada),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _InfoItem(rotulo: 'CAA', valor: estrutura.caa ?? '-'),
                _InfoItem(
                  rotulo: 'Idade',
                  valor: '${estrutura.idadeCalculada} anos',
                ),
                _InfoItem(
                  rotulo: 'Cidade/Estado',
                  valor: cidadeEstado.isEmpty ? '-' : cidadeEstado,
                ),
                _InfoItem(
                  rotulo: 'Elementos cadastrados',
                  valor: qtdElementos?.toString() ?? '...',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeMonitorada extends StatelessWidget {
  final bool monitorada;
  const _BadgeMonitorada({required this.monitorada});

  @override
  Widget build(BuildContext context) {
    final corFundo = monitorada
        ? const Color(0xFFE6F4EA)
        : AppColors.greyVeryLight;
    final corTexto = monitorada
        ? Colors.green.shade800
        : AppColors.greyMediumDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        monitorada ? 'Monitorada' : 'Não monitorada',
        style: TextStyle(
          color: corTexto,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String rotulo;
  final String valor;
  const _InfoItem({required this.rotulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          rotulo,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.hintText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
