import 'dart:io';
import 'package:diavicon/features/planos/acesso_plano.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


// Importações do Core (Componentes Globais, Serviços e Utils)
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_dropdown.dart';
import '../../../core/widgets/custom_dropdown_with_add.dart';
import '../../../core/widgets/compact_button.dart';
import '../../../core/utils/formatters/cep_formatter.dart';
import '../../../core/utils/validators/cep_validator.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/map_selection_helper.dart';

// Importações Locais da Feature (Models, Providers e os Novos Widgets Isolados)
import '../models/estrutura_model.dart';
import '../providers/estrutura_provider.dart';
import '../widgets/avatar_seletor_imagem.dart';
import '../widgets/mapa_preview_widget.dart';
import 'estrutura_home.dart';
import '../providers/estruturas_dropdown_provider.dart';
import '../widgets/novo_item_dropdown_modal.dart';
import '../services/image_picker_service.dart';


//importações de outra features
import '../../auth/providers/auth_provider.dart';
import '../../projetos/providers/projetos_provider.dart';
import '../../planos/planos_mensagens.dart';
import '../../planos/providers/tokens_estrutura_provider.dart';
import '../../gastos/providers/gastos_providers.dart' show ehAdminEmpresaProvider;

class NovaEstruturaScreen extends ConsumerStatefulWidget {
  final String projetoId;
  // 👇 Novos parâmetros opcionais para receber os dados do modal
  final String? initialNome;
  final File? initialImagem;

  const NovaEstruturaScreen({
    super.key, 
    required this.projetoId,
    this.initialNome,
    this.initialImagem,
  });

  @override
  ConsumerState<NovaEstruturaScreen> createState() => _NovaEstruturaScreenState();
}

class _NovaEstruturaScreenState extends ConsumerState<NovaEstruturaScreen> {
  final double _fieldSpacing = 10.0;
  bool _isLoading = false;
  bool _isFetchingCep = false;
  Timer? _debounce;
  final _formKey = GlobalKey<FormState>();

  File? _imagemSelecionada;

  // Controladores de Texto
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController(); 
  final _anoConcepcaoController = TextEditingController();
  final _latController = TextEditingController();
  final _longController = TextEditingController();
  final _cepController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _numeroController = TextEditingController();
  final _paisController = TextEditingController();
  final _ufController = TextEditingController();
  final ImagePickerService _imagePickerService = ImagePickerService();

  // Estados dos Dropdowns
  String? _caaSelecionado;
  String? _conjuntoSelecionado;
  String? _utilizacaoSelecionada;
  String? _tipoEstruturaSelecionado;
  String? _tipologiaSelecionada;
  bool _monitorada = false;

