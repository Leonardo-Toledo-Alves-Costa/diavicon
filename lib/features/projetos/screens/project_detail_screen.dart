import 'dart:io';
import 'package:diavicon/features/projetos/screens/project_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/menu_drawer_app_bar.dart';
import '../../../core/widgets/diavicon_menu_item.dart';
import '../../../core/widgets/compact_search_bar.dart';
import '../../../core/widgets/compact_button.dart';
import '../../../core/utils/diavicon_modal.dart';
import '../../../core/widgets/status_badge.dart';
import '../../equipe/widgets/team_member_item.dart';
import '../../estrutura/widgets/structure_card.dart';
import '../../auth/screens/edit_team_body.dart';
import '../models/projeto_model.dart';
import 'package:diavicon/features/estrutura/widgets/incluir_estrutura_body.dart';
import 'package:diavicon/features/estrutura/providers/estrutura_provider.dart';
import 'package:diavicon/features/projetos/providers/projetos_provider.dart';
import 'package:diavicon/features/projetos/screens/project_companies_screen.dart';

// Import do provider da equipe
import '../../equipe/providers/equipe_provider.dart';

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
                        // Se estiver dentro de um StatefulWidget, use widget.projetoId
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

            // 🔥 TELA PRINCIPAL SUPER LIMPA
            body: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? 20 : 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProjectHeader(projeto: projeto), // Componente extraído!

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

                          _buildGestoraSection(projeto.empresaNome),
                          const SizedBox(height: 24),

                          _ProjectProgressCard(
                            progresso: projeto.progresso,
                          ), // Componente extraído!
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

                          _TeamSection(
                            projetoId: projetoId,
                          ), // Componente extraído!
                          const SizedBox(height: 32),

                          _StructuresSection(
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

  // Isso pode ficar na tela principal pois é muito simples
  Widget _buildGestoraSection(String empresaNome) {
    return Row(
      children: [
        Image.asset('assets/images/empresa.png', height: 35),
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

// ─────────────────────────────────────────────────────────────────────────────
// 🔥 WIDGETS SEPARADOS POR BOA PRÁTICA (Podem ir para arquivos separados depois)
// ─────────────────────────────────────────────────────────────────────────────

class _ProjectHeader extends StatelessWidget {
  final ProjetoModel projeto;
  const _ProjectHeader({required this.projeto});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        projeto.imageUrl.startsWith('http')
            ? Image.network(
                projeto.imageUrl,
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallbackImage(),
              )
            : Image.asset(
                projeto.imageUrl.isNotEmpty
                    ? projeto.imageUrl
                    : 'assets/images/project_placeholder1.png',
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallbackImage(),
              ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4],
                colors: [Colors.black.withOpacity(0.5), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBadge(
                projeto.prioridadeNome,
                AppColors.primary,
                Icons.info,
              ),
              const SizedBox(height: 8),
              _buildStatusBadge(projeto.statusBadge),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fallbackImage() {
    return Image.asset(
      'assets/images/project_placeholder1.png',
      height: 280,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }

  Widget _buildBadge(String label, Color color, IconData? icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, color: color, size: 14),
          if (icon != null) const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BadgeStatus status) {
    String label = 'Em Andamento';
    if (status == BadgeStatus.concluido) label = 'Concluído';
    if (status == BadgeStatus.cancelado) label = 'Cancelado';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ProjectProgressCard extends StatelessWidget {
  final double progresso;
  const _ProjectProgressCard({required this.progresso});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progresso',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                '${(progresso * 100).toInt()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progresso,
              backgroundColor: const Color(0xFFE0E0E0),
              color: AppColors.primary,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

// 🔥 Seção da Equipe com Riverpod Otimizado (Só ela recarrega quando a equipe muda!)
class _TeamSection extends ConsumerWidget {
  final String projetoId;
  const _TeamSection({required this.projetoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colaboradoresAsync = ref.watch(
      colaboradoresAtivosProjetoProvider(projetoId),
    );

    return colaboradoresAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (err, stack) => const Text(
        'Erro ao carregar equipe',
        style: TextStyle(color: Colors.red),
      ),
      data: (listaColaboradores) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            // 🔥 Mudei de "end" para "start" para remover o buraco em branco acima das fotos!
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...listaColaboradores.map((item) {
                final usuario = item['usuario'] as Map<String, dynamic>;
                return TeamMemberItem(
                  name: usuario['nome'] ?? 'Sem nome',
                  role: usuario['cargo'] ?? 'Colaborador',
                  imagePath: usuario['foto_url'] ?? 'assets/images/user.png',
                );
              }),

              Padding(
                padding: EdgeInsets.only(bottom: 16, left: 0, right: 0),
                child: GestureDetector(
                  onTap: () {
                    showDiaviconModal(
                      context: context,
                      title: 'Edite a equipe',
                      body: EditTeamBody(projetoId: projetoId),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 🔥 Seção de Estruturas com Riverpod Otimizado
class _StructuresSection extends ConsumerWidget {
  final ProjetoModel projeto;
  final String projetoId;
  const _StructuresSection({required this.projeto, required this.projetoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estruturasAsync = ref.watch(projetoEstruturasProvider(projetoId));

    return Column(
      children: [
        Row(
          children: [
            const Text(
              'Estruturas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(child: CompactSearchBar()),
            const SizedBox(width: 6),
            CompactButton(
              text: 'Incluir',
              onPressed: () {
                showDiaviconModal(
                  context: context,
                  title: 'Incluir Estrutura',
                  height: MediaQuery.of(context).size.height * 0.80,
                  isScrollable: false,
                  margin: const EdgeInsets.fromLTRB(18, 150, 18, 0),
                  centerTitle: true,
                  body: IncluirEstruturaBody(
                    clienteNome: projeto.clienteNome ?? 'Cliente não definido',
                    empresaNome: projeto.empresaNome,
                    projetoId: projetoId,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: estruturasAsync.when(
            data: (estruturas) {
              if (estruturas.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 50,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Projeto sem estruturas incluídas',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: estruturas.length,
                itemBuilder: (context, index) {
                  return StructureCard(
                    estrutura: estruturas[index],
                    projetoId: projetoId,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Erro: $err')),
          ),
        ),
      ],
    );
  }
}
