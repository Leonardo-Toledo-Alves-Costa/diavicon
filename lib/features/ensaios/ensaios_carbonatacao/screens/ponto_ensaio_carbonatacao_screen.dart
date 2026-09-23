import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:diavicon/core/widgets/foto_ensaio.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../ensaios_geral/providers/ensaios_provider.dart';
import '../../ensaios_geral/providers/ensaio_permissoes_provider.dart';
import '../../ensaios_geral/screens/galeria_ensaio_screen.dart';
import '../models/ponto_carbonatacao_completo_model.dart';
import '../repositories/carbonatacao_repository.dart';
import 'analise_pontos_ensaios_carbonatacao_screen.dart';
import '../../../../core/web/escolher_foto.dart';

class PontoEnsaioCarbonatacaoScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String pontoNome;
  final String elementoNome;
  final String tipoElemento;
  final String local;
  final String elementoId;
  final String? pontoGeralId; // Se nulo = CRIAR. Se preenchido = EDITAR.
  final String tipoEnsaioId; // OBRIGATÓRIO PARA O NOVO BANCO

  const PontoEnsaioCarbonatacaoScreen({
    super.key,
    required this.projetoId,
    required this.pontoNome,
    required this.elementoNome,
    required this.tipoElemento,
    required this.local,
    required this.elementoId,
    this.pontoGeralId,
    required this.tipoEnsaioId,
  });

  @override
  ConsumerState<PontoEnsaioCarbonatacaoScreen> createState() =>
      _PontoEnsaioCarbonatacaoScreenState();
}