  @override
  void initState() {
    super.initState();
    
    // 👇 Inicializa os campos com os dados vindos do modal, se existirem
    if (widget.initialNome != null) {
      _nomeController.text = widget.initialNome!;
    }
    if (widget.initialImagem != null) {
      _imagemSelecionada = widget.initialImagem;
    }

    _cepController.addListener(_onCepChanged);
    _numeroController.addListener(_onNumeroChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cepController.removeListener(_onCepChanged);
    _numeroController.removeListener(_onNumeroChanged);
    _nomeController.dispose();
    _anoConcepcaoController.dispose();
    _descricaoController.dispose();
    _latController.dispose();
    _longController.dispose();
    _cepController.dispose();
    _enderecoController.dispose();
    _cidadeController.dispose();
    _numeroController.dispose();
    _paisController.dispose();
    _ufController.dispose();
    super.dispose();
  }

  

  // --- MÉTODOS DE AÇÃO E LÓGICA DE NEGÓCIO ---

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

  void _onCepChanged() {
    final text = _cepController.text;
    setState(() {}); // Reconstrói para ativar/desativar o bloqueio de edição do endereço
    if (text.length == 9 && !_isFetchingCep) {
      _buscarCep(text);
    }
  }

  void _onNumeroChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      _atualizarCoordenadasPeloNumero();
    });
  }

  Future<void> _buscarCep(String cepFormatado) async {
    setState(() => _isFetchingCep = true);

    try {
      final endereco = await LocationService.buscarEnderecoPorCep(cepFormatado);
      
      // Se a tela foi fechada enquanto buscava, para aqui
      if (!mounted) return; 

      if (endereco != null) {
        setState(() {
          _enderecoController.text = endereco['rua']!;
          _cidadeController.text = endereco['cidade']!;
          _ufController.text = endereco['uf']!;
          _paisController.text = endereco['pais']!;
        });

        String textoBusca = endereco['rua']!.isNotEmpty
            ? '${endereco['rua']}, ${endereco['cidade']}, ${endereco['uf']}, Brasil'
            : '$cepFormatado, Brasil';

        final coords = await LocationService.buscarCoordenadasPorEndereco(textoBusca);
        
        if (!mounted) return; 

        if (coords != null) {
          setState(() {
            _latController.text = coords['lat'].toString();
            _longController.text = coords['lng'].toString();
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CEP não encontrado.'), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingCep = false); 
    }
  }

  Future<void> _atualizarCoordenadasPeloNumero() async {
    String rua = _enderecoController.text.trim();
    String numero = _numeroController.text.trim();
    String city = _cidadeController.text.trim();
    String state = _ufController.text.trim();

    if (rua.isNotEmpty && numero.isNotEmpty && city.isNotEmpty) {
      String textoBusca = '$rua, $numero, $city, $state, Brasil';
      final coords = await LocationService.buscarCoordenadasPorEndereco(textoBusca);

      if (!mounted) return; 

      if (coords != null) {
        setState(() {
          _latController.text = coords['lat'].toString();
          _longController.text = coords['lng'].toString();
        });
      }
    }
  }

  Future<void> _abrirMapaESelecionar() async {
    final resultado = await MapSelectionHelper.selecionarNoMapa(context);

    if (!mounted) return; 

    if (resultado != null) {
      setState(() {
        _latController.text = resultado['latitude'];
        _longController.text = resultado['longitude'];
        
        final endereco = resultado['endereco'] as Map<String, String>?;
        
        if (endereco != null) {
          _cepController.text = endereco['cep'] ?? '';
          _enderecoController.text = endereco['rua'] ?? '';
          _numeroController.text = endereco['numero'] ?? '';
          _cidadeController.text = endereco['cidade'] ?? '';
          _ufController.text = endereco['uf'] ?? '';
          _paisController.text = endereco['pais'] ?? '';
        } else {
          _cepController.clear(); _enderecoController.clear(); _numeroController.clear();
          _cidadeController.clear(); _ufController.clear(); _paisController.clear();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível encontrar o nome da rua deste local exato.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
    }
  }

  Future<void> _handleCriar() async {
    if (_isLoading) return;
    // Plano sem espaço: nenhuma criação nova (o servidor também recusa).
    if (!await verificarArmazenamento(context, ref)) return;
    if (!mounted || _isLoading) return;
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, preencha todos os campos obrigatórios.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      //  Lemos quem está logado e de quem é o projeto
      final user = ref.read(currentUserProvider);
      final projeto = ref.read(projectDetailProvider(widget.projetoId)).value;
      
      // O dono da estrutura é o Cliente da Obra — mas só quando o vínculo já
      // está 'ativo' (cliente aceitou); um convite ainda 'pendente' não deve
      // tornar a empresa convidada dona antes mesmo dela aceitar participar.
      // Caso não haja cliente ativo, a dona temporária é a própria gestora.
      final donoId = (projeto?.statusVinculoCliente == 'ativo' ? projeto?.empresaClienteId : null) ?? user?.empresaId;
      final gestoraId = user?.empresaId;

      String? imageUrlFinal;
      if (_imagemSelecionada != null) {
        imageUrlFinal = await ref
            .read(estruturaRepositoryProvider)
            .uploadImagemEstrutura(_imagemSelecionada!);
      }

      final novaEstrutura = EstruturaModel(
        id: '',
        nome: _nomeController.text.trim(),
        descricao: _descricaoController.text.trim(),
        caa: _caaSelecionado,
        anoConcepcao: int.tryParse(_anoConcepcaoController.text.trim()),
        conjuntoEstruturalId: _conjuntoSelecionado,
        utilizacaoId: _utilizacaoSelecionada,
        tipoId: _tipoEstruturaSelecionado,
        tipologiaId: _tipologiaSelecionada,
        latitude: double.tryParse(_latController.text.trim()),
        longitude: double.tryParse(_longController.text.trim()),
        cep: _cepController.text.trim().isNotEmpty ? _cepController.text.trim() : null,
        endereco: _enderecoController.text.trim().isNotEmpty ? _enderecoController.text.trim() : null,
        cidade: _cidadeController.text.trim().isNotEmpty ? _cidadeController.text.trim() : null,
        numero: _numeroController.text.trim().isNotEmpty ? _numeroController.text.trim() : null,
        pais: _paisController.text.trim().isNotEmpty ? _paisController.text.trim() : null,
        uf: _ufController.text.trim().isNotEmpty ? _ufController.text.trim() : null,
        status: 'Pendente',
        imageUrl: imageUrlFinal,
        
        // Automações Críticas de Banco de Dados
        criadoEm: DateTime.now(), 
        userId: user?.id, 
        projetoId: widget.projetoId,
        proprietariaId: donoId,
        empresaGestoraId: gestoraId,
        monitorada: _monitorada,
      );

      final estruturaCriada = await ref.read(estruturaRepositoryProvider).criarEstrutura(novaEstrutura, widget.projetoId);
      
      // Avisam os 2 lugares para recarregar a lista!
      ref.invalidate(projetoEstruturasProvider(widget.projetoId)); // Tela de detalhes
      ref.invalidate(minhasEstruturasProvider(widget.projetoId)); // Modal de Seleção

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EstruturaHomeScreen(
              estrutura: estruturaCriada, 
              projetoId: widget.projetoId,
            ),
          ),
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Estrutura criada com sucesso'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _alternarMonitorada(bool novoValor, TokensEstruturaInfo? info) {
    if (novoValor && (info == null || info.disponivel <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sem tokens de monitoramento disponíveis. $kMensagemContatoVendas'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _monitorada = novoValor);
  }

  Widget _buildSeletorMonitorada() {
    final tokensAsync = ref.watch(tokensEstruturaInfoProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Monitorar esta estrutura', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 14)),
              ),
              Switch(
                value: _monitorada,
                activeThumbColor: AppColors.primary,
                onChanged: (val) => _alternarMonitorada(val, tokensAsync.value),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Estruturas monitoradas aparecem na aba Estruturas e habilitam funcionalidades de acompanhamento.',
            style: TextStyle(fontSize: 11, color: AppColors.hintText),
          ),
          const SizedBox(height: 8),
          tokensAsync.when(
            loading: () => const Text('Carregando tokens disponíveis...', style: TextStyle(fontSize: 11, color: AppColors.hintText)),
            error: (_, _) => const SizedBox.shrink(),
            data: (info) => Text(
              '${info.disponivel} de ${info.limite} token(s) de monitoramento disponíveis.',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: info.disponivel > 0 ? AppColors.primary : AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  // --- CONSTRUÇÃO DA INTERFACE VISUAL ---

  @override
  Widget build(BuildContext context) {
    bool podeEditarEndereco = _cepController.text.trim().isEmpty;
    double? latAtual = double.tryParse(_latController.text.trim());
    double? longAtual = double.tryParse(_longController.text.trim());

    //  ESCUTANDO OS 4 PROVIDERS DO SUPABASE 
    final conjuntosAsync = ref.watch(conjuntosEstruturaisProvider);
    // Criar conjunto é coisa de administrador (o banco recusa os demais). O
    // "+" fica desligado para quem não pode, com a explicação no ícone de
    // ajuda, em vez de abrir a janela e falhar no Salvar.
    final podeCriarConjunto = ref.watch(ehAdminEmpresaProvider);
    final utilizacoesAsync = ref.watch(utilizacoesEstruturaProvider);
    final tiposAsync = ref.watch(tiposEstruturaProvider);
    final tipologiasAsync = ref.watch(tipologiasEstruturaProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(title: 'Projeto', showBackButton: true, showMenuButton: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: Text(
                    'Nova Estrutura',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                ),
                const SizedBox(height: 24),

                // Widget Modular do Avatar (Foto da Obra)
                AvatarSeletorImagem(
                  imagemSelecionada: _imagemSelecionada,
                  onTap: _escolherImagem,
                ),
                const SizedBox(height: 32),

                CustomTextField(
                  label: 'Nome da estrutura*',
                  hint: 'ABC Corp.',
                  controller: _nomeController,
                  validator: (value) => value == null || value.trim().isEmpty ? 'Obrigatório' : null,
                ),
                SizedBox(height: _fieldSpacing),

                // campo descrição
                CustomTextField(
                  label: 'Descrição*',
                  hint: 'Descreva os detalhes e finalidade da estrutura...',
                  controller: _descricaoController,
                  maxLines: 6, // Transforma num Box maior
                  validator: (value) => value == null || value.trim().isEmpty ? 'Obrigatório' : null,
                ),
                SizedBox(height: _fieldSpacing),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2, 
                      child: CustomDropdown<String>(
                        label: 'CAA*',
                        tooltip: 'Classe de Agressividade Ambiental',
                        validator: (value) => value == null ? 'Obrigatório' : null,
                        value: _caaSelecionado,
                        items: const [
                          DropdownMenuItem(value: 'I', child: Text('I')),
                          DropdownMenuItem(value: 'II', child: Text('II')),
                          DropdownMenuItem(value: 'III', child: Text('III')),
                          DropdownMenuItem(value: 'IV', child: Text('IV')),
                        ],
                        onChanged: (val) => setState(() => _caaSelecionado = val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3, 
                      child: CustomTextField(
                        label: 'Ano de construção*', 
                        hint: '2015',
                        keyboardType: TextInputType.number,
                        controller: _anoConcepcaoController,
                        validator: (value) => value == null || value.trim().isEmpty ? 'Obrigatório' : null,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _fieldSpacing),

                // 1. CONJUNTO ESTRUTURAL
                conjuntosAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Text('Erro ao carregar: $err'),
                  data: (lista) => CustomDropdownWithAdd<String>(
                    label: 'Conjunto Estrutural*',
                    value: _conjuntoSelecionado,
                    isAddEnabled: podeCriarConjunto,
                    tooltip: podeCriarConjunto
                        ? null
                        : 'Só administradores da empresa criam conjuntos estruturais. '
                            'Peça a um administrador ou escolha um conjunto existente.',
                    validator: (value) => value == null ? 'Obrigatório' : null,
                    items: lista.map((item) => DropdownMenuItem(
                      value: item['id'].toString(), 
                      child: Text(item['nome'].toString())
                    )).toList(),
                    onChanged: (val) => setState(() => _conjuntoSelecionado = val),
                    onAddPressed: () async {
                      final novoId = await showDialog<String>(
                        context: context,
                        builder: (context) => const NovoItemDropdownModal(
                          titulo: 'Conjunto Estrutural', 
                          nomeTabela: 'conjuntos_estruturais',
                        ),
                      );
                      if (novoId != null) {
                        ref.invalidate(conjuntosEstruturaisProvider);
                        setState(() => _conjuntoSelecionado = novoId);
                      }
                    },
                  ),
                ),
                SizedBox(height: _fieldSpacing),

                // 2. UTILIZAÇÃO DA ESTRUTURA
                utilizacoesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Text('Erro ao carregar: $err'),
                  data: (lista) => CustomDropdownWithAdd<String>(
                    label: 'Utilização da estrutura*',
                    value: _utilizacaoSelecionada,
                    validator: (value) => value == null ? 'Obrigatório' : null,
                    items: lista.map((item) => DropdownMenuItem(
                      value: item['id'].toString(), 
                      child: Text(item['nome'].toString())
                    )).toList(),
                    onChanged: (val) => setState(() => _utilizacaoSelecionada = val),
                    onAddPressed: () async {
                      final novoId = await showDialog<String>(
                        context: context,
                        builder: (context) => const NovoItemDropdownModal(
                          titulo: 'Utilização', 
                          nomeTabela: 'utilizacoes_estrutura',
                        ),
                      );
                      if (novoId != null) {
                        ref.invalidate(utilizacoesEstruturaProvider);
                        setState(() => _utilizacaoSelecionada = novoId);
                      }
                    },
                  ),
                ),
                SizedBox(height: _fieldSpacing),

                // 3. TIPO DE ESTRUTURA
                tiposAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Text('Erro ao carregar: $err'),
                  data: (lista) => CustomDropdownWithAdd<String>(
                    label: 'Tipo de estrutura*',
                    value: _tipoEstruturaSelecionado,
                    validator: (value) => value == null ? 'Obrigatório' : null,
                    items: lista.map((item) => DropdownMenuItem(
                      value: item['id'].toString(), 
                      child: Text(item['nome'].toString())
                    )).toList(),
                    onChanged: (val) => setState(() => _tipoEstruturaSelecionado = val),
                    onAddPressed: () async {
                      final novoId = await showDialog<String>(
                        context: context,
                        builder: (context) => const NovoItemDropdownModal(
                          titulo: 'Tipo de Estrutura', 
                          nomeTabela: 'tipos_estrutura',
                        ),
                      );
                      if (novoId != null) {
                        ref.invalidate(tiposEstruturaProvider);
                        setState(() => _tipoEstruturaSelecionado = novoId);
                      }
                    },
                  ),
                ),
                SizedBox(height: _fieldSpacing),

                // 4. TIPOLOGIA ESTRUTURAL
                tipologiasAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Text('Erro ao carregar: $err'),
                  data: (lista) => CustomDropdownWithAdd<String>(
                    label: 'Tipologia estrutural*',
                    value: _tipologiaSelecionada,
                    validator: (value) => value == null ? 'Obrigatório' : null,
                    items: lista.map((item) => DropdownMenuItem(
                      value: item['id'].toString(), 
                      child: Text(item['nome'].toString())
                    )).toList(),
                    onChanged: (val) => setState(() => _tipologiaSelecionada = val),
                    onAddPressed: () async {
                      final novoId = await showDialog<String>(
                        context: context,
                        builder: (context) => const NovoItemDropdownModal(
                          titulo: 'Tipologia Estrutural', 
                          nomeTabela: 'tipologias_estrutura',
                        ),
                      );
                      if (novoId != null) {
                        ref.invalidate(tipologiasEstruturaProvider);
                        setState(() => _tipologiaSelecionada = novoId);
                      }
                    },
                  ),
                ),
                SizedBox(height: _fieldSpacing),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'Latitude',
                        hint: '-',
                        controller: _latController,
                        enabled: false, // Fica bloqueado para edição manual
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CustomTextField(
                        label: 'Longitude',
                        hint: '-',
                        controller: _longController,
                        enabled: false, // Fica bloqueado para edição manual
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // O BOTÃO DO MAPA RECUPERADO
                    GestureDetector(
                      onTap: _abrirMapaESelecionar, // Chama a função que abre o mapa interativo
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/map_pin.png',
                            width: 24,
                            height: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _fieldSpacing),

                CustomTextField(
                  label: 'CEP',
                  hint: '00000-000',
                  controller: _cepController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CepFormatter.mask],
                  suffixIcon: _isFetchingCep
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                        )
                      : null,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    if (!CepValidator.isValid(value)) return 'CEP inválido';
                    return null;
                  },
                ),
                SizedBox(height: _fieldSpacing),

                CustomTextField(
                  label: 'Endereço',
                  hint: 'Rua....',
                  controller: _enderecoController,
                  enabled: podeEditarEndereco,
                ),
                SizedBox(height: _fieldSpacing),

                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'Cidade*',
                        hint: 'Cidade',
                        controller: _cidadeController,
                        enabled: podeEditarEndereco,
                        validator: (value) => value == null || value.trim().isEmpty ? 'Obrigatório' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        label: 'Número', 
                        hint: '123', 
                        controller: _numeroController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _fieldSpacing),

                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'País*',
                        hint: 'Brasil',
                        controller: _paisController,
                        validator: (value) => value == null || value.trim().isEmpty ? 'Obrigatório' : null,
                        enabled: podeEditarEndereco,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        label: 'UF*',
                        hint: 'XX',
                        controller: _ufController,
                        validator: (value) => value == null || value.trim().isEmpty ? 'Obrigatório' : null,
                        enabled: podeEditarEndereco,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Widget Modular do Mini-Mapa Preview
                MapaPreviewWidget(
                  latitude: latAtual,
                  longitude: longAtual,
                ),
                const SizedBox(height: 24),

                _buildSeletorMonitorada(),
                const SizedBox(height: 40),

                Center(
                  child: SizedBox(
                    width: 180,
                    child: CompactButton(
                      text: _isLoading ? '...' : 'Criar',
                      onPressed: _isLoading ? () {} : _handleCriar,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}