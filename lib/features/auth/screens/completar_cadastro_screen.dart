import 'package:diavicon/core/security/upload_seguro.dart';
import '../../../core/widgets/requisitos_senha.dart';
import 'dart:io';

import 'package:diavicon/core/utils/formatters/celular_formatter.dart';
import 'package:diavicon/core/utils/validators/celular_validator.dart';
import 'package:diavicon/core/utils/validators/validators_cadastro.dart';
import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/diavicon_alerts.dart';
import '../repositories/auth_operations_repository.dart';
import '../utils/auth_error_messages.dart';

class CompletarCadastroScreen extends ConsumerStatefulWidget {
  const CompletarCadastroScreen({super.key});

  @override
  ConsumerState<CompletarCadastroScreen> createState() => _CompletarCadastroScreenState();
}

class _CompletarCadastroScreenState extends ConsumerState<CompletarCadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nomeController = TextEditingController();
  final _sobrenomeController = TextEditingController();
  final _cargoController = TextEditingController();
  final _celularController = TextEditingController();
  final _senhaController = TextEditingController();
  /// Depois da primeira tentativa, o que falta na senha fica em vermelho.
  bool _tentouEnviarSenha = false;
  final _confirmarSenhaController = TextEditingController();
  
  bool _isLoading = false;
  bool _dadosCarregados = false;
  
  // Variável para guardar a foto do usuário
  XFile? _fotoPerfil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarDadosIniciais();
    });
  }

  void _carregarDadosIniciais() {
    final usuario = ref.read(currentUserProvider);
    if (usuario != null) {
      _nomeController.text = usuario.nome ?? '';
      _sobrenomeController.text = usuario.sobrenome ?? '';
      _cargoController.text = usuario.cargo ?? '';
      _celularController.text = usuario.celular ?? '';
      setState(() {
        _dadosCarregados = true;
      });
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _sobrenomeController.dispose();
    _cargoController.dispose();
    _celularController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  // ── Lógica da Foto ───────────────────────────────────────────────────────
  Future<void> _selecionarFoto() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024, 
      maxHeight: 1024,
    );

    if (img != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: img.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), 
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar Foto',
            toolbarColor: AppColors.primary, 
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true, 
          ),
          IOSUiSettings(
            title: 'Ajustar Foto',
            cancelButtonTitle: 'Cancelar',
            doneButtonTitle: 'Concluir',
            aspectRatioLockEnabled: true, 
            resetButtonHidden: true,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _fotoPerfil = XFile(croppedFile.path); 
        });
      }
    }
  }

  // ── Submissão do Formulário ──────────────────────────────────────────────
  Future<void> _finalizarCadastro() async {
    if (_fotoPerfil == null) {
      DiaviconAlerts.show(context, 'Foto Obrigatória', 'Por favor, adicione uma foto de perfil para continuar.', isAviso: true);
      return;
    }

    setState(() => _tentouEnviarSenha = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Qual passo está em execução. Serve pra diagnosticar o relato de
    // "falha ao salvar e acessar, mas reabrir o app resolve": sem isso o
    // catch lá embaixo mostra uma mensagem genérica (authErrorMessage achata
    // todo AuthException) e não dá pra saber se o cadastro chegou a ser
    // concluído no servidor ou não.
    var etapa = 'iniciando';

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) throw Exception('Usuário não autenticado.');

      // Upload da Foto
      String? fotoUrl;
      // perfis/<uid>_<uuid>.<ext>: a policy de escrita do bucket `avatars`
      // exige o uid seguido de '_' no início do nome. Tipo, nome e
      // Content-Type decididos pelo app (ver upload_seguro.dart).
      etapa = 'upload da foto';
      final caminhoStorage = await supabase.storage
          .from('avatars')
          .enviarArquivoSeguro('perfis', File(_fotoPerfil!.path), prefixo: '${user.id}_');
      fotoUrl = supabase.storage.from('avatars').getPublicUrl(caminhoStorage);

      // Atualiza Senha
      //
      // ATENÇÃO: isto roda ANTES de complete_profile e emite um evento de
      // auth, que dispara sincronizarSessaoAtiva() em paralelo. Se a troca de
      // senha rotacionar o token, as chamadas seguintes podem sair com
      // credencial em transição. É a hipótese principal pro sintoma relatado.
      etapa = 'atualizar senha';
      await supabase.auth.updateUser(
        UserAttributes(password: _senhaController.text),
      );

      etapa = 'concluir perfil (complete_profile)';
      await AuthOperationsRepository().execute('complete_profile', {
        'nome': _nomeController.text.trim(),
        'sobrenome': _sobrenomeController.text.trim(),
        'celular': _celularController.text.trim(),
        'foto_url': fotoUrl,
      });

      // Atualiza Provider
      //
      // Passado este ponto o cadastro JÁ está concluído no servidor: qualquer
      // falha daqui pra frente é só de estado local, e reabrir o app resolve.
      etapa = 'reler perfil';
      final repo = ref.read(authRepositoryProvider);
      final perfilAtualizado = await repo.getUsuarioPerfil(user.id);
      if (perfilAtualizado != null) {
        ref.read(currentUserProvider.notifier).setUser(perfilAtualizado);
      }

      if (!mounted) return;

      DiaviconAlerts.show(context, 'Cadastro Completo!', 'Bem-vindo à equipe! Seu acesso foi liberado.');

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.go('/projetos');
      });

    } catch (e, pilha) {
      // Log completo pro diagnóstico (a mensagem da tela é deliberadamente
      // genérica e esconde o código do provedor).
      debugPrint('[CompletarCadastro] falhou na etapa "$etapa": $e');
      debugPrintStack(stackTrace: pilha, label: '[CompletarCadastro]');
      if (!mounted) return;
      DiaviconAlerts.show(
        context,
        'Erro',
        '${authErrorMessage(e)}\n\nEtapa: $etapa',
        isErro: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Column(
          children: [
            // 🔥 CABEÇALHO LARANJA
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 24, 
                bottom: 32,
                left: 24,
                right: 24
              ),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Complete seu Perfil',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Adicione sua foto e confirme seus dados.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  
                  GestureDetector(
                    onTap: _selecionarFoto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: AppColors.greyVeryLight,
                            backgroundImage: _fotoPerfil != null ? FileImage(File(_fotoPerfil!.path)) : null,
                            child: _fotoPerfil == null 
                                ? const Icon(Icons.person, size: 50, color: AppColors.greyMedium)
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt, size: 20, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 🔥 FORMULÁRIO COM OS CAMPOS VOLTANDO À VIDA
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: 24.0,
                  left: 24.0,
                  right: 24.0,
                  // Pega a barra do celular e dá 48 pixels de sobra pra cima!
                  bottom: MediaQuery.of(context).padding.bottom + 48.0, 
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              label: 'Nome',
                              hint: 'Seu nome',
                              isRequired: true,
                              controller: _nomeController,
                              validator: (val) => val == null || val.isEmpty ? 'Obrigatório' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CustomTextField(
                              label: 'Sobrenome',
                              hint: 'Seu sobrenome',
                              isRequired: true,
                              controller: _sobrenomeController,
                              validator: (val) => val == null || val.isEmpty ? 'Obrigatório' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      CustomTextField(
                        label: 'Cargo / Função',
                        hint: 'Ex: Desenvolvedor', 
                        controller: _cargoController,
                        enabled: false, 
                        validator: (val) => val == null || val.isEmpty ? 'Obrigatório' : null,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          'Seu cargo foi definido pelo gestor.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        label: 'Celular (com DDD)',
                        hint: '(11) 99999-9999',
                        isRequired: true,
                        controller: _celularController,
                        keyboardType: TextInputType.phone,
                        // 🔥 Chamando a máscara e o validador modulares:
                        inputFormatters: [CelularFormatter.mask],
                        validator: CelularValidator.validar,
                      ),
                      const SizedBox(height: 32),
                      
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      const Text(
                        'Segurança',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        label: 'Criar Senha',
                        hint: 'Maiúscula, minúscula e número, com 8 ou mais',
                        isRequired: true, 
                        controller: _senhaController,
                        obscureText: true,
                        validator: ValidatorsCadastro.senha,
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _senhaController,
                        builder: (_, valor, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ForcaSenha(senha: valor.text),
                            RequisitosSenha(senha: valor.text, marcarFaltantes: _tentouEnviarSenha),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        label: 'Confirmar Senha',
                        hint: 'Digite a senha novamente',
                        isRequired: true, 
                        controller: _confirmarSenhaController,
                        obscureText: true,
                        validator: (val) {
                          if (val != _senhaController.text) return 'As senhas não coincidem';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      _isLoading
                          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                          : CustomButton(
                              text: 'Salvar e Acessar',
                              onPressed: _finalizarCadastro,
                            ),
                    ],
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