class _PontoEnsaioCarbonatacaoScreenState
    extends ConsumerState<PontoEnsaioCarbonatacaoScreen> {
  bool _isEditingName = false;
  bool _isLoading = false;
  bool _isInitializing = true;

  bool _hasChanges = false;
  bool _isFetchingData = false;

  late TextEditingController _nomePontoCtrl;
  final TextEditingController _cobArmPCtrl = TextEditingController();
  final TextEditingController _bitArmPCtrl = TextEditingController();
  final TextEditingController _cobArmSCtrl = TextEditingController();
  final TextEditingController _bitArmSCtrl = TextEditingController();

  List<MedicaoFrente> _frentes = [];
  File? _fotoQuebraLocal;
  File? _fotoAspersaoLocal;

  String? _urlFotoQuebra;
  String? _urlFotoAspersao;

  String? _carbIdExistente;
  String? _pontoGeralIdAtual;

  String _tipoEnsaio = 'Frente de carbonatação';

  @override
  void initState() {
    super.initState();
    _nomePontoCtrl = TextEditingController(text: widget.pontoNome);

    // Define se estamos em modo de EDIÇÃO ou CRIAÇÃO
    if (widget.pontoGeralId != null && widget.pontoGeralId!.isNotEmpty) {
      _pontoGeralIdAtual = widget.pontoGeralId;
    } else {
      _hasChanges = true; // Se é novo, já começa precisando salvar
    }

    _adicionarListenersDeAlteracao();
    _carregarDadosExistentes();
  }

  @override
  void dispose() {
    _removerListenersDeAlteracao();
    _nomePontoCtrl.dispose();
    _cobArmPCtrl.dispose();
    _bitArmPCtrl.dispose();
    _cobArmSCtrl.dispose();
    _bitArmSCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!_isFetchingData && !_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  void _adicionarListenersDeAlteracao() {
    _nomePontoCtrl.addListener(_onFieldChanged);
    _cobArmPCtrl.addListener(_onFieldChanged);
    _bitArmPCtrl.addListener(_onFieldChanged);
    _cobArmSCtrl.addListener(_onFieldChanged);
    _bitArmSCtrl.addListener(_onFieldChanged);
  }

  void _removerListenersDeAlteracao() {
    _nomePontoCtrl.removeListener(_onFieldChanged);
    _cobArmPCtrl.removeListener(_onFieldChanged);
    _bitArmPCtrl.removeListener(_onFieldChanged);
    _cobArmSCtrl.removeListener(_onFieldChanged);
    _bitArmSCtrl.removeListener(_onFieldChanged);
  }

  // Busca as informações do banco para popular os campos no modo EDIÇÃO
  Future<void> _carregarDadosExistentes() async {
    if (_pontoGeralIdAtual == null) {
      setState(() => _isInitializing = false);
      return;
    }

    _isFetchingData = true;
    try {
      final supabase = Supabase.instance.client;

      // Busca o nome do ensaio através do JOIN com a tabela tipos_ensaio
      final geralResp = await supabase
          .from('pontos_ensaios_geral')
          .select('tipos_ensaio(nome)')
          .eq('id', _pontoGeralIdAtual!)
          .maybeSingle();

      if (geralResp != null && geralResp['tipos_ensaio'] != null) {
        _tipoEnsaio =
            geralResp['tipos_ensaio']['nome'] ?? 'Frente de carbonatação';
      }

      // Busca as variáveis preenchidas da tabela carb
      final carbResp = await supabase
          .from('ponto_ensaio_carb')
          .select('*')
          .eq('ponto_ensaio_id', _pontoGeralIdAtual!)
          .maybeSingle();

      if (carbResp != null) {
        _carbIdExistente = carbResp['id'] as String;
        _nomePontoCtrl.text = carbResp['nome_ponto'] ?? widget.pontoNome;

        if (carbResp['cob_arm_p'] != null) {
          _cobArmPCtrl.text = carbResp['cob_arm_p'].toString();
        }
        if (carbResp['bit_arm_p'] != null) {
          _bitArmPCtrl.text = carbResp['bit_arm_p'].toString();
        }
        if (carbResp['cob_arm_s'] != null) {
          _cobArmSCtrl.text = carbResp['cob_arm_s'].toString();
        }
        if (carbResp['bit_arm_s'] != null) {
          _bitArmSCtrl.text = carbResp['bit_arm_s'].toString();
        }

        if (_carbIdExistente != null) {
          final frentesResp = await supabase
              .from('ponto_ensaio_carb_frentes')
              .select('profundidade, id')
              .eq('ponto_ensaio_id', _carbIdExistente!);

          _frentes = (frentesResp as List)
              .map(
                (f) => MedicaoFrente(
                  id: f['id'] as String?,
                  profundidade: (f['profundidade'] as num).toDouble(),
                ),
              )
              .toList();

          final fotosResp = await supabase
              .from('galeria_ponto_ensaio_carb')
              .select('imagem_url, referencia')
              .eq('ponto_ensaio_id', _carbIdExistente!);

          for (var foto in (fotosResp as List)) {
            if (foto['referencia'] == '1') _urlFotoQuebra = foto['imagem_url'];
            if (foto['referencia'] == '2') {
              _urlFotoAspersao = foto['imagem_url'];
            }
          }
        }
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isFetchingData = false;
          _hasChanges = false;
        });
      }
    }
  }

  Future<void> _capturarFoto(int referencia) async {
    final ImageSource? source = origemFotoNoNavegador ?? await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Selecionar Imagem',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('Tirar foto com a Câmera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppColors.primary,
                ),
                title: const Text('Escolher da Galeria'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source != null) {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          if (referencia == 1) _fotoQuebraLocal = File(image.path);
          if (referencia == 2) _fotoAspersaoLocal = File(image.path);
          _hasChanges = true;
        });
      }
    }
  }

  double get _media {
    if (_frentes.isEmpty) return 0.0;
    return _frentes.map((e) => e.profundidade).reduce((a, b) => a + b) /
        _frentes.length;
  }

  double get _coefVariacao {
    if (_frentes.isEmpty || _frentes.length == 1) return 0.0;
    double m = _media;
    double variance =
        _frentes
            .map((x) => pow(x.profundidade - m, 2))
            .reduce((a, b) => a + b) /
        _frentes.length;
    double stdDev = sqrt(variance);
    return m == 0 ? 0.0 : (stdDev / m) * 100;
  }

  void _abrirModalFrente({int? indexAtualizar}) {
    final ctrl = TextEditingController(
      text: indexAtualizar != null
          ? _frentes[indexAtualizar].profundidade.toStringAsFixed(2)
          : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Profundidade da Frente (mm)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            if (indexAtualizar != null)
              OutlinedButton(
                onPressed: () async {
                  final frenteParaRemover = _frentes[indexAtualizar];

                  if (frenteParaRemover.id != null &&
                      frenteParaRemover.id!.isNotEmpty) {
                    try {
                      setState(() => _isLoading = true);
                      final repo = ref.read(carbonatacaoRepositoryProvider);
                      await repo.deletarFrente(frenteParaRemover.id!);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString().replaceAll('Exception: ', ''),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      setState(() => _isLoading = false);
                      return;
                    }
                  }

                  setState(() {
                    _frentes.removeAt(indexAtualizar);
                    _hasChanges = true;
                    _isLoading = false;
                  });
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text(
                  'Apagar',
                  style: TextStyle(color: Colors.red),
                ),
              )
            else
              const SizedBox.shrink(),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(ctrl.text.replaceAll(',', '.'));
                if (val != null) {
                  setState(() {
                    if (indexAtualizar != null) {
                      _frentes[indexAtualizar] = MedicaoFrente(
                        profundidade: val,
                        id: _frentes[indexAtualizar].id,
                      );
                    } else {
                      _frentes.add(MedicaoFrente(profundidade: val));
                    }
                    _hasChanges = true;
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  // --- Função que engatilha o Repositório Inteligente (Cria/Edita) ---
  Future<void> _salvarDados() async {
    // Trava síncrona de reentrância — o botão só fica desabilitado
    // (`onPressed: _isLoading ? null : _salvarDados`) a partir do PRÓXIMO
    // rebuild/frame. Num toque duplo rápido, a segunda chamada ainda acha o
    // botão habilitado e entra aqui de novo antes do rebuild acontecer. Como
    // o repositório decide INSERT vs UPDATE em `pontos_ensaios_geral` e
    // `ponto_ensaio_carb` a partir de `_pontoGeralIdAtual`/
    // `_carbIdExistente` (nulos pra um ponto novo), as duas chamadas
    // cairiam no ramo de INSERT e duplicariam as linhas. Setar `_isLoading`
    // aqui é síncrono (setState muda o campo na hora, só o rebuild é
    // adiado), então a segunda chamada já vê `_isLoading == true` e sai
    // antes de inserir de novo.
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final model = PontoCarbonatacaoCompletoModel(
        idGeral:
            _pontoGeralIdAtual, // 👈 Chave que o Repositório usa para saber se é Insert ou Update
        nomePonto: _nomePontoCtrl.text,
        elementoNome: widget.elementoNome,
        tipoElemento: widget.tipoElemento,
        local: widget.local,
        cobArmP: double.tryParse(_cobArmPCtrl.text.replaceAll(',', '.')),
        bitArmP: double.tryParse(_bitArmPCtrl.text.replaceAll(',', '.')),
        cobArmS: double.tryParse(_cobArmSCtrl.text.replaceAll(',', '.')),
        bitArmS: double.tryParse(_bitArmSCtrl.text.replaceAll(',', '.')),
        urlFotoQuebra: _urlFotoQuebra,
        urlFotoAspersao: _urlFotoAspersao,
        frentes: _frentes,
      );

      final repository = ref.read(carbonatacaoRepositoryProvider);

      // Repassa as variáveis para o método salvarPonto()
      final resultados = await repository.salvarPonto(
        dados: model,
        projetoId: widget.projetoId,
        elementoId: widget.elementoId,
        tipoEnsaioId: widget.tipoEnsaioId, // 👈 Enviando o UUID corretamente!
        fotoQuebraNova: _fotoQuebraLocal,
        fotoAspersaoNova: _fotoAspersaoLocal,
      );

      if (mounted) {
        setState(() {
          _pontoGeralIdAtual = resultados['pontoGeralId'];
          _carbIdExistente = resultados['carbId'];

          if (resultados['urlFotoQuebra'] != null) {
            _urlFotoQuebra = resultados['urlFotoQuebra'];
          }
          if (resultados['urlFotoAspersao'] != null) {
            _urlFotoAspersao = resultados['urlFotoAspersao'];
          }

          _fotoQuebraLocal = null;
          _fotoAspersaoLocal = null;
          _hasChanges = false;
        });
        // <-- INVALIDE O PROVIDER AQUI PARA RECARREGAR A TELA ANTERIOR -->
      // Caso sua tela de pontos geral use este provider específico (ajuste se usar outro nome):
      try {
        ref.invalidate(resumoEnsaiosProvider);
      } catch(_) {}


        ref.invalidate(resumoEnsaiosProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deletarPonto() async {
    if (_pontoGeralIdAtual == null) {
      Navigator.pop(context);
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Ponto'),
        content: const Text(
          'Deseja realmente excluir este ponto de ensaio e todos os seus dados vinculados?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(carbonatacaoRepositoryProvider);
      await repo.deletarPontoCompleto(_pontoGeralIdAtual!, _carbIdExistente);

      if (mounted) {
        ref.invalidate(resumoEnsaiosProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ponto excluído com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao excluir: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final permissoes = ref.watch(ensaioPermissoesProvider(_pontoGeralIdAtual ?? '')).value ?? EnsaioPermissoes.somenteVisualizar;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        systemNavigationBarColor: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,

        endDrawer: MenuDrawerAppBar(
          title: 'Ponto de\nensaio',
          items: [
            Opacity(
              opacity: 0.4,
              child: DiaviconMenuItem(
                icon: Icons.info_outline,
                label: 'Informações',
                onTap: () {},
              ),
            ),
            DiaviconMenuItem(
              icon: Icons.camera_alt_outlined,
              label: 'Fotos',
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                if (_pontoGeralIdAtual == null || _hasChanges) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Salve as informações primeiro.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) => GaleriaEnsaioScreen(
                      pontoGeralId: _pontoGeralIdAtual!,
                      pontoNome: _nomePontoCtrl.text,
                      elementoNome: widget.elementoNome,
                      tipoElemento: widget.tipoElemento,
                      local: widget.local,
                      tipoEnsaio: _tipoEnsaio,
                    ),
                  ),
                );
              },
            ),

            DiaviconMenuItem(
              icon: Icons.show_chart_rounded,
              label: 'Análise',
              onTap: () {
                Navigator.pop(context);
                if (_pontoGeralIdAtual == null || _hasChanges) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Salve o ponto primeiro para visualizar a análise.',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AnalisePontosEnsaiosCarbonatacaoScreen(
                          pontoGeralId: _pontoGeralIdAtual!,
                        ),
                  ),
                );
              },
            ),

            const Spacer(),
            const Divider(),

            if (permissoes.canDelete)
              Center(
                child: IconButton(
                  iconSize: 30,
                  color: Colors.red.shade800,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    Navigator.pop(context);
                    _deletarPonto();
                  },
                ),
              ),
          ],
        ),

        appBar: CustomAppBar(
          title: 'Ensaio',
          showBackButton: true,
          titleWidget: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ponto de ensaio',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _tipoEnsaio,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!permissoes.canEdit)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Somente visualização — apenas a empresa que criou este ensaio pode editá-lo.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              AbsorbPointer(
                absorbing: !permissoes.canEdit,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _isEditingName
                        ? TextField(
                            controller: _nomePontoCtrl,
                            style: GoogleFonts.lato(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF3E3E3D),
                            ),
                            decoration: const InputDecoration(isDense: true),
                            onSubmitted: (_) {
                              setState(() => _isEditingName = false);
                              _onFieldChanged();
                            },
                          )
                        : Text(
                            '${_nomePontoCtrl.text} - ${widget.elementoNome}',
                            style: GoogleFonts.lato(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF3E3E3D),
                            ),
                          ),
                  ),
                  if (permissoes.canEdit)
                    IconButton(
                      icon: Icon(
                        _isEditingName ? Icons.check : Icons.edit_square,
                        color: const Color(0xFF3E3E3D),
                      ),
                      onPressed: () =>
                          setState(() => _isEditingName = !_isEditingName),
                    ),
                ],
              ),
              Text(
                widget.tipoElemento,
                style: GoogleFonts.lato(
                  fontSize: 13,
                  color: const Color(0xFF888888),
                ),
              ),
              Text(
                widget.local,
                style: GoogleFonts.lato(
                  fontSize: 13,
                  color: const Color(0xFF888888),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _buildFotoCard(
                      'Quebra do concreto',
                      _fotoQuebraLocal,
                      _urlFotoQuebra,
                      () => _capturarFoto(1),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFotoCard(
                      'Aspersão do reagente',
                      _fotoAspersaoLocal,
                      _urlFotoAspersao,
                      () => _capturarFoto(2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                'Armadura principal',
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3E3E3D),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildInput('Cob. (mm)', _cobArmPCtrl)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInput('Bit. (mm)', _bitArmPCtrl)),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                'Armadura Secundária',
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3E3E3D),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildInput('Cob. (mm)', _cobArmSCtrl)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInput('Bit. (mm)', _bitArmSCtrl)),
                ],
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Text(
                    'Medição das frentes de carbonatação',
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3E3E3D),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_frentes.length, (i) {
                          return GestureDetector(
                            onTap: () => _abrirModalFrente(indexAtualizar: i),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _frentes[i].profundidade.toStringAsFixed(2),
                                    style: GoogleFonts.lato(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: const Color(0xFF3E3E3D),
                                    ),
                                  ),
                                  const Text(
                                    'mm',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildEstatisticaCard(
                            'Média',
                            '${_media.toStringAsFixed(2)} mm',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildEstatisticaCard(
                            'Coef.de variação',
                            '${_coefVariacao.toStringAsFixed(0)}%',
                            isHomogeneo: _coefVariacao <= 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _abrirModalFrente(),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFA726),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              if (_hasChanges && permissoes.canEdit)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _salvarDados,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFA726),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Salvar Informações',
                            style: GoogleFonts.lato(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEstatisticaCard(
    String label,
    String valor, {
    bool? isHomogeneo,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // 👇 SOLUÇÃO 2: Trocamos a 'Row' por um 'Wrap' para ele quebrar linha automaticamente
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              Text(
                valor,
                style: GoogleFonts.lato(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3E3E3D),
                ),
              ),
              if (isHomogeneo != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isHomogeneo
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isHomogeneo ? 'Homogêneo' : 'Heterogêneo',
                    style: TextStyle(
                      fontSize: 8,
                      color: isHomogeneo ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFotoCard(
    String titulo,
    File? fotoLocal,
    String? urlRemota,
    VoidCallback onTap,
  ) {
    ImageProvider? imageProvider;
    if (fotoLocal != null) {
      imageProvider = FileImage(fotoLocal);
    } else if (urlRemota != null && urlRemota.isNotEmpty) {
      imageProvider = StorageNetworkImage(urlRemota);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          titulo,
          style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 8),
        // Proporção fixa em vez de altura fixa: a foto não achata em tela larga.
        // Tocar continua capturando/trocando a foto.
        FotoEnsaio(
          imagem: imageProvider,
          raio: 16,
          aoTocar: onTap,
          vazio: const Center(
            child: Icon(Icons.camera_alt, color: Colors.grey),
          ),
          acao: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.edit_square,
              size: 20,
              color: Color(0xFF3E3E3D),
            ),
          ),
        ),
      ],
    );
  }
}
