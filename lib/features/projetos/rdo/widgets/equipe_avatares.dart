import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../equipe/providers/equipe_provider.dart';
import 'equipe_helpers.dart';

/// Pilha compacta de avatares da equipe de um RDO — foto real de quem está
/// na equipe do projeto (por nome), usada nos cards de RDO. Se a lista de
/// equipe do projeto ainda estiver carregando, cai num ícone genérico em vez
/// de travar o card numa fiação de carregamento.
class EquipeAvataresCompacto extends ConsumerWidget {
  final String projetoId;
  final List<String> nomes;
  final double radius;

  const EquipeAvataresCompacto({
    super.key,
    required this.projetoId,
    required this.nomes,
    this.radius = 15,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (nomes.isEmpty) {
      return Text('Sem equipe registrada', style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyLight));
    }

    final membros = ref.watch(colaboradoresProjetoVisiveisProvider(projetoId)).value ?? const [];
    final mapaEquipe = mapaEquipePorNome(membros);

    final int visiveis = nomes.length > 3 ? 3 : nomes.length;
    final int restante = nomes.length - visiveis;
    final double passo = radius * 1.45;

    return SizedBox(
      height: radius * 2 + 2,
      child: Stack(
        children: [
          for (int i = 0; i < visiveis; i++)
            Positioned(
              left: i * passo,
              child: _Avatar(fotoUrl: fotoDoMembro(mapaEquipe[nomes[i]]), radius: radius),
            ),
          if (restante > 0)
            Positioned(
              left: visiveis * passo,
              child: CircleAvatar(
                radius: radius,
                backgroundColor: AppColors.primary,
                child: Text(
                  '+$restante',
                  style: GoogleFonts.lato(color: Colors.white, fontSize: radius * 0.73, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? fotoUrl;
  final double radius;

  const _Avatar({required this.fotoUrl, required this.radius});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.greyVeryLight,
      backgroundImage: fotoUrl != null ? StorageNetworkImage(fotoUrl!) : null,
      child: fotoUrl == null ? Icon(Icons.person, size: radius, color: AppColors.greyMedium) : null,
    );
  }
}
