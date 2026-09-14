import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/widgets/custom_appbar.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/criar_post_provider.dart';
import '../models/feed_post_model.dart';

class CriarPostScreen extends ConsumerStatefulWidget {
  final FeedPostModel? postParaEditar;

  const CriarPostScreen({super.key, this.postParaEditar});

  @override
  ConsumerState<CriarPostScreen> createState() => _CriarPostScreenState();
}

class _CriarPostScreenState extends ConsumerState<CriarPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textoController = TextEditingController();
  final _nomeAnexoController = TextEditingController(); 
  final _urlAnexoController = TextEditingController();  
  
  static const List<String> _tagsDisponiveis = [
    'Ebooks', 'Artigos', 'Associações', 'Produto', 'Equipamento', 'Campo'
  ];

  String _tagSelecionada = _tagsDisponiveis.first;
  bool _isPatrocinado = false;

  // Novas listas para controle de fotos mistas (Nuvem x Local)
  List<String> _fotosAtuais = [];
  List<XFile> _novasFotos = [];

  bool get _isEdicao => widget.postParaEditar != null;
  int get _totalFotos => _fotosAtuais.length + _novasFotos.length;

  @override
  void initState() {
    super.initState();
    if (_isEdicao) {
      _textoController.text = widget.postParaEditar!.texto;
      _tagSelecionada = widget.postParaEditar!.tag;
      _isPatrocinado = widget.postParaEditar!.patrocinado;
      _nomeAnexoController.text = widget.postParaEditar!.anexoNome ?? '';
      _urlAnexoController.text = widget.postParaEditar!.anexoUrl ?? '';
      _fotosAtuais = List.from(widget.postParaEditar!.fotos); // Clona as fotos existentes
    }
  }

  @override
  void dispose() {
    _textoController.dispose();
    _nomeAnexoController.dispose();
    _urlAnexoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarFotos() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> imagens = await picker.pickMultiImage();
    
    if (imagens.isNotEmpty) {
      setState(() {
        _novasFotos.addAll(imagens);
        // Trava de segurança para limite de fotos somando as atuais com as novas
        if (_totalFotos > 6) {
          int excesso = _totalFotos - 6;
          _novasFotos.removeRange(_novasFotos.length - excesso, _novasFotos.length);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Máximo de 6 fotos permitidas no total.')),
          );
        }
      });
    }
  }

  Future<void> _salvar(CriarPostController controller) async {
    if (!_formKey.currentState!.validate()) return;
    if (_textoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escreva algo para publicar.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      return;
    }

    try {
      if (_isEdicao) {
        await controller.editarPostagem(
          postId: widget.postParaEditar!.id,
          texto: _textoController.text.trim(),
          tag: _tagSelecionada,
          patrocinado: _isPatrocinado,
          fotosAtuais: _fotosAtuais, // Passa as URLs que sobraram
          novasFotos: _novasFotos,   // Passa os XFiles novos
          anexoNome: _nomeAnexoController.text.trim(),
          anexoUrl: _urlAnexoController.text.trim(),
        );
      } else {
        await controller.criarPostagem(
          texto: _textoController.text.trim(),
          tag: _tagSelecionada,
          patrocinado: _isPatrocinado,
          fotos: _novasFotos,
          anexoNome: _nomeAnexoController.text.trim(),
          anexoUrl: _urlAnexoController.text.trim(),
        );
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEdicao ? 'Publicação atualizada!' : 'Publicação criada!'), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(criarPostProvider);

    return ValueListenableBuilder<bool>(
      valueListenable: controller.isUploading,
      builder: (context, isUploading, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          
        appBar:  CustomAppBar(
        title: 'Painel',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            //Text('Empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text(_isEdicao ? 'Editar Publicação' : 'Nova Publicação', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            //Text('Colaboradores', style: TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ),
      ),

          body: GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. TAGS
                    Container(
                      color: Colors.grey.shade50,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Categoria (Tag)', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade700)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _tagsDisponiveis.map((tag) {
                              final isSelected = _tagSelecionada == tag;
                              return ChoiceChip(
                                label: Text(tag),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) setState(() => _tagSelecionada = tag);
                                },
                                selectedColor: const Color(0xFFE87B1D).withOpacity(0.15),
                                backgroundColor: Colors.white,
                                side: BorderSide(color: isSelected ? const Color(0xFFE87B1D) : Colors.grey.shade300),
                                labelStyle: TextStyle(
                                  color: isSelected ? const Color(0xFFE87B1D) : Colors.grey.shade700,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),

                    // 2. CORPO DO POST E FOTOS MISTAS
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Sua publicação', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF333333))),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _textoController,
                            maxLines: 6,
                            maxLength: 2000,
                            decoration: InputDecoration(
                              hintText: 'Compartilhe ideias, conhecimentos ou novidades...',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // HEADER DAS FOTOS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Fotos ($_totalFotos/6)', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF333333))),
                              TextButton.icon(
                                onPressed: _totalFotos >= 6 ? null : _selecionarFotos,
                                icon: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFFE87B1D)),
                                label: const Text('Adicionar', style: TextStyle(color: Color(0xFFE87B1D))),
                              ),
                            ],
                          ),
                          
                          // LISTA HORIZONTAL (RENDERIZA URLs + XFiles)
                          if (_totalFotos > 0)
                            SizedBox(
                              height: 90,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  // FOTOS DA WEB
                                  ..._fotosAtuais.map((url) => Stack(
                                    children: [
                                      Container(
                                        width: 90, margin: const EdgeInsets.only(right: 12, top: 8),
                                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)),
                                      ),
                                      Positioned(
                                        top: 0, right: 4,
                                        child: GestureDetector(
                                          onTap: () => setState(() => _fotosAtuais.remove(url)),
                                          child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: Colors.white)),
                                        ),
                                      ),
                                    ],
                                  )),
                                  // NOVAS FOTOS LOCAIS
                                  ..._novasFotos.map((file) => Stack(
                                    children: [
                                      Container(
                                        width: 90, margin: const EdgeInsets.only(right: 12, top: 8),
                                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: DecorationImage(image: FileImage(File(file.path)), fit: BoxFit.cover)),
                                      ),
                                      Positioned(
                                        top: 0, right: 4,
                                        child: GestureDetector(
                                          onTap: () => setState(() => _novasFotos.remove(file)),
                                          child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: Colors.white)),
                                        ),
                                      ),
                                    ],
                                  )),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),

                          // 4. ANEXOS E PATROCÍNIO
                          Text('Botão de Link (Opcional)', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF333333))),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nomeAnexoController,
                            decoration: InputDecoration(hintText: 'Nome do botão (Ex: Baixar E-book)', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _urlAnexoController,
                            keyboardType: TextInputType.url,
                            decoration: InputDecoration(hintText: 'Cole o link externo aqui (https://...)', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                          ),
                          const SizedBox(height: 24),

                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeColor: const Color(0xFFE87B1D),
                            title: Text('Post Patrocinado', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF333333))),
                            subtitle: const Text('Aumenta significativamente a chance de aparecer no topo do feed educacional.'),
                            value: _isPatrocinado,
                            onChanged: (val) => setState(() => _isPatrocinado = val),
                          ),
                          
                          const SizedBox(height: 32),

                          // 5. BOTÃO DE SALVAR
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE87B1D),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: isUploading ? null : () => _salvar(controller),
                              child: isUploading
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text(_isEdicao ? 'Salvar Alterações' : 'Publicar', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }
}