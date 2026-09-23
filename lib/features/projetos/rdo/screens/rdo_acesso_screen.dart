import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../providers/empresas_projeto_provider.dart';
import '../providers/rdo_provider.dart';
import 'rdo_empresas_screen.dart';
import 'rdo_lista_screen.dart';

/// Portão de entrada do RDO de um projeto: resolve o papel da empresa do
/// usuário logado e decide se ele vê a lista de empresas (gestora/cliente)
/// ou cai direto no próprio RDO (colaboradora comum, que não enxerga o das
/// outras empresas).
class RdoAcessoScreen extends ConsumerWidget {
  final String projetoId;
  final String projetoNome;

  const RdoAcessoScreen({super.key, required this.projetoId, this.projetoNome = 'Projeto'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final papelAsync = ref.watch(papelEmpresaNoProjetoProvider(projetoId));

    return papelAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary))),
      error: (err, _) => Scaffold(
        body: Center(child: Text('Erro ao verificar permissões: $err', style: GoogleFonts.lato(color: AppColors.error))),
      ),
      data: (papel) {
        if (papel.vePapeisDeTodasEmpresas) {
          return RdoEmpresasScreen(projetoId: projetoId, projetoNome: projetoNome);
        }
        return Consumer(
          builder: (context, ref, _) {
            final minhaEmpresaAsync = ref.watch(minhaEmpresaProvider);
            final usuario = ref.watch(currentUserProvider);
            return minhaEmpresaAsync.when(
              loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary))),
              error: (err, _) => Scaffold(
                body: Center(child: Text('Erro ao carregar empresa: $err', style: GoogleFonts.lato(color: AppColors.error))),
              ),
              data: (minhaEmpresa) => RdoListaScreen(
                projetoId: projetoId,
                projetoNome: projetoNome,
                empresaId: usuario?.empresaId ?? '',
                empresaNome: minhaEmpresa?['nome']?.toString() ?? 'Minha empresa',
                empresaFotoUrl: minhaEmpresa?['foto_url']?.toString(),
              ),
            );
          },
        );
      },
    );
  }
}
