import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/modal_selecao_base.dart';
import '../../../core/widgets/custom_dropdown_with_add.dart';
import '../providers/projeto_form_provider.dart';

class NovoClienteModal extends ConsumerStatefulWidget {
  const NovoClienteModal({super.key});

  @override
  ConsumerState<NovoClienteModal> createState() => _NovoClienteModalState();
}

class _NovoClienteModalState extends ConsumerState<NovoClienteModal> {
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  String? _tipoSelecionado;
  String? _areaSelecionada;
  final bool _isLoading = false;
  File? _fotoSelecionada; 

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _escolherFotoCliente() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40, 
      maxWidth: 500, 
    );

    if (pickedFile != null) {
      setState(() {
        _fotoSelecionada = File(pickedFile.path);
      });
    }
  }

  Future<void> _confirmarCadastro() async {
    if (_nomeController.text.trim().isEmpty || _emailController.text.trim().isEmpty) {
      _showSnackBar('Preencha o nome e o e-mail do cliente (*)', isError: true);
      return;
    }

    final novoEstadoForm = ref.read(projetoFormProvider).copyWith(
          clienteNome: _nomeController.text.trim(),
          emailNovoCliente: _emailController.text.trim(),
          tipoNovoCliente: _tipoSelecionado,
          areaAtuacaoNovoCliente: _areaSelecionada,
          isNovoCliente: true,
          clienteId: null,
          clienteFotoUrl: _fotoSelecionada?.path, 
        );

    ref.read(projetoFormProvider.notifier).update((state) => novoEstadoForm);

    if (mounted) {
      Navigator.pop(context);
      _showSnackBar('✅ Cliente pré-cadastrado para convite!');
    }
  }

  void _showSnackBar(String mensagem, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: isError ? AppColors.error : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModalSelecaoBase(
      titulo: Text(
        'Novo Cliente',
        style: AppTextStyles.tituloPrincipal,
      ),
      textoBotao: _isLoading ? 'Salvando...' : 'Criar',
      iconeBotao: _isLoading ? null : Icons.add,
      aoPressionarBotao: _isLoading ? null : _confirmarCadastro,
      filhos: [
        Center(
          child: GestureDetector(
            onTap: _escolherFotoCliente, 
            child: Stack(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.greyVeryLight,
                    shape: BoxShape.circle,
                    // Se escolheu foto, exibe a foto
                    image: _fotoSelecionada != null
                        ? DecorationImage(
                            image: FileImage(_fotoSelecionada!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _fotoSelecionada == null
                      ? Padding(
                          padding: const EdgeInsets.all(25.0),
                          child: Image.asset(
                            'assets/images/empresa.png', 
                            fit: BoxFit.contain,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined, 
                      color: AppColors.greyDarkest,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        // 2. FORMULÁRIO
        _buildCampoTexto(
          rotulo: 'Nome do cliente*',
          dica: 'Ex: Construtora Exemplo',
          controller: _nomeController,
        ),
        const SizedBox(height: 16),

        CustomDropdownWithAdd<String>(
          label: 'Tipo*',
          hint: _tipoSelecionado ?? 'Selecione',
          value: _tipoSelecionado,
          items: const [
            DropdownMenuItem(value: 'PF', child: Text('Pessoa Física')),
            DropdownMenuItem(value: 'PJ', child: Text('Pessoa Jurídica')),
          ],
          onChanged: (val) => setState(() => _tipoSelecionado = val),
          onAddPressed: () {}, 
        ),
        const SizedBox(height: 16),

        _buildCampoTexto(
          rotulo: 'Email de contato*',
          dica: 'contato@empresa.com',
          controller: _emailController,
        ),
        const SizedBox(height: 16),

        CustomDropdownWithAdd<String>(
          label: 'Área de atuação*',
          hint: _areaSelecionada ?? 'Selecione',
          value: _areaSelecionada,
          items: const [
            DropdownMenuItem(value: 'CC', child: Text('Construção Civil')),
            DropdownMenuItem(value: 'IND', child: Text('Indústria')),
          ],
          onChanged: (val) => setState(() => _areaSelecionada = val),
          onAddPressed: () {}, 
        ),
      ],
    );
  }

  Widget _buildCampoTexto({
    required String rotulo,
    required String dica,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: rotulo.replaceAll('*', ''),
            style: AppTextStyles.labelCampo,
            children: [
              if (rotulo.contains('*'))
                const TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: AppTextStyles.corpoTextoEscuro,
          decoration: InputDecoration(
            hintText: dica,
            hintStyle: const TextStyle(color: AppColors.greyLight, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.greyLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}