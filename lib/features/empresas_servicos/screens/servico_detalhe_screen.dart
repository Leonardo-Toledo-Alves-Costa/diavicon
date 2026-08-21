import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../empresa/providers/painel_servicos_provider.dart';

class ServicoDetalheScreen extends ConsumerWidget {
  final dynamic servico;
  final String empresaNome;
  final String? empresaFotoUrl;
  final String? empresaCidade;
  final String? empresaEstado;

  const ServicoDetalheScreen({
    super.key,
    required this.servico,
    required this.empresaNome,
    this.empresaFotoUrl,
    this.empresaCidade,
    this.empresaEstado,
  });

  Future<void> _abrirAnexo(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o link do anexo.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('O link informado é inválido.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final galeriaAsync = ref.watch(servicoGaleriaProvider(servico.id));
    final localizacao = (empresaCidade != null && empresaEstado != null && empresaCidade!.isNotEmpty && empresaEstado!.isNotEmpty)
        ? '$empresaCidade - $empresaEstado'
        : 'Localização indisponível';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      extendBodyBehindAppBar: true, 
      
      appBar: const CustomAppBar(
        title: 'Empresa',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Text('Serviço', style: TextStyle(fontSize: 14, color: Colors.white70)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 75),
            // 1. FOTO DE CAPA
            if (servico.fotoPrincipal != null && servico.fotoPrincipal!.isNotEmpty)
              Image.network(
                servico.fotoPrincipal!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            else
              Container(
                height: 220,
                color: Colors.grey[300],
                child: const Icon(Icons.image, size: 60, color: Colors.grey),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. TÍTULO E DADOS DA EMPRESA
                  Text(
                    servico.nome,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: empresaFotoUrl != null && empresaFotoUrl!.isNotEmpty ? NetworkImage(empresaFotoUrl!) : null,
                        child: (empresaFotoUrl == null || empresaFotoUrl!.isEmpty) ? const Icon(Icons.business, size: 16, color: Colors.grey) : null,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(empresaNome, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3E3E3D))),
                          Text(localizacao, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. CARD DE OBJETIVO
                  if (servico.objetivo != null && servico.objetivo!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Objetivo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D))),
                          const SizedBox(height: 8),
                          Text(servico.objetivo!, style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 4. BOTÃO DE ANEXO (Clicável para abrir o Link do documento/apresentação)
                  if (servico.linkAnexo != null && servico.linkAnexo!.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => _abrirAnexo(context, servico.linkAnexo!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.insert_drive_file_outlined, color: AppColors.primary, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    servico.nomeAnexo ?? 'Documento anexo',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF3E3E3D)),
                                  ),
                                  const Text('Toque para abrir o link', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                            const Icon(Icons.open_in_new, size: 18, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 5. CARD DE DESCRIÇÃO
                  if (servico.descricao != null && servico.descricao!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Descrição', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D))),
                          const SizedBox(height: 8),
                          Text(servico.descricao!, style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 6. GALERIA DE FOTOS
                  const Text('Galeria', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D))),
                  const SizedBox(height: 12),
                  galeriaAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (e, _) => Text('Erro ao carregar galeria: $e', style: const TextStyle(color: Colors.red)),
                    data: (fotos) {
                      if (fotos.isEmpty) {
                        return const Text('Nenhuma foto adicional na galeria.', style: TextStyle(color: Colors.grey, fontSize: 12));
                      }
                      return SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: fotos.length,
                          itemBuilder: (context, index) {
                            final imageUrl = fotos[index].fotoUrl;
                            
                            return GestureDetector(
                              onTap: () {
                                // 🔥 Abre o modal em tela cheia ao clicar na foto
                                showDialog(
                                  context: context,
                                  builder: (dialogContext) => Dialog(
                                    backgroundColor: Colors.black87,
                                    insetPadding: EdgeInsets.zero,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // Permite dar zoom na imagem
                                        InteractiveViewer(
                                          minScale: 0.5,
                                          maxScale: 4.0,
                                          child: Image.network(imageUrl, fit: BoxFit.contain),
                                        ),
                                        // Botão de fechar no canto superior direito
                                        Positioned(
                                          top: 40,
                                          right: 20,
                                          child: IconButton(
                                            icon: const Icon(Icons.close, color: Colors.orange, size: 30),
                                            onPressed: () => Navigator.pop(dialogContext),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 90,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: NetworkImage(imageUrl),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}