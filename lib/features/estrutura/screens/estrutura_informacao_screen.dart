import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_dropdown.dart';
import '../../../core/widgets/custom_dropdown_with_add.dart';
import '../models/estrutura_model.dart';
import '../widgets/proprietario_vinculo_section.dart';
import '../widgets/header_imagem_editavel.dart';
import '../widgets/mapa_preview_widget.dart';

class EstruturaInformacaoScreen extends ConsumerStatefulWidget {
  final EstruturaModel estrutura;
  final String projetoId; 

  const EstruturaInformacaoScreen({super.key, required this.estrutura, required this.projetoId});

  @override
  ConsumerState<EstruturaInformacaoScreen> createState() => _EstruturaInformacaoScreenState();
}

class _EstruturaInformacaoScreenState extends ConsumerState<EstruturaInformacaoScreen> {
  final double _fieldSpacing = 16.0;

  // Controladores de Texto
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

  String? _caaSelecionado, _conjuntoSelecionado, _utilizacaoSelecionada, _tipoEstruturaSelecionado, _tipologiaSelecionada;

  String? _clean(String? val) => (val != null && val.trim().isNotEmpty) ? val : null;

  @override
  void initState() {
    super.initState();
    final e = widget.estrutura;
    _nomeController.text = e.nome ?? '';
    _descricaoController.text = e.descricao ?? '';
    _idadeController.text = e.anoConcepcao?.toString() ?? '';
    _latController.text = e.latitude?.toString() ?? '';
    _longController.text = e.longitude?.toString() ?? '';
    _cepController.text = e.cep ?? '';
    _enderecoController.text = e.endereco ?? '';
    _cidadeController.text = e.cidade ?? '';
    _numeroController.text = e.numero ?? '';
    _paisController.text = e.pais ?? '';
    _ufController.text = e.uf ?? '';

    _caaSelecionado = _clean(e.caa);
    _conjuntoSelecionado = _clean(e.conjuntoEstruturalId);
    _utilizacaoSelecionada = _clean(e.utilizacaoId);
    _tipoEstruturaSelecionado = _clean(e.tipoId);
    _tipologiaSelecionada = _clean(e.tipologiaId);
  }

  @override
  void dispose() {
    _nomeController.dispose(); _descricaoController.dispose(); _idadeController.dispose(); _latController.dispose();
    _longController.dispose(); _cepController.dispose(); _enderecoController.dispose(); _cidadeController.dispose();
    _numeroController.dispose(); _paisController.dispose(); _ufController.dispose();
    super.dispose();
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
      child: Text(widget.estrutura.status ?? 'Pendente', style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    double? latAtual = double.tryParse(_latController.text.trim());
    double? longAtual = double.tryParse(_longController.text.trim());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(title: 'Estrutura\nInformações', showBackButton: true),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeaderImagemEditavel(
              imageUrl: widget.estrutura.imageUrl,
              onEditPressed: () { /* Lógica futura de alterar imagem */ },
            ),
            
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bloco Inicial Desativado
                  AbsorbPointer(
                    absorbing: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomTextField(label: 'Nome', hint: 'Sem nome', controller: _nomeController, enabled: false),
                        SizedBox(height: _fieldSpacing),
                        const Text('Status', style: TextStyle(fontSize: 14, color: AppColors.hintText)),
                        const SizedBox(height: 4),
                        _buildStatusBadge(),
                        SizedBox(height: _fieldSpacing),
                        const Text('Descrição', style: TextStyle(fontSize: 14, color: AppColors.hintText)),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _descricaoController,
                          maxLines: 4,
                          enabled: false, 
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
                            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // Seção do Proprietário (Sincronizada com o Supabase)
                  ProprietarioVinculoSection(projetoId: widget.projetoId),
                  const SizedBox(height: 24),

                  // Bloco de Cadastro e Localização Desativado
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
                            Expanded(flex: 3, child: CustomDropdown<String>(label: 'CAA', value: _caaSelecionado ?? '1', items: [DropdownMenuItem(value: _caaSelecionado ?? '1', child: Text(_caaSelecionado ?? 'Não Informado'))], onChanged: (_) {})),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: CustomTextField(label: 'Idade (anos)', hint: '-', controller: _idadeController, enabled: false)),
                          ],
                        ),
                        CustomDropdownWithAdd<String>(label: 'Conjunto Estrutural', value: _conjuntoSelecionado ?? '1', items: [DropdownMenuItem(value: _conjuntoSelecionado ?? '1', child: Text(widget.estrutura.conjuntoNome ?? 'Não Informado'))], onChanged: (_) {}, onAddPressed: (){}),
SizedBox(height: _fieldSpacing),
CustomDropdownWithAdd<String>(label: 'Utilização da estrutura', value: _utilizacaoSelecionada ?? '1', items: [DropdownMenuItem(value: _utilizacaoSelecionada ?? '1', child: Text(widget.estrutura.utilizacaoNome ?? 'Não Informado'))], onChanged: (_) {}, onAddPressed: (){}),
SizedBox(height: _fieldSpacing),
CustomDropdownWithAdd<String>(label: 'Tipo de estrutura', value: _tipoEstruturaSelecionado ?? '1', items: [DropdownMenuItem(value: _tipoEstruturaSelecionado ?? '1', child: Text(widget.estrutura.tipoNome ?? 'Não Informado'))], onChanged: (_) {}, onAddPressed: (){}),
SizedBox(height: _fieldSpacing),
CustomDropdownWithAdd<String>(label: 'Tipologia estrutural', value: _tipologiaSelecionada ?? '1', items: [DropdownMenuItem(value: _tipologiaSelecionada ?? '1', child: Text(widget.estrutura.tipologiaNome ?? 'Não Informado'))], onChanged: (_) {}, onAddPressed: (){}),
                        SizedBox(height: _fieldSpacing),
                        
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: CustomTextField(label: 'Latitude', hint: '-', controller: _latController, enabled: false)),
                            const SizedBox(width: 8),
                            Expanded(child: CustomTextField(label: 'Longitude', hint: '-', controller: _longController, enabled: false)),
                            const SizedBox(width: 12),
                            // 👇 SIMBOLO DO MAPA AJUSTADO VOLTANDO A SER LARANJA (AppColors.primary) 👇
                            Container(
                              width: 48, 
                              height: 48, 
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), 
                              child: Center(child: Image.asset('assets/images/map_pin.png', width: 24, height: 24, color: Colors.white))
                            ),
                          ],
                        ),
                        SizedBox(height: _fieldSpacing),
                        CustomTextField(label: 'CEP', hint: '-', controller: _cepController, enabled: false),
                        SizedBox(height: _fieldSpacing),
                        CustomTextField(label: 'Endereço', hint: '-', controller: _enderecoController, enabled: false),
                        SizedBox(height: _fieldSpacing),
                        Row(
                          children: [
                            Expanded(child: CustomTextField(label: 'Cidade', hint: '-', controller: _cidadeController, enabled: false)),
                            const SizedBox(width: 16),
                            Expanded(child: CustomTextField(label: 'Número', hint: '-', controller: _numeroController, enabled: false)),
                          ],
                        ),
                        SizedBox(height: _fieldSpacing),
                        Row(
                          children: [
                            Expanded(child: CustomTextField(label: 'País', hint: '-', controller: _paisController, enabled: false)),
                            const SizedBox(width: 16),
                            Expanded(child: CustomTextField(label: 'UF', hint: '-', controller: _ufController, enabled: false)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Mini-Mapa Preview interativo (Read-Only com AbsorbPointer interno)
                        MapaPreviewWidget(
                          latitude: latAtual,
                          longitude: longAtual,
                        ),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}