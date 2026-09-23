import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:diavicon/core/widgets/foto_ensaio.dart';

import '../../../../core/constants/app_colors.dart';
import '../models/chumbador_model.dart';
import '../../../../core/web/escolher_foto.dart';

// Formulário de nova leitura (carregamento/descarregamento) do ensaio de
// tração em chumbador. Devolve um Map via Navigator.pop — mesmo padrão de
// `NovaMedicaoModal` (Monitoramento de Fissuras). A tabela real
// (`ponto_ensaio_tracao_leitura`) não tem um número de leitura manual — as
// curvas do gráfico são ordenadas por `criado_em` (ordem de inserção).
class NovaLeituraChumbadorModal extends StatefulWidget {
  final LeituraChumbadorModel? leituraExistente;

  const NovaLeituraChumbadorModal({super.key, this.leituraExistente});

  @override
  State<NovaLeituraChumbadorModal> createState() => _NovaLeituraChumbadorModalState();
}

class _NovaLeituraChumbadorModalState extends State<NovaLeituraChumbadorModal> {
  final _forcaCtrl = TextEditingController();
  final _deslocamentoCtrl = TextEditingController();
  final _ocorrenciaCtrl = TextEditingController();
  EtapaLeituraChumbador _etapa = EtapaLeituraChumbador.carregamento;
  File? _fotoLocal;
  String? _fotoUrlExistente;

  @override
  void initState() {
    super.initState();
    final l = widget.leituraExistente;
    _forcaCtrl.text = l?.forcaKn.toStringAsFixed(1) ?? '';
    _deslocamentoCtrl.text = l?.deslocamentoMm.toStringAsFixed(2) ?? '';
    _ocorrenciaCtrl.text = l?.ocorrencia ?? '';
    _etapa = l?.etapa ?? EtapaLeituraChumbador.carregamento;
    _fotoUrlExistente = l?.foto;
  }

  @override
  void dispose() {
    _forcaCtrl.dispose();
    _deslocamentoCtrl.dispose();
    _ocorrenciaCtrl.dispose();
    super.dispose();
  }

  Future<void> _escolherFoto() async {
    final source = origemFotoNoNavegador ?? await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Câmera'), onTap: () => Navigator.pop(context, ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galeria'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ],
        ),
      ),
    );
    if (source == null) return;
    final imagem = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (imagem != null) setState(() => _fotoLocal = File(imagem.path));
  }

  void _salvar() {
    final forca = double.tryParse(_forcaCtrl.text.replaceAll(',', '.'));
    final deslocamento = double.tryParse(_deslocamentoCtrl.text.replaceAll(',', '.'));
    if (forca == null || deslocamento == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe força e deslocamento.'), backgroundColor: Colors.orange));
      return;
    }

    Navigator.pop(context, {
      'etapa': _etapa,
      'forcaKn': forca,
      'deslocamentoMm': deslocamento,
      'foto': _fotoLocal,
      'ocorrencia': _ocorrenciaCtrl.text.trim(),
    });
  }

  Widget _rotulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(texto, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600, letterSpacing: 0.3)),
      );

  Widget _botaoEtapa(EtapaLeituraChumbador etapa) {
    final selecionado = _etapa == etapa;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _etapa = etapa),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selecionado ? etapa.cor.withValues(alpha: 0.12) : Colors.transparent,
            border: Border.all(color: selecionado ? etapa.cor : const Color(0xFF9E9E9E)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(etapa.label, textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w600, color: selecionado ? etapa.cor : Colors.grey.shade700)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ehEdicao = widget.leituraExistente != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ehEdicao ? 'Editar leitura' : 'Nova leitura', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              _rotulo('ETAPA'),
              Row(children: [_botaoEtapa(EtapaLeituraChumbador.carregamento), const SizedBox(width: 10), _botaoEtapa(EtapaLeituraChumbador.descarregamento)]),
              _rotulo('MEDIDAS'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _forcaCtrl,
                      autofocus: !ehEdicao,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Força (kN)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _deslocamentoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Deslocamento (mm)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ],
              ),
              _rotulo('FOTO'),
              // Proporção fixa em vez de altura fixa: a foto não achata em tela
              // larga. Tocar continua trocando a foto.
              FotoEnsaio(
                imagem: imagemDe(
                  url: _fotoUrlExistente,
                  local: _fotoLocal != null ? FileImage(_fotoLocal!) : null,
                ),
                raio: 12,
                aoTocar: _escolherFoto,
                vazio: const Center(child: Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 28)),
                acao: _fotoLocal != null || (_fotoUrlExistente?.isNotEmpty ?? false)
                    ? Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.edit_square, size: 16, color: Color(0xFF3E3E3D)),
                      )
                    : null,
              ),
              _rotulo('OCORRÊNCIA'),
              TextField(
                controller: _ocorrenciaCtrl,
                maxLines: 3,
                decoration: InputDecoration(hintText: 'Ex: Carga máxima atingida, leve ruído no chumbador...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _salvar,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                child: Text('Salvar leitura', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
