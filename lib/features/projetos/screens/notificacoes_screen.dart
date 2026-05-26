import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/notificacoes_provider.dart';

class NotificacoesScreen extends ConsumerWidget {
  const NotificacoesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificacoesAsync = ref.watch(notificacoesProvider);
    final controller = ref.read(notificacoesControllerProvider);
    
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Notificações',
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontFamily: 'Lato'),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: notificacoesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('Erro ao carregar notificações: $err')),
        data: (listaConvites) {
          if (listaConvites.isEmpty) {
            return SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Sua caixa de entrada está limpa!',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: listaConvites.length,
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
            itemBuilder: (context, index) {
              final convite = listaConvites[index];
              final projeto = convite['projeto'] as Map<String, dynamic>;
              final remetente = convite['remetente'] as Map<String, dynamic>?;
              
              final nomeProjeto = projeto['nome'] ?? 'Projeto Sem Nome';
              final fotoProjeto = projeto['image_url'] ?? '';
              final nomeRemetente = remetente != null 
                  ? '${remetente['nome']} ${remetente['sobrenome']}' 
                  : 'Um administrador';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.inputBorder,
                      backgroundImage: fotoProjeto.startsWith('http') ? NetworkImage(fotoProjeto) : null,
                      child: !fotoProjeto.startsWith('http') 
                          ? const Icon(Icons.business, color: Colors.grey) 
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontFamily: 'Lato'),
                              children: [
                                TextSpan(text: nomeRemetente, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const TextSpan(text: ' convidou sua empresa para colaborar no projeto '),
                                TextSpan(text: nomeProjeto, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  try {
                                    await controller.recusarConvite(convite['id']);
                                    if (!context.mounted) return;
                                    DiaviconAlerts.show(context, 'Convite Recusado', 'O convite foi removido.');
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    DiaviconAlerts.show(context, 'Erro', 'Não foi possível recusar: $e', isErro: true);
                                  }
                                },
                                child: const Text('Recusar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                ),
                                onPressed: () async {
                                  try {
                                    await controller.aceitarConvite(
                                      conviteId: convite['id'],
                                      projetoId: convite['projeto_id'],
                                    );
                                    if (!context.mounted) return;
                                    DiaviconAlerts.show(context, 'Sucesso!', 'Você agora colabora no projeto $nomeProjeto.');
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    DiaviconAlerts.show(context, 'Erro', 'Falha ao aceitar convite: $e', isErro: true);
                                  }
                                },
                                child: const Text('Aceitar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}