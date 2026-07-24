import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/compact_button.dart';
import '../../../core/widgets/compact_search_bar.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/diavicon_alerts.dart';

class EnsaiosContratadosScreen extends StatefulWidget {
  final String estruturaId;
  final String empresaId;
  final String empresaNome;
  final bool isGestora; 

  const EnsaiosContratadosScreen({
    super.key,
    required this.estruturaId,
    required this.empresaId,
    required this.empresaNome,
    required this.isGestora,
  });

  @override
  State<EnsaiosContratadosScreen> createState() => _EnsaiosContratadosScreenState();
}

class _EnsaiosContratadosScreenState extends State<EnsaiosContratadosScreen> {
  final List<Map<String, dynamic>> _ensaiosMock = [
    {
      'id': '1',
      'nome': 'Frente de carbonatação',
      'icone': 'assets/images/ensaios/carbonatacao.png', 
      'contratadas': 2,
      'realizadas': 2,
    },
    {
      'id': '2',
      'nome': 'Potencial de corrosão',
      'icone': 'assets/images/ensaios/potencial_corrosao.png',
      'contratadas': 2,
      'realizadas': 1,
    },
    {
      'id': '3',
      'nome': 'Resistividade el. sup.',
      'icone': 'assets/images/ensaios/resistividade.png',
      'contratadas': 2,
      'realizadas': 1,
    },
  ];

  String _searchQuery = '';

  String _obterIconePorNome(String nomeEnsaio) {
    if (nomeEnsaio.contains('carbonatação')) return 'assets/images/ensaios/carbonatacao.png';
    if (nomeEnsaio.contains('corrosão')) return 'assets/images/ensaios/potencial_corrosao.png';
    if (nomeEnsaio.contains('Resistividade')) return 'assets/images/ensaios/resistividade.png';
    if (nomeEnsaio.contains('Esclerometria')) return 'assets/images/ensaios/esclerometria.png';
    if (nomeEnsaio.contains('carga')) return 'assets/images/ensaios/carga_estatica.png';
    return 'assets/images/ensaios/carbonatacao.png'; 
  }

  void _abrirModalNovoEnsaio() {
    String? ensaioSelecionado;
    final qtdController = TextEditingController();

    final List<String> tiposDisponiveis = [
      'Frente de carbonatação',
      'Resistividade el. sup.',
      'Potencial de corrosão',
      'Esclerometria',
      'Prova de carga estática',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            backgroundColor: Colors.white, 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Novo Ensaio',
                        style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF3E3E3D)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, color: AppColors.greyMedium),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text('Ensaio*', style: GoogleFonts.lato(fontSize: 14, color: AppColors.greyMedium)),
                  const SizedBox(height: 8),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.inputBorder), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: ensaioSelecionado,
                        hint: Text('Selecione', style: GoogleFonts.lato(color: AppColors.greyMedium)),
                        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textDark),
                        items: tiposDisponiveis.map((tipo) {
                          return DropdownMenuItem<String>(
                            value: tipo,
                            child: Text(tipo, style: GoogleFonts.lato(color: const Color(0xFF3E3E3D))),
                          );
                        }).toList(),
                        onChanged: (val) => setStateDialog(() => ensaioSelecionado = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('Qtd*', style: GoogleFonts.lato(fontSize: 14, color: AppColors.greyMedium)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: qtdController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '00',
                        hintStyle: GoogleFonts.lato(color: AppColors.greyMedium),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Ao adicionar um ensaio, o mesmo será adicionado ao contrato, sendo acessível no painel de gestão de empresas no projeto',
                    style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyMedium, height: 1.4),
                  ),
                  const SizedBox(height: 24),

                  Center(
                    child: CompactButton(
                      text: 'Incluir',
                      width: 120,
                      backgroundColor: AppColors.primary,
                      onPressed: () {
                        if (ensaioSelecionado == null || qtdController.text.isEmpty) {
                          DiaviconAlerts.show(context, 'Atenção', 'Preencha o ensaio e a quantidade.', isAviso: true);
                          return;
                        }
                        
                        setState(() {
                          _ensaiosMock.add({
                            'id': DateTime.now().millisecondsSinceEpoch.toString(),
                            'nome': ensaioSelecionado!,
                            'icone': _obterIconePorNome(ensaioSelecionado!), 
                            'contratadas': int.tryParse(qtdController.text) ?? 1,
                            'realizadas': 0,
                          });
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _deletarEnsaio(String id) {
    setState(() {
      _ensaiosMock.removeWhere((ensaio) => ensaio['id'] == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ensaiosFiltrados = _ensaiosMock.where((e) => e['nome'].toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(
        title: 'Estrutura',
        showBackButton: true,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Projeto', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
            Text('Estrutura', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Ensaios', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ensaios contratados',
              style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D)),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: CompactSearchBar(
                    hintText: 'Nome do Ensaio',
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                if (widget.isGestora) ...[
                  const SizedBox(width: 12),
                  CompactButton(
                    text: 'Adicionar',
                    width: 100,
                    backgroundColor: AppColors.primary,
                    onPressed: _abrirModalNovoEnsaio,
                  ),
                ]
              ],
            ),
            const SizedBox(height: 24),

            Expanded(
              child: ListView.separated(
                itemCount: ensaiosFiltrados.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final ensaio = ensaiosFiltrados[index];
                  final bool completado = ensaio['realizadas'] >= ensaio['contratadas'];
                  
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔥 VOLTOU PARA IMAGE.ASSET
                        SizedBox(
                          width: 42,
                          height: 42,
                          child: Image.asset(
                            ensaio['icone'],
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.science_outlined, color: AppColors.textDark, size: 28),
                          ),
                        ),
                        const SizedBox(width: 14),
                        
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ensaio['nome'],
                                style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${ensaio['contratadas'].toString().padLeft(2, '0')} Und. contratadas',
                                      style: GoogleFonts.lato(fontSize: 11, color: AppColors.greyMedium),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: completado ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${ensaio['realizadas'].toString().padLeft(2, '0')} Und. realizadas',
                                      style: GoogleFonts.lato(
                                        color: completado ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        if (widget.isGestora) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _deletarEnsaio(ensaio['id']),
                            child: const Icon(Icons.delete_outline, color: AppColors.textDark, size: 22),
                          ),
                        ]
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}