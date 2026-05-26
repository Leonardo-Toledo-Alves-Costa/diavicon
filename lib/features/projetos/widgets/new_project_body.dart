import 'dart:io';
import 'package:diavicon/features/projetos/widgets/selecao_cliente_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_dropdown_with_add.dart';

import '../providers/projeto_form_provider.dart';
import '../providers/projetos_provider.dart'; 
import '../providers/clientes_provider.dart';
import '../../auth/providers/auth_provider.dart';

class NewProjectBody extends ConsumerStatefulWidget {
  const NewProjectBody({super.key});

  @override
  ConsumerState<NewProjectBody> createState() => _NewProjectBodyState();
}

class _NewProjectBodyState extends ConsumerState<NewProjectBody> {
  final _nomeController = TextEditingController();
  bool _estaSalvando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _escolherImagem() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40, 
      maxWidth: 1080,   
    ); 
    
    if (pickedFile != null) {
      ref.read(projetoFormProvider.notifier).update(
        (state) => state.copyWith(imagemProjeto: File(pickedFile.path)),
      );
    }
  }

  /// Função que consolida os dados do rascunho e envia para o repositório
  Future<void> _salvarProjetoCompleto() async {
    final formState = ref.read(projetoFormProvider);
    final user = ref.read(currentUserProvider);

    if (user == null || user.empresaId == null) {
      _showSnackBar(
        'Erro: Empresa não identificada no seu perfil.',
        isError: true,
      );
      return;
    }

    if (_nomeController.text.trim().isEmpty) {
      _showSnackBar('Dê um nome ao projeto.', isError: true);
      return;
    }

    if (formState.clienteNome == null) {
      _showSnackBar('Selecione ou cadastre um cliente.', isError: true);
      return;
    }

    setState(() => _estaSalvando = true);

    try {
      final repo = ref.read(projetoRepositoryProvider);

      await repo.createProject(
        nome: _nomeController.text.trim(),
        empresaGestoraId: user.empresaId!,
        usuarioId: user.id,
        empresaClienteId: formState.clienteId,
        isNovoCliente: formState.isNovoCliente,
        emailNovoCliente: formState.emailNovoCliente,
        nomeNovoCliente: formState.clienteNome,
        imagemProjeto: formState.imagemProjeto,
        fotoNovoCliente: formState.clienteFotoUrl != null 
            ? File(formState.clienteFotoUrl!) 
            : null,
      );

      // 🔥 CORREÇÃO AQUI: Usa o nome novo do provider principal de lista
      ref.invalidate(projetoFormProvider);
      ref.invalidate(filteredProjectsProvider); // Antes estava projectsListProvider

      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('Projeto criado com sucesso!');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erro ao salvar: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _estaSalvando = false);
    }
  }

  void _showSnackBar(String mensagem, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: isError ? AppColors.error : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // Escuta o rascunho (estado global do formulário)
    final rascunho = ref.watch(projetoFormProvider);

    // Escuta o provider COMBINADO (Carteira + Cliente Selecionado na Busca Global)
    final clientesDropdownAsync = ref.watch(dropdownClientesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // HEADER / IMAGEM DO PROJETO
        GestureDetector(
          onTap: _estaSalvando ? null : _escolherImagem,
          child: Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 55,
                  backgroundColor: AppColors.greyVeryLight,
                  backgroundImage: rascunho.imagemProjeto != null
                      ? FileImage(rascunho.imagemProjeto!) as ImageProvider
                      : const AssetImage('assets/images/empresa.png'),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined, 
                      color: AppColors.textDark,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        CustomTextField(
          label: 'Nome do projeto*',
          hint: 'Ex: Reforma Galpão Industrial',
          controller: _nomeController,
          enabled: !_estaSalvando,
          isRequired: true,
        ),
        const SizedBox(height: 20),

        clientesDropdownAsync.when(
          data: (listaClientes) => CustomDropdownWithAdd<String>(
            label: 'Cliente',
            hint: rascunho.clienteNome ?? 'Selecione ou pesquise',
            value: rascunho.clienteId,
            isRequired: true,
            items: listaClientes
                .map(
                  (c) => DropdownMenuItem(
                    value: c['id'].toString(),
                    child: Text(c['nome'].toString()),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) {
                final selecionado = listaClientes.firstWhere(
                  (c) => c['id'] == val,
                );
                ref
                    .read(projetoFormProvider.notifier)
                    .update(
                      (state) => state.copyWith(
                        clienteId: val,
                        clienteNome: selecionado['nome'],
                        isNovoCliente: false,
                      ),
                    );
              }
            },
            onAddPressed: () {
              if (_estaSalvando) return; 

              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: const SelecaoClienteModal(),
                ),
              );
            },
          ),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          error: (err, stack) => Text(
            'Erro ao carregar clientes: $err',
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ),

        const SizedBox(height: 40),

        // CRIAR
        CustomButton(
          text: _estaSalvando ? 'Salvando...' : 'Criar',
          showArrow: false,
          onPressed: _estaSalvando ? null : _salvarProjetoCompleto,
        ),

        // Ajuste de espaçamento para teclados e safe area
        SizedBox(height: bottomPadding > 0 ? bottomPadding : 16),
      ],
    );
  }
}