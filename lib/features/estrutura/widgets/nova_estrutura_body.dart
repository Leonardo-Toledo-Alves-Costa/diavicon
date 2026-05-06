import 'package:diavicon/core/widgets/custom_appbar.dart';
import 'package:diavicon/core/widgets/diavicon_menu_item.dart';
import 'package:diavicon/core/widgets/menu_app_bar.dart';
import 'package:diavicon/core/widgets/menu_drawer_app_bar.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_dropdown.dart';
import '../../../core/widgets/custom_dropdown_with_add.dart';

class NovaEstruturaScreen extends StatefulWidget {
  const NovaEstruturaScreen({super.key});

  @override
  State<NovaEstruturaScreen> createState() => _NovaEstruturaScreenState();
}

class _NovaEstruturaScreenState extends State<NovaEstruturaScreen> {
  // Único lugar para alterar o espaçamento entre todos os campos
  final double _fieldSpacing = 14.0; 

  final _nomeController = TextEditingController();
  final _idadeController = TextEditingController();
  final _latController = TextEditingController();
  final _longController = TextEditingController();

  String? _caaSelecionado;
  String? _conjuntoSelecionado;
  String? _utilizacaoSelecionada;
  String? _tipoEstruturaSelecionado;
  String? _tipologiaSelecionada;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
       endDrawer: MenuDrawerAppBar(
          title: 'Menu da\nEstrutura',
          items: [
            DiaviconMenuItem(
              icon: Icons.info_outline,
              label: 'Informações',
              onTap: () => Navigator.pop(context),
            ),
            DiaviconMenuItem(
              icon: Icons.layers_outlined,
              label: 'Planejamento',
              onTap: () {},
            ),
            DiaviconMenuItem(
              icon: Icons.science_outlined,
              label: 'Ensaios',
              onTap: () {},
            ),
            DiaviconMenuItem(
              icon: Icons.description_outlined,
              label: 'Relatórios',
              onTap: () {},
            ),
            DiaviconMenuItem(
              icon: Icons.pie_chart_outline,
              label: 'Dashboard',
              onTap: () {},
            ),
          ],
        ),
      appBar: const CustomAppBar(title: 'Projetos', showBackButton: true),
      
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, 
          children: [
            const SizedBox(height: 24),
            // Título
            const Center(
              child: Text(
                'Nova Estrutura',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Seletor de Imagem
            Center(
              child: Stack(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.background,
                    backgroundImage: AssetImage('assets/images/empresa.png'),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.edit_note, color: AppColors.textDark, size: 28),
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
                    hint: '26',
                    keyboardType: TextInputType.number,
                    controller: _idadeController,
                  ),
                ),
              ],
            ),
            SizedBox(height: _fieldSpacing),

            CustomDropdownWithAdd<String>(
              label: 'Conjunto Estrutural',
              tooltip: 'Defina o agrupamento',
              hint: 'Selecione',
              value: _conjuntoSelecionado,
              items: const [DropdownMenuItem(value: '1', child: Text('Conjunto A'))],
              onChanged: (val) => setState(() => _conjuntoSelecionado = val),
              onAddPressed: () {},
            ),
            SizedBox(height: _fieldSpacing),

            CustomDropdownWithAdd<String>(
              label: 'Utilização da estrutura',
              value: _utilizacaoSelecionada,
              items: const [DropdownMenuItem(value: '1', child: Text('Comercial'))],
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

            //Row latitude longitude
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
                
                //botãoo gps
                InkWell(
                  onTap: () {
                    
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
            
            const SizedBox(height: 40),

            // Botãp criar
            Center(
              child: SizedBox(
                width: 180, 
                height: 50, 
                child: ElevatedButton(
                  onPressed: () {
                    // Lógica para criar a nova estrutura
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30), 
                    ),
                  ),
                  child: const Text(
                    'Criar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}