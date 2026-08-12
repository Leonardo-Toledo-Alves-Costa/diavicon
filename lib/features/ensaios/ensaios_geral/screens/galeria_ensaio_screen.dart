import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';

import '../repositories/galeria_ensaio_repository.dart';
import '../widgets/imagem_ensaio_modal.dart';
import '../models/galeria_ensaio_model.dart';

class GaleriaEnsaioScreen extends ConsumerWidget {
  final String pontoGeralId;
  final String pontoNome;
  final String elementoNome;
  final String tipoElemento;
  final String local;
  final String tipoEnsaio; 

  const GaleriaEnsaioScreen({
    super.key,
    required this.pontoGeralId,
    required this.pontoNome,
    required this.elementoNome,
    required this.tipoElemento,
    required this.local,
    required this.tipoEnsaio,
  });

  // Função única que abre o modal: se receber 'imagemExistente', edita. Se não, cria.
  void _abrirModalGerenciamento(BuildContext context, {GaleriaEnsaioModel? imagemExistente}) {
    showDialog(
      context: context,
      builder: (context) => ImagemEnsaioModal(
        pontoEnsaioId: pontoGeralId, 
        imagemExistente: imagemExistente,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Como estamos usando o StreamProvider, ao editar/excluir/adicionar, a UI atualiza sozinha.
    final galeriaStream = ref.watch(galeriaPontoProvider(pontoGeralId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      
      endDrawer: MenuDrawerAppBar(
        title: 'Ponto de\nensaio',
        items: [
          DiaviconMenuItem(
            icon: Icons.info_outline,
            label: 'Informações',
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop(); 
              navigator.pop(); 
            },
          ),
          Opacity(
            opacity: 0.4,
            child: DiaviconMenuItem(
              icon: Icons.camera_alt_outlined,
              label: 'Fotos',
              onTap: () {}, 
            ),
          ),
          DiaviconMenuItem(
            icon: Icons.show_chart_rounded,
            label: 'Análise',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Acesse a Análise através da aba de Informações.'), backgroundColor: Colors.orange)
              );
              Navigator.pop(context); 
            },
          ),
        ],
      ),
      appBar: CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ponto de ensaio', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
            Text(tipoEnsaio, style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho informacional
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$pontoNome - $elementoNome',
                  style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
                ),
                const SizedBox(height: 4),
                Text(
                  '$tipoElemento \n$local',
                  style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF888888)),
                ),
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Galeria', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                    ElevatedButton(
                      onPressed: () => _abrirModalGerenciamento(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFA726),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Nova', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Lista da Galeria (Em Tempo Real)
          Expanded(
            child: galeriaStream.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, stack) => Center(child: Text('Erro ao carregar galeria.', style: const TextStyle(color: Colors.red))),
              data: (lista) {
                if (lista.isEmpty) {
                  return const Center(child: Text('Nenhuma foto adicionada à galeria.', style: TextStyle(color: Colors.grey)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: lista.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final img = lista[index];
                    
                    // CARD CLICÁVEL: Quando clicado, abre o modal enviando a imagem Existente
                    return GestureDetector(
                      onTap: () => _abrirModalGerenciamento(context, imagemExistente: img),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                img.imagemUrl,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (c, o, s) => Container(width: 100, height: 100, color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.grey)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                img.legenda?.isNotEmpty == true ? img.legenda! : 'Sem legenda...',
                                style: GoogleFonts.lato(fontSize: 15, color: Colors.grey.shade600),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}