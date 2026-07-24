import 'package:flutter/material.dart';

class VisualizarRelatorioScreen extends StatefulWidget {
  final String? urlConteudo;

  const VisualizarRelatorioScreen({super.key, this.urlConteudo});

  @override
  State<VisualizarRelatorioScreen> createState() => _VisualizarRelatorioScreenState();
}

class _VisualizarRelatorioScreenState extends State<VisualizarRelatorioScreen> {
  static const Color corLaranja = Color(0xFFF5A623);
  static const Color corFundo = Color(0xFFE6E7E8);
  static const Color corTexto = Color(0xFF3A3A3A);

  @override
  Widget build(BuildContext context) {
    final bool temConteudo = widget.urlConteudo != null && widget.urlConteudo!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBar(context),
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: _buildBotaoBaixar(temConteudo),
          ),
          Expanded(
            child: temConteudo ? _buildConteudo() : _buildEstadoVazio(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: corLaranja,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 16,
        left: 8,
        right: 16,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'Projeto',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Relatórios',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoBaixar(bool temConteudo) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: temConteudo ? _baixarRelatorio : null,
        icon: const Icon(Icons.download, size: 18, color: Colors.white),
        label: const Text(
          'Baixar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: corLaranja,
          disabledBackgroundColor: corLaranja.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildEstadoVazio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade400, width: 1.5),
              ),
              child: Icon(Icons.priority_high, color: Colors.grey.shade400, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              'Add o conteúdo do relatório\ncomo pré-visualização',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConteudo() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: corFundo,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Pré-visualização do relatório',
            style: TextStyle(color: corTexto),
          ),
        ),
      ),
    );
  }

  void _baixarRelatorio() {}
}