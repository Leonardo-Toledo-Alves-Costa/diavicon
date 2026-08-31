import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_empty_state.dart'; // 🔥 Import do seu novo componente global
import '../providers/empresas_projeto_provider.dart'; 

class TrocarGestoraBody extends ConsumerWidget {
  final String projetoId;
  final String empresaGestoraAtualId;
  final Function(String novaEmpresaId, String nome) onSelecionada;

  const TrocarGestoraBody({
    super.key,
    required this.projetoId,
    required this.empresaGestoraAtualId,
    required this.onSelecionada,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empresasAsync = ref.watch(projetoEmpresasIntegrantesProvider(projetoId));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tratamento dos dados vindos do Supabase
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
            // Filtra removendo a gestora atual da lista de opções
            final opcoes = lista.where((e) => e['id'] != empresaGestoraAtualId).toList();

            // 🔥 CORRIGIDO: Agora chamando o componente global unificado de Empty State!
            if (opcoes.isEmpty) {
              return const CustomEmptyState(
                text: 'Nenhuma empresa encontrada',
              );
            }

            // Renderiza a lista se houver empresas parceiras elegíveis
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: opcoes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final empresa = opcoes[index];
                return InkWell(
                  onTap: () => onSelecionada(empresa['id'], empresa['nome']),
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
                            Text(
                              empresa['nome'],
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                            ),
                            Text(
                              '${empresa['cidade'] ?? 'Cidade'} - ${empresa['estado'] ?? 'UF'}',
                              style: const TextStyle(fontSize: 13, color: AppColors.greyMedium),
                            ),
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

        // Footer estático de aviso
        const Text(
          'A empresa selecionada receberá a gestão dos dados e as permissões de gestor do projeto.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.greyMedium,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}