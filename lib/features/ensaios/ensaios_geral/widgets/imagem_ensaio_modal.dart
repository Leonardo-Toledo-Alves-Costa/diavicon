import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../repositories/galeria_ensaio_repository.dart';
import '../models/galeria_ensaio_model.dart';

class ImagemEnsaioModal extends ConsumerStatefulWidget {
  final String pontoEnsaioId;
  final GaleriaEnsaioModel? imagemExistente; // Nulo = Criar | Preenchido = Editar

  const ImagemEnsaioModal({
    super.key,
    required this.pontoEnsaioId,
    this.imagemExistente,
  });

  @override
  ConsumerState<ImagemEnsaioModal> createState() => _ImagemEnsaioModalState();
}

class _ImagemEnsaioModalState extends ConsumerState<ImagemEnsaioModal> {
  final _legendaController = TextEditingController();
  File? _imagemLocal;
  bool _isLoading = false;

  bool get _isEditing => widget.imagemExistente != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _legendaController.text = widget.imagemExistente!.legenda ?? '';
    }
  }

  @override
  void dispose() {
    _legendaController.dispose();
    super.dispose();
  }

  Future<void> _capturarFoto() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('Tirar foto com a Câmera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary),
                title: const Text('Escolher da Galeria'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source != null) {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, imageQuality: 70);

      if (image != null) {
        setState(() => _imagemLocal = File(image.path));
      }
    }
  }

  Future<void> _salvar() async {
    // Validação
    if (!_isEditing && _imagemLocal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma imagem.'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);
    final repo = ref.read(galeriaEnsaioRepositoryProvider);

    try {
      if (_isEditing) {
        // MODO EDIÇÃO
        await repo.atualizarImagem(
          imagemId: widget.imagemExistente!.id,
          urlAtual: widget.imagemExistente!.imagemUrl,
          novaImagemLocal: _imagemLocal,
          novaLegenda: _legendaController.text,
        );
      } else {
        // MODO CRIAÇÃO
        await repo.adicionarImagem(
          pontoEnsaioId: widget.pontoEnsaioId,
          imagemLocal: _imagemLocal!,
          legenda: _legendaController.text,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _apagar() async {
    if (!_isEditing) {
      // Modo Criação: Apenas limpa a foto e texto do rascunho
      setState(() {
        _imagemLocal = null;
        _legendaController.clear();
      });
      return;
    }

    // Modo Edição: Alerta de confirmação para deletar do banco
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar Imagem'),
        content: const Text('Tem certeza que deseja apagar esta imagem da galeria? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _isLoading = true);
      try {
        await ref.read(galeriaEnsaioRepositoryProvider).deletarImagem(widget.imagemExistente!.id);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imagem apagada com sucesso.'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define qual imagem mostrar (Foto Nova vs Foto do Banco)
    ImageProvider? imageProvider;
    if (_imagemLocal != null) {
      imageProvider = FileImage(_imagemLocal!);
    } else if (_isEditing && widget.imagemExistente!.imagemUrl.isNotEmpty) {
      imageProvider = NetworkImage(widget.imagemExistente!.imagemUrl);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24), 
                Text(
                  _isEditing ? 'Editar imagem' : 'Nova imagem do ensaio', 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D))
                ),
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 24),
            
            // Preview de Imagem
            GestureDetector(
              onTap: _capturarFoto,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                      image: imageProvider != null ? DecorationImage(image: imageProvider, fit: BoxFit.cover) : null,
                    ),
                    child: imageProvider == null ? const Center(child: Icon(Icons.camera_alt, color: Colors.grey, size: 40)) : null,
                  ),
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                    child: const Icon(Icons.edit_square, size: 20, color: Color(0xFF3E3E3D)),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Campo de Legenda
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Legenda', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 4),
                TextField(
                  controller: _legendaController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Legenda da foto',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Botões de Ação
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _apagar,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Apagar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _salvar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFA726),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}