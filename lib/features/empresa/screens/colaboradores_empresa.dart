import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/custom_appbar.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/colaboradores_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../equipe/screens/convidar_funcionario_screen.dart';
import '../widgets/papeis_colaboradores_dialog.dart';

/// Página de planos e preços no site da Diavicon.
final _paginaDePlanos = Uri.parse('https://diavicon.com.br/home/plataforma/planos-e-precos/');

Future<void> _abrirPaginaDePlanos() async {
  await launchUrl(_paginaDePlanos, mode: LaunchMode.externalApplication);
}

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
      appBar: CustomAppBar(
        title: 'Painel',
        showBackButton: true,
        showMenuButton: false,
        // Explica gestor, admin, acesso ao painel e colaborador — é o que
        // decide quais opções aparecem no menu de cada pessoa.
        extraActions: [
          IconButton(
            tooltip: 'Entenda os papéis',
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => mostrarPapeisColaboradores(context),
          ),
        ],
        titleWidget: const Column(
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
          final bool amIMaster = currentUserData?.isMaster == true;
          final bool amIAdmin = currentUserData?.isAdmin == true || amIMaster;

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
                                  builder: (_) => const ConvidarFuncionarioScreen() // Convite de empresa, sem projeto
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
                      amIMaster: amIMaster,
                      souEu: user.id == currentUserId,
                      onOptionsTap: () => _mostrarOpcoesColaborador(context, ref, empresaId, user, amIMaster: amIMaster),
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

  // Verde das mensagens de confirmação.
  static const _verdeSucesso = Color(0xFF2E7D32);

  /// Roda uma ação de colaborador e sempre responde na tela.
  ///
  /// Antes, suspender ou restaurar acesso era disparado sem `await`: a tela
  /// não confirmava nada e um erro no servidor passava calado, parecendo que
  /// o botão não fazia coisa nenhuma.
  static Future<void> _comRetorno(
    ScaffoldMessengerState messenger,
    String sucesso,
    Future<void> Function() acao,
  ) async {
    try {
      await acao();
      messenger.showSnackBar(SnackBar(content: Text(sucesso), backgroundColor: _verdeSucesso));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.error,
      ));
    }
  }

  void _confirmarExclusao(BuildContext context, WidgetRef ref, String empresaId, ColaboradorModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Excluir Colaborador', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Excluir ${user.nome} apaga a conta e todo o acesso dela, e não dá para desfazer. '
          'O e-mail volta a ficar livre para um novo convite.\n\n'
          'Se a ideia é só tirar o acesso por um tempo, use "Suspender acesso".',
        ),
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
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              _comRetorno(
                messenger,
                '${user.nome} foi excluído da empresa.',
                () => ref.read(equipeActionProvider.notifier).deletarColaborador(empresaId, user),
              );
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmarTornarGestor(BuildContext context, WidgetRef ref, String empresaId, ColaboradorModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Tornar Gestor da empresa', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Tem certeza que deseja tornar ${user.nome} Gestor da empresa? '
          'Gestores têm acesso total ao Painel da empresa e podem tornar outros colaboradores Gestores também.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              _comRetorno(
                messenger,
                '${user.nome} agora é Gestor da empresa.',
                () => ref.read(equipeActionProvider.notifier).tornarGestor(empresaId, user),
              );
            },
            child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Níveis de cargo — os mesmos do cadastro da empresa
  /// (empresa_cadastro_screen.dart).
  static const _niveis = ['Júnior', 'Pleno', 'Sênior', 'Gerente', 'Diretor', 'CEO'];

  /// Janela do Gestor para mudar cargo e nível de alguém.
  void _editarCargoNivel(BuildContext context, WidgetRef ref, String empresaId, ColaboradorModel user) {
    final cargoCtrl = TextEditingController(text: user.cargo == 'Colaborador' ? '' : user.cargo);
    // Um nível antigo fora da lista continua aparecendo como opção, para não
    // sumir sem ninguém pedir.
    final opcoes = [..._niveis, if (user.nivel != null && !_niveis.contains(user.nivel)) user.nivel!];
    String? nivel = user.nivel;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Cargo e nível de ${user.nome}', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: cargoCtrl,
                  autofocus: true,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Cargo', hintText: 'Ex.: Engenheiro civil'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: nivel,
                  decoration: const InputDecoration(labelText: 'Nível'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Sem nível')),
                    for (final n in opcoes) DropdownMenuItem<String?>(value: n, child: Text(n)),
                  ],
                  onChanged: (v) => setDialog(() => nivel = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                final cargo = cargoCtrl.text;
                Navigator.pop(ctx);
                _comRetorno(
                  messenger,
                  'Cargo e nível de ${user.nome} atualizados.',
                  () => ref.read(equipeActionProvider.notifier).editarCargo(empresaId, user, cargo: cargo, nivel: nivel),
                );
              },
              child: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ).whenComplete(cargoCtrl.dispose);
  }

  void _confirmarRemoverGestor(BuildContext context, WidgetRef ref, String empresaId, ColaboradorModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Remover papel de Gestor', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          '${user.nome} deixa de ser Gestor da empresa e passa a ser um administrador comum: '
          'perde a permissão de conceder gestão e de alterar outros Gestores.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              _comRetorno(
                messenger,
                '${user.nome} não é mais Gestor da empresa.',
                () => ref.read(equipeActionProvider.notifier).removerGestor(empresaId, user),
              );
            },
            child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _mostrarOpcoesColaborador(BuildContext context, WidgetRef ref, String empresaId, ColaboradorModel user, {required bool amIMaster}) {
    final bool isInativo = user.status == 'inativo';
    final bool podeVirarGestor = amIMaster && !isInativo && user.isAdmin && !user.isMaster;

    showModalBottomSheet(
      context: context,
      // Branco de propósito: sem isto o tema pinta a folha com um tom
      // alaranjado tirado da cor da marca.
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cargo e nível: só o Gestor edita.
                if (amIMaster)
                  ListTile(
                    leading: const Icon(Icons.badge_outlined, color: Colors.black87),
                    title: Text('Editar cargo e nível', style: GoogleFonts.lato(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _editarCargoNivel(context, ref, empresaId, user);
                    },
                  ),

                // O Gestor já é admin por definição: a opção não aparece para ele.
                if (!isInativo && !user.isMaster)
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined, color: Colors.black87),
                    title: Text(user.isAdmin ? 'Remover admin' : 'Tornar admin', style: GoogleFonts.lato(fontWeight: FontWeight.w600)),
                    onTap: () {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      _comRetorno(
                        messenger,
                        user.isAdmin
                            ? '${user.nome} não é mais admin.'
                            : '${user.nome} agora é admin.',
                        () => ref.read(equipeActionProvider.notifier).alternarAdmin(empresaId, user),
                      );
                    },
                  ),

                // O Gestor enxerga o painel por definição.
                if (!isInativo && !user.isMaster)
                  ListTile(
                    leading: Icon(user.podeVisualizarEmpresa ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.black87),
                    title: Text(
                      user.podeVisualizarEmpresa ? 'Remover acesso ao painel' : 'Permitir visualizar painel',
                      style: GoogleFonts.lato(fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      _comRetorno(
                        messenger,
                        user.podeVisualizarEmpresa
                            ? '${user.nome} não vê mais o painel da empresa.'
                            : '${user.nome} já pode ver o painel da empresa.',
                        () => ref.read(equipeActionProvider.notifier).alternarVisualizacaoPainel(empresaId, user),
                      );
                    },
                  ),

                if (podeVirarGestor)
                  ListTile(
                    leading: Icon(Icons.workspace_premium_outlined, color: AppColors.primary),
                    title: Text('Tornar Gestor da empresa', style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: AppColors.primary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmarTornarGestor(context, ref, empresaId, user);
                    },
                  ),

                // Só outro Gestor tira a gestão de alguém.
                if (amIMaster && user.isMaster)
                  ListTile(
                    leading: const Icon(Icons.workspace_premium_outlined, color: Colors.black87),
                    title: Text('Remover papel de Gestor', style: GoogleFonts.lato(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmarRemoverGestor(context, ref, empresaId, user);
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
                    final messenger = ScaffoldMessenger.of(context);
                    final notifier = ref.read(equipeActionProvider.notifier);
                    Navigator.pop(ctx);
                    _comRetorno(
                      messenger,
                      isInativo
                          ? '${user.nome} voltou a ter acesso.'
                          : 'O acesso de ${user.nome} foi suspenso.',
                      () => isInativo
                          ? notifier.reativarAcesso(empresaId, user)
                          : notifier.removerAcesso(empresaId, user),
                    );
                  },
                ),

                // Vale para ativo ou suspenso: quem administra confirma na
                // janela seguinte.
                if (!user.isMaster || amIMaster)
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
                InkWell(
                  onTap: _abrirPaginaDePlanos,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      'ver planos >',
                      style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
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
  /// Quem olha é Gestor (pode mexer até em outro Gestor).
  final bool amIMaster;

  /// A linha é a do próprio usuário — ninguém altera o próprio acesso aqui.
  final bool souEu;

  final ColaboradorModel user;
  final bool amIAdmin;
  final VoidCallback onOptionsTap;

  const _ColaboradorItem({
    required this.user,
    required this.amIAdmin,
    required this.amIMaster,
    required this.souEu,
    required this.onOptionsTap,
  });

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
              backgroundImage: user.fotoUrl != null ? StorageNetworkImage(user.fotoUrl!) : null,
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
                        Tooltip(
                          message: 'Gestor da empresa',
                          child: Icon(Icons.workspace_premium, color: isInativo ? Colors.grey : AppColors.primary, size: 16),
                        ),
                      ],
                      // O Gestor enxerga o painel por definição; os demais só
                      // quando receberam essa permissão.
                      if (user.isMaster || user.podeVisualizarEmpresa) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Vê o painel da empresa',
                          child: Icon(
                            Icons.visibility_outlined,
                            color: isInativo ? Colors.grey : const Color(0xFF00695C),
                            size: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.nivel == null ? user.cargo : '${user.cargo} · ${user.nivel}',
                    style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade600),
                  ),
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
            if (amIAdmin && !souEu && (!user.isMaster || amIMaster))
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