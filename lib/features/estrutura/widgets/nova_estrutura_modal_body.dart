import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_button.dart';
import '../services/image_picker_service.dart'; 
import '../screens/nova_estrutura_body.dart'; 

class NovaEstruturaModalBody extends ConsumerStatefulWidget {
  const NovaEstruturaModalBody({super.key});

  @override
  ConsumerState<NovaEstruturaModalBody> createState() => _NovaEstruturaModalBodyState();
}

class _NovaEstruturaModalBodyState extends ConsumerState<NovaEstruturaModalBody> {
  final _nomeController = TextEditingController();
  File? _imagemSelecionada;
  final ImagePickerService _imagePickerService = ImagePickerService();
  bool _estaSalvando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  
  Future<void> _escolherImagem() async {
    final File? image = await _imagePickerService.pickAndCropImage(
      title: 'Enquadrar Capa da Estrutura',
    );
    
    if (image != null) {
      setState(() {
        _imagemSelecionada = image;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. FOTO DA ESTRUTURA (Com visualização dinâmica e edição 
        GestureDetector(
          onTap: _estaSalvando ? null : _escolherImagem,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(16),
                  image: _imagemSelecionada != null
                      ? DecorationImage(
                          image: FileImage(_imagemSelecionada!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _imagemSelecionada == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.black54),
                          SizedBox(height: 8),
                          Text(
                            'Adicionar capa',
                            style: TextStyle(color: Colors.black54, fontSize: 14),
                          ),
                        ],
                      )
                    : null,
              ),
              // Botãozinho de lápis visível se a imagem já tiver sido selecionada
              if (_imagemSelecionada != null)
                Positioned(
                  bottom: -15,
                  right: 15,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.edit_square, color: AppColors.textDark, size: 24),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 2. CAMPO DE NOME
        CustomTextField(
          label: 'Nome da estrutura*',
          hint: 'Ex: Galpão de Distribuição Norte',
          controller: _nomeController,
          enabled: !_estaSalvando,
          isRequired: true,
        ),
        const SizedBox(height: 16),

        // 3. SECÇÃO DO PROPRIETÁRIO
        const Text(
          'Proprietário da estrutura', 
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)
        ),
        const SizedBox(height: 2), 
        const Text(
          'O proprietário da estrutura é responsável pela gestão e compartilhamento dos dados',
          style: TextStyle(fontSize: 11, color: AppColors.hintText, height: 1.2), 
        ),
        const SizedBox(height: 12),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Icon(Icons.domain, size: 32, color: Colors.grey[400]), 
            ),
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Proprietário da Estrutura*', style: TextStyle(fontSize: 11, color: AppColors.hintText)),
                  const SizedBox(height: 4),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.inputBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Selecione', style: TextStyle(color: AppColors.textDark, fontSize: 13)),
                        Icon(Icons.keyboard_arrow_down, color: AppColors.textDark, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE), 
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Não Vinculado', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                      
                      const Spacer(), 
                      
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                          minimumSize: const Size(0, 28), 
                        ),
                        onPressed: () {}, 
                        child: const Text('Vincular', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 4. BOTÃO CRIAR
        CustomButton(
          text: 'Criar',
          showArrow: false,
          onPressed: () {
            // 1. Captura o texto digitado e a imagem do estado atual do modal
            final nomeInformado = _nomeController.text.trim();
            final imagemInformada = _imagemSelecionada;

            // 2. Fecha o modal de forma limpa
            Navigator.pop(context);

            // 3. Navega para a tela completa passando os dados capturados
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NovaEstruturaScreen(
                  projetoId: '', // Insira o projetoId real se a chamada vier de dentro de um projeto
                  initialNome: nomeInformado,
                  initialImagem: imagemInformada,
                ),
              ),
            );
          }, 
        ),
      ],
    );
  }
}