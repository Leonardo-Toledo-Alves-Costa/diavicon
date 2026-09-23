import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:diavicon/core/widgets/foto_ensaio.dart';

import '../../../../core/constants/app_colors.dart';
import '../models/monitoramento_fissura_model.dart';
import '../../../../core/web/escolher_foto.dart';

// Formulário de nova medição — o campo "Rompido?" só aparece quando o selo
// da instalação permite rompimento (gesso/vidro). Devolve um Map via
// Navigator.pop pra tela chamadora calcular a variação/status (que depende
// da medição ANTERIOR, que só a tela tem carregada).
//
// Hora digitada em 2 campos (HH/MM) em vez do `showTimePicker` padrão do
// Flutter — abrir um diálogo de relógio POR CIMA de um bottom sheet que já
// é, ele mesmo, uma espécie de modal, ficava lento/confuso (2 diálogos
// empilhados só pra marcar a hora). Datas digitadas erradas viram `null`
// nos campos e ficam destacadas em vermelho, sem travar o teclado.
class NovaMedicaoModal extends StatefulWidget {
  final bool seloPermiteRompimento;
  final MedicaoFissuraModel? medicaoExistente;
  final MedicaoFissuraModel? medicaoAnterior;

  const NovaMedicaoModal({super.key, required this.seloPermiteRompimento, this.medicaoExistente, this.medicaoAnterior});

  @override
  State<NovaMedicaoModal> createState() => _NovaMedicaoModalState();
}

class _NovaMedicaoModalState extends State<NovaMedicaoModal> {
  late DateTime _data;
  final _horaCtrl = TextEditingController();
  final _minutoCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  final _temperaturaCtrl = TextEditingController();
  final _umidadeCtrl = TextEditingController();
  final _medidaXCtrl = TextEditingController();
  final _medidaYCtrl = TextEditingController();
  bool _rompido = false;
  File? _fotoLocal;
  String? _fotoUrlExistente;

  @override
  void initState() {
    super.initState();
    final m = widget.medicaoExistente;
    final dh = m?.dataHora ?? DateTime.now();
    _data = DateTime(dh.year, dh.month, dh.day);
    _horaCtrl.text = dh.hour.toString().padLeft(2, '0');
    _minutoCtrl.text = dh.minute.toString().padLeft(2, '0');
    _descricaoCtrl.text = m?.descricao ?? '';
    _temperaturaCtrl.text = m?.temperatura?.toStringAsFixed(0) ?? '';
    _umidadeCtrl.text = m?.umidade?.toStringAsFixed(0) ?? '';
    _medidaXCtrl.text = m?.medidaX.toStringAsFixed(2) ?? '';
    _medidaYCtrl.text = m?.medidaY.toStringAsFixed(2) ?? '';
    _fotoUrlExistente = m?.foto;
    _rompido = m?.rompido ?? false;
  }

  @override
  void dispose() {
    _horaCtrl.dispose();
    _minutoCtrl.dispose();
    _descricaoCtrl.dispose();
    _temperaturaCtrl.dispose();
    _umidadeCtrl.dispose();
    _medidaXCtrl.dispose();
    _medidaYCtrl.dispose();
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

  void _usarAgora() {
    final agora = DateTime.now();
    setState(() {
      _data = DateTime(agora.year, agora.month, agora.day);
      _horaCtrl.text = agora.hour.toString().padLeft(2, '0');
      _minutoCtrl.text = agora.minute.toString().padLeft(2, '0');
    });
  }

  void _salvar() {
    final medidaX = double.tryParse(_medidaXCtrl.text.replaceAll(',', '.'));
    final medidaY = double.tryParse(_medidaYCtrl.text.replaceAll(',', '.'));
    if (medidaX == null || medidaY == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe as medidas X e Y.'), backgroundColor: Colors.orange));
      return;
    }

    final hora = (int.tryParse(_horaCtrl.text) ?? 0).clamp(0, 23);
    final minuto = (int.tryParse(_minutoCtrl.text) ?? 0).clamp(0, 59);
    final dataHora = DateTime(_data.year, _data.month, _data.day, hora, minuto);

    Navigator.pop(context, {
      'dataHora': dataHora,
      'foto': _fotoLocal,
      'descricao': _descricaoCtrl.text.trim(),
      'temperatura': double.tryParse(_temperaturaCtrl.text.replaceAll(',', '.')),
      'umidade': double.tryParse(_umidadeCtrl.text.replaceAll(',', '.')),
      'medidaX': medidaX,
      'medidaY': medidaY,
      'rompido': widget.seloPermiteRompimento ? _rompido : false,
    });
  }

  Widget _rotulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(texto, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600, letterSpacing: 0.3)),
      );

  @override
  Widget build(BuildContext context) {
    final ehEdicao = widget.medicaoExistente != null;
    final anterior = widget.medicaoAnterior;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
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
                  Text(ehEdicao ? 'Editar medição' : 'Nova medição', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              if (anterior != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    'Leitura anterior: X ${anterior.medidaX.toStringAsFixed(2)}mm · Y ${anterior.medidaY.toStringAsFixed(2)}mm'
                    '${anterior.dataHora != null ? ' (${DateFormat('dd/MM/yyyy').format(anterior.dataHora!)})' : ''}',
                    style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
              _rotulo('QUANDO'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: () async {
                        final data = await showDatePicker(context: context, initialDate: _data, firstDate: DateTime(2020), lastDate: DateTime(2100));
                        if (data != null) setState(() => _data = data);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFF9E9E9E)), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey),
                            const SizedBox(width: 10),
                            Text(DateFormat('dd/MM/yyyy').format(_data), style: GoogleFonts.lato(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 68,
                    child: TextField(
                      controller: _horaCtrl,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w600),
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        labelText: 'HH',
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14), child: Text(':', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold))),
                  SizedBox(
                    width: 68,
                    child: TextField(
                      controller: _minutoCtrl,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w600),
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        labelText: 'MM',
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _usarAgora,
                  icon: const Icon(Icons.access_time, size: 16),
                  label: const Text('Agora'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                ),
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
              _rotulo('MEDIDAS (MM)'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _medidaXCtrl,
                      autofocus: !ehEdicao,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Eixo X', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _medidaYCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Eixo Y', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ],
              ),
              _rotulo('CONDIÇÕES'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _temperaturaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Temperatura (°C)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _umidadeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Umidade (%)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ],
              ),
              if (widget.seloPermiteRompimento)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Selo rompido?', style: GoogleFonts.lato(fontSize: 14)),
                  value: _rompido,
                  activeThumbColor: Colors.red,
                  onChanged: (v) => setState(() => _rompido = v),
                ),
              _rotulo('OBSERVAÇÕES'),
              TextField(
                controller: _descricaoCtrl,
                maxLines: 3,
                decoration: InputDecoration(hintText: 'Descrição da fissura/leitura...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _salvar,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                child: Text('Salvar medição', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
