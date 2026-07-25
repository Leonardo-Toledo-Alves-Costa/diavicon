import 'package:flutter/material.dart';
import 'rdo_lista_screen.dart';

class EmpresaRdo {
  final String nome;
  final String local;
  final String ultimaAtualizacao;

  const EmpresaRdo({
    required this.nome,
    required this.local,
    required this.ultimaAtualizacao,
  });
}

class RdoEmpresasScreen extends StatefulWidget {
  const RdoEmpresasScreen({super.key});

  @override
  State<RdoEmpresasScreen> createState() => _RdoEmpresasScreenState();
}

class _RdoEmpresasScreenState extends State<RdoEmpresasScreen> {
  static const Color corLaranja = Color(0xFFF5A623);
  static const Color corFundo = Color(0xFFE6E7E8);
  static const Color corTextoTitulo = Color(0xFF1A1A1A);
  static const Color corTextoSub = Color(0xFF8A8A8A);

  final TextEditingController _buscaController = TextEditingController();

  final List<EmpresaRdo> _empresas = [
    const EmpresaRdo(
      nome: 'Inspecione Engenharia',
      local: 'Belo Horizonte - MG',
      ultimaAtualizacao: '03/04/2026',
    ),
    const EmpresaRdo(
      nome: 'Housing Engenharia',
      local: 'Belo Horizonte - MG',
      ultimaAtualizacao: '10/03/2026',
    ),
    const EmpresaRdo(
      nome: 'HMCM Engenharia',
      local: 'São Paulo - SP',
      ultimaAtualizacao: '12/12/2025',
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
                    'RDOs registrados',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: corTextoTitulo,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildBuscaField()),
                      const SizedBox(width: 10),
                      _buildBotaoNovoRdo(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _empresas.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildEmpresaCard(context, _empresas[index]);
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
                  'RDO',
                  style: TextStyle(color: Colors.white, fontSize: 12),
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
        hintText: 'Busque por empresa',
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

  Widget _buildBotaoNovoRdo() {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.add, size: 18, color: Colors.white),
      label: const Text(
        'Novo RDO',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: corLaranja,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        elevation: 0,
      ),
    );
  }

  Widget _buildEmpresaCard(BuildContext context, EmpresaRdo empresa) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RdoListaScreen(empresa: empresa),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: Color(0xFFEFEFEF),
              child: Icon(Icons.apartment, color: corLaranja),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    empresa.nome,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: corTextoTitulo,
                    ),
                  ),
                  Text(
                    empresa.local,
                    style: const TextStyle(fontSize: 12, color: corTextoSub),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Última atualização: ${empresa.ultimaAtualizacao}',
                    style: const TextStyle(fontSize: 11, color: corTextoSub),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}