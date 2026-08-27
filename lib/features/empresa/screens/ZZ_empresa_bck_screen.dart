import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/screens/perfil_drawer.dart';
import '../providers/empresa_provider.dart';
import '../widgets/empresa_about_section.dart';
import '../widgets/empresa_header.dart';
import '../widgets/empresa_info_section.dart';
import '../widgets/empresa_team_section.dart';

class EmpresaScreen2 extends ConsumerStatefulWidget {
  const EmpresaScreen2({super.key});

  @override
  ConsumerState<EmpresaScreen2> createState() => _EmpresaScreenState();
}

class _EmpresaScreenState extends ConsumerState<EmpresaScreen2> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final usuario = ref.read(currentUserProvider);
      if (usuario != null && usuario.empresaId != null) {
        ref
            .read(empresaControllerProvider.notifier)
            .carregarEmpresaAtual(usuario.empresaId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final empresaAtual = ref.watch(empresaAtualProvider);

    return Scaffold(
      key: _scaffoldKey,
      drawer: const PerfilDrawer(),
      backgroundColor: const Color(0xFFF5F5F5),
      body: empresaAtual == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EmpresaHeader(
                    topPadding: topPadding,
                    empresa: empresaAtual,
                    onOpenDrawer: () {
                      _scaffoldKey.currentState?.openDrawer();
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        EmpresaInfoSection(empresa: empresaAtual),
                        const SizedBox(height: 24),
                        EmpresaTeamSection(empresaId: empresaAtual.id),
                        const SizedBox(height: 24),
                        EmpresaAboutSection(empresa: empresaAtual),
                        const SizedBox(height: 24),
                        // const EmpresaServicesSection(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
