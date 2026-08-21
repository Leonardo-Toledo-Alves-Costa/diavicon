import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../providers/painel_servicos_provider.dart';
import 'servico_form_screen.dart';

class PainelServicosScreen extends ConsumerWidget {
  final String empresaId;
  final String empresaNome;
  final String? empresaFotoUrl;

  const PainelServicosScreen({
    super.key, 
    required this.empresaId,
    required this.empresaNome,
    this.empresaFotoUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicosAsync = ref.watch(painelServicosListProvider(empresaId));
    final categorias = ['Todos', 'Produto', 'Serviço', 'Equipamento'];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const CustomAppBar(
        title: 'Painel',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            Text('Empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Painel', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Serviços', style: TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {
          // Navega para a tela de formulário no modo CRIAÇÃO (servico = null)
          Navigator.push(context, MaterialPageRoute(builder: (_) => ServicoFormScreen(empresaId: empresaId)));
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // BARRA DE BUSCA E FILTRO
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    onChanged: (val) => ref.read(painelServicoSearchProvider.notifier).setBusca(val),
                    decoration: InputDecoration(
                      hintText: 'Buscar serviço, produto...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.black12)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.black12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.primary)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: ref.watch(painelServicoFilterProvider),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    decoration: const InputDecoration(border: InputBorder.none),
                    hint: const Text('Todos', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                    items: categorias.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value == 'Todos' ? null : value,
                        child: Text(value, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (newValue) => ref.read(painelServicoFilterProvider.notifier).setFiltro(newValue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // LISTA DE SERVIÇOS
            Expanded(
              child: servicosAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.red))),
                data: (servicos) {
                  if (servicos.isEmpty) return const Center(child: Text('Nenhum item cadastrado.'));
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: servicos.length,
                    itemBuilder: (context, index) {
                      final servico = servicos[index];
                      return _ServicoCard(
                        servico: servico, 
                        empresaNome: empresaNome, 
                        empresaFotoUrl: empresaFotoUrl,
                        onTap: () {
                          // Navega para edição passando o serviço existente
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ServicoFormScreen(empresaId: empresaId, servico: servico)));
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServicoCard extends StatelessWidget {
  final ServicoEmpresaModel servico;
  final String empresaNome;
  final String? empresaFotoUrl;
  final VoidCallback onTap;

  const _ServicoCard({required this.servico, required this.empresaNome, this.empresaFotoUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: servico.fotoPrincipal != null 
                      ? Image.network(servico.fotoPrincipal!, height: 140, width: double.infinity, fit: BoxFit.cover)
                      : Container(height: 140, color: Colors.grey[300], child: const Icon(Icons.image, color: Colors.grey, size: 40)),
                ),
                if (servico.categoria != null)
                  Positioned(
                    top: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
                      child: Text(servico.categoria!, style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: empresaFotoUrl != null ? NetworkImage(empresaFotoUrl!) : null,
                      ),
                      const SizedBox(width: 8),
                      Text(empresaNome, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(servico.nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                  
                  if (servico.objetivo != null || servico.descricao != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        (servico.objetivo ?? servico.descricao)!, 
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis, 
                        style: TextStyle(fontSize: 13, color: Colors.grey[600])
                      ),
                    ),
                  
                  if (servico.nomeAnexo != null && servico.linkAnexo != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(servico.nomeAnexo!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}