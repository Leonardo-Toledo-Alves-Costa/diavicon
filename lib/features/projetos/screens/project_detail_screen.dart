import 'package:diavicon/features/empresa/providers/projetos_provider.dart';
import 'package:diavicon/features/estrutura/screens/estrutura_home.dart';
import 'package:diavicon/features/estrutura/screens/estrutura_informacao_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/menu_drawer_app_bar.dart';
import '../../../core/widgets/diavicon_menu_item.dart';
import '../../../core/widgets/compact_search_bar.dart';
import '../../../core/widgets/compact_button.dart';
import '../../../core/utils/diavicon_modal.dart';
import '../../../core/widgets/status_badge.dart';
import '../widgets/team_member_item.dart';
import '../widgets/structure_card.dart';
import '../widgets/team_edit_body.dart';
import '../models/projeto_model.dart';
import 'package:diavicon/features/estrutura/widgets/incluir_estrutura_body.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final String projetoId;

  const ProjectDetailScreen({super.key, required this.projetoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      data: (projeto) => Scaffold(
        backgroundColor: Colors.white,
        // Efeito de sobreposição: o corpo começa no topo absoluto da tela
        extendBodyBehindAppBar: true,

        //  (DRAWER)
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

        // APPBAR PADRÃO (TÍTULO DA FEATURE)
        resizeToAvoidBottomInset: false,
        appBar: const CustomAppBar(title: 'Projetos', showBackButton: true),

        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER COM IMAGEM (Cobre o topo atrás da AppBar)
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
                    _buildTeamSection(context),
                    const SizedBox(height: 32),

                    _buildStructuresSection(context),

                    // Espaço para não bater no BottomAppBar da MainScreen
                    const SizedBox(height: 140),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MÉTODOS AUXILIARES

  Widget _buildHeader(ProjetoModel projeto) {
    return Stack(
      children: [
        Image.asset(
          projeto.imageUrl,
          height: 280, // Altura suficiente para passar por baixo da AppBar
          width: double.infinity,
          fit: BoxFit.cover,
        ),
        // Overlay gradiente para garantir que os botões brancos da AppBar sejam lidos
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

  Widget _buildTeamSection(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const TeamMemberItem(
            name: 'Fulano',
            role: 'Engenheiro',
            imagePath: 'assets/images/user.png',
          ),
          const TeamMemberItem(
            name: 'Ciclana',
            role: 'Estagiária',
            imagePath: 'assets/images/user.png',
          ),
          const TeamMemberItem(
            name: 'Fulano',
            role: 'Engenheiro',
            imagePath: 'assets/images/user.png',
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 25, left: 8),
            child: GestureDetector(
              onTap: () {
                showDiaviconModal(
                  context: context,
                  title: 'Edite a equipe',
                  body: const EditTeamBody(),
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
  }

  Widget _buildStructuresSection(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Text(
              'Estruturas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: CompactSearchBar(hintText: 'Nome da estrutura'),
            ),
            const SizedBox(width: 8),
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
                  body: IncluirEstruturaBody(clienteNome: '',empresaNome: '',estruturas: [],),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [StructureCard(), StructureCard()],
          ),
        ),
      ],
    );
  }
}

//estrutura para o mock de estruturas
class EstruturaMock {
  final String id;
  final String? nome;
  final String? tipo;
  final String? descricao;
  final String? imageUrl;

  EstruturaMock({
    required this.id,
    this.nome,
    this.tipo,
    this.descricao,
    this.imageUrl,
  });
}
