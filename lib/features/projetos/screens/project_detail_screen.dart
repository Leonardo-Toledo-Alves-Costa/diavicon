import 'package:diavicon/features/projetos/providers/projetos_provider.dart';
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
import '../widgets/team_member_item.dart';
import '../../estrutura/widgets/structure_card.dart';
import '../widgets/edit_team_body.dart';
import '../models/projeto_model.dart';
import 'package:diavicon/features/estrutura/widgets/incluir_estrutura_body.dart';
import 'package:diavicon/features/estrutura/providers/estrutura_provider.dart';

// Certifique-se de importar o provider da equipe
import '../providers/equipe_provider.dart'; 

class ProjectDetailScreen extends ConsumerWidget {
  final String projetoId;

  const ProjectDetailScreen({super.key, required this.projetoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    // OBTENÇÃO DOS DADOS DO SUPABASE
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
        //Clicou fora, o teclado fecha e o foco some
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

            //PERMITE QUE A TELA SE AJUSTE AO TECLADO
            resizeToAvoidBottomInset: true,

            // BARRA DE NAVEGAÇÃO DO SISTEMA
            bottomNavigationBar: Container(
              color: Colors.white,
              child: const SafeArea(top: false, child: SizedBox.shrink()),
            ),

            // MENU LATERAL (DRAWER)
            endDrawer: MenuDrawerAppBar(
              title: 'Menu do\nProjeto',
              items: [
                DiaviconMenuItem(
                  icon: Icons.info_outline,
                  label: 'Informações',
                  onTap: () => Navigator.pop(context),
                ),
                DiaviconMenuItem(
                  icon: Icons.assignment_outlined,
                  label: 'RDO',
                  onTap: () {},
                ),
                DiaviconMenuItem(
                  icon: Icons.business_outlined,
                  label: 'Empresas',
                  onTap: () {},
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
              //PADDING DINÂMICO QUE RESPONDE AO TECLADO
              child: Padding(
                padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? 20 : 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER COM IMAGEM
                    _buildHeader(projeto),

                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // TÍTULO DO PROJETO
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

                          _buildProgressCard(projeto.progresso),
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
                          _buildTeamSection(context, ref),
                          const SizedBox(height: 32),

                          // SEÇÃO DE ESTRUTURAS
                          _buildStructuresSection(context, ref, projeto),
            
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

  // --- MÉTODOS AUXILIARES ---

  Widget _buildHeader(ProjetoModel projeto) {
    return Stack(
      children: [
        projeto.imageUrl.startsWith('http')
            ? Image.network(
                projeto.imageUrl,
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
                // Fallback: Se o link estiver quebrado ou sem internet, mostra a imagem padrão
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'assets/images/project_placeholder1.png',
                  height: 280,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            : Image.asset(
                projeto.imageUrl,
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
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

  Widget _buildProgressCard(double value) {
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
                '${(value * 100).toInt()}%',
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
              value: value,
              backgroundColor: const Color(0xFFE0E0E0),
              color: AppColors.primary,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSection(BuildContext context, WidgetRef ref) {
    // 🔥 AQUI ESTÁ A MÁGICA: Agora escutamos o provider filtrado!
    final colaboradoresAsync = ref.watch(colaboradoresAtivosProjetoProvider(projetoId));

    return colaboradoresAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (err, stack) => const Text(
        'Erro ao carregar equipe',
        style: TextStyle(color: Colors.red),
      ),
      data: (listaColaboradores) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Mapeia APENAS os utilizadores ATIVOS reais vindos do Supabase
              ...listaColaboradores.map((item) {
                final usuario = item['usuario'] as Map<String, dynamic>;
                final nome = usuario['nome'] ?? 'Sem nome';
                final cargo = usuario['cargo'] ?? 'Colaborador';
                final fotoUrl = usuario['foto_url'] ?? 'assets/images/user.png';

                return TeamMemberItem(
                  name: nome,
                  role: cargo,
                  imagePath: fotoUrl,
                );
              }),
              
              // Botão Laranja de Editar/Adicionar (+) continua sempre aqui
              Padding(
                padding: const EdgeInsets.only(bottom: 25, left: 8),
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

  Widget _buildStructuresSection(BuildContext context, WidgetRef ref, ProjetoModel projeto) {
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
                  margin:  EdgeInsets.fromLTRB(18, 150, 18, 0),
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
                  return StructureCard(estrutura: estruturas[index],
                  projetoId: projetoId,);
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