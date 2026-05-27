import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/compact_button.dart';
import '../../projetos/providers/projetos_provider.dart';

class ProprietarioVinculoSection extends ConsumerWidget {
  final String projetoId;

  const ProprietarioVinculoSection({super.key, required this.projetoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projetoAsync = ref.watch(projectDetailProvider(projetoId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: AppColors.inputBorder, thickness: 1),
        const SizedBox(height: 16),
        const Text('Proprietário da estrutura', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 4),
        const Text('O proprietário da estrutura é responsável pela gestão e compartilhamento dos dados', style: TextStyle(fontSize: 12, color: AppColors.hintText)),
        const SizedBox(height: 16),
        
        projetoAsync.when(
          data: (projeto) {
            String statusTexto = 'Não Vinculado';
            Color corFundo = const Color(0xFFFFEBEE); 
            Color corTexto = Colors.red;
            bool mostrarBotaoVincular = true;

            if (projeto.statusVinculoCliente == 'vinculado') {
              statusTexto = 'Vinculado';
              corFundo = const Color(0xFFE8F5E9); 
              corTexto = Colors.green;
              mostrarBotaoVincular = false;
            } else if (projeto.statusVinculoCliente == 'pendente') {
              statusTexto = 'Pendente';
              corFundo = const Color(0xFFFFF3E0); 
              corTexto = AppColors.primary;
              mostrarBotaoVincular = false;
            } else if (projeto.statusVinculoCliente == 'proprio') {
              statusTexto = 'Próprio';
              corFundo = const Color(0xFFE3F2FD); 
              corTexto = Colors.blue;
              mostrarBotaoVincular = false;
            }

            return Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  backgroundImage: AssetImage('assets/images/empresa.png'),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(projeto.clienteNome ?? 'Cliente não definido', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: corFundo, borderRadius: BorderRadius.circular(12)),
                      child: Text(statusTexto, style: TextStyle(color: corTexto, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const Spacer(),
                if (mostrarBotaoVincular)
                  CompactButton(text: 'Vincular', onPressed: () {}),
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