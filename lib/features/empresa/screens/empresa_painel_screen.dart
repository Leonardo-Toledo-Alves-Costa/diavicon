import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../providers/empresa_profile_provider.dart';
import 'empresa_informacoes_screen.dart'; // Tela do formulário
import 'painel_servicos_screen.dart';
import 'campos_menu_screen.dart';

class EmpresaPainelScreen extends StatelessWidget {
  final EmpresaDetalheModel empresa;

  const EmpresaPainelScreen({super.key, required this.empresa});

  @override
  Widget build(BuildContext context) {
    final location = (empresa.cidade != null && empresa.estado != null)
        ? '${empresa.cidade}, ${empresa.estado}' : 'Localização indisponível';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const CustomAppBar(
        title: 'Painel',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Logo Centralizada
            CircleAvatar(
              radius: 46,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 42,
                backgroundImage: empresa.fotoUrl != null ? NetworkImage(empresa.fotoUrl!) : null,
                child: empresa.fotoUrl == null ? const Icon(Icons.business, size: 40) : null,
              ),
            ),
            const SizedBox(height: 16),
            Text(empresa.nome, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (empresa.descricao != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(empresa.descricao!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              ),
            const SizedBox(height: 4),
            Text(location, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            
            const SizedBox(height: 32),

            // Grid de Opções
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _PainelCard(
                  icon: Icons.info_outline,
                  title: 'Informações\nda empresa',
                  onTap: () {
                    // Direciona para o formulário de informações adicionais
                    Navigator.push(context, MaterialPageRoute(builder: (_) => EmpresaInformacoesScreen(empresa: empresa)));
                  },
                ),
                _PainelCard(
                  icon: Icons.people_outline,
                  title: 'Colaboradores\ncadastrados',
                  //badgeCount: '12', // Substitua pelos dados reais futuramente
                  onTap: () {},
                ),
                _PainelCard(
                  icon: Icons.store_outlined,
                  title: 'Serviços e\nprodutos',
                  //badgeCount: '07',
                  onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => PainelServicosScreen(empresaId: empresa.id,
                                                                                                      empresaNome: empresa.nome,
                                                                                                      )));
                    },
                ),
                _PainelCard(
                  icon: Icons.build_outlined,
                  title: 'Equipamentos',
                  badgeCount: '09',
                  onTap: () {},
                ),
                _PainelCard(
                  icon: Icons.backup_table,
                  title: 'Campos \npersonalizáveis ',
                  onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => CamposMenuScreen(empresaId: empresa.id,
                                                                                                      
                                                                                                      )));

                  },
                ),
                _PainelCard(
                  icon: Icons.business_outlined,
                  title: 'Estruturas sob\ngestão',
                  badgeCount: '02',
                  onTap: () {},
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            // Preferências
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.settings, color: Colors.black87),
                label: const Text('Preferências', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.black12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

class _PainelCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badgeCount;
  final VoidCallback onTap;

  const _PainelCard({required this.icon, required this.title, this.badgeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.black54),
                if (badgeCount != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                    child: Text(badgeCount!, style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
          ],
        ),
      ),
    );
  }
}