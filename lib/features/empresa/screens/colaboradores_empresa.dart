import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/custom_appbar.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/colaboradores_provider.dart';
import '../../equipe/screens/convidar_funcionario_screen.dart';

class ColaboradoresEmpresaScreen extends ConsumerWidget {
  final String empresaId;

  const ColaboradoresEmpresaScreen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (empresaId: empresaId);
    final equipeAsync = ref.watch(equipeEmpresaProvider(params));
    final limiteAsync = ref.watch(limitePlanoProvider(params));
    
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(
        title: 'Painel',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            Text('Empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Painel', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Colaboradores', style: TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ),
      ),
      body: equipeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (equipe) {
          final int usuariosConsumindoPlano = equipe.where((e) => e.status != 'inativo').length;
          
          final currentUserData = equipe.where((u) => u.id == currentUserId).firstOrNull;
          final bool amIAdmin = currentUserData?.isAdmin == true || currentUserData?.isMaster == true;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                limiteAsync.when(
                  data: (permitidos) {
                    final bool isPlanoEsgotado = permitidos > 0 && usuariosConsumindoPlano >= permitidos;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DashboardCard(cadastrados: usuariosConsumindoPlano, permitidos: permitidos),
                        const SizedBox(height: 24),

                        if (amIAdmin)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPlanoEsgotado ? Colors.grey.shade400 : AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.white),
                            label: Text(
                              isPlanoEsgotado ? 'limite do plano atingido' : 'convidar colaborador', 
                              style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                            ),
                            onPressed: isPlanoEsgotado ? null : () {
                              Navigator.push(
                                context, 
                                MaterialPageRoute(
                                  builder: (_) => ConvidarFuncionarioScreen(projetoId: '') // Ajuste o projetoId se necessário
                                )
                              );
                            },
                          ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                
                const SizedBox(height: 24),
                
                TextField(
                  decoration: InputDecoration(
                    hintText: 'buscar colaborador',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                
                const SizedBox(height: 20),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: equipe.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.black12),
                  itemBuilder: (context, index) {
                    final user = equipe[index];
                    return _ColaboradorItem(
                      user: user,
                      amIAdmin: amIAdmin,
                      onOptionsTap: () => _mostrarOpcoesColaborador(context, ref, empresaId, user),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmarExclusao(BuildContext context, WidgetRef ref, String empresaId, ColaboradorModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Colaborador', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Tem certeza que deseja excluir ${user.nome} definitivamente da sua empresa? Essa ação não pode ser desfeita.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              ref.read(equipeActionProvider.notifier).deletarColaborador(empresaId, user);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _mostrarOpcoesColaborador(BuildContext context, WidgetRef ref, String empresaId, ColaboradorModel user) {
    final bool isInativo = user.status == 'inativo';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isInativo)
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined, color: Colors.black87),
                    title: Text(user.isAdmin ? 'Remover admin' : 'Tornar admin', style: GoogleFonts.lato(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(equipeActionProvider.notifier).alternarAdmin(empresaId, user);
                    },
                  ),
                
                ListTile(
                  leading: Icon(
                    isInativo ? Icons.person_add_outlined : Icons.person_remove_outlined, 
                    color: isInativo ? Colors.green : Colors.orange.shade800
                  ),
                  title: Text(
                    isInativo ? 'Restaurar acesso' : 'Suspender acesso', 
                    style: GoogleFonts.lato(color: isInativo ? Colors.green : Colors.orange.shade800, fontWeight: FontWeight.w600)
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isInativo) {
                      ref.read(equipeActionProvider.notifier).reativarAcesso(empresaId, user);
                    } else {
                      ref.read(equipeActionProvider.notifier).removerAcesso(empresaId, user);
                    }
                  },
                ),

                // Nova opção: Excluir definitivamente se já estiver inativo
                if (isInativo)
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Excluir definitivamente', style: GoogleFonts.lato(color: Colors.red, fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmarExclusao(context, ref, empresaId, user);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ========================================================
// COMPONENTES MANTIDOS DA TELA
// ========================================================

class _DashboardCard extends StatelessWidget {
  final int cadastrados;
  final int permitidos;

  const _DashboardCard({required this.cadastrados, required this.permitidos});

  @override
  Widget build(BuildContext context) {
    final double progresso = permitidos == 0 ? 0 : (cadastrados / permitidos).clamp(0.0, 1.0);
    final Color progressColor = cadastrados >= permitidos && permitidos > 0 ? Colors.redAccent : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          SizedBox(
            height: 60,
            width: 60,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progresso,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  strokeCap: StrokeCap.round,
                ),
                Center(child: Text('$cadastrados/${permitidos == 0 ? '∞' : permitidos}', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Colaboradores ativos', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF333333))),
                const SizedBox(height: 4),
                Text('$cadastrados de ${permitidos == 0 ? 'ilimitados' : permitidos} permitidos no seu plano atual', style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    // TODO: Ação para tela de Upgrade
                  },
                  child: Text('ver planos >', style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColaboradorItem extends StatelessWidget {
  final ColaboradorModel user;
  final bool amIAdmin;
  final VoidCallback onOptionsTap;

  const _ColaboradorItem({required this.user, required this.amIAdmin, required this.onOptionsTap});

  @override
  Widget build(BuildContext context) {
    final bool isInativo = user.status == 'inativo';

    return Opacity(
      opacity: isInativo ? 0.45 : 1.0, 
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: isInativo ? Colors.grey.shade300 : const Color(0xFFE0F2F1),
              backgroundImage: user.fotoUrl != null ? NetworkImage(user.fotoUrl!) : null,
              child: user.fotoUrl == null
                  ? Text(
                      user.nome.substring(0, user.nome.length >= 2 ? 2 : 1).toUpperCase(), 
                      style: GoogleFonts.lato(
                        color: isInativo ? Colors.grey.shade600 : const Color(0xFF00695C), 
                        fontWeight: FontWeight.bold
                      )
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.nome, 
                          style: GoogleFonts.lato(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold, 
                            color: isInativo ? Colors.grey.shade700 : const Color(0xFF333333)
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.isMaster) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.workspace_premium, color: isInativo ? Colors.grey : AppColors.primary, size: 16),
                      ]
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(user.cargo, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (user.isAdmin || user.isMaster) ...[
                        _Badge(
                          text: 'admin', 
                          bgColor: isInativo ? Colors.grey.shade400 : const Color(0xFF333333), 
                          textColor: Colors.white
                        ),
                        const SizedBox(width: 8),
                      ],
                      _Badge(
                        text: user.status, 
                        bgColor: _obterCorFundoStatus(user.status), 
                        textColor: _obterCorTextoStatus(user.status),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!user.isMaster && amIAdmin)
              IconButton(icon: const Icon(Icons.more_vert, color: Colors.black54), onPressed: onOptionsTap),
          ],
        ),
      ),
    );
  }

  Color _obterCorFundoStatus(String status) {
    if (status == 'ativo') return const Color(0xFFE0F2F1); 
    if (status == 'convidado') return const Color(0xFFFFF3E0); 
    return const Color(0xFFEEEEEE); 
  }

  Color _obterCorTextoStatus(String status) {
    if (status == 'ativo') return const Color(0xFF00695C); 
    if (status == 'convidado') return const Color(0xFFE65100); 
    return Colors.grey.shade700; 
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color textColor;

  const _Badge({required this.text, required this.bgColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
    );
  }
}