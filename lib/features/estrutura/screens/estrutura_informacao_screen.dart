import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_dropdown.dart';
import '../../../core/widgets/custom_dropdown_with_add.dart';
import '../../../core/widgets/compact_button.dart';
import '../models/estrutura_model.dart';

import '../../projetos/providers/projetos_provider.dart'; 

class EstruturaInformacaoScreen extends ConsumerStatefulWidget {
  final EstruturaModel estrutura;
  final String projetoId; 

  const EstruturaInformacaoScreen({
    super.key, 
    required this.estrutura, 
    required this.projetoId,
  });

  @override
  ConsumerState<EstruturaInformacaoScreen> createState() => _EstruturaInformacaoScreenState();
}

class _EstruturaInformacaoScreenState extends ConsumerState<EstruturaInformacaoScreen> {
  final double _fieldSpacing = 16.0;

  // Controllers
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _idadeController = TextEditingController();
  final _latController = TextEditingController();
  final _longController = TextEditingController();
  final _cepController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _numeroController = TextEditingController();
  final _paisController = TextEditingController();
  final _ufController = TextEditingController();

  String? _caaSelecionado;
  String? _conjuntoSelecionado;
  String? _utilizacaoSelecionada;
  String? _tipoEstruturaSelecionado;
  String? _tipologiaSelecionada;

  String? _clean(String? val) => (val != null && val.trim().isNotEmpty) ? val : null;

