import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/web/escolher_foto.dart';

class PontoInspecaoDetalheScreen extends ConsumerStatefulWidget {
  final String pontoId;

  const PontoInspecaoDetalheScreen({super.key, required this.pontoId});

  @override
  ConsumerState<PontoInspecaoDetalheScreen> createState() => _PontoInspecaoDetalheScreenState();
}

class _PontoInspecaoDetalheScreenState extends ConsumerState<PontoInspecaoDetalheScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nomeCtrl = TextEditingController(text: 'Trincas presentes nas paredes'); // Mock
  final _descCtrl = TextEditingController(text: 'Abertura linear de pequena dimensão...');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nomeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _abrirModalNovaFoto() {
    showDialog(context: context, builder: (_) => ModalNovaFoto(pontoId: widget.pontoId));
  }

  void _abrirModalMarcacaoPlanta() {
    showDialog(context: context, builder: (_) => const ModalMarcacaoPlanta());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(
        title: 'Painel',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            //Text('Empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Inspeção Visual', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Registro', style: TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('Ponto de Inspeção', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
          ),
          
          // TAB BAR
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            height: 40,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade300)),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(color: const Color(0xFFFFA726), borderRadius: BorderRadius.circular(24)),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 13),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [Tab(text: 'Registro'), Tab(text: 'Informações'), Tab(text: 'Anomalias')],
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAbaRegistro(),
                _buildAbaInformacoes(),
                _buildAbaAnomalias(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ABA 1: REGISTRO E GALERIA ---
  Widget _buildAbaRegistro() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nome do Registro', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          TextField(controller: _nomeCtrl, decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)))),
          const SizedBox(height: 24),

          // GALERIA (Foto principal + Thumbs + Botão Add)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Image.asset('assets/images/project_placeholder1.png', fit: BoxFit.cover), // Mock 
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text('Descrição da foto', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Container(height: 55, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: const DecorationImage(image: AssetImage('assets/images/project_placeholder1.png'), fit: BoxFit.cover))),
                    const SizedBox(height: 8),
                    Container(height: 55, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: const DecorationImage(image: AssetImage('assets/images/project_placeholder1.png'), fit: BoxFit.cover))),
                    const SizedBox(height: 8),
                    Container(height: 55, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: const DecorationImage(image: AssetImage('assets/images/project_placeholder1.png'), fit: BoxFit.cover))),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _abrirModalNovaFoto,
                      child: const CircleAvatar(backgroundColor: Color(0xFFFFA726), radius: 24, child: Icon(Icons.add, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text('Descrição', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          TextField(controller: _descCtrl, maxLines: 4, decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)))),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // --- ABA 2: INFORMAÇÕES E PLANTA ---
  Widget _buildAbaInformacoes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDropdownInfo('Local'),
          const SizedBox(height: 16),
          _buildDropdownInfo('Tipo de Elemento'),
          const SizedBox(height: 16),
          _buildDropdownInfo('Elemento Estrutural'),
          const SizedBox(height: 24),

          // PREVIEW DA PLANTA
          Container(
            height: 200,
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300)),
            child: Image.asset('assets/images/planta_elementos_info.png', fit: BoxFit.contain), // Mock da planta
          ),
          const SizedBox(height: 16),
          
          ElevatedButton(
            onPressed: _abrirModalMarcacaoPlanta,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
            child: const Text('Adicionar marcação em Planta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownInfo(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44, padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, hint: const Text('Selecione'), items: const [], onChanged: (val) {})),
              ),
            ),
            const SizedBox(width: 8),
            const CircleAvatar(backgroundColor: Color(0xFFFFA726), radius: 20, child: Icon(Icons.add, color: Colors.white, size: 20)),
          ],
        ),
      ],
    );
  }

  // --- ABA 3: ANOMALIAS ---
  Widget _buildAbaAnomalias() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cadastro de Anomalias', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
              ElevatedButton(
                onPressed: () {}, // Abre catálogo
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: const Text('Novo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Cards de Anomalias Mockados para bater com o Figma
          _buildCardAnomalia('Trinca em concreto', '25%', 'Alto', '30%', '600'),
          const SizedBox(height: 12),
          _buildCardAnomalia('Corrosão de armadura', '50%', 'Médio', '20%', '400'),
        ],
      ),
    );
  }

  Widget _buildCardAnomalia(String nome, String area, String risco, String maj, String gut) {
    Color corRisco = risco == 'Alto' ? Colors.red.shade100 : Colors.orange.shade100;
    Color corTextoRisco = risco == 'Alto' ? Colors.red : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nome, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
              const SizedBox(height: 4),
              Text('Área afetada $area', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: corRisco, borderRadius: BorderRadius.circular(8)), child: Text('Risco Humano $risco', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: corTextoRisco))),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  Text('G.U.T', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(width: 8),
                  Text(gut, style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                ],
              ),
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)), child: Text('Majoração $maj', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54))),
            ],
          ),
        ],
      ),
    );
  }
}

