import 'dart:io';
import 'package:diavicon/core/widgets/custom_appbar.dart';
import 'package:diavicon/features/elementos/widgets/nova_opcao_modal.dart';
import 'package:diavicon/features/elementos/widgets/novo_tipo_elemento_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_dropdown_with_add.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/diavicon_alerts.dart';

import '../widgets/bigger_custom_button.dart';
import '../widgets/novo_local_widget.dart';
import '../models/elemento_model.dart';
import '../providers/elemento_provider.dart';
import '../providers/opcoes_elemento_provider.dart'; 
import '../../projetos/providers/projetos_provider.dart';

import '../../estrutura/providers/local_provider.dart';

import 'planejamento_plantas_screen.dart';

class ElementoFormScreen extends ConsumerStatefulWidget {
  final String estruturaId;
  final String projetoId;
  final ElementoModel? elemento;
  final VoidCallback? onSalvo; 

  const ElementoFormScreen({
    super.key,
    required this.estruturaId,
    required this.projetoId,
    this.elemento,
    this.onSalvo,
  });

  @override
  ConsumerState<ElementoFormScreen> createState() => _ElementoFormScreenState();
}

class _ElementoFormScreenState extends ConsumerState<ElementoFormScreen> {
  final _nomeController = TextEditingController();

  String? _tipoElemento;
  String? _tipologiaEstrutural;
  String? _localElemento;
  String? _revestimento;

  List<String> _tipoElementoOptions = ['Pilar', 'Viga', 'Laje'];
  List<String> _tipologiaOptions = ['Concreto armado', 'Metalica', 'Mista'];
  List<String> _localOptions = ['Interno', 'Externo', 'Cobertura'];
  List<String> _revestimentoOptions = ['Pintura', 'Argamassa', 'Ceramica'];

  File? _novaImagemBanner;
  bool _isSubmitting = false;
  bool _isDirty = false;

  bool get _isEditing => widget.elemento != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _preencherDados();
    _nomeController.addListener(_marcarComoSujo);
  }

  void _preencherDados() {
    final el = widget.elemento!;
    _nomeController.text = el.nome ?? '';

    if (el.tipo != null && !_tipoElementoOptions.contains(el.tipo!)) _tipoElementoOptions.add(el.tipo!);
    _tipoElemento = el.tipo;

    if (el.tipologiaEstrutural != null && !_tipologiaOptions.contains(el.tipologiaEstrutural!)) _tipologiaOptions.add(el.tipologiaEstrutural!);
    _tipologiaEstrutural = el.tipologiaEstrutural;

    if (el.local != null && !_localOptions.contains(el.local!)) _localOptions.add(el.local!);
    _localElemento = el.local;

    if (el.revestimento != null && !_revestimentoOptions.contains(el.revestimento!)) _revestimentoOptions.add(el.revestimento!);
    _revestimento = el.revestimento;
  }

  void _marcarComoSujo() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _verificarSaida() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }

    final sair = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Alterações não salvas', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        content: const Text('Você fez alterações que ainda não foram salvas. Deseja sair e perder tudo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ficar', style: TextStyle(color: AppColors.primary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sair sem salvar', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );

    if (sair == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _alterarBanner() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Enquadrar Banner',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _novaImagemBanner = File(croppedFile.path);
          _isDirty = true;
        });
      }
    }
  }

  Future<void> _salvar() async {
    if (_nomeController.text.trim().isEmpty) {
      DiaviconAlerts.show(context, 'Atenção', 'O nome do elemento é obrigatório.', isErro: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(elementoRepositoryProvider);
      List<String> fotosFinais = widget.elemento?.fotos != null ? List.from(widget.elemento!.fotos!) : [];

      if (_novaImagemBanner != null) {
        final refId = _isEditing ? widget.elemento!.id : 'novo_${DateTime.now().millisecondsSinceEpoch}';
        final urlPublica = await repo.uploadFoto(elementoId: refId, caminhoLocalFoto: _novaImagemBanner!.path);
        
        if (fotosFinais.isNotEmpty) {
          fotosFinais[0] = urlPublica;
        } else {
          fotosFinais.add(urlPublica);
        }
      }

      ElementoModel elementoAtualizado;
      if (_isEditing) {
        elementoAtualizado = widget.elemento!.copyWith(
          nome: _nomeController.text.trim(),
          tipo: _tipoElemento,
          tipologiaEstrutural: _tipologiaEstrutural,
          local: _localElemento,
          revestimento: _revestimento,
          fotos: fotosFinais.isNotEmpty ? fotosFinais : null,
        );
      } else {
        elementoAtualizado = ElementoModel(
          id: '',
          estruturaId: widget.estruturaId,
          nome: _nomeController.text.trim(),
          tipo: _tipoElemento,
          tipologiaEstrutural: _tipologiaEstrutural,
          local: _localElemento,
          revestimento: _revestimento,
          fotos: fotosFinais.isNotEmpty ? fotosFinais : null,
          ativo: true,
        );
      }

      ElementoModel elementoSalvo;
      if (_isEditing) {
        elementoSalvo = await repo.atualizarElemento(elementoAtualizado);
      } else {
        elementoSalvo = await repo.criarElemento(elementoAtualizado, widget.estruturaId);
      }

      ref.invalidate(elementosPorEstruturaProvider(widget.estruturaId));
      widget.onSalvo?.call();

      if (mounted) {
        Navigator.pop(context, elementoSalvo);
        DiaviconAlerts.show(context, 'Sucesso!', _isEditing ? 'Elemento atualizado.' : 'Elemento criado.');
      }
    } catch (e) {
      if (mounted) {
        DiaviconAlerts.show(context, 'Erro', e.toString(), isErro: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleAddOption(ElementoInfoDropdownField field) async {
    String? newOption;

    if (field == ElementoInfoDropdownField.localElemento) {
      final novoLocalId = await showDialog<String>(
        context: context,
        barrierColor: Colors.transparent,
        builder: (_) => NovoLocalModal(estruturaId: widget.estruturaId),
      );
      
      if (novoLocalId != null) {
        try {
          final response = await Supabase.instance.client
              .from('estruturas_locais')
              .select('nome')
              .eq('id', novoLocalId)
              .single();
              
          setState(() {
            _isDirty = true;
            _localElemento = response['nome'] as String;
          });
        } catch (e) {
          debugPrint('Erro ao buscar nome do local: $e');
        }
      }
      return;
    } else if (field == ElementoInfoDropdownField.tipoElemento) {
      newOption = await showDialog<String>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.42),
        builder: (_) => const NovoTipoElementoModal(),
      );
    } else if (field == ElementoInfoDropdownField.tipologiaEstrutural) {
      newOption = await showNovaOpcaoModal(
        context,
        titulo: 'Nova Tipologia',
        campoBanco: 'tipologia',
      );
    } else if (field == ElementoInfoDropdownField.revestimento) {
      newOption = await showNovaOpcaoModal(
        context,
        titulo: 'Novo Revestimento',
        campoBanco: 'revestimento',
      );
    }

    if (newOption == null || newOption.trim().isEmpty) return;

    final normalized = newOption.trim();

    setState(() {
      _isDirty = true;
      switch (field) {
        case ElementoInfoDropdownField.tipoElemento:
          if (!_tipoElementoOptions.contains(normalized)) _tipoElementoOptions.add(normalized);
          _tipoElemento = normalized;
          break;
        case ElementoInfoDropdownField.tipologiaEstrutural:
          if (!_tipologiaOptions.contains(normalized)) _tipologiaOptions.add(normalized);
          _tipologiaEstrutural = normalized;
          break;
        case ElementoInfoDropdownField.revestimento:
          if (!_revestimentoOptions.contains(normalized)) _revestimentoOptions.add(normalized);
          _revestimento = normalized;
          break;
        default: break;
      }
    });

    ref.invalidate(opcoesFormularioElementoProvider);
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> options,
    required ElementoInfoDropdownField field,
    required bool canEdit,
  }) {
    final safeOptions = List<String>.from(options);
    if (value != null && value.isNotEmpty && !safeOptions.contains(value)) {
      safeOptions.add(value);
    }

    return IgnorePointer(
      ignoring: !canEdit,
      child: CustomDropdownWithAdd<String>(
        label: label,
        hint: 'Selecione',
        value: value,
        items: safeOptions.map((item) => DropdownMenuItem<String>(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (newValue) {
          if (!canEdit) return;
          setState(() {
            _isDirty = true;
            switch (field) {
              case ElementoInfoDropdownField.tipoElemento: _tipoElemento = newValue; break;
              case ElementoInfoDropdownField.tipologiaEstrutural: _tipologiaEstrutural = newValue; break;
              case ElementoInfoDropdownField.localElemento: _localElemento = newValue; break;
              case ElementoInfoDropdownField.revestimento: _revestimento = newValue; break;
            }
          });
        },
        onAddPressed: () async {
          _handleAddOption(field); 
        },
        isAddEnabled: canEdit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topContentPadding = MediaQuery.paddingOf(context).top + 124;
    final projetoAsync = ref.watch(projectDetailProvider(widget.projetoId));
    final usuarioEmpresaIdAsync = ref.watch(loggedUserCompanyIdProvider);
    
    final opcoesFormulario = ref.watch(opcoesFormularioElementoProvider);
    final locaisAsync = ref.watch(locaisPorEstruturaProvider(widget.estruturaId)); 

    List<String> tiposFinais = List.from(_tipoElementoOptions);
    List<String> tipologiasFinais = List.from(_tipologiaOptions);
    List<String> revestimentosFinais = List.from(_revestimentoOptions);
    List<String> locaisFinais = List.from(_localOptions); 

    opcoesFormulario.whenData((opcoes) {
      tiposFinais = {...tiposFinais, ...opcoes.tipos}.toList();
      tipologiasFinais = {...tipologiasFinais, ...opcoes.tipologias}.toList();
      revestimentosFinais = {...revestimentosFinais, ...opcoes.revestimentos}.toList();
    });

    locaisAsync.whenData((locais) {
      locaisFinais = {...locaisFinais, ...locais.map((l) => l.nome)}.toList();
    });

    bool canEdit = false;
    projetoAsync.whenData((projeto) {
      usuarioEmpresaIdAsync.whenData((empresaId) {
        canEdit = (projeto.empresaGestoraId == empresaId);
      });
    });

    String? imageUrl;
    if (_novaImagemBanner != null) {
      imageUrl = _novaImagemBanner!.path; 
    } else if (widget.elemento?.fotos != null && widget.elemento!.fotos!.isNotEmpty) {
      imageUrl = widget.elemento!.fotos!.first;
    }

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _verificarSaida();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: AppColors.primary),
        child: Scaffold(
          backgroundColor: Colors.white,
          extendBodyBehindAppBar: true,
          
          appBar: CustomAppBar(
            title: "",
            showBackButton: true,
            showMenuButton: false, 
            showNotificationButton: false, 
            titleWidget: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Elemento',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
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
          
          body: SafeArea(
            top: false,
            bottom: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(28, topContentPadding, 28, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ElementoBanner(
                    onEditPressed: canEdit ? _alterarBanner : null,
                    imageFile: _novaImagemBanner,
                    networkUrl: (_novaImagemBanner == null && imageUrl != null) ? imageUrl : null,
                  ),
                  const SizedBox(height: 22),
                  
                  CustomTextField(
                    label: 'Nome do Elemento',
                    hint: 'ABC Corp.',
                    controller: _nomeController,
                    enabled: canEdit, 
                  ),
                  const SizedBox(height: 18),
                  
                  _buildDropdownField(
                    label: 'Tipo do Elemento',
                    value: _tipoElemento,
                    options: tiposFinais, 
                    field: ElementoInfoDropdownField.tipoElemento,
                    canEdit: canEdit,
                  ),
                  const SizedBox(height: 18),
                  
                  _buildDropdownField(
                    label: 'Tipologia Estrutural',
                    value: _tipologiaEstrutural,
                    options: tipologiasFinais, 
                    field: ElementoInfoDropdownField.tipologiaEstrutural,
                    canEdit: canEdit,
                  ),
                  const SizedBox(height: 18),
                  
                  _buildDropdownField(
                    label: 'Local do Elemento',
                    value: _localElemento,
                    options: locaisFinais, 
                    field: ElementoInfoDropdownField.localElemento,
                    canEdit: canEdit,
                  ),
                  const SizedBox(height: 20),
                  
                  Center(child: _PlantaCard(onPressed: canEdit ? () {} : null)),
                  const SizedBox(height: 14),
                  
                  if (canEdit)
                    Center(
                      child: BiggerCustomButton(
                        width: 292,
                        height: 40,
                        text: 'Adicionar marcação em Planta',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlanejamentoPlantasScreen(
                                estruturaId: widget.estruturaId,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 18),
                  
                  _buildDropdownField(
                    label: 'Revestimento',
                    value: _revestimento,
                    options: revestimentosFinais, 
                    field: ElementoInfoDropdownField.revestimento,
                    canEdit: canEdit,
                  ),
                  const SizedBox(height: 44),
                  
                  if (_isDirty && canEdit)
                    Center(
                      child: BiggerCustomButton(
                        width: 139,
                        height: 52,
                        text: _isSubmitting ? 'Salvando...' : (_isEditing ? 'Salvar' : 'Criar'),
                        onPressed: _isSubmitting ? () {} : _salvar,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ElementoBanner extends StatelessWidget {
  const _ElementoBanner({this.onEditPressed, this.imageFile, this.networkUrl});

  final VoidCallback? onEditPressed;
  final File? imageFile;
  final String? networkUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 122,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            image: DecorationImage(
              image: imageFile != null
                  ? ResizeImage(FileImage(imageFile!), width: 800) as ImageProvider
                  : (networkUrl != null 
                      ? NetworkImage(networkUrl!) 
                      : const AssetImage('assets/images/elemento_info.png') as ImageProvider),
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (onEditPressed != null)
          Positioned(
            right: 14,
            bottom: -18,
            child: Material(
              color: Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onEditPressed,
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: Icon(Icons.edit_outlined, color: AppColors.greyDarkest.withOpacity(0.95), size: 31),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PlantaCard extends StatelessWidget {
  const _PlantaCard({this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 279, height: 150,
        decoration: BoxDecoration(color: const Color(0xFFD9D9D9), border: Border.all(color: const Color(0xFFD1D1D1), width: 4)),
        padding: const EdgeInsets.all(2),
        child: Container(decoration: BoxDecoration(border: Border.all(color: const Color(0xFF5E5E5E), width: 1), image: const DecorationImage(image: AssetImage('assets/images/planta_elementos_info.png'), fit: BoxFit.cover))),
      ),
    );
  }
}

enum ElementoInfoDropdownField { tipoElemento, tipologiaEstrutural, localElemento, revestimento }