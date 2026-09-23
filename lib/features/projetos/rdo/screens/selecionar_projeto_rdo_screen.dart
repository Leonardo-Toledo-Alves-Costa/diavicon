import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';

import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/custom_appbar.dart';
import 'package:diavicon/core/widgets/custom_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/projeto_model.dart';
import '../../providers/projetos_provider.dart';

/// Passo obrigatório antes de criar um RDO a partir do menu lateral (onde
/// nenhum projeto já está no contexto da tela): o usuário escolhe para qual
/// projeto o RDO é. Retorna o [ProjetoModel] escolhido via `Navigator.pop`.
/// Reaproveitada pelos Gastos ("Para qual projeto é este gasto?").
class SelecionarProjetoRdoScreen extends ConsumerStatefulWidget {
  final String pergunta;

  const SelecionarProjetoRdoScreen({super.key, this.pergunta = 'Para qual projeto é este RDO?'});

  @override
  ConsumerState<SelecionarProjetoRdoScreen> createState() => _SelecionarProjetoRdoScreenState();
}

class _SelecionarProjetoRdoScreenState extends ConsumerState<SelecionarProjetoRdoScreen> {
  final TextEditingController _buscaController = TextEditingController();
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _buscaController.addListener(() {
      setState(() => _filtro = _buscaController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projetosAsync = ref.watch(projectsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Selecione o projeto', showBackButton: true, showMenuButton: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.pergunta,
                style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _buscaController,
                style: GoogleFonts.lato(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Busque por projeto',
                  hintStyle: GoogleFonts.lato(color: AppColors.hintText, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: AppColors.hintText),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: projetosAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (err, _) => Center(
                    child: Text('Erro ao carregar projetos: $err', style: GoogleFonts.lato(color: AppColors.error)),
                  ),
                  data: (projetos) {
                    final filtrados = _filtro.isEmpty
                        ? projetos
                        : projetos.where((p) => p.nome.toLowerCase().contains(_filtro)).toList();

                    if (filtrados.isEmpty) {
                      return const CustomEmptyState(text: 'Nenhum projeto encontrado.');
                    }

                    return ListView.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildProjetoCard(context, filtrados[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjetoCard(BuildContext context, ProjetoModel projeto) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).pop(projeto),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: _buildCapa(projeto.imageUrl),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                projeto.nome,
                style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF3E3E3D)),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.greyMedium),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }

  /// Mesmo padrão de `project_card.dart`: `imageUrl` pode ser uma URL de
  /// rede, um arquivo local do dispositivo ou (o default do model) um asset
  /// do próprio app — cada caso precisa do widget de imagem certo.
  Widget _buildCapa(String imageUrl) {
    const double tamanho = 64;

    Widget capaFallback() => Image.asset(
          'assets/images/project_placeholder1.png',
          height: tamanho,
          width: tamanho,
          fit: BoxFit.cover,
        );

    if (imageUrl.startsWith('http')) {
      return ImagemStorage.network(
        imageUrl,
        height: tamanho,
        width: tamanho,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => capaFallback(),
      );
    }

    if (imageUrl.startsWith('/data') || imageUrl.startsWith('file://')) {
      return Image.file(
        File(imageUrl.replaceFirst('file://', '')),
        height: tamanho,
        width: tamanho,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => capaFallback(),
      );
    }

    if (imageUrl.isNotEmpty) {
      return Image.asset(
        imageUrl,
        height: tamanho,
        width: tamanho,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => capaFallback(),
      );
    }

    return capaFallback();
  }
}