// =======================================================
// MODAL DE NOVA FOTO (Aba Registro)
// =======================================================
class ModalNovaFoto extends StatefulWidget {
  final String pontoId;
  const ModalNovaFoto({super.key, required this.pontoId});

  @override
  State<ModalNovaFoto> createState() => _ModalNovaFotoState();
}

class _ModalNovaFotoState extends State<ModalNovaFoto> {
  File? _foto;
  final _descCtrl = TextEditingController();

  Future<void> _tirarFoto() async {
    final picker = ImagePicker();
    // No navegador não há câmera: abre os arquivos do computador.
    final file = await picker.pickImage(source: origemFotoNoNavegador ?? ImageSource.camera);
    if (file != null) setState(() => _foto = File(file.path));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Nova imagem do ensaio', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold)),
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 24),
            
            GestureDetector(
              onTap: _tirarFoto,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    height: 150, width: double.infinity,
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16), image: _foto != null ? DecorationImage(image: ResizeImage(FileImage(_foto!), width: 1080), fit: BoxFit.cover) : null),
                    child: _foto == null ? const Icon(Icons.camera_alt, color: Colors.grey, size: 40) : null,
                  ),
                  if (_foto != null)
                    Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.edit_square, size: 20)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            Text('Descrição', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            TextField(controller: _descCtrl, decoration: InputDecoration(hintText: 'Descrição da foto', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('Apagar', style: TextStyle(color: Colors.red))),
                ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('Salvar', style: TextStyle(color: Colors.white))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// MODAL INTERATIVO DE MARCAÇÃO EM PLANTA (Aba Informações)
// =======================================================
class ModalMarcacaoPlanta extends StatefulWidget {
  const ModalMarcacaoPlanta({super.key});

  @override
  State<ModalMarcacaoPlanta> createState() => _ModalMarcacaoPlantaState();
}

class _ModalMarcacaoPlantaState extends State<ModalMarcacaoPlanta> {
  // Lógica simplificada para arrastar o pino na planta
  Offset _posicaoPino = const Offset(0.5, 0.5); // Relativo (centro)

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Selecione o local', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.grey)),
              ],
            ),
          ),
          
          Expanded(
            child: Container(
              color: Colors.grey.shade100,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Planta Base
                        Image.asset('assets/images/planta_elementos_info.png', fit: BoxFit.contain, width: constraints.maxWidth, height: constraints.maxHeight),
                        
                        // Pino arrastável
                        Positioned(
                          left: _posicaoPino.dx * constraints.maxWidth - 20, // 20 = half size do pino
                          top: _posicaoPino.dy * constraints.maxHeight - 20,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                double newX = (_posicaoPino.dx * constraints.maxWidth + details.delta.dx) / constraints.maxWidth;
                                double newY = (_posicaoPino.dy * constraints.maxHeight + details.delta.dy) / constraints.maxHeight;
                                _posicaoPino = Offset(newX.clamp(0.0, 1.0), newY.clamp(0.0, 1.0));
                              });
                            },
                            child: const CircleAvatar(backgroundColor: Color(0xFFFFA726), radius: 20, child: Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              ),
            ),
          ),

          // Menu Inferior (Cores e Controles)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))], borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))),
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(backgroundColor: Colors.orange, radius: 16),
                    const SizedBox(width: 8),
                    const CircleAvatar(backgroundColor: Colors.blue, radius: 16),
                    const SizedBox(width: 8),
                    const CircleAvatar(backgroundColor: Colors.red, radius: 16),
                    const SizedBox(width: 8),
                    Icon(Icons.colorize, color: Colors.grey.shade400),
                    const Spacer(),
                    Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.circle_outlined), SizedBox(width: 8), Icon(Icons.square_outlined, color: Colors.orange)])),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context), 
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                      child: const Text('Próximo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}