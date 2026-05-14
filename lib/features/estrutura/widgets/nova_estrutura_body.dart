import 'package:diavicon/core/widgets/rodape_seguro.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:diavicon/core/widgets/custom_appbar.dart';
import 'package:diavicon/core/widgets/diavicon_menu_item.dart';
import 'package:diavicon/core/widgets/menu_drawer_app_bar.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_dropdown.dart';
import '../../../core/widgets/custom_dropdown_with_add.dart';
import '../providers/estrutura_provider.dart';
import '../models/estrutura_model.dart';
import '../../../core/widgets/compact_button.dart';

class NovaEstruturaScreen extends ConsumerStatefulWidget {
  final String projetoId; 
  const NovaEstruturaScreen({super.key, required this.projetoId});

  @override
  ConsumerState<NovaEstruturaScreen> createState() => _NovaEstruturaScreenState();
}

class _NovaEstruturaScreenState extends ConsumerState<NovaEstruturaScreen> {
  // Único lugar para alterar o espaçamento entre todos os campos
  final double _fieldSpacing = 16.0; 
  bool _isLoading = false;

  // Controladores de texto 
  final _nomeController = TextEditingController();
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

  @override
  void dispose() {
    //limpa a memória quando a tela é fechada
    _nomeController.dispose();
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
       
      appBar: const CustomAppBar(title: 'Projeto', showBackButton: true,), 
      
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, 
          children: [
            // Seletor de Imagem Centralizado
            Center(
              child: Stack(
                children: [
                  const CircleAvatar(
                    radius: 45,
                    backgroundColor: AppColors.background,
                    backgroundImage: AssetImage('assets/images/empresa.png'), 
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.textDark, width: 1.5),
                      ),
                      child: const Icon(Icons.edit_outlined, color: AppColors.textDark, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            CustomTextField(
              label: 'Nome da estrutura',
              hint: 'ABC Corp.',
              controller: _nomeController,
            ),
            SizedBox(height: _fieldSpacing),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: CustomDropdown<String>(
                    label: 'CAA',
                    tooltip: 'Classe de Agressividade Ambiental',
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
                  flex: 2,
                  child: CustomTextField(
                    label: 'Idade (anos)',
                    hint: '26',
                    keyboardType: TextInputType.number,
                    controller: _idadeController,
                  ),
                ),
              ],
            ),
            SizedBox(height: _fieldSpacing),

            // Conjunto Estrutural
            CustomDropdownWithAdd<String>(
              label: 'Conjunto Estrutural',
              value: _conjuntoSelecionado,
              items: const [
                DropdownMenuItem(value: 'Setor Industrial Norte', child: Text('Setor Industrial Norte')),
                DropdownMenuItem(value: 'Conjunto A', child: Text('Conjunto A')),
              ],
              onChanged: (val) => setState(() => _conjuntoSelecionado = val),
              onAddPressed: () {},
            ),
            SizedBox(height: _fieldSpacing),

            // Utilização
            CustomDropdownWithAdd<String>(
              label: 'Utilização da estrutura',
              value: _utilizacaoSelecionada,
              items: const [
                DropdownMenuItem(value: 'Industrial', child: Text('Industrial')),
                DropdownMenuItem(value: 'Comercial', child: Text('Comercial')),
                DropdownMenuItem(value: 'Residencial', child: Text('Residencial')),
              ],
              onChanged: (val) => setState(() => _utilizacaoSelecionada = val),
              onAddPressed: () {},
            ),
            SizedBox(height: _fieldSpacing),

            // Tipo de Estrutura
            CustomDropdownWithAdd<String>(
              label: 'Tipo de estrutura',
              value: _tipoEstruturaSelecionado,
              items: const [
                DropdownMenuItem(value: 'Concreto Armado', child: Text('Concreto Armado')),
                DropdownMenuItem(value: 'Aço', child: Text('Aço')),
                DropdownMenuItem(value: 'Madeira', child: Text('Madeira')),
              ],
              onChanged: (val) => setState(() => _tipoEstruturaSelecionado = val),
              onAddPressed: () {},
            ),
            SizedBox(height: _fieldSpacing),

            // Tipologia Estrutural
            CustomDropdownWithAdd<String>(
              label: 'Tipologia estrutural',
              value: _tipologiaSelecionada,
              items: const [
                DropdownMenuItem(value: 'Edifício', child: Text('Edifício')),
                DropdownMenuItem(value: 'Galpão', child: Text('Galpão')),
                DropdownMenuItem(value: 'Ponte', child: Text('Ponte')),
              ],
              onChanged: (val) => setState(() => _tipologiaSelecionada = val),
              onAddPressed: () {},
            ),
            SizedBox(height: _fieldSpacing),

            // Linha Latitude e Longitude
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'Latitude',
                    hint: '26',
                    controller: _latController,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomTextField(
                    label: 'Longitude',
                    hint: '26',
                    controller: _longController,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Botão GPS 
                InkWell(
                  onTap: () {
                    // TODO: Abrir seletor de mapa futuramente
                  },
                  borderRadius: BorderRadius.circular(24),
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

            // campos de endereço
            CustomTextField(label: 'CEP', hint: '000.000.000-00', controller: _cepController, keyboardType: TextInputType.number),
            SizedBox(height: _fieldSpacing),
            CustomTextField(label: 'Endereço', hint: 'Rua....', controller: _enderecoController),
            SizedBox(height: _fieldSpacing),

            Row(
              children: [
                Expanded(child: CustomTextField(label: 'Cidade', hint: 'Cidade', controller: _cidadeController)),
                const SizedBox(width: 16),
                Expanded(child: CustomTextField(label: 'Número', hint: '123', controller: _numeroController)),
              ],
            ),
            SizedBox(height: _fieldSpacing),

            Row(
              children: [
                Expanded(child: CustomTextField(label: 'País', hint: 'Brasil', controller: _paisController)),
                const SizedBox(width: 16),
                Expanded(child: CustomTextField(label: 'UF', hint: 'XX', controller: _ufController)),
              ],
            ),
            SizedBox(height: _fieldSpacing),

            // Indicação no mapa placeholder
            const Text('Indicação no mapa', style: TextStyle(fontSize: 14, color: AppColors.hintText)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 40, color: AppColors.hintText),
                  SizedBox(height: 8),
                  Text('Mapa da Estrutura', style: TextStyle(color: AppColors.hintText)),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Botão criar conectado ao Supabase
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
    );
  }

  Future<void> _handleCriar() async {
    if (_nomeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O nome da estrutura é obrigatório.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final novaEstrutura = EstruturaModel(
        id: '', 
        nome: _nomeController.text,
        caa: _caaSelecionado,
        idadeAnos: int.tryParse(_idadeController.text),
        conjuntoEstrutural: _conjuntoSelecionado,
        utilizacao: _utilizacaoSelecionada,
        tipo: _tipoEstruturaSelecionado,
        tipologiaEstrutural: _tipologiaSelecionada,
        latitude: double.tryParse(_latController.text),
        longitude: double.tryParse(_longController.text),
        cep: _cepController.text.isNotEmpty ? _cepController.text : null,
        endereco: _enderecoController.text.isNotEmpty ? _enderecoController.text : null,
        cidade: _cidadeController.text.isNotEmpty ? _cidadeController.text : null,
        numero: _numeroController.text.isNotEmpty ? _numeroController.text : null,
        pais: _paisController.text.isNotEmpty ? _paisController.text : null,
        uf: _ufController.text.isNotEmpty ? _ufController.text : null,
        status: 'Pendente', 
      );

      await ref.read(estruturaRepositoryProvider).criarEstrutura(novaEstrutura, widget.projetoId);
      ref.invalidate(projetoEstruturasProvider(widget.projetoId));

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Estrutura criada com sucesso!'), backgroundColor: Colors.green),
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
}