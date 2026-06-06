import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../equipe/providers/equipe_provider.dart'; 
import '../../equipe/widgets/team_edit_item.dart';

import '../../equipe/screens/convidar_funcionario_screen.dart';

class EditTeamBody extends ConsumerWidget {
  final String projetoId;
  
  const EditTeamBody({super.key, required this.projetoId});

  // --- 🔥 AVISO FLUTUANTE MODERNO (OVERLAY) ---
  void _mostrarAvisoFlutuante(BuildContext context, String titulo, String mensagem, {bool isErro = false, bool isAviso = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    bool isRemoved = false;

    void remover() {
      if (!isRemoved) {
        overlayEntry.remove();
        isRemoved = true;
      }
    }

    final Color corPrincipal = isErro ? Colors.red : (isAviso ? Colors.orange.shade800 : Colors.green);
    final IconData icone = isErro ? Icons.error_outline : (isAviso ? Icons.warning_amber_rounded : Icons.check_circle_outline);

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20, 
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            tween: Tween<double>(begin: -100, end: 0), 
            builder: (context, double value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                ],
                border: Border(left: BorderSide(color: corPrincipal, width: 4)),
              ),
              child: Row(
                children: [
                  Icon(icone, color: corPrincipal, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(mensagem, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: remover,
                    child: Text('Entendi', style: TextStyle(color: corPrincipal, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 4), remover);
  }

  Future<void> _confirmarRemocao(BuildContext context, WidgetRef ref, String usuarioId, String nomeColaborador) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Remover Colaborador', 
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)
          ),
          content: Text('Tem certeza que deseja remover $nomeColaborador da equipe deste projeto? Ele perderá o acesso aos dados atuais.'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remover', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmar == true && context.mounted) {
      try {
        await ref.read(equipeControllerProvider).atualizarStatusColaborador(
          projetoId: projetoId, 
          usuarioId: usuarioId,
          ativo: false,
        );
        if (context.mounted) {
          _mostrarAvisoFlutuante(context, 'Sucesso!', 'Colaborador removido da equipe.');
        }
      } catch (e) {
        if (context.mounted) {
          _mostrarAvisoFlutuante(context, 'Ops!', 'Erro ao remover: $e', isErro: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gestaoAsync = ref.watch(gestaoProjetoProvider(projetoId));
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: gestaoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('Erro ao validar permissões: $err')),
        data: (gestaoData) {
          final empresaGestoraId = gestaoData?['empresa_gestora_id'];
          final empresaLogadaId = gestaoData?['empresa_usuario_logado_id'];
          
          final bool isViewerGestor = empresaGestoraId != null && empresaGestoraId == empresaLogadaId;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [


              // ── LISTA ROLÁVEL DE FUNCIONÁRIOS ──
              Flexible( 
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Consumer(
                    builder: (context, ref, child) {
                      final colaboradoresAsync = ref.watch(colaboradoresProjetoProvider(projetoId));
                      
                      return colaboradoresAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                        ),
                        error: (err, stack) => Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Center(child: Text('Erro ao carregar equipe: $err')),
                        ),
                        data: (listaColaboradores) {
                          if (listaColaboradores.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  'Nenhum colaborador vinculado a este projeto.',
                                  style: TextStyle(color: AppColors.hintText),
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: [
                              ...listaColaboradores.map((item) {
                                final usuario = item['usuario'] as Map<String, dynamic>? ?? {};
                                final empresaIdColaborador = item['empresa_id'] as String?;
                                
                                final String nomeCompleto = '${usuario['nome'] ?? ''} ${usuario['sobrenome'] ?? ''}'.trim();
                                final String cargo = usuario['cargo'] ?? 'Colaborador';
                                final String tituloPrincipal = usuario['titulo_principal'] ?? '';
                                
                                final bool isAtivo = item['ativo'] ?? false;
                                final bool isUserGestor = empresaGestoraId != null && empresaGestoraId == empresaIdColaborador;
                                final bool isCurrentCompany = empresaLogadaId != null && empresaLogadaId == empresaIdColaborador;

                                return TeamEditItem(
                                  name: nomeCompleto,
                                  role: cargo, 
                                  subRole: tituloPrincipal, 
                                  isSelected: isAtivo, 
                                  isUserGestor: isUserGestor,
                                  isViewerGestor: isViewerGestor,
                                  onChanged: (val) {
                                    if (isCurrentCompany) {
                                      _mostrarAvisoFlutuante(context, 'Ação Bloqueada', 'Você não pode alterar o seu próprio nível de acesso.', isAviso: true);
                                      return;
                                    }

                                    if (!isViewerGestor) {
                                      _mostrarAvisoFlutuante(context, 'Acesso Negado', 'Apenas a empresa gestora pode editar os acessos.', isAviso: true);
                                      return;
                                    }

                                    if (val == false) {
                                      _confirmarRemocao(context, ref, usuario['id'], nomeCompleto);
                                    } 
                                  },
                                  onToggleGestor: (val) async {
                                    if (!isViewerGestor) return;

                                    if (val && empresaIdColaborador != null) {
                                      try {
                                        await ref.read(equipeControllerProvider).alterarGestorEquipe(
                                            projetoId: projetoId, 
                                            usuarioId: usuario['id'], 
                                            isGestor: val, 
                                           );
                                        if (context.mounted) {
                                          _mostrarAvisoFlutuante(context, 'Gestão Alterada', 'A nova empresa gestora foi definida.', isAviso: false);
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          _mostrarAvisoFlutuante(context, 'Ops!', 'Erro ao alterar gestão: $e', isErro: true);
                                        }
                                      }
                                    }
                                  },
                                  onRemove: () {
                                    if (isCurrentCompany) {
                                      _mostrarAvisoFlutuante(context, 'Ação Bloqueada', 'Você não pode se remover do projeto. Solicite à gestora.', isAviso: true);
                                      return;
                                    }

                                    if (!isViewerGestor) {
                                      _mostrarAvisoFlutuante(context, 'Acesso Negado', 'Apenas a empresa gestora pode remover membros.', isAviso: true);
                                      return;
                                    }

                                    _confirmarRemocao(context, ref, usuario['id'], nomeCompleto);
                                  },
                                );
                              }),
                            ],
                          );
                        },
                      );
                    }
                  ),
                ),
              ),
              
              const SizedBox(height: 16),

              // ── BOTÃO FIXO NO RODAPÉ ──
              OutlinedButton.icon(
                icon: const Icon(Icons.person_add_alt_1, color: AppColors.primary),
                label: const Text(
                  'Convidar novo funcionário',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context); // Fecha o modal atual antes de abrir a próxima tela
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ConvidarFuncionarioScreen(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}