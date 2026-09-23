import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';
import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/galeria_rdo_model.dart';
import '../repositories/galeria_rdo_repository.dart';
import '../../../../core/web/escolher_foto.dart';

/// Cria ou edita uma foto da galeria do RDO — mesmo padrão do
/// `ImagemEnsaioModal` (câmera/galeria, prévia, descrição, salvar/apagar).
class ImagemRdoModal extends ConsumerStatefulWidget {
  final String rdoId;
  final GaleriaRdoModel? fotoExistente;

  const ImagemRdoModal({super.key, required this.rdoId, this.fotoExistente});

  @override
  ConsumerState<ImagemRdoModal> createState() => _ImagemRdoModalState();
}

class _ImagemRdoModalState extends ConsumerState<ImagemRdoModal> {
  final _descricaoController = TextEditingController();
  File? _fotoLocal;
  bool _isLoading = false;

  bool get _isEditing => widget.fotoExistente != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _descricaoController.text = widget.fotoExistente!.descricao ?? '';
    }
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _capturarFoto() async {
    final source = origemFotoNoNavegador ?? await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: Text('Tirar foto com a câmera', style: GoogleFonts.lato()),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: Text('Escolher da galeria', style: GoogleFonts.lato()),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    final imagem = await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (imagem != null) setState(() => _fotoLocal = File(imagem.path));
  }

  Future<void> _salvar() async {
    if (!_isEditing && _fotoLocal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma foto.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    final repo = ref.read(galeriaRdoRepositoryProvider);

    try {
      if (_isEditing) {
        await repo.atualizarFoto(
          fotoId: widget.fotoExistente!.id,
          urlAtual: widget.fotoExistente!.foto,
          novaFotoLocal: _fotoLocal,
          novaDescricao: _descricaoController.text,
        );
      } else {
        await repo.adicionarFoto(
          rdoId: widget.rdoId,
          fotoLocal: _fotoLocal!,
          descricao: _descricaoController.text,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _apagar() async {
    if (!_isEditing) {
      setState(() {
        _fotoLocal = null;
        _descricaoController.clear();
      });
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar foto'),
        content: const Text('Tem certeza que deseja apagar esta foto da galeria do RDO? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(galeriaRdoRepositoryProvider).deletarFoto(widget.fotoExistente!.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto apagada.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (_fotoLocal != null) {
      imageProvider = FileImage(_fotoLocal!);
    } else if (_isEditing && widget.fotoExistente!.foto.isNotEmpty) {
      imageProvider = StorageNetworkImage(widget.fotoExistente!.foto);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24),
                Text(
                  _isEditing ? 'Editar foto' : 'Nova foto do RDO',
                  style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D)),
                ),
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: AppColors.greyMedium)),
              ],
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _capturarFoto,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: AppColors.greyVeryLight,
                      borderRadius: BorderRadius.circular(16),
                      image: imageProvider != null ? DecorationImage(image: imageProvider, fit: BoxFit.cover) : null,
                    ),
                    child: imageProvider == null
                        ? const Center(child: Icon(Icons.camera_alt, color: AppColors.greyMedium, size: 40))
                        : null,
                  ),
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: const Icon(Icons.edit_square, size: 20, color: Color(0xFF3E3E3D)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Descrição', style: GoogleFonts.lato(fontSize: 13, color: AppColors.greyMedium)),
                const SizedBox(height: 4),
                TextField(
                  controller: _descricaoController,
                  maxLines: 3,
                  style: GoogleFonts.lato(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Descrição da foto',
                    hintStyle: GoogleFonts.lato(fontSize: 13, color: AppColors.hintText),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _apagar,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Apagar', style: GoogleFonts.lato(color: AppColors.error, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _salvar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Salvar', style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
