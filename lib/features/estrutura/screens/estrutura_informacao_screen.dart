import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_dropdown.dart';
import '../../../core/widgets/custom_dropdown_with_add.dart';
import '../../../core/widgets/compact_button.dart';

class EstruturaInformacaoScreen extends StatefulWidget {
  const EstruturaInformacaoScreen({super.key});

  @override
  State<EstruturaInformacaoScreen> createState() => _EstruturaInformacaoScreenState();
}

class _EstruturaInformacaoScreenState extends State<EstruturaInformacaoScreen> {
  final double _fieldSpacing = 16.0;

  // Controllers para os campos de texto
  final _nomeController = TextEditingController(text: 'Estrutura 123');
  final _descricaoController = TextEditingController();
  final _idadeController = TextEditingController(text: '26');
  final _latController = TextEditingController(text: '26');
  final _longController = TextEditingController(text: '26');
  final _cepController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _numeroController = TextEditingController();
  final _paisController = TextEditingController();
  final _ufController = TextEditingController();

  // Variáveis para os Dropdowns
  String? _caaSelecionado;
  String? _conjuntoSelecionado;
  String? _utilizacaoSelecionada;
  String? _tipoEstruturaSelecionado;
  String? _tipologiaSelecionada;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(
        title: 'Estrutura\nInformações', 
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Imagem de Cabeçalho com ícone de edição
            _buildImageHeader(),
            const SizedBox(height: 24),

            // 2. Campos Iniciais (HINT ADICIONADO AQUI)
            CustomTextField(
              label: 'Nome',
              hint: 'Estrutura 123', // <-- Adicionado
              controller: _nomeController,
            ),
            SizedBox(height: _fieldSpacing),

            const Text('Status', style: TextStyle(fontSize: 14, color: AppColors.hintText)),
            const SizedBox(height: 4),
            _buildBadge('Pendente', const Color(0xFFFFF3E0), AppColors.primary),
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

            // 3. Seção do Proprietário
            _buildProprietarioSection(),
            const SizedBox(height: 24),

            // 4. Seção de Cadastro
            const Text(
              'Cadastro',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: CustomDropdown<String>(
                    label: 'CAA',
                    value: _caaSelecionado,
                    items: const [
                      DropdownMenuItem(value: '1', child: Text('I')),
                      DropdownMenuItem(value: '2', child: Text('II')),
                    ],
                    onChanged: (val) => setState(() => _caaSelecionado = val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: CustomTextField(
                    label: 'Idade (anos)',
                    hint: '26', // <-- Adicionado
                    keyboardType: TextInputType.number,
                    controller: _idadeController,
                  ),
                ),
              ],
            ),
            SizedBox(height: _fieldSpacing),

            CustomDropdownWithAdd<String>(
              label: 'Conjunto Estrutural',
              value: _conjuntoSelecionado,
              items: const [DropdownMenuItem(value: '1', child: Text('Conjunto Padrão'))],
              onChanged: (val) => setState(() => _conjuntoSelecionado = val),
              onAddPressed: () {},
            ),
            SizedBox(height: _fieldSpacing),

            CustomDropdownWithAdd<String>(
              label: 'Utilização da estrutura',
              value: _utilizacaoSelecionada,
              items: const [DropdownMenuItem(value: '1', child: Text('Residencial'))],
              onChanged: (val) => setState(() => _utilizacaoSelecionada = val),
              onAddPressed: () {},
            ),
            SizedBox(height: _fieldSpacing),

            CustomDropdownWithAdd<String>(
              label: 'Tipo de estrutura',
              value: _tipoEstruturaSelecionado,
              items: const [DropdownMenuItem(value: '1', child: Text('Concreto Armado'))],
              onChanged: (val) => setState(() => _tipoEstruturaSelecionado = val),
              onAddPressed: () {},
            ),
            SizedBox(height: _fieldSpacing),

            CustomDropdownWithAdd<String>(
              label: 'Tipologia estrutural',
              value: _tipologiaSelecionada,
              items: const [DropdownMenuItem(value: '1', child: Text('Edifício'))],
              onChanged: (val) => setState(() => _tipologiaSelecionada = val),
              onAddPressed: () {},
            ),
            SizedBox(height: _fieldSpacing),

            // Latitude e Longitude (HINTS ADICIONADOS AQUI)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'Latitude', 
                    hint: '26', // <-- Adicionado
                    controller: _latController,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomTextField(
                    label: 'Longitude', 
                    hint: '26', // <-- Adicionado
                    controller: _longController,
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () {},
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

            // Endereço (Os hints já estavam aqui)
            CustomTextField(label: 'CEP', hint: '000000-000', controller: _cepController),
            SizedBox(height: _fieldSpacing),
            CustomTextField(label: 'Endereço', hint: 'Rua...', controller: _enderecoController),
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
                Expanded(child: CustomTextField(label: 'Pais', hint: 'Brasil', controller: _paisController)),
                const SizedBox(width: 16),
                Expanded(child: CustomTextField(label: 'UF', hint: 'XX', controller: _ufController)),
              ],
            ),
            const SizedBox(height: 24),

            // 5. Indicação no mapa (Imagem)
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
    );
  }

  Widget _buildImageHeader() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/images/empresa.png', 
            width: double.infinity,
            height: 140,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: const Icon(Icons.edit_outlined, color: AppColors.textDark, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildProprietarioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: AppColors.inputBorder, thickness: 1),
        const SizedBox(height: 16),
        const Text(
          'Proprietário da estrutura',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 4),
        const Text(
          'O proprietário da estrutura é responsável pela gestão e compartilhamento dos dados',
          style: TextStyle(fontSize: 12, color: AppColors.hintText),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              backgroundImage: AssetImage('assets/images/empresa.png'),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cond. Portal do Solar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                _buildBadge('Não Vinculado', const Color(0xFFFFEBEE), Colors.red),
              ],
            ),
            const Spacer(),
            CompactButton(
              text: 'Vincular',
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: AppColors.inputBorder, thickness: 1),
      ],
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}