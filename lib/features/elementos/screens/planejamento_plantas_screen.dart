import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/custom_appbar.dart';
import 'package:diavicon/features/elementos/providers/plantas_provider.dart';
import 'package:diavicon/features/elementos/screens/planejamento_screen.dart';
import 'package:diavicon/features/elementos/widgets/novo_arquivo_popup.dart';
import 'package:diavicon/features/elementos/widgets/planta_formato_card.dart';
import 'package:diavicon/features/estrutura/models/local_model.dart';
import 'package:diavicon/features/estrutura/providers/local_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:google_fonts/google_fonts.dart';


/// Tela "Planejamento" da estrutura: lista as plantas/formatos cadastrados.
class PlanejamentoPlantasScreen extends ConsumerWidget { 
  const PlanejamentoPlantasScreen({
    super.key,
    required this.estruturaId, 
  });

  final String estruturaId;

  // Função que intercepta o arquivo do popup e envia para o controlador
  Future<void> _adicionarNovaPlanta(BuildContext context, WidgetRef ref) async {
    final result = await showNovoArquivoPopup(context, estruturaId);
    
    if (result != null && context.mounted) {
      try {
        final arquivo = result.arquivo;
        
        // Dispara o salvamento através do nosso Controller
        await ref.read(plantaControllerProvider.notifier).salvarNovaPlanta(
              estruturaId: estruturaId,
              titulo: result.nome,
              localVinculado: result.localId, 
              caminhoLocal: arquivo.path!,
              extensao: arquivo.extension ?? 'pdf',
              tamanhoArquivo: '${(arquivo.size / (1024 * 1024)).toStringAsFixed(2)} MB',
            );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Planta adicionada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao fazer upload da planta: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) { 
    // Escuta a lista de plantas em tempo real
    final plantasAsync = ref.watch(plantasPorEstruturaProvider(estruturaId));
    // Escuta o estado de loading do upload
    final isSubmitting = ref.watch(plantaControllerProvider);
    final locaisAsync = ref.watch(locaisPorEstruturaProvider(estruturaId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'Estrutura',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Projeto',
              style: GoogleFonts.lato(
                fontSize: 11,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Estrutura',
              style: GoogleFonts.lato(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Planejamento',
              style: GoogleFonts.lato(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plantas e Formatos da Estrutura',
                    style: GoogleFonts.lato(
                      color: const Color(0xFF3E3E3D),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: _BuscaMock()),
                      const SizedBox(width: 12),
                      _NovoButton(
                        onPressed: isSubmitting 
                            ? null 
                            : () => _adicionarNovaPlanta(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Tratamento do estado assíncrono do banco de dados
                  Expanded(
                    child: plantasAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                      error: (err, _) => Center(
                        child: Text(
                          'Erro ao carregar plantas: $err',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                      data: (plantas) {
                        // Pega a lista de locais carregada (ou vazia se der erro/loading)
                        final locais = locaisAsync.value ?? [];

                        if (plantas.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.architecture, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  'Nenhuma planta cadastrada.',
                                  style: GoogleFonts.lato(color: Colors.grey, fontSize: 16),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: plantas.length,
                          itemBuilder: (context, index) {
                            final planta = plantas[index];
                            
                            // Transforma a URL em minúsculo antes de checar
                            final urlLower = planta.arquivoUrl.toLowerCase();
                            final esImagem = urlLower.contains('.png') || 
                                             urlLower.contains('.jpg') || 
                                             urlLower.contains('.jpeg');

                            //  Traduz o ID (UUID) para o Nome real
                            final localReal = locais.firstWhere(
                              (l) => l.id == planta.localVinculado,
                              orElse: () => LocalModel(id: '', estruturaId: '', nome: 'Local desconhecido'),
                            );

                            return PlantaFormatoCard(
                              titulo: planta.titulo,
                              local: localReal.nome,
                              detalhe: planta.tamanhoArquivo ?? 'Tamanho desconhecido',
                              iconAsset: esImagem ? 'assets/images/image_icon.png' : 'assets/images/pdf.png',
                              onTap: () async {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlanejamentoScreen(
                                        // Passando o ID da estrutura
                                        estruturaId: estruturaId, // ou 'estrutura.id', dependendo de como está o nome da sua variável nessa tela
                                        plantaId: planta.id,
                                        plantaUrl: planta.arquivoUrl,
                                        plantaTitulo: planta.titulo,
                                        plantaLocal: localReal.nome,
                                      ),
                                    ),
                                  );
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
            
            //  Overlay visual de bloqueio enquanto o arquivo sobe pro Storage
            if (isSubmitting)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.primary),
                          SizedBox(height: 16),
                          Text('Enviando arquivo da planta...', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BuscaMock extends StatelessWidget {
  const _BuscaMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD9D9D9).withOpacity(0.62)),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Nome do arquivo ou local',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.lato(
                color: const Color(0xFFCCCCCC),
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const Icon(Icons.search, size: 17, color: Color(0xFFCCCCCC)),
        ],
      ),
    );
  }
}

class _NovoButton extends StatelessWidget {
  const _NovoButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A57E8).withOpacity(0.30),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          'Novo',
          style: GoogleFonts.lato(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
      ),
    );
  }
}