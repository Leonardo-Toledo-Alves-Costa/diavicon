import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/custom_appbar.dart';
import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:diavicon/features/notificacoes/controllers/notificacoes_controller.dart';
import 'package:diavicon/features/notificacoes/providers/notificacoes_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef ResponderConviteProjetoCallback =
    Future<void> Function({
      required String conviteId,
      required String projetoId,
      required String notificacaoId,
      required bool aceitar,
    });

typedef ResponderConviteClienteCallback =
    Future<void> Function({
      required String projetoId,
      required String notificacaoId,
      required bool aceitar,
    });

class NotificacoesScreen extends ConsumerWidget {
  const NotificacoesScreen({
    super.key,
    required this.onResponderConviteProjeto,
    required this.onResponderConviteCliente,
  });

  final ResponderConviteProjetoCallback onResponderConviteProjeto;
  final ResponderConviteClienteCallback onResponderConviteCliente;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Usando o novo StreamProvider
    final notificacoesAsync = ref.watch(notificacoesProvider);
    final controller = ref.read(notificacoesControllerProvider);

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: CustomAppBar(
        title: 'Notificações',
        showBackButton: true,
        showMenuButton: false,
        showNotificationButton: false,
      ),
      body: notificacoesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) =>
            Center(child: Text('Erro ao carregar notificações: $err')),
        data: (listaCompleta) {
          if (listaCompleta.isEmpty) {
            return _buildEmptyState();
          }

          // Separa as lidas das não lidas
          final naoLidas = listaCompleta
              .where((n) => n['lida'] != true)
              .toList();
          final lidas = listaCompleta.where((n) => n['lida'] == true).toList();

          return ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
            children: [
              if (naoLidas.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 12),
                  child: Text(
                    'Novas',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                ...naoLidas.map(
                  (notificacao) => _buildCard(
                    context,
                    notificacao,
                    controller,
                    isNova: true,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (lidas.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 12, top: 12),
                  child: Text(
                    'Anteriores',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ...lidas.map(
                  (notificacao) => _buildCard(
                    context,
                    notificacao,
                    controller,
                    isNova: false,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Sua caixa de entrada está limpa!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    Map<String, dynamic> notificacao,
    NotificacoesController controller, {
    required bool isNova,
  }) {
    final tipo = notificacao['tipo']?.toString();
    final dados = _asMap(notificacao['dados_extras']);
    final notificationId = _nonEmptyString(notificacao['id']);
    final invitationId = _nonEmptyString(dados['convite_id']);
    final projectId = _nonEmptyString(dados['projeto_id']);
    final isProjectInvite = tipo == 'convite_projeto';
    final isClientInvite = tipo == 'convite_cliente';
    final canRespondToProject =
        isProjectInvite &&
        notificationId != null &&
        invitationId != null &&
        projectId != null;
    final canRespondToClient =
        isClientInvite && notificationId != null && projectId != null;
    final hasInviteAction = canRespondToProject || canRespondToClient;

    //  InkWell para marcar como lida ao clicar (se for um aviso simples)
    return InkWell(
      onTap: isNova && !hasInviteAction && notificationId != null
          ? () => controller.marcarComoLida(notificationId)
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isNova
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 Bolinha Laranja para as Novas
            if (isNova)
              Container(
                margin: const EdgeInsets.only(top: 18, right: 12),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),

            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.inputBorder,
              backgroundImage:
                  (dados['foto_url'] != null &&
                      dados['foto_url'].toString().startsWith('http'))
                  ? StorageNetworkImage(dados['foto_url'].toString())
                  : null,
              child:
                  (dados['foto_url'] == null ||
                      !dados['foto_url'].toString().startsWith('http'))
                  ? Icon(
                      (isProjectInvite || isClientInvite)
                          ? Icons.business
                          : Icons.notifications,
                      color: Colors.grey,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: isNova
                            ? AppColors.textDark
                            : Colors.grey.shade700,
                        fontSize: 14,
                        fontFamily: 'Lato',
                      ),
                      children: [
                        TextSpan(
                          text:
                              '${notificacao['titulo']?.toString() ?? 'Notificação'} ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: notificacao['mensagem']?.toString() ?? '',
                        ),
                      ],
                    ),
                  ),

                  // 🔥 Renderização específica para os convites de projeto
                  if (canRespondToProject && isNova) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () async {
                            try {
                              await onResponderConviteProjeto(
                                conviteId: invitationId,
                                projetoId: projectId,
                                notificacaoId: notificationId,
                                aceitar: false,
                              );
                              if (!context.mounted) return;
                              DiaviconAlerts.show(
                                context,
                                'Convite Recusado',
                                'O convite foi removido.',
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              DiaviconAlerts.show(
                                context,
                                'Erro',
                                'Não foi possível recusar: $e',
                                isErro: true,
                              );
                            }
                          },
                          child: const Text(
                            'Recusar',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () async {
                            try {
                              await onResponderConviteProjeto(
                                conviteId: invitationId,
                                projetoId: projectId,
                                notificacaoId: notificationId,
                                aceitar: true,
                              );
                              if (!context.mounted) return;
                              DiaviconAlerts.show(
                                context,
                                'Sucesso!',
                                'Você agora colabora no projeto.',
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              DiaviconAlerts.show(
                                context,
                                'Erro',
                                'Falha ao aceitar convite: $e',
                                isErro: true,
                              );
                            }
                          },
                          child: const Text(
                            'Aceitar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (canRespondToClient && isNova) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () async {
                            try {
                              await onResponderConviteCliente(
                                projetoId: projectId,
                                notificacaoId: notificationId,
                                aceitar: false,
                              );
                              if (!context.mounted) return;
                              DiaviconAlerts.show(
                                context,
                                'Convite recusado',
                                'O convite de cliente foi removido.',
                              );
                            } catch (error) {
                              if (!context.mounted) return;
                              DiaviconAlerts.show(
                                context,
                                'Erro',
                                'Não foi possível recusar: $error',
                                isErro: true,
                              );
                            }
                          },
                          child: const Text(
                            'Recusar',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () async {
                            try {
                              await onResponderConviteCliente(
                                projetoId: projectId,
                                notificacaoId: notificationId,
                                aceitar: true,
                              );
                              if (!context.mounted) return;
                              DiaviconAlerts.show(
                                context,
                                'Sucesso!',
                                'Sua empresa agora é cliente do projeto.',
                              );
                            } catch (error) {
                              if (!context.mounted) return;
                              DiaviconAlerts.show(
                                context,
                                'Erro',
                                'Falha ao aceitar convite: $error',
                                isErro: true,
                              );
                            }
                          },
                          child: const Text(
                            'Aceitar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static String? _nonEmptyString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
