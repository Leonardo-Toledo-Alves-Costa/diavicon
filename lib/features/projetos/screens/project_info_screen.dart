import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_dropdown.dart'; 
import '../../../core/widgets/custom_button.dart'; // 🔥 Import do seu botão global
import '../../../core/widgets/diavicon_alerts.dart';
import '../../../core/widgets/status_badge.dart'; 
import '../models/projeto_model.dart'; 
import '../providers/projetos_provider.dart';

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

  // 🔥 VARIÁVEIS PARA RASTREAR O ESTADO ORIGINAL (Antes da edição)
  bool _isInitialized = false;
  String _initialNome = '';
  String _initialDesc = '';
  String? _initialStatus;
  String? _initialPrioridade;
  
  bool _isSaving = false; // Controle do loading do botão de salvar

  @override
  void initState() {
    super.initState();
    // Adiciona "olheiros" nos campos de texto para atualizar a tela quando o usuário digitar
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
    setState(() {}); // Apenas recarrega a tela para recalcular o "_hasChanges"
  }

  // 🔥 GETTER MÁGICO: Retorna TRUE se algo foi alterado
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
    // Só preenche na primeira vez que a tela carrega
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

      // Joga os valores originais para a tela
      _nomeController.text = _initialNome;
      _descController.text = _initialDesc;
      _statusSelecionado = _initialStatus;
      _prioridadeSelecionada = _initialPrioridade;
      
      _isInitialized = true; // Trava para não sobrescrever o que o usuário digitar
    }
  }

  String _formatarStatusCliente(String? statusDb) {
    if (statusDb == 'ativo') return 'Vinculado';
    if (statusDb == 'pendente') return 'Pendente';
    return 'Não Vinculado';
  }

  // 🔥 LÓGICA DE FOTO COM ENQUADRAMENTO (CROP)
  Future<void> _pickImage() async {
    try {
      // 1. Abre a galeria para escolher a foto
      FilePickerResult? result = await FilePicker.pickFiles(type: FileType.image);
      
      if (result != null && result.files.single.path != null) {
        final pickedFilePath = result.files.single.path!;

        // 2. Abre a tela de enquadramento (Crop)
        CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFilePath,
          aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9), // 🔥 Força o formato de capa!
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Enquadrar Capa',
              toolbarColor: AppColors.primary, // Sua cor Laranja DiaViCon
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.ratio16x9,
              lockAspectRatio: true, // Não deixa o usuário bagunçar a proporção
              hideBottomControls: false,
            ),
            IOSUiSettings(
              title: 'Enquadrar Capa',
              aspectRatioLockEnabled: true, // Trava a proporção no iOS também
              resetButtonHidden: true,
            ),
          ],
        );

        // 3. Se o usuário confirmou o corte, atualiza a tela!
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

  // 🔥 FUNÇÃO DE SALVAR REAL (Integrada com o Banco de Dados)
  Future<void> _salvarAlteracoes() async {
    setState(() => _isSaving = true);
    
    try {
      // Chama o repositório que acabamos de criar, passando os dados da tela
      await ref.read(projetoRepositoryProvider).updateProject(
        projetoId: widget.projetoId,
        nome: _nomeController.text.trim(),
        descricao: _descController.text.trim(),
        statusNomeUI: _statusSelecionado ?? 'Em Andamento',
        prioridadeNomeUI: _prioridadeSelecionada ?? 'Média',
        novaImagem: _novaImagemCapa,
      );

      // Invalida a tela de detalhes e a home para elas recarregarem sozinhas com os dados novos
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

  @override
  Widget build(BuildContext context) {
    final projetoAsync = ref.watch(projectDetailProvider(widget.projetoId));
    final usuarioEmpresaIdAsync = ref.watch(loggedUserCompanyIdProvider);

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Column(
          children: [
            Text(
              'Projeto',
              style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              'Informações',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      
      // 🔥 O BOTÃO DE SALVAR QUE SÓ APARECE SE TIVER MUDANÇAS
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
          : null, // Se não tiver mudanças, não mostra nada!

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
                  subtitle: 'As estruturas são referentes ao cliente do projeto, sendo este ponto focal do projeto.',
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
                _buildGestoraCard(nomeGestora, canEdit),
                
                const SizedBox(height: 40), 
              ],
            ),
          );
        },
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
          style: const TextStyle(fontSize: 13, color: AppColors.greyMediumDark),
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
        if (canEdit)
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
            child: const Text('Vincular', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildGestoraCard(String nome, bool canEdit) {
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
            onTap: () {
              DiaviconAlerts.show(context, 'Editar Gestora', 'Abrirá a lista de empresas ativas para transferir a gestão.', isAviso: true);
            },
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