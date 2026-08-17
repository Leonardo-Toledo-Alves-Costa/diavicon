import 'package:flutter/material.dart';
import '../widgets/novo_relatorio_modal.dart';
import 'detalhe_relatorio_screen.dart';

enum StatusRelatorio { aprovado, postado }

class RelatorioItem {
  final String titulo;
  final String estruturas;
  final String autora;
  final String data;
  final StatusRelatorio status;

  const RelatorioItem({
    required this.titulo,
    required this.estruturas,
    required this.autora,
    required this.data,
    required this.status,
  });
}

class CentralRelatoriosScreen extends StatefulWidget {
  const CentralRelatoriosScreen({super.key});

  @override
  State<CentralRelatoriosScreen> createState() => _CentralRelatoriosScreenState();
}

class _CentralRelatoriosScreenState extends State<CentralRelatoriosScreen> {
  static const Color corLaranja = Color(0xFFF5A623);
  static const Color corFundo = Color(0xFFE6E7E8);
  static const Color corTextoTitulo = Color(0xFF1A1A1A);
  static const Color corTextoSub = Color(0xFF8A8A8A);

  final TextEditingController _buscaController = TextEditingController();

  final List<RelatorioItem> _relatorios = const [
    RelatorioItem(
      titulo: 'Relatório de Inspeção Parcial',
      estruturas: 'Und. Britador; Decantador',
      autora: 'Inspecione Engenharia',
      data: '22/08/2026',
      status: StatusRelatorio.aprovado,
    ),
    RelatorioItem(
      titulo: 'Relatório de Ensaios de Durab...',
      estruturas: 'Und. Britador',
      autora: 'Inspecione Engenharia',
      data: '15/08/2026',
      status: StatusRelatorio.postado,
    ),
    RelatorioItem(
      titulo: 'Relatório de Ensaios Final',
      estruturas: 'Und. Britador; Decantador +2',
      autora: 'Inspecione Engenharia',
      data: '28/08/2026',
      status: StatusRelatorio.aprovado,
    ),
  ];

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: corFundo,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Central de relatórios',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: corTextoTitulo,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBuscaField(),
                  const SizedBox(height: 16),
                  _buildBotaoNovoRelatorio(context),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _relatorios.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final relatorio = _relatorios[index];
                        return _buildRelatorioCard(context, relatorio);
                      },
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _buildBuscaField() {
    return TextField(
      controller: _buscaController,
      decoration: InputDecoration(
        hintText: 'Busque por estrutura',
        hintStyle: const TextStyle(color: corTextoSub, fontSize: 14),
        prefixIcon: const Icon(Icons.search, color: corTextoSub),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildBotaoNovoRelatorio(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ElevatedButton.icon(
        onPressed: () => _abrirModalNovoRelatorio(context),
        icon: const Icon(Icons.add, size: 18, color: Colors.white),
        label: const Text(
          'Novo Relatório',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: corLaranja,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildRelatorioCard(BuildContext context, RelatorioItem relatorio) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalheRelatorioScreen(relatorio: relatorio),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: corLaranja.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description, color: corLaranja),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    relatorio.titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: corTextoTitulo,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    relatorio.estruturas,
                    style: const TextStyle(fontSize: 12, color: corTextoSub),
                  ),
                  Text(
                    relatorio.autora,
                    style: const TextStyle(fontSize: 12, color: corTextoSub),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    relatorio.data,
                    style: const TextStyle(fontSize: 12, color: corTextoSub),
                  ),
                ],
              ),
            ),
            _buildStatusBadge(relatorio.status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(StatusRelatorio status) {
    final bool aprovado = status == StatusRelatorio.aprovado;
    final Color corFundoBadge = aprovado ? const Color(0xFFDFF5E3) : const Color(0xFFFCE7CC);
    final Color corTextoBadge = aprovado ? const Color(0xFF3AA655) : corLaranja;
    final String texto = aprovado ? 'Aprovado' : 'Postado';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: corFundoBadge,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: corTextoBadge,
        ),
      ),
    );
  }

  void _abrirModalNovoRelatorio(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const NovoRelatorioModal(),
    );
  }
}