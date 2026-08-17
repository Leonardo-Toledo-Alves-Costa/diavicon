import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../estrutura/providers/estruturas_dropdown_provider.dart';
import '../widgets/tabela_expansion_widget.dart';

class EditarTabelasScreen extends ConsumerWidget {
  const EditarTabelasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Streams de Estruturas
    final conjuntosAsync = ref.watch(conjuntosEstruturaisProvider);
    final utilizacoesAsync = ref.watch(utilizacoesEstruturaProvider);
    final tiposAsync = ref.watch(tiposEstruturaProvider);
    final tipologiasAsync = ref.watch(tipologiasEstruturaProvider);

    // Streams de Elementos
    final tiposElementoAsync = ref.watch(tiposElementoStreamProvider);
    final tipologiasElementoAsync = ref.watch(tipologiasElementoStreamProvider);
    final revestimentosElementoAsync = ref.watch(
      revestimentosElementoStreamProvider,
    );

    // Streams de Locais
    final tipologiasLocalAsync = ref.watch(tipologiasLocalStreamProvider);
    final condicoesLocalAsync = ref.watch(condicoesLocalStreamProvider);

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
              'Organize os dados e opções da sua empresa',
              style: TextStyle(fontSize: 14, color: AppColors.hintText),
            ),
            const SizedBox(height: 24),

            // ================== SEÇÃO: ESTRUTURAS ==================
            _buildSecaoTitulo('Estruturas', Icons.apartment),
            BuildTabelaExpansion(
              titulo: 'Conjuntos Estruturais',
              nomeTabela: 'conjuntos_estruturais',
              itemsAsync: conjuntosAsync,
            ),
            const SizedBox(height: 12),
            BuildTabelaExpansion(
              titulo: 'Utilização da Estrutura',
              nomeTabela: 'utilizacoes_estrutura',
              itemsAsync: utilizacoesAsync,
            ),
            const SizedBox(height: 12),
            BuildTabelaExpansion(
              titulo: 'Tipo da Estrutura',
              nomeTabela: 'tipos_estrutura',
              itemsAsync: tiposAsync,
            ),
            const SizedBox(height: 12),
            BuildTabelaExpansion(
              titulo: 'Tipologia Estrutural',
              nomeTabela: 'tipologias_estrutura',
              itemsAsync: tipologiasAsync,
            ),
            const SizedBox(height: 32),

            // ================== SEÇÃO: ELEMENTOS ==================
            _buildSecaoTitulo('Elementos', Icons.foundation),
            BuildTabelaExpansion(
              titulo: 'Tipos de Elemento',
              nomeTabela: 'tipos_elemento',
              itemsAsync: tiposElementoAsync,
            ),
            const SizedBox(height: 12),
            BuildTabelaExpansion(
              titulo: 'Tipologias do Elemento',
              nomeTabela: 'tipologias_elemento',
              itemsAsync: tipologiasElementoAsync,
            ),
            const SizedBox(height: 12),
            BuildTabelaExpansion(
              titulo: 'Revestimentos',
              nomeTabela: 'revestimentos_elemento',
              itemsAsync: revestimentosElementoAsync,
            ),
            const SizedBox(height: 32),

            // ================== SEÇÃO: LOCAIS ==================
            _buildSecaoTitulo('Locais e Exposição', Icons.place_outlined),
            BuildTabelaExpansion(
              titulo: 'Tipologias do Local',
              nomeTabela: 'tipologias_local',
              itemsAsync: tipologiasLocalAsync,
            ),
            const SizedBox(height: 12),
            BuildTabelaExpansion(
              titulo: 'Condições de Exposição',
              nomeTabela: 'condicoes_local',
              itemsAsync: condicoesLocalAsync,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Pequeno componente para gerar os títulos das seções
  Widget _buildSecaoTitulo(String titulo, IconData icone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icone, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            titulo,
            style: GoogleFonts.lato(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
