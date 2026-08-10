import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/menu_drawer_app_bar.dart';
import '../../../core/widgets/diavicon_menu_item.dart';
import 'package:diavicon/features/projetos/providers/projetos_provider.dart';
import 'package:diavicon/features/projetos/screens/project_info_screen.dart';
import 'package:diavicon/features/projetos/screens/project_companies_screen.dart';

import '../widgets/project_header.dart';
import '../widgets/project_progress_card.dart';
import '../widgets/team_section.dart';
import '../widgets/structures_section.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final String projetoId;

  const ProjectDetailScreen({super.key, required this.projetoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final projetoAsync = ref.watch(projectDetailProvider(projetoId));

    return projetoAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (err, stack) =>
          Scaffold(body: Center(child: Text('Erro ao carregar projeto: $err'))),
      data: (projeto) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          child: Scaffold(
            backgroundColor: Colors.white,
            extendBodyBehindAppBar: true,
            resizeToAvoidBottomInset: true,
            bottomNavigationBar: Container(
              color: Colors.white,
              child: const SafeArea(top: false, child: SizedBox.shrink()),
            ),
            endDrawer: MenuDrawerAppBar(
              title: 'Menu do\nProjeto',
              items: [
                DiaviconMenuItem(
                  icon: Icons.info_outline,
                  label: 'Informações',
                  onTap: () {
                    Navigator.pop(context); // Fecha o menu lateral
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProjectInfoScreen(projetoId: projetoId),
                      ),
                    );
                  },
                ),
                DiaviconMenuItem(
                  icon: Icons.assignment_outlined,
                  label: 'RDO',
                  onTap: () {},
                ),
                DiaviconMenuItem(
                  icon: Icons.business_outlined,
                  label: 'Empresas',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProjectCompaniesScreen(projetoId: projetoId),
                      ),
                    );
                  },
                ),
                DiaviconMenuItem(
                  icon: Icons.description_outlined,
                  label: 'Relatórios',
                  onTap: () {},
                ),
                DiaviconMenuItem(
                  icon: Icons.payments_outlined,
                  label: 'Gastos',
                  onTap: () {},
                ),
                DiaviconMenuItem(
                  icon: Icons.pie_chart_outline,
                  label: 'Dashboard',
                  onTap: () {},
                ),
              ],
            ),
            appBar: const CustomAppBar(title: 'Projetos', showBackButton: true),

            body: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? 20 : 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProjectHeader(projeto: projeto), 

                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            projeto.nome,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 12),

                          _buildGestoraSection(projeto.empresaNome, projeto.empresaFotoUrl),
                          const SizedBox(height: 24),

                          ProjectProgressCard(progresso: projeto.progresso), // Componente extraído!
                          const SizedBox(height: 32),

                          const Text(
                            'Equipe',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 12),

                          TeamSection(projetoId: projetoId), // Componente extraído!
                          const SizedBox(height: 32),

                          StructuresSection(
                            projeto: projeto,
                            projetoId: projetoId,
                          ), // Componente extraído!
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Mantido na tela principal pois é um trecho de UI muito simples e específico daqui
  Widget _buildGestoraSection(String empresaNome, String? fotoUrl) {
    return Row(
      children: [
        // 🔥 Lógica de fallback para a imagem
        ClipOval(
          child: fotoUrl != null && fotoUrl.isNotEmpty
              ? Image.network(
                  fotoUrl,
                  height: 35,
                  width: 35,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Image.asset('assets/images/empresa.png', height: 35),
                )
              : Image.asset('assets/images/empresa.png', height: 35),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              empresaNome,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const Text(
              'Gestora',
              style: TextStyle(color: AppColors.hintText, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}