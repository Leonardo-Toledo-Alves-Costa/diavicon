import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/features/elementos/widgets/novo_arquivo_popup.dart';
import 'package:diavicon/features/elementos/widgets/planta_formato_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:google_fonts/google_fonts.dart';

import '../models/planta_model.dart';
import '../providers/plantas_provider.dart';

/// Abre o popup "Plantas e Formatos da Estrutura" passando o [estruturaId] 
/// e devolve a [PlantaModel] escolhida, ou `null` se o usuário fechar sem selecionar.
Future<PlantaModel?> showSelecionarPlantaPopup(BuildContext context, String estruturaId) {
  return showDialog<PlantaModel>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => SelecionarPlantaPopup(estruturaId: estruturaId),
  );
}

/// Popup que lista as plantas reais da estrutura lidas do Supabase
class SelecionarPlantaPopup extends ConsumerWidget { 
  const SelecionarPlantaPopup({
    super.key,
    required this.estruturaId,
  });

  final String estruturaId;

  // Função para chamar o botão de "Novo" de dentro deste popup
  Future<void> _criarNovaPlanta(BuildContext context, WidgetRef ref) async {
    final result = await showNovoArquivoPopup(context, estruturaId);
    
    if (result != null && context.mounted) {
      try {
        final arquivo = result.arquivo;
        
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
            const SnackBar(content: Text('Planta adicionada com sucesso!'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao fazer upload: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plantasAsync = ref.watch(plantasPorEstruturaProvider(estruturaId));

    final mediaQuery = MediaQuery.of(context);
    final largura = (mediaQuery.size.width - 32).clamp(280.0, 350.0).toDouble();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: largura,
        child: Material(
          color: Colors.white,
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Cabeçalho: botão fechar ──────────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: _CloseButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                // ── Título ───────────────────────────────────────────────────
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
                // ── Busca (mock) + botão Novo ─────────────────────────────────
                Row(
                  children: [
                    const Expanded(child: _BuscaMock()),
                    const SizedBox(width: 12),
                    _NovoButton(
                      onPressed: () => _criarNovaPlanta(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // ── Lista de plantas real do Supabase ─────────────────────────
                Flexible(
                  child: plantasAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(child: Text('Erro ao carregar plantas: $err', style: const TextStyle(color: AppColors.error))),
                    ),
                    data: (plantas) {
                      if (plantas.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.architecture, size: 48, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  'Nenhuma planta encontrada.',
                                  style: GoogleFonts.lato(color: Colors.grey, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final planta in plantas)
                              PlantaFormatoCard(
                                titulo: planta.titulo,
                                local: 'Ver Local', // Como mudamos o model, ajustaríamos aqui para buscar o nome se necessário
                                detalhe: planta.tamanhoArquivo ?? 'Tamanho desconhecido',
                                iconAsset: (planta.arquivoUrl.contains('.png') || planta.arquivoUrl.contains('.jpg')) 
                                    ? 'assets/images/image_icon.png' 
                                    : 'assets/images/pdf.png',
                                onTap: () => Navigator.of(context).pop<PlantaModel>(planta), // Retorna a planta real
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de busca apenas visual (a busca real virá com o upload de plantas).
class _BuscaMock extends StatelessWidget {
  const _BuscaMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD9D9D9).withValues(alpha: 0.62)),
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
            color: const Color(0xFF3A57E8).withValues(alpha: 0.30),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF9A232),
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

class _CloseButton extends StatelessWidget {
  const _CloseButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        splashRadius: 18,
        icon: Icon(
          Icons.close,
          color: const Color(0xFF626365).withValues(alpha: 0.40),
          size: 24,
        ),
      ),
    );
  }
}