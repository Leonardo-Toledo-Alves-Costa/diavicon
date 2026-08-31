import 'dart:io';
import 'package:diavicon/features/projetos/widgets/selecao_cliente_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart'; // 🔥 Trocado para file_picker
import 'package:image_cropper/image_cropper.dart'; // 🔥 Import do cropper
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_dropdown_with_add.dart';

import '../providers/projeto_form_provider.dart';
import '../providers/projetos_provider.dart';
import '../providers/clientes_provider.dart';
import '../providers/notificacoes_provider.dart';
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

  // 🔥 NOVA LÓGICA DE FOTO COM ENQUADRAMENTO
  Future<void> _escolherImagem() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(type: FileType.image);
      
      if (result != null && result.files.single.path != null) {
        final pickedFilePath = result.files.single.path!;

        CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFilePath,
          aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9), // Força 16:9
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Enquadrar Capa',
              toolbarColor: AppColors.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.ratio16x9,
              lockAspectRatio: true,
              hideBottomControls: false,
            ),
            IOSUiSettings(
              title: 'Enquadrar Capa',
              aspectRatioLockEnabled: true,
              resetButtonHidden: true,
            ),
          ],
        );

        if (croppedFile != null) {
          // Salva o arquivo recortado no provider
          ref.read(projetoFormProvider.notifier).update(
            (state) => state.copyWith(imagemProjeto: File(croppedFile.path)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erro ao selecionar ou cortar imagem: $e', isError: true);
      }
    }
  }

  Future<void> _salvarProjetoCompleto() async {
    final formState = ref.read(projetoFormProvider);
    final user = ref.read(currentUserProvider);

    if (user == null || user.empresaId == null) {
      _showSnackBar('Erro: Empresa não identificada no seu perfil.', isError: true);
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

      final novoProjetoId = await repo.createProject(
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

      // Cliente já cadastrado (não é convite por e-mail): o projeto já
      // nasceu com o vínculo 'pendente' — falta só disparar a notificação
      // pros admins da empresa cliente aceitarem.
      String avisoConvite = '';
      if (!formState.isNovoCliente && formState.clienteId != null) {
        try {
          await ref.read(notificacoesControllerProvider).enviarNotificacaoConviteCliente(
                projetoId: novoProjetoId,
                empresaClienteId: formState.clienteId!,
                nomeProjeto: _nomeController.text.trim(),
              );
        } catch (e) {
          avisoConvite = ' Porém não foi possível notificar o cliente: ${e.toString().replaceAll('Exception: ', '')}';
        }
      }

      ref.invalidate(projetoFormProvider);
      ref.invalidate(filteredProjectsProvider);

      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('Projeto criado com sucesso!$avisoConvite', isError: avisoConvite.isNotEmpty);
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
    
    final rascunho = ref.watch(projetoFormProvider);
    final clientesDropdownAsync = ref.watch(dropdownClientesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 🔥 HEADER / IMAGEM DO PROJETO (Agora retangular 16:9)
        GestureDetector(
          onTap: _estaSalvando ? null : _escolherImagem,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.greyVeryLight,
                  borderRadius: BorderRadius.circular(16),
                  image: rascunho.imagemProjeto != null
                      ? DecorationImage(
                          image: FileImage(rascunho.imagemProjeto!),
                          fit: BoxFit.cover,
                        )
                      : null, // Deixamos o placeholder de fallback se não tiver
                ),
                // Exibe o ícone e texto só quando não tem imagem selecionada
                child: rascunho.imagemProjeto == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 32, color: AppColors.greyMedium),
                          SizedBox(height: 8),
                          Text(
                            'Adicionar capa',
                            style: TextStyle(color: AppColors.greyMediumDark, fontSize: 14),
                          ),
                        ],
                      )
                    : null,
              ),
              // Botãozinho de lápis igual ao da tela de Informações
              if (rascunho.imagemProjeto != null)
                Positioned(
                  bottom: -15,
                  right: 15,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.edit_square, color: AppColors.textDark, size: 24),
                  ),
                ),
            ],
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

        CustomButton(
          text: _estaSalvando ? 'Salvando...' : 'Criar',
          showArrow: false,
          onPressed: _estaSalvando ? null : _salvarProjetoCompleto,
        ),

        SizedBox(height: bottomPadding > 0 ? bottomPadding : 16),
      ],
    );
  }
}