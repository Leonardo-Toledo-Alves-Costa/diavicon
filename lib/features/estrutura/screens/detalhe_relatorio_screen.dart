import 'package:flutter/material.dart';
import 'central_relatorios_screen.dart';
import 'visualizar_relatorio_screen.dart';

class DetalheRelatorioScreen extends StatefulWidget {
  final RelatorioItem relatorio;

  const DetalheRelatorioScreen({super.key, required this.relatorio});

  @override
  State<DetalheRelatorioScreen> createState() => _DetalheRelatorioScreenState();
}

class _DetalheRelatorioScreenState extends State<DetalheRelatorioScreen> {
  static const Color corLaranja = Color(0xFFF5A623);
  static const Color corFundo = Color(0xFFE6E7E8);
  static const Color corTextoTitulo = Color(0xFF1A1A1A);
  static const Color corTextoSub = Color(0xFF8A8A8A);

  late StatusRelatorio _statusSelecionado;

  final List<Map<String, String>> _empresasEnvolvidas = const [
    {'nome': 'P&D Engenharia', 'local': 'Brumadinho - MG'},
    {'nome': 'Housing Engenharia', 'local': 'Belo Horizonte - MG'},
    {'nome': 'HMCM Engenharia', 'local': 'São Paulo - SP'},
  ];

  final List<Map<String, String>> _estruturasAnalisadas = const [
    {'nome': 'Und. Britador', 'local': 'Setorial Norte'},
    {'nome': 'Decantador', 'local': 'Setorial Sul'},
  ];

  @override
  void initState() {
    super.initState();
    _statusSelecionado = widget.relatorio.status;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: corFundo,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCabecalhoRelatorio(),
                  const SizedBox(height: 20),
                  _buildLinhaStatus(),
                  const SizedBox(height: 24),
                  _buildSecaoAutora(),
                  const SizedBox(height: 24),
                  _buildSecaoLista(
                    titulo: 'Empresas Envolvidas',
                    itens: _empresasEnvolvidas,
                    icone: Icons.apartment,
                  ),
                  const SizedBox(height: 24),
                  _buildSecaoLista(
                    titulo: 'Estruturas Analisadas',
                    itens: _estruturasAnalisadas,
                    icone: Icons.location_city,
                  ),
                  const SizedBox(height: 32),
                  _buildBotaoApagar(context),
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
        ],
      ),
    );
  }

  Widget _buildCabecalhoRelatorio() {
    return Row(
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
                widget.relatorio.titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: corTextoTitulo,
                ),
              ),
              Text(
                widget.relatorio.data,
                style: const TextStyle(fontSize: 12, color: corTextoSub),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLinhaStatus() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Status',
                style: TextStyle(fontSize: 13, color: corTextoSub),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD0D0D0)),
                  color: Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<StatusRelatorio>(
                    value: _statusSelecionado,
                    isExpanded: true,
                    items: StatusRelatorio.values.map((status) {
                      final texto = status == StatusRelatorio.aprovado ? 'Aprovado' : 'Postado';
                      return DropdownMenuItem(value: status, child: Text(texto));
                    }).toList(),
                    onChanged: (valor) {
                      setState(() {
                        _statusSelecionado = valor!;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VisualizarRelatorioScreen(),
              ),
            );
          },
          icon: const Icon(Icons.visibility, size: 18, color: Colors.white),
          label: const Text('Visualizar', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: corLaranja,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoAutora() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Autora',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: corTextoTitulo),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFEFEFEF),
              child: Icon(Icons.shield, size: 16, color: corLaranja),
            ),
            const SizedBox(width: 10),
            Text(
              widget.relatorio.autora,
              style: const TextStyle(fontSize: 14, color: corTextoTitulo),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecaoLista({
    required String titulo,
    required List<Map<String, String>> itens,
    required IconData icone,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: corTextoTitulo),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: itens.map((item) {
              return ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFEFEFEF),
                  child: Icon(icone, size: 16, color: corLaranja),
                ),
                title: Text(
                  item['nome'] ?? '',
                  style: const TextStyle(fontSize: 14, color: corTextoTitulo),
                ),
                subtitle: Text(
                  item['local'] ?? '',
                  style: const TextStyle(fontSize: 12, color: corTextoSub),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBotaoApagar(BuildContext context) {
    return Center(
      child: OutlinedButton(
        onPressed: () => _confirmarExclusao(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        ),
        child: const Text('Apagar'),
      ),
    );
  }

  void _confirmarExclusao(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Apagar relatório'),
        content: const Text('Tem certeza que deseja apagar este relatório?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Apagar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}