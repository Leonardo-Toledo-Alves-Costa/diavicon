import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
// Certifique-se de colocar o caminho correto para o seu provider:
import '../providers/empresa_provider.dart'; 

class EmpresaTeamSection extends ConsumerWidget {
  final String empresaId; 

  const EmpresaTeamSection({
    super.key,
    required this.empresaId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colaboradoresAsync = ref.watch(colaboradoresEmpresaProvider(empresaId));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), 
            blurRadius: 20, 
            offset: const Offset(0, 10)
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Colaboradores', 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)
          ),
          const SizedBox(height: 16),
          
          colaboradoresAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (err, stack) => const Text(
              'Erro ao carregar equipe',
              style: TextStyle(color: Colors.red),
            ),
            data: (listaColaboradores) {
              if (listaColaboradores.isEmpty) {
                return const Text(
                  'Nenhum colaborador encontrado.',
                  style: TextStyle(color: AppColors.hintText, fontSize: 12),
                );
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: listaColaboradores.map((usuario) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: _buildAvatar(
                        usuario['nome'] ?? 'Sem nome',
                        usuario['cargo'] ?? 'Colaborador',
                        usuario['foto_url'],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, String role, String? fotoUrl) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24, 
          backgroundColor: Colors.grey[200], 
          backgroundImage: fotoUrl != null 
              ? StorageNetworkImage(fotoUrl) 
              : const AssetImage('assets/images/user.png') as ImageProvider,
        ),
        const SizedBox(height: 8),
        Text(
          name, 
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark)
        ),
        Text(
          role, 
          style: const TextStyle(fontSize: 10, color: AppColors.hintText)
        ),
      ],
    );
  }
}