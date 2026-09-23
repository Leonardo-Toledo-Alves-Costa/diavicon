import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';
import 'package:diavicon/core/utils/diavicon_modal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/compact_button.dart';
import '../../../core/widgets/confirmar_exclusao_dialog.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_dropdown.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/diavicon_alerts.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/resumo_exclusao_accordion.dart';
import '../../equipe/providers/equipe_provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../estrutura/models/estrutura_model.dart';
import '../../estrutura/providers/estrutura_provider.dart';
import '../controllers/clientes_projeto_controller.dart';
import '../controllers/empresas_projeto_controller.dart';
import '../models/projeto_model.dart';
import '../providers/projetos_provider.dart';
import '../widgets/busca_cliente_modal.dart';
import '../widgets/trocar_gestora_modal.dart';

class ProjectInfoScreen extends ConsumerStatefulWidget {
  final String projetoId;

  const ProjectInfoScreen({super.key, required this.projetoId});

  @override
  ConsumerState<ProjectInfoScreen> createState() => _ProjectInfoScreenState();
}

class _ProjectInfoScreenState extends ConsumerState<ProjectInfoScreen> {
  static const _knownStatusOptions = <String>[
    'Em andamento',
    'Concluído',
    'Atrasado',
    'Parado',
    'Cancelado',
  ];
  static const _knownPriorityOptions = <String>['Baixa', 'Média', 'Alta'];

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

      _initialStatus = projeto.statusNome;
      _initialPrioridade = projeto.prioridadeNome;

      _nomeController.removeListener(_onFieldChanged);
      _descController.removeListener(_onFieldChanged);
      _nomeController.text = _initialNome;
      _descController.text = _initialDesc;
      _nomeController.addListener(_onFieldChanged);
      _descController.addListener(_onFieldChanged);
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
        title: const Text(
          'Alterações não salvas',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Você fez alterações que ainda não foram salvas. Se sair agora, perderá todas as mudanças. Deseja realmente sair?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Ficar na Tela',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sair sem salvar',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
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
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.image,
      );

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
        DiaviconAlerts.show(
          context,
          'Erro',
          'Não foi possível selecionar ou cortar a imagem: $e',
          isErro: true,
        );
      }
    }
  }

  Future<void> _salvarAlteracoes() async {
    setState(() => _isSaving = true);

    try {
      await ref
          .read(projectRepositoryProvider)
          .updateProject(
            projetoId: widget.projetoId,
            nome: _nomeController.text.trim(),
            descricao: _descController.text.trim(),
            statusNomeUI: _statusSelecionado ?? 'Em andamento',
            prioridadeNomeUI: _prioridadeSelecionada ?? 'Média',
            novaImagem: _novaImagemCapa,
          );

      ref.invalidate(projectDetailProvider(widget.projetoId));
      ref.invalidate(projectsProvider);

      if (mounted) {
        DiaviconAlerts.show(
          context,
          'Sucesso!',
          'Informações do projeto atualizadas com sucesso!',
        );

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
        DiaviconAlerts.show(
          context,
          'Erro ao salvar',
          e.toString().replaceAll('Exception: ', ''),
          isErro: true,
        );
        setState(() => _isSaving = false);
      }
    }
  }

  /// Exclui o projeto e, se a empresa do usuário for gestora de alguma
  /// estrutura vinculada a ele, pergunta se quer excluir essa(s)
  /// estrutura(s) também (e todos os elementos/ensaios dela).
  Future<void> _excluirProjeto(ProjetoModel projeto) async {
    Map<String, List<String>> resumoProjeto = const {};
    try {
      resumoProjeto = await ref.read(projectRepositoryProvider).buscarResumoExclusao(widget.projetoId);
    } catch (_) {
      // Segue sem o resumo se a busca falhar — não trava a exclusão em si.
    }
    if (!mounted) return;

    final confirmar = await showConfirmarExclusaoDialog(
      context: context,
      titulo: 'Excluir Projeto',
      mensagem:
          'Deseja realmente excluir o projeto "${projeto.nome}"? Esta ação não poderá ser desfeita.',
      extraContent: ResumoExclusaoAccordion(itensPorCategoria: resumoProjeto),
    );
    if (confirmar != true || !mounted) return;

    // Precisa buscar as estruturas vinculadas ANTES de excluir o projeto —
    // o vínculo (projeto_estruturas) some junto quando o projeto for apagado.
    final empresaId = ref.read(loggedUserCompanyIdProvider).value;
    List<EstruturaModel> estruturasGerenciadas = [];
    if (empresaId != null) {
      try {
        estruturasGerenciadas = await ref
            .read(estruturaRepositoryProvider)
            .buscarEstruturasGerenciadasDoProjeto(widget.projetoId, empresaId);
      } catch (_) {
        // Segue sem oferecer a exclusão em cascata da estrutura se essa busca falhar.
      }
    }

    try {
      await ref.read(projectRepositoryProvider).deleteProject(widget.projetoId);
    } catch (e) {
      if (mounted) {
        DiaviconAlerts.show(
          context,
          'Erro',
          'Falha ao excluir projeto: $e',
          isErro: true,
        );
      }
      return;
    }

    ref.invalidate(projectsProvider);
    ref.invalidate(projectDetailProvider(widget.projetoId));

    if (!mounted) return;

    if (estruturasGerenciadas.isNotEmpty) {
      final nomes = estruturasGerenciadas.map((e) => e.nome).join(', ');

      // Combina o resumo de todas as estruturas gerenciadas nessa mesma lista.
      final resumoEstruturas = <String, List<String>>{};
      for (final estrutura in estruturasGerenciadas) {
        try {
          final resumo = await ref.read(estruturaRepositoryProvider).buscarResumoExclusao(estrutura.id);
          for (final entrada in resumo.entries) {
            resumoEstruturas.putIfAbsent(entrada.key, () => []).addAll(entrada.value);
          }
        } catch (_) {
          // Segue sem o resumo dessa estrutura se a busca falhar.
        }
      }
      resumoEstruturas['Estruturas'] = estruturasGerenciadas.map((e) => e.nome ?? 'Sem nome').toList();
      if (!mounted) return;

      final confirmarEstrutura = await showConfirmarExclusaoDialog(
        context: context,
        titulo: 'Excluir estrutura também?',
        mensagem:
            'O projeto foi excluído. Sua empresa é a gestora de "$nomes" — deseja excluir também essa estrutura (e todos os elementos e ensaios vinculados a ela)?',
        extraContent: ResumoExclusaoAccordion(itensPorCategoria: resumoEstruturas),
      );

      if (confirmarEstrutura == true && mounted) {
        for (final estrutura in estruturasGerenciadas) {
          try {
            await ref
                .read(estruturaRepositoryProvider)
                .excluirEstrutura(estrutura.id);
          } catch (e) {
            if (mounted) {
              DiaviconAlerts.show(
                context,
                'Erro',
                'Falha ao excluir a estrutura "${estrutura.nome}": $e',
                isErro: true,
              );
            }
          }
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Projeto excluído com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Confirmar Transferência',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Tem certeza que deseja transferir a gestão para $nomeEmpresa? Sua empresa perderá as permissões administrativas deste projeto.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctxConfirma),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: AppColors.greyMedium),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctxConfirma);

                    try {
                      await ref
                          .read(empresasProjetoControllerProvider)
                          .alterarEmpresaGestora(
                            projetoId: projeto.id,
                            novaEmpresaGestoraId: novaEmpresaId,
                          );

                      if (mounted) {
                        ref.invalidate(projectDetailProvider(projeto.id));
                        setState(() {
                          _isInitialized = false;
                        });

                        DiaviconAlerts.show(
                          context,
                          'Sucesso!',
                          'Gestão transferida com sucesso!',
                        );
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
                  child: const Text(
                    'Transferir',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
    final podeGerenciarAsync = ref.watch(
      permissaoEdicaoEquipeProvider(widget.projetoId),
    );

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _verificarSaida();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,

        appBar: CustomAppBar(
          title: 'Projeto',
          showBackButton: true,
          onBackPressed: _verificarSaida,
          showMenuButton: false,
          showNotificationButton: false,
          titleWidget: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Projeto',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Informações',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
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
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : CustomButton(
                          text: 'Salvar Alterações',
                          onPressed: _salvarAlteracoes,
                        ),
                ),
              )
            : null,

        body: projetoAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, stack) =>
              Center(child: Text('Erro ao carregar dados: $err')),
          data: (projeto) {
            _preencherControladores(projeto);

            final nomeGestora = projeto.empresaNome;
            final nomeCliente = projeto.clienteNome ?? 'Cliente não definido';
            final statusVinculoCliente = _formatarStatusCliente(
              projeto.statusVinculoCliente,
            );

            bool canEdit = usuarioEmpresaIdAsync.maybeWhen(
              data: (empresaIdLogada) =>
                  projeto.empresaGestoraId == empresaIdLogada,
              orElse: () => false,
            );
            final canManage = canEdit && (podeGerenciarAsync.value ?? false);
            final statusOptions = _optionsFor(
              _knownStatusOptions,
              _statusSelecionado,
            );
            final priorityOptions = _optionsFor(
              _knownPriorityOptions,
              _prioridadeSelecionada,
            );

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCoverImage(projeto.imageUrl, canManage),

                  const SizedBox(height: 24),

                  CustomTextField(
                    label: 'Nome',
                    hint: 'Nome do Projeto',
                    controller: _nomeController,
                    enabled: canManage,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: IgnorePointer(
                          ignoring: !canManage,
                          child: Opacity(
                            opacity: canManage ? 1.0 : 0.6,
                            child: CustomDropdown<String>(
                              label: 'Status',
                              value: _statusSelecionado,
                              items: statusOptions.map((String valor) {
                                return DropdownMenuItem<String>(
                                  value: valor,
                                  child: Text(
                                    valor,
                                    style: const TextStyle(
                                      color: AppColors.textDark,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (novoValor) {
                                if (novoValor != null) {
                                  setState(
                                    () => _statusSelecionado = novoValor,
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: IgnorePointer(
                          ignoring: !canManage,
                          child: Opacity(
                            opacity: canManage ? 1.0 : 0.6,
                            child: CustomDropdown<String>(
                              label: 'Prioridade',
                              value: _prioridadeSelecionada,
                              items: priorityOptions.map((String valor) {
                                return DropdownMenuItem<String>(
                                  value: valor,
                                  child: Text(
                                    valor,
                                    style: const TextStyle(
                                      color: AppColors.textDark,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (novoValor) {
                                if (novoValor != null) {
                                  setState(
                                    () => _prioridadeSelecionada = novoValor,
                                  );
                                }
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
                    enabled: canManage,
                  ),

                  const SizedBox(height: 32),
                  const Divider(color: AppColors.inputBorder),
                  const SizedBox(height: 24),

                  _buildSectionHeader(
                    title: 'Cliente proprietário',
                    subtitle:
                        'As estruturas são referentes ao cliente do projeto, sendo este ponto focal do projeto.',
                  ),
                  const SizedBox(height: 16),
                  _buildClienteCard(
                    nomeCliente,
                    statusVinculoCliente,
                    canManage,
                    projeto.clienteFotoUrl,
                  ),

                  const SizedBox(height: 24),
                  const Divider(color: AppColors.inputBorder),
                  const SizedBox(height: 24),

                  _buildSectionHeader(
                    title: 'Gestora do projeto',
                    subtitle:
                        'A empresa gestora do projeto possui todas as permissões de edição dos dados.',
                  ),
                  const SizedBox(height: 16),
                  _buildGestoraCard(
                    nomeGestora,
                    projeto.empresaFotoUrl,
                    canManage,
                    () => _abrirModalTrocaGestora(projeto),
                  ),

                  if (canManage &&
                      ref.watch(currentUserProvider)?.isAdminEmpresa ==
                          true) ...[
                    const SizedBox(height: 24),
                    const Divider(color: AppColors.inputBorder),
                    const SizedBox(height: 24),
                    CompactButton(
                      text: 'Excluir Projeto',
                      icon: Icons.delete_outline,
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.error,
                      borderColor: AppColors.error,
                      elevation: 0,
                      onPressed: () => _excluirProjeto(projeto),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<String> _optionsFor(List<String> knownOptions, String? currentValue) {
    final options = List<String>.from(knownOptions);
    final normalizedCurrent = currentValue?.trim();
    if (normalizedCurrent == null || normalizedCurrent.isEmpty) return options;

    final knownIndex = options.indexWhere(
      (option) => option.toLowerCase() == normalizedCurrent.toLowerCase(),
    );
    if (knownIndex >= 0) {
      options[knownIndex] = normalizedCurrent;
    } else {
      options.insert(0, normalizedCurrent);
    }
    return options;
  }

  // --- WIDGETS AUXILIARES DA TELA ---

  Widget _buildCoverImage(String? imageUrl, bool canEdit) {
    DecorationImage defineImage() {
      if (_novaImagemCapa != null) {
        return DecorationImage(
          image: FileImage(_novaImagemCapa!),
          fit: BoxFit.cover,
        );
      }

      if (imageUrl != null &&
          imageUrl.isNotEmpty &&
          imageUrl.startsWith('http')) {
        return DecorationImage(
          image: StorageNetworkImage(imageUrl),
          fit: BoxFit.cover,
        );
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
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.edit_square,
                  color: AppColors.textDark,
                  size: 24,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.lato(
            fontSize: 13,
            fontWeight: FontWeight.w300,
            color: AppColors.greyMediumDark,
          ),
        ),
      ],
    );
  }

  Widget _buildClienteCard(
    String nome,
    String status,
    bool canEdit,
    String? fotoUrl,
  ) {
    final bool isVinculado = status == 'Vinculado';
    final bool isPendente = status == 'Pendente';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.greyVeryLight,
          backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty)
              ? StorageNetworkImage(fotoUrl)
              : const AssetImage('assets/images/user.png') as ImageProvider,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nome,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isVinculado
                      ? const Color(0xFFE6F4EA)
                      : (isPendente
                            ? const Color(0xFFFFF3E0)
                            : const Color(0xFFFFE5E5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isVinculado
                        ? Colors.green.shade800
                        : (isPendente
                              ? Colors.orange.shade800
                              : AppColors.error),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              if (isPendente) ...[
                const SizedBox(height: 4),
                Text(
                  'Aguardando aceite do convite',
                  style: GoogleFonts.lato(
                    fontSize: 11,
                    color: AppColors.greyMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (canEdit && !isPendente)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              elevation: 0,
            ),
            onPressed: () => _abrirBuscaClienteEConvidar(
              clienteAtualNome: isVinculado ? nome : null,
            ),
            child: Text(
              isVinculado ? 'Trocar' : 'Vincular',
              style: GoogleFonts.lato(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  /// [clienteAtualNome] só é informado quando já existe um cliente vinculado
  /// ('ativo') — nesse caso confirma antes de desvincular o atual e só então
  /// abre a busca pra convidar o novo.
  void _abrirBuscaClienteEConvidar({String? clienteAtualNome}) {
    if (clienteAtualNome != null) {
      showDialog(
        context: context,
        builder: (ctxConfirma) => AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Trocar cliente proprietário',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '$clienteAtualNome perderá o acesso a este projeto imediatamente. Deseja continuar e convidar outra empresa?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctxConfirma),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppColors.greyMedium),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctxConfirma);
                if (!mounted) return;
                _abrirBuscaClienteEConvidar();
              },
              child: const Text(
                'Continuar',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => BuscaClienteModal(
        onSelecionado: (empresaId, nomeEmpresa) async {
          try {
            await ref
                .read(clientesProjetoControllerProvider)
                .inviteExistingClient(
                  projectId: widget.projetoId,
                  clientCompanyId: empresaId,
                );
            ref.invalidate(projectDetailProvider(widget.projetoId));
            if (!mounted) return;
            DiaviconAlerts.show(
              context,
              'Convite enviado!',
              '$nomeEmpresa vai receber uma notificação para aceitar ser cliente deste projeto.',
            );
          } catch (e) {
            if (!mounted) return;
            DiaviconAlerts.show(
              context,
              'Erro',
              e.toString().replaceAll('Exception: ', ''),
              isErro: true,
            );
          }
        },
      ),
    );
  }

  Widget _buildGestoraCard(
    String nome,
    String? fotoUrl,
    bool canEdit,
    VoidCallback onTapEdit,
  ) {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.white,
          backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty)
              ? StorageNetworkImage(fotoUrl)
              : null,
          child: (fotoUrl == null || fotoUrl.isEmpty)
              ? const Icon(
                  Icons.business,
                  color: AppColors.greyMedium,
                  size: 28,
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            nome,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textDark,
            ),
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
