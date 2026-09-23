import 'package:flutter/material.dart';

import '../../../core/widgets/custom_appbar.dart';
import '../../dashboards_bi/screens/modelos_dashboard_screen.dart';
import '../../dashboards_bi/screens/modelos_equacao_screen.dart';
import '../../dashboards_bi/screens/modelos_simulacao_screen.dart';
import '../../gastos/screens/categorias_gasto_screen.dart';
import '../../modelos_relatorios/screens/modelos_relatorios_screen.dart';
import '../../projetos/rdo/screens/modelos_rdo_screen.dart';
import 'padrao_timestamp_foto_screen.dart';
import 'package:diavicon/features/planos/acesso_plano.dart';

class PadroesEmpresaScreen extends StatelessWidget {
  final String empresaId;

  const PadroesEmpresaScreen({super.key, required this.empresaId});

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
            Text('Padrões da empresa', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildCategoryTitle('FOTOS'),
            _PadraoMenuItem(
              icon: Icons.photo_camera_back_outlined,
              title: 'Legenda nas fotos',
              subtitle: 'Marca d\'água com dados do projeto exibida nas fotos das inspeções',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PadraoTimestampFotoScreen(empresaId: empresaId)),
                );
              },
            ),
            const SizedBox(height: 24),
            _buildCategoryTitle('RELATÓRIOS'),
            _PadraoMenuItem(
              icon: Icons.description_outlined,
              title: 'Modelos de Relatórios',
              subtitle: 'Modelos de relatórios padronizados para ensaios',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GuardaModuloPlano(modulo: ModuloPlano.relatorios, child: ModelosRelatoriosScreen(empresaId: empresaId))),
                );
              },
            ),
            _PadraoMenuItem(
              icon: Icons.assignment_outlined,
              title: 'Modelos de RDO',
              subtitle: 'Modelos de RDO específicos para cada demanda',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GuardaModuloPlano(modulo: ModuloPlano.rdoGastos, child: ModelosRdoScreen(empresaId: empresaId))),
                );
              },
            ),
            const SizedBox(height: 24),
            _buildCategoryTitle('DASHBOARD'),
            _PadraoMenuItem(
              icon: Icons.dashboard_customize_outlined,
              title: 'Modelos de Dashboard',
              subtitle: 'Padrões de dashboard de BI por projeto, estrutura ou elemento',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GuardaModuloPlano(modulo: ModuloPlano.dashboard, child: ModelosDashboardScreen(empresaId: empresaId))),
                );
              },
            ),
            _PadraoMenuItem(
              icon: Icons.functions,
              title: 'Modelos de equação',
              subtitle: 'Variáveis calculadas a partir de um ou mais ensaios, usadas nos dashboards',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GuardaModuloPlano(modulo: ModuloPlano.dashboard, child: ModelosEquacaoScreen(empresaId: empresaId))),
                );
              },
            ),
            _PadraoMenuItem(
              icon: Icons.casino_outlined,
              title: 'Modelos de simulação',
              subtitle: 'Simulações de Monte Carlo prontas para usar nos dashboards',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GuardaModuloPlano(modulo: ModuloPlano.dashboard, child: ModelosSimulacaoScreen(empresaId: empresaId))),
                );
              },
            ),
            const SizedBox(height: 24),
            _buildCategoryTitle('GASTOS'),
            _PadraoMenuItem(
              icon: Icons.sell_outlined,
              title: 'Categorias de gasto',
              subtitle: 'Categorias usadas no lançamento de gastos (além das padrão DIAVICON)',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GuardaModuloPlano(modulo: ModuloPlano.rdoGastos, child: CategoriasGastoScreen(empresaId: empresaId))),
                );
              },
            ),
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
}

class _PadraoMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PadraoMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[400]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, color: Colors.grey[800])),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
