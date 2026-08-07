import 'dart:io';
import 'package:diavicon/core/utils/diavicon_modal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_dropdown.dart'; 
import '../../../core/widgets/custom_button.dart'; 
import '../../../core/widgets/diavicon_alerts.dart';
import '../../../core/widgets/status_badge.dart'; 

import '../../../core/widgets/custom_appbar.dart';

import '../models/projeto_model.dart'; 
import '../providers/projetos_provider.dart';
import '../providers/empresas_projeto_provider.dart';
import '../widgets/trocar_gestora_modal.dart'; 

class ProjectInfoScreen extends ConsumerStatefulWidget {
  final String projetoId;

  const ProjectInfoScreen({super.key, required this.projetoId});

  @override
  ConsumerState<ProjectInfoScreen> createState() => _ProjectInfoScreenState();
}

class _ProjectInfoScreenState extends ConsumerState<ProjectInfoScreen> {
  final _nomeController = TextEditingController();
  final _descController = TextEditingController();
  
  String? _statusSelecionado;
  String? _prioridadeSelecionada;
  File? _novaImagemCapa; 

  bool _isInitialized = false;
  String _initialNome = '';
  String _initialDesc = '';
  String? _initialStatus;
  String? _initialPrioridade;
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nomeController.addListener(_onFieldChanged);
    _descController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nomeController.removeListener(_onFieldChanged);
    _descController.removeListener(_onFieldChanged);
    _nomeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {}); 
  }

  bool get _hasChanges {
    if (!_isInitialized) return false;
    if (_nomeController.text != _initialNome) return true;
    if (_descController.text != _initialDesc) return true;
    if (_statusSelecionado != _initialStatus) return true;
    if (_prioridadeSelecionada != _initialPrioridade) return true;
    if (_novaImagemCapa != null) return true;
    return false;
  }

  void _preencherControladores(ProjetoModel projeto) {
    if (!_isInitialized) {
      _initialNome = projeto.nome;
      _initialDesc = projeto.descricao ?? '';

      switch (projeto.statusBadge) {
        case BadgeStatus.concluido:
          _initialStatus = 'Concluído';
          break;
        case BadgeStatus.cancelado:
          _initialStatus = 'Cancelado'; 
          break;
        case BadgeStatus.emAndamento:
        default:
          _initialStatus = 'Em Andamento';
          break;
      }
      _initialPrioridade = projeto.prioridadeNome;

      _nomeController.text = _initialNome;
      _descController.text = _initialDesc;
      _statusSelecionado = _initialStatus;
      _prioridadeSelecionada = _initialPrioridade;
      
      _isInitialized = true;
    }
  }

  String _formatarStatusCliente(String? statusDb) {
    if (statusDb == 'ativo') return 'Vinculado';
    if (statusDb == 'pendente') return 'Pendente';
    return 'Não Vinculado';
  }

  Future<void> _verificarSaida() async {
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }

    final sair = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Alterações não salvas', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        content: const Text('Você fez alterações que ainda não foram salvas. Se sair agora, perderá todas as mudanças. Deseja realmente sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ficar na Tela', style: TextStyle(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair sem salvar', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (sair == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(type: FileType.image);
      
      if (result != null && result.files.single.path != null) {
        final pickedFilePath = result.files.single.path!;

        CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFilePath,
          aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9), 
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
          setState(() {
            _novaImagemCapa = File(croppedFile.path);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        DiaviconAlerts.show(context, 'Erro', 'Não foi possível selecionar ou cortar a imagem: $e', isErro: true);
      }
    }
  }

  Future<void> _salvarAlteracoes() async {
    setState(() => _isSaving = true);
    
    try {
      await ref.read(projetoRepositoryProvider).updateProject(
        projetoId: widget.projetoId,
        nome: _nomeController.text.trim(),
        descricao: _descController.text.trim(),
        statusNomeUI: _statusSelecionado ?? 'Em Andamento',
        prioridadeNomeUI: _prioridadeSelecionada ?? 'Média',
        novaImagem: _novaImagemCapa,
      );

      ref.invalidate(projectDetailProvider(widget.projetoId));
      ref.invalidate(filteredProjectsProvider);

      if (mounted) {
        DiaviconAlerts.show(context, 'Sucesso!', 'Informações do projeto atualizadas com sucesso!');
        
        setState(() {
          _initialNome = _nomeController.text;
          _initialDesc = _descController.text;
          _initialStatus = _statusSelecionado;
          _initialPrioridade = _prioridadeSelecionada;
          _novaImagemCapa = null; 
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        DiaviconAlerts.show(context, 'Erro ao salvar', e.toString().replaceAll('Exception: ', ''), isErro: true);
        setState(() => _isSaving = false);
      }
    }
  }

  void _abrirModalTrocaGestora(ProjetoModel projeto) {
    showDiaviconModal(
      context: context,
      title: 'Selecionar empresa',
      centerTitle: false,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.center,
      body: TrocarGestoraBody(
        projetoId: projeto.id,
        empresaGestoraAtualId: projeto.empresaGestoraId ?? '',
        onSelecionada: (novaEmpresaId, nomeEmpresa) {
          Navigator.pop(context); 
          
          showDialog(
            context: context,
            builder: (ctxConfirma) => AlertDialog(
              backgroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Confirmar Transferência', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
              content: Text('Tem certeza que deseja transferir a gestão para $nomeEmpresa? Sua empresa perderá as permissões administrativas deste projeto.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctxConfirma),
                  child: const Text('Cancelar', style: TextStyle(color: AppColors.greyMedium)),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctxConfirma); 
                    
                    try {
                      await ref.read(empresasProjetoControllerProvider).alterarEmpresaGestora(
                        projetoId: projeto.id,
                        novaEmpresaGestoraId: novaEmpresaId,
                      );
                      
                      if (mounted) {
                        await ref.refresh(projectDetailProvider(projeto.id).future);

                        setState(() {
                          _isInitialized = false; 
                        });
                        
                        DiaviconAlerts.show(context, 'Sucesso!', 'Gestão transferida com sucesso!');
                      }
                    } catch (e) {
                      if (mounted) {
                        DiaviconAlerts.show(
                          context, 
                          'Erro na transferência', 
                          e.toString().replaceAll('Exception: ', ''), 
                          isErro: true,
                        );
                      }
                    }
                  },
                  child: const Text('Transferir', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projetoAsync = ref.watch(projectDetailProvider(widget.projetoId));
    final usuarioEmpresaIdAsync = ref.watch(loggedUserCompanyIdProvider);

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _verificarSaida();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        
        // 🔥 endDrawer foi removido completamente!

        appBar: CustomAppBar(
          title: 'Projeto',
          showBackButton: true,
          onBackPressed: _verificarSaida,
          showMenuButton: false, // 🔥 Menu desativado
          showNotificationButton: false, // 🔥 Sininho desativado
          titleWidget: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Projeto',
                style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
              ),
              Text(
                'Informações',
                style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        
        bottomNavigationBar: _hasChanges
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: _isSaving
                      ? const SizedBox(
                          height: 48,
                          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                        )
                      : CustomButton(
                          text: 'Salvar Alterações',
                          onPressed: _salvarAlteracoes,
                        ),
                ),
              )
            : null, 

        body: projetoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, stack) => Center(child: Text('Erro ao carregar dados: $err')),
          data: (projeto) {
            _preencherControladores(projeto);

            final nomeGestora = projeto.empresaNome;
            final nomeCliente = projeto.clienteNome ?? 'Cliente não definido'; 
            final statusVinculoCliente = _formatarStatusCliente(projeto.statusVinculoCliente); 

            bool canEdit = usuarioEmpresaIdAsync.maybeWhen(
              data: (empresaIdLogada) => projeto.empresaGestoraId == empresaIdLogada,
              orElse: () => false,
            );

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCoverImage(projeto.imageUrl, canEdit),
                  
                  const SizedBox(height: 24),

                  CustomTextField(
                    label: 'Nome',
                    hint: 'Nome do Projeto',
                    controller: _nomeController,
                    enabled: canEdit,
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: IgnorePointer(
                          ignoring: !canEdit,
                          child: Opacity(
                            opacity: canEdit ? 1.0 : 0.6,
                            child: CustomDropdown<String>(
                              label: 'Status',
                              value: _statusSelecionado,
                              items: ['Em Andamento', 'Concluído', 'Cancelado'].map((String valor) {
                                return DropdownMenuItem<String>(
                                  value: valor,
                                  child: Text(
                                    valor, 
                                    style: const TextStyle(color: AppColors.textDark, fontSize: 13), 
                                    overflow: TextOverflow.ellipsis, 
                                  ),
                                );
                              }).toList(),
                              onChanged: (novoValor) {
                                if (novoValor != null) setState(() => _statusSelecionado = novoValor);
                              }, 
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: IgnorePointer(
                          ignoring: !canEdit,
                          child: Opacity(
                            opacity: canEdit ? 1.0 : 0.6,
                            child: CustomDropdown<String>(
                              label: 'Prioridade',
                              value: _prioridadeSelecionada,
                              items: ['Baixa', 'Média', 'Alta'].map((String valor) {
                                return DropdownMenuItem<String>(
                                  value: valor,
                                  child: Text(
                                    valor, 
                                    style: const TextStyle(color: AppColors.textDark, fontSize: 13), 
                                    overflow: TextOverflow.ellipsis, 
                                  ),
                                );
                              }).toList(),
                              onChanged: (novoValor) {
                                if (novoValor != null) setState(() => _prioridadeSelecionada = novoValor);
                              }, 
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  CustomTextField(
                    label: 'Descrição',
                    hint: 'Escreva detalhes sobre este projeto...',
                    controller: _descController,
                    maxLines: 4,
                    enabled: canEdit,
                  ),

                  const SizedBox(height: 32),
                  const Divider(color: AppColors.inputBorder),
                  const SizedBox(height: 24),

                  _buildSectionHeader(
                    title: 'Cliente proprietário',
                    subtitle: 'As estruturas são referentes ao cliente do projeto, sendo este point focal do projeto.',
                  ),
                  const SizedBox(height: 16),
                  _buildClienteCard(nomeCliente, statusVinculoCliente, canEdit),

                  const SizedBox(height: 24),
                  const Divider(color: AppColors.inputBorder),
                  const SizedBox(height: 24),

                  _buildSectionHeader(
                    title: 'Gestora do projeto',
                    subtitle: 'A empresa gestora do projeto possui todas as permissões de edição dos dados.',
                  ),
                  const SizedBox(height: 16),
                  _buildGestoraCard(nomeGestora, canEdit, () => _abrirModalTrocaGestora(projeto)),
                  
                  const SizedBox(height: 40), 
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES DA TELA ---

  Widget _buildCoverImage(String? imageUrl, bool canEdit) {
    DecorationImage defineImage() {
      if (_novaImagemCapa != null) {
        return DecorationImage(image: FileImage(_novaImagemCapa!), fit: BoxFit.cover);
      }
      
      if (imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
        return DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover);
      }

      return const DecorationImage(
        image: AssetImage('assets/images/project_placeholder1.png'),
        fit: BoxFit.cover,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 140,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.greyVeryLight,
            borderRadius: BorderRadius.circular(16),
            image: defineImage(),
          ),
        ),
        if (canEdit)
          Positioned(
            bottom: -15,
            right: 15,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.edit_square, color: AppColors.textDark, size: 24),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w300, color: AppColors.greyMediumDark),
        ),
      ],
    );
  }

  Widget _buildClienteCard(String nome, String status, bool canEdit) {
    final bool isVinculado = status == 'Vinculado';

    return Row(
      children: [
        const CircleAvatar(
          radius: 28,
          backgroundImage: AssetImage('assets/images/user.png'), 
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isVinculado ? const Color(0xFFE6F4EA) : const Color(0xFFFFE5E5), 
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isVinculado ? Colors.green.shade800 : AppColors.error, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 10
                  ),
                ),
              ),
            ],
          ),
        ),
        if (canEdit && !isVinculado)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              elevation: 0,
            ),
            onPressed: () {
              DiaviconAlerts.show(context, 'Vincular Cliente', 'Abrirá o modal para buscar CNPJ do cliente.', isAviso: true);
            },
            child: Text('Vincular', style: GoogleFonts.lato(color: AppColors.white, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildGestoraCard(String nome, bool canEdit, VoidCallback onTapEdit) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.white,
          child: Icon(Icons.business, color: AppColors.greyMedium, size: 28), 
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            nome,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark),
          ),
        ),
        if (canEdit)
          GestureDetector(
            onTap: onTapEdit,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, color: AppColors.white, size: 18),
            ),
          ),
      ],
    );
  }
}