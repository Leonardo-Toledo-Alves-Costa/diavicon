import 'package:diavicon/features/ensaios/screens/ensaio_carbonatacao_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/compact_button.dart';
import '../../../core/widgets/compact_search_bar.dart';
import '../../../core/widgets/custom_appbar.dart';

class PontosEnsaioScreen extends StatefulWidget {
  final String elementoNome; 
  final String tipoEnsaioNome; 
  final String iconeEnsaio; // Caminho do PNG (ex: assets/images/ensaios/carbonatacao.png)
  final String projetoNome; 
  final String localElemento; 

  const PontosEnsaioScreen({
    super.key,
    required this.elementoNome,
    required this.tipoEnsaioNome,
    required this.iconeEnsaio,
    required this.projetoNome,
    required this.localElemento,
  });

  @override
  State<PontosEnsaioScreen> createState() => _PontosEnsaioScreenState();
}

class _PontosEnsaioScreenState extends State<PontosEnsaioScreen> {
  final List<Map<String, dynamic>> _pontosMock = [
    {
      'id': '1',
      'nome': 'Ponto 01',
      'tipo_elemento': 'Viga - Concreto armado', 
      'local': '2ª Subsolo',
      'risco': 'Risco Alto',
      'cor_risco': const Color(0xFFFFEBEE),
      'cor_texto_risco': const Color(0xFFF44336),
      'avatar_empresa': 'https://img.freepik.com/vetores-gratis/logotipo-do-passaro-colorido-gradiente_343694-1365.jpg',
    },
    {
      'id': '2',
      'nome': 'Ponto 02',
      'tipo_elemento': 'Viga - Concreto armado',
      'local': '2ª Subsolo',
      'risco': 'Despassivado',
      'cor_risco': const Color(0xFFFFEBEE),
      'cor_texto_risco': const Color(0xFFF44336),
      'avatar_empresa': 'https://img.freepik.com/vetores-gratis/logotipo-do-passaro-colorido-gradiente_343694-1365.jpg',
    },
    {
      'id': '3',
      'nome': 'Ponto 03',
      'tipo_elemento': 'Viga - Concreto armado',
      'local': '2ª Subsolo',
      'risco': 'Risco Baixo',
      'cor_risco': const Color(0xFFE8F5E9),
      'cor_texto_risco': const Color(0xFF4CAF50),
      'avatar_empresa': 'https://img.freepik.com/vetores-gratis/logotipo-do-passaro-colorido-gradiente_343694-1365.jpg',
    },
  ];

  String _searchQuery = '';
  String _filtroStatus = 'Todos';

  @override
  Widget build(BuildContext context) {
    final pontosFiltrados = _pontosMock.where((p) => p['nome'].toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Projeto', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
            Text('Ensaio', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                // 🔥 VOLTOU PARA IMAGE.ASSET
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Image.asset(
                    widget.iconeEnsaio, 
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.science_outlined, color: AppColors.textDark, size: 36),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tipoEnsaioNome,
                        style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.projetoNome,
                        style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868)),
                      ),
                      Text(
                        'Edifício / ${widget.elementoNome}',
                        style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Progresso no projeto', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF3E3E3D))),
                      Text('05/07', style: GoogleFonts.lato(fontSize: 14, color: const Color(0xFF686868))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: 5 / 7,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFFFE0B2),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('71%', style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pontos de Ensaio',
                  style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D)),
                ),
                CompactButton(text: 'Novo', width: 80, onPressed: () {}), 
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: CompactSearchBar(
                    hintText: 'Local',
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFD9D9D9)), borderRadius: BorderRadius.circular(20)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _filtroStatus,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                        style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF3E3E3D)),
                        items: ['Todos', 'Concluídos', 'Pendentes'].map((String value) {
                          return DropdownMenuItem<String>(value: value, child: Text(value));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _filtroStatus = val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              itemCount: pontosFiltrados.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final ponto = pontosFiltrados[index];
                return GestureDetector(
                  onTap: () {
                    // 🔥 NAVEGAÇÃO PARA O FORMULÁRIO
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EnsaioCarbonatacaoFormScreen(
                          pontoNome: ponto['nome'],
                          elementoNome: widget.elementoNome,
                          tipoElemento: ponto['tipo_elemento'],
                          local: ponto['local'],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade200,
                            image: const DecorationImage(
                              image: NetworkImage('https://t3.ftcdn.net/jpg/04/79/35/05/360_F_479350587_b9l5C8V60p4uK5q4Q8gC5p2N6k9X3M3p.jpg'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${widget.elementoNome} - ${ponto['nome']}',
                                    style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF3E3E3D)),
                                  ),
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundImage: NetworkImage(ponto['avatar_empresa']),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ponto['tipo_elemento'],
                                style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868)),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    ponto['local'],
                                    style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: ponto['cor_risco'],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      ponto['risco'],
                                      style: GoogleFonts.lato(
                                        color: ponto['cor_texto_risco'],
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}