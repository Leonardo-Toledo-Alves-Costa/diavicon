import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../estrutura/providers/estruturas_dropdown_provider.dart';
import '../widgets/tabela_expansion_widget.dart';

class EditarTabelasScreen extends ConsumerWidget {
  const EditarTabelasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conjuntosAsync = ref.watch(conjuntosEstruturaisProvider);
    final utilizacoesAsync = ref.watch(utilizacoesEstruturaProvider);
    final tiposAsync = ref.watch(tiposEstruturaProvider);
    final tipologiasAsync = ref.watch(tipologiasEstruturaProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const CustomAppBar(
        showNotificationButton: false,
        showMenuButton: false,
        title: 'Gerenciar Tabelas',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Organize os dados estruturais da sua empresa',
              style: TextStyle(fontSize: 14, color: AppColors.hintText),
            ),
            const SizedBox(height: 24),

            // CONJUNTOS ESTRUTURAIS
            BuildTabelaExpansion(
              titulo: 'Conjuntos Estruturais',
              nomeTabela: 'conjuntos_estruturais',
              itemsAsync: conjuntosAsync,
            ),
            const SizedBox(height: 16),

            // UTILIZAÇÃO DA ESTRUTURA
            BuildTabelaExpansion(
              titulo: 'Utilização da Estrutura',
              nomeTabela: 'utilizacoes_estrutura',
              itemsAsync: utilizacoesAsync,
            ),
            const SizedBox(height: 16),

            // TIPO DA ESTRUTURA
            BuildTabelaExpansion(
              titulo: 'Tipo da Estrutura',
              nomeTabela: 'tipos_estrutura',
              itemsAsync: tiposAsync,
            ),
            const SizedBox(height: 16),

            // TIPOLOGIA ESTRUTURAL
            BuildTabelaExpansion(
              titulo: 'Tipologia Estrutural',
              nomeTabela: 'tipologias_estrutura',
              itemsAsync: tipologiasAsync,
            ),
          ],
        ),
      ),
    );
  }
}
