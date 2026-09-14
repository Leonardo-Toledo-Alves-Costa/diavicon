import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/diavicon_modal.dart';
import '../../../../core/widgets/compact_button.dart';
import '../../../../core/widgets/custom_empty_state.dart';
import '../../../../core/widgets/diavicon_alerts.dart';
import '../../empresa/providers/empresa_profile_provider.dart';
import '../../projetos/providers/empresas_projeto_provider.dart';
import '../providers/estrutura_provider.dart';

/// Mostra a empresa proprietária da estrutura (quem detém a gestão e o
/// compartilhamento dos dados) e, se a empresa logada for a proprietária
/// atual, permite transferir a propriedade pra outra empresa que também
/// participe do mesmo projeto (gestora, colaboradora aceita ou cliente).
class ProprietarioVinculoSection extends ConsumerWidget {
  final String estruturaId;
  final String projetoId;
  final String? proprietariaId;
  final bool podeTransferir;
  final void Function(String novaEmpresaId) onTransferido;

  const ProprietarioVinculoSection({
    super.key,
    required this.estruturaId,
    required this.projetoId,
    required this.proprietariaId,
    required this.podeTransferir,
    required this.onTransferido,
  });

  Future<void> _abrirSelecaoNovaProprietaria(BuildContext context, WidgetRef ref) async {
    showDiaviconModal(
      context: context,
      title: 'Transferir propriedade',
      centerTitle: false,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.center,
      body: Consumer(
        builder: (context, ref, _) {
          final empresasAsync = ref.watch(projetoEmpresasIntegrantesProvider(projetoId));

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              empresasAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                ),
                error: (err, stack) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Erro ao carregar: $err', style: const TextStyle(color: AppColors.error)),
                ),
                data: (lista) {
                  final opcoes = lista.where((e) => e['id'] != proprietariaId).toList();

                  if (opcoes.isEmpty) {
                    return const CustomEmptyState(text: 'Nenhuma outra empresa do projeto encontrada');
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: opcoes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final empresa = opcoes[index];
                      return InkWell(
                        onTap: () => _confirmarTransferencia(context, ref, empresa['id'], empresa['nome']),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.white,
                              backgroundImage: (empresa['foto_url'] != null && empresa['foto_url'].toString().isNotEmpty)
                                  ? NetworkImage(empresa['foto_url'])
                                  : const AssetImage('assets/images/empresa.png') as ImageProvider,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(empresa['nome'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                                  Text('${empresa['cidade'] ?? 'Cidade'} - ${empresa['estado'] ?? 'UF'}', style: const TextStyle(fontSize: 13, color: AppColors.greyMedium)),
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
              const SizedBox(height: 32),
              const Text(
                'A empresa selecionada passará a ser a proprietária da estrutura, responsável pela gestão e compartilhamento dos dados.',
                style: TextStyle(fontSize: 13, color: AppColors.greyMedium, height: 1.4),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmarTransferencia(BuildContext context, WidgetRef ref, String novaEmpresaId, String nomeEmpresa) {
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (ctxConfirma) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar transferência', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        content: Text('Tem certeza que deseja transferir a propriedade desta estrutura para $nomeEmpresa? Sua empresa perderá a gestão dos dados dela.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctxConfirma),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.greyMedium)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctxConfirma);
              try {
                await ref.read(estruturaRepositoryProvider).transferirPropriedade(
                      estruturaId: estruturaId,
                      novaProprietariaId: novaEmpresaId,
                    );
                onTransferido(novaEmpresaId);
                if (context.mounted) {
                  DiaviconAlerts.show(context, 'Sucesso!', 'Propriedade transferida para $nomeEmpresa.');
                }
              } catch (e) {
                if (context.mounted) {
                  DiaviconAlerts.show(context, 'Erro na transferência', e.toString().replaceAll('Exception: ', ''), isErro: true);
                }
              }
            },
            child: const Text('Transferir', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empresaAsync = proprietariaId != null ? ref.watch(empresaDetalheProvider(proprietariaId!)) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: AppColors.inputBorder, thickness: 1),
        const SizedBox(height: 16),
        const Text('Proprietário da estrutura', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 4),
        const Text('O proprietário da estrutura é responsável pela gestão e compartilhamento dos dados', style: TextStyle(fontSize: 12, color: AppColors.hintText)),
        const SizedBox(height: 16),

        if (empresaAsync == null)
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Icon(Icons.business, color: AppColors.greyMedium),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Não definido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.greyMedium)),
              ),
            ],
          )
        else
          empresaAsync.when(
            data: (empresa) {
              return Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    backgroundImage: (empresa.fotoUrl != null && empresa.fotoUrl!.isNotEmpty) ? NetworkImage(empresa.fotoUrl!) : null,
                    child: (empresa.fotoUrl == null || empresa.fotoUrl!.isEmpty) ? const Icon(Icons.business, color: AppColors.greyMedium) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(empresa.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  if (podeTransferir)
                    CompactButton(text: 'Transferir', onPressed: () => _abrirSelecaoNovaProprietaria(context, ref)),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (err, stack) => const Text('Erro ao carregar dados do proprietário', style: TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 16),
        const Divider(color: AppColors.inputBorder, thickness: 1),
      ],
    );
  }
}
