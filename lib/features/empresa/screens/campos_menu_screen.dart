import 'package:flutter/material.dart';

import '../../../core/widgets/custom_appbar.dart';
import 'anomalias_screen.dart';
import 'campo_itens_screen.dart';
import 'conjuntos_estruturais_screen.dart';

class CamposMenuScreen extends StatelessWidget {
  final String empresaId; 

  const CamposMenuScreen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(
        title: 'Empresa',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            Text('Empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Painel', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Campos personalizáveis', style: TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho da Seção
            
            const SizedBox(height: 20),

            // GRUPO ESTRUTURA
            _buildCategoryTitle('ESTRUTURA'),
            _buildMenuItem(context, 'Conjuntos estruturais', 'conjuntos_estruturais', Icons.workspaces_outline),
            _buildMenuItem(context, 'Tipos de estrutura', 'tipos_estrutura', Icons.apartment),
            _buildMenuItem(context, 'Tipologias de estrutura', 'tipologias_estrutura', Icons.account_tree_outlined),
            _buildMenuItem(context, 'Utilização da estrutura', 'utilizacoes_estrutura', Icons.business_center_outlined),
            const SizedBox(height: 24),

            // GRUPO LOCAL
            _buildCategoryTitle('LOCAL'),
            _buildMenuItem(context, 'Condições do local', 'condicoes_local', Icons.wb_sunny_outlined),
            _buildMenuItem(context, 'Tipologia do local', 'tipologias_local', Icons.place_outlined),
            const SizedBox(height: 24),

            // GRUPO ELEMENTO
            _buildCategoryTitle('ELEMENTO'),
            _buildMenuItem(context, 'Tipos de elemento', 'tipos_elemento', Icons.foundation),
            _buildMenuItem(context, 'Tipologias de elemento', 'tipologias_elemento', Icons.account_tree),
            _buildMenuItem(context, 'Sistemas', 'sistemas_habitacionais', Icons.home_work_outlined),
            _buildMenuItem(context, 'Revestimento de elemento', 'revestimentos_elemento', Icons.layers_outlined),
            const SizedBox(height: 24),

            //ANOMALIAS
            _buildCategoryTitle('INSPEÇÃO VISUAL E GUT'),
            _buildMenuItem(context, 'Anomalias e manifestações patológicas', 'anomalias', Icons.report_outlined),
            
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, String tableName, IconData icon) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            // Conjuntos têm tela própria: além do nome, mostram quantas
            // estruturas cada um agrupa e só deixam apagar o que está vazio.
            builder: (_) => tableName == 'conjuntos_estruturais'
                ? const ConjuntosEstruturaisScreen()
                : tableName == 'anomalias'
                ? AnomaliasScreen(empresaId: empresaId)
                : CampoItensScreen(
                    empresaId: empresaId,
                    tableName: tableName,
                    displayTitle: title,
                  ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child:Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[400]),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: TextStyle(fontSize: 15, color: Colors.grey[800]))),
            const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}