import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:diavicon/features/empresa/providers/empresa_provider.dart';
import 'package:diavicon/features/empresa/screens/empresa_profile_screen.dart';
import 'package:diavicon/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class PerfilDrawer extends ConsumerStatefulWidget {
  const PerfilDrawer({super.key});

  @override
  ConsumerState<PerfilDrawer> createState() => _PerfilDrawerState();
}

class _PerfilDrawerState extends ConsumerState<PerfilDrawer> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<String?>(
      currentUserProvider.select((usuario) => usuario?.empresaId),
      (_, empresaId) => _sincronizarEmpresa(empresaId),
      fireImmediately: true,
    );
  }

  Future<void> _sincronizarEmpresa(String? empresaId) async {
    final empresaAtual = ref.read(empresaAtualProvider);

    if (empresaId == null || empresaId.isEmpty) {
      if (empresaAtual != null) {
        ref.read(empresaAtualProvider.notifier).state = null;
      }
      return;
    }

    if (empresaAtual?.id == empresaId) return;

    if (empresaAtual != null) {
      ref.read(empresaAtualProvider.notifier).state = null;
    }

    try {
      await ref
          .read(empresaControllerProvider.notifier)
          .carregarEmpresaAtual(empresaId);
    } catch (_) {
      // O drawer continua utilizável; a empresa pode ser recarregada no próximo evento.
    }
  }

  Future<void> _navegarPara(BuildContext context, String nomeRota) async {
    final router = GoRouter.of(context);

    await Navigator.of(context).maybePop();
    router.pushNamed(nomeRota);
  }

  Future<void> _fazerLogout(BuildContext context) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await Navigator.of(context).maybePop();
      await ref.read(authControllerProvider.notifier).logout();
      router.goNamed(AppRouteNames.login);
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Erro ao sair da conta')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(currentUserProvider);
    final empresa = ref.watch(empresaAtualProvider);

    final nome = usuario == null
        ? 'Carregando...'
        : '${usuario.nome ?? ''} ${usuario.sobrenome ?? ''}'.trim();

    final cargo = usuario?.cargo ?? usuario?.tituloPrincipal ?? '';
    final fotoUrl = usuario?.fotoUrl;
    final titulo = usuario?.tituloPrincipal ?? '';
    final empresaNome = empresa?.nome ?? '';
    final empresaId = usuario?.empresaId ?? '';

    return Drawer(
      backgroundColor: const Color(0xFFEFEFEF),
      child: SafeArea(
        child: Column(
          children: [
            // --- HEADER: FOTO E DADOS DO USUÁRIO ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.orange, width: 2),
                      image: DecorationImage(
                        image: fotoUrl != null && fotoUrl.isNotEmpty
                            ? NetworkImage(fotoUrl)
                            : const AssetImage('assets/images/user.png')
                                  as ImageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          style: GoogleFonts.lato(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cargo,
                          style: GoogleFonts.lato(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          empresaNome,
                          style: GoogleFonts.lato(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          titulo,
                          style: GoogleFonts.lato(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- BOTÕES SUPERIORES: GASTOS, RDO, EMPRESA ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TopButton(
                    icon: Icons.monetization_on_outlined,
                    label: 'Gastos',
                    isDisabled: true,
                    onTap: () {},
                  ),
                  _TopButton(
                    icon: Icons.assignment_outlined,
                    label: 'RDO',
                    isDisabled: true,
                    onTap: () {},
                  ),
                  _TopButton(
                    icon: Icons.business_outlined,
                    label: 'Empresa',
                    isDisabled: false,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              EmpresaProfileScreen(empresaId: empresaId),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Divider(
              height: 1,
              color: Colors.black12,
              indent: 20,
              endIndent: 20,
            ),

            // --- DESTAQUES ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                children: [
                  Text(
                    'Destaques',
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3E3E3D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ListTileCard(
                    icon: Icons.person_outline,
                    label: 'Perfil',
                    onTap: () =>
                        _navegarPara(context, AppRouteNames.profileData),
                  ),
                  _ListTileCard(
                    icon: Icons.manage_accounts_outlined,
                    label: 'Minha Conta',
                    onTap: () =>
                        _navegarPara(context, AppRouteNames.profileAccount),
                  ),
                  _ListTileCard(
                    icon: Icons.notifications_none,
                    label: 'Notificações',
                    onTap: () => _navegarPara(
                      context,
                      AppRouteNames.profileNotifications,
                    ),
                  ),
                  _ListTileCard(
                    icon: Icons.shield_outlined,
                    label: 'Privacidade',
                    onTap: () =>
                        _navegarPara(context, AppRouteNames.profilePrivacy),
                  ),

                  const SizedBox(height: 32),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: 16),

                  // --- OUTROS ---
                  Text(
                    'Outros',
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3E3E3D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ListTileCard(
                    icon: Icons.help_outline,
                    label: 'Central de Ajuda',
                    onTap: () =>
                        _navegarPara(context, AppRouteNames.profileHelp),
                  ),
                  _ListTileCard(
                    icon: Icons.logout,
                    label: 'Sair',
                    isLogout: true,
                    onTap: () => _fazerLogout(context),
                  ),
                ],
              ),
            ),

            // --- RODAPÉ ---
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DIAVICON',
                    style: GoogleFonts.lato(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF686868),
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'Versão 1.0',
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: const Color(0xFF8F8F8F),
                    ),
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

// Widget auxiliar para os botões quadrados do topo
class _TopButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDisabled;

  const _TopButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (isDisabled) {
          DiaviconAlerts.show(
            context,
            'Em desenvolvimento',
            'Esta funcionalidade estará disponível em breve!',
            isAviso: true,
          );
        } else {
          onTap();
        }
      },
      child: Opacity(
        opacity: isDisabled ? 0.4 : 1.0, // 👇 Deixa opaco
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF686868), size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.lato(
                  fontSize: 12,
                  color: const Color(0xFF686868),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget auxiliar para as opções em lista brancas
class _ListTileCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLogout;

  const _ListTileCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isLogout ? Colors.red : const Color(0xFF3E3E3D),
        ),
        title: Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isLogout ? Colors.red : const Color(0xFF3E3E3D),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Color(0xFF686868),
        ),
        onTap: onTap,
        dense: true,
      ),
    );
  }
}