  @override
  void initState() {
    super.initState();
    final e = widget.estrutura;
    
    _nomeController.text = e.nome ?? '';
    _descricaoController.text = e.descricao ?? '';
    _idadeController.text = e.idadeAnos?.toString() ?? '';
    _latController.text = e.latitude?.toString() ?? '';
    _longController.text = e.longitude?.toString() ?? '';
    _cepController.text = e.cep ?? '';
    _enderecoController.text = e.endereco ?? '';
    _cidadeController.text = e.cidade ?? '';
    _numeroController.text = e.numero ?? '';
    _paisController.text = e.pais ?? '';
    _ufController.text = e.uf ?? '';

    _caaSelecionado = _clean(e.caa);
    _conjuntoSelecionado = _clean(e.conjuntoEstrutural);
    _utilizacaoSelecionada = _clean(e.utilizacao);
    _tipoEstruturaSelecionado = _clean(e.tipo);
    _tipologiaSelecionada = _clean(e.tipologiaEstrutural);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _idadeController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(title: 'Estrutura\nInformações', showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informações Básicas (Bloqueadas para edição)
            AbsorbPointer(
              absorbing: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageHeader(),
                  const SizedBox(height: 24),

                  CustomTextField(label: 'Nome', hint: 'Sem nome', controller: _nomeController),
                  SizedBox(height: _fieldSpacing),

                  const Text('Status', style: TextStyle(fontSize: 14, color: AppColors.hintText)),
                  const SizedBox(height: 4),
                  _buildBadge(widget.estrutura.status ?? 'Pendente', const Color(0xFFFFF3E0), AppColors.primary),
                  SizedBox(height: _fieldSpacing),

                  const Text('Descrição', style: TextStyle(fontSize: 14, color: AppColors.hintText)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _descricaoController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Proprietário (sem AbsorbPointer para o botão Vincular funcionar)
            _buildProprietarioSection(),
            const SizedBox(height: 24),

            // Cadastro e Localização (Bloqueados para edição)
            AbsorbPointer(
              absorbing: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cadastro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: CustomDropdown<String>(
                          label: 'CAA',
                          value: _caaSelecionado ?? '1',
                          items: [
                            if (_caaSelecionado != null) DropdownMenuItem(value: _caaSelecionado, child: Text(_caaSelecionado!))
                            else const DropdownMenuItem(value: '1', child: Text('Não Informado')),
                          ],
                          onChanged: (val) {},
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: CustomTextField(label: 'Idade (anos)', hint: '-', keyboardType: TextInputType.number, controller: _idadeController),
                      ),
                    ],
                  ),
                  SizedBox(height: _fieldSpacing),

                  CustomDropdownWithAdd<String>(
                    label: 'Conjunto Estrutural',
                    value: _conjuntoSelecionado ?? '1',
                    items: [
                      if (_conjuntoSelecionado != null) DropdownMenuItem(value: _conjuntoSelecionado, child: Text(_conjuntoSelecionado!))
                      else const DropdownMenuItem(value: '1', child: Text('Não Informado')),
                    ],
                    onChanged: (val) {},
                    onAddPressed: () {},
                  ),
                  SizedBox(height: _fieldSpacing),

                  CustomDropdownWithAdd<String>(
                    label: 'Utilização da estrutura',
                    value: _utilizacaoSelecionada ?? '1',
                    items: [
                      if (_utilizacaoSelecionada != null) DropdownMenuItem(value: _utilizacaoSelecionada, child: Text(_utilizacaoSelecionada!))
                      else const DropdownMenuItem(value: '1', child: Text('Não Informado')),
                    ],
                    onChanged: (val) {},
                    onAddPressed: () {},
                  ),
                  SizedBox(height: _fieldSpacing),

                  CustomDropdownWithAdd<String>(
                    label: 'Tipo de estrutura',
                    value: _tipoEstruturaSelecionado ?? '1',
                    items: [
                      if (_tipoEstruturaSelecionado != null) DropdownMenuItem(value: _tipoEstruturaSelecionado, child: Text(_tipoEstruturaSelecionado!))
                      else const DropdownMenuItem(value: '1', child: Text('Não Informado')),
                    ],
                    onChanged: (val) {},
                    onAddPressed: () {},
                  ),
                  SizedBox(height: _fieldSpacing),

                  CustomDropdownWithAdd<String>(
                    label: 'Tipologia estrutural',
                    value: _tipologiaSelecionada ?? '1',
                    items: [
                      if (_tipologiaSelecionada != null) DropdownMenuItem(value: _tipologiaSelecionada, child: Text(_tipologiaSelecionada!))
                      else const DropdownMenuItem(value: '1', child: Text('Não Informado')),
                    ],
                    onChanged: (val) {},
                    onAddPressed: () {},
                  ),
                  SizedBox(height: _fieldSpacing),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: CustomTextField(label: 'Latitude', hint: '-', controller: _latController)),
                      const SizedBox(width: 8),
                      Expanded(child: CustomTextField(label: 'Longitude', hint: '-', controller: _longController)),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {},
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: Center(child: Image.asset('assets/images/map_pin.png', width: 24, height: 24, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: _fieldSpacing),

                  CustomTextField(label: 'CEP', hint: '-', controller: _cepController),
                  SizedBox(height: _fieldSpacing),
                  CustomTextField(label: 'Endereço', hint: '-', controller: _enderecoController),
                  SizedBox(height: _fieldSpacing),

                  Row(
                    children: [
                      Expanded(child: CustomTextField(label: 'Cidade', hint: '-', controller: _cidadeController)),
                      const SizedBox(width: 16),
                      Expanded(child: CustomTextField(label: 'Número', hint: '-', controller: _numeroController)),
                    ],
                  ),
                  SizedBox(height: _fieldSpacing),

                  Row(
                    children: [
                      Expanded(child: CustomTextField(label: 'País', hint: '-', controller: _paisController)),
                      const SizedBox(width: 16),
                      Expanded(child: CustomTextField(label: 'UF', hint: '-', controller: _ufController)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Text('Indicação no mapa', style: TextStyle(fontSize: 14, color: AppColors.hintText)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/project_placeholder.png', 
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 180,
                        color: Colors.grey[300],
                        child: const Center(child: Text('Imagem do Mapa')),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==== WIDGET CONECTADO AO BANCO: PROPRIETÁRIO ====
  Widget _buildProprietarioSection() {
    // Escutando o projeto em tempo real!
    final projetoAsync = ref.watch(projectDetailProvider(widget.projetoId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: AppColors.inputBorder, thickness: 1),
        const SizedBox(height: 16),
        const Text('Proprietário da estrutura', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 4),
        const Text('O proprietário da estrutura é responsável pela gestão e compartilhamento dos dados', style: TextStyle(fontSize: 12, color: AppColors.hintText)),
        const SizedBox(height: 16),
        
        // Renderização reativa do banco de dados
        projetoAsync.when(
          data: (projeto) {
            // Valores padrão (Não Vinculado)
            String statusTexto = 'Não Vinculado';
            Color corFundo = const Color(0xFFFFEBEE); 
            Color corTexto = Colors.red;
            bool mostrarBotaoVincular = true;

            // Lógica baseada no statusVinculoCliente do seu ProjetoModel
            if (projeto.statusVinculoCliente == 'vinculado') {
              statusTexto = 'Vinculado';
              corFundo = const Color(0xFFE8F5E9); 
              corTexto = Colors.green;
              mostrarBotaoVincular = false;
            } else if (projeto.statusVinculoCliente == 'pendente') {
              statusTexto = 'Pendente';
              corFundo = const Color(0xFFFFF3E0); 
              corTexto = AppColors.primary;
              mostrarBotaoVincular = false;
            } else if (projeto.statusVinculoCliente == 'proprio') {
              statusTexto = 'Próprio';
              corFundo = const Color(0xFFE3F2FD); 
              corTexto = Colors.blue;
              mostrarBotaoVincular = false;
            }

            return Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  backgroundImage: AssetImage('assets/images/empresa.png'), // Futuramente projeto.imageUrl
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(projeto.clienteNome ?? 'Cliente não definido', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    _buildBadge(statusTexto, corFundo, corTexto),
                  ],
                ),
                const Spacer(),
                if (mostrarBotaoVincular)
                  CompactButton(
                    text: 'Vincular',
                    onPressed: () {
                      
                    },
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, stack) => const Text('Erro ao carregar dados do proprietário', style: TextStyle(color: Colors.red)),
        ),

        const SizedBox(height: 16),
        const Divider(color: AppColors.inputBorder, thickness: 1),
      ],
    );
  }

  Widget _buildImageHeader() {
    const String defaultAsset = 'assets/images/empresa.png';
    final imageUrl = widget.estrutura.imageUrl;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: (imageUrl == null || imageUrl.isEmpty) 
            ? Image.asset(defaultAsset, width: double.infinity, height: 140, fit: BoxFit.cover)
            : Image.network(
                imageUrl,
                width: double.infinity,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Image.asset(defaultAsset, width: double.infinity, height: 140, fit: BoxFit.cover),
              ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
            child: const Icon(Icons.edit_outlined, color: AppColors.textDark, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}