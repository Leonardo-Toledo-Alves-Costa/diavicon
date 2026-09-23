import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:diavicon/core/widgets/foto_ensaio.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/ponto_arrancamento_ceramica_model.dart';
import '../../../../core/web/escolher_foto.dart';

class ModalPontoLeituraArrancamentoCeramica extends StatefulWidget {
  final PontoLeituraCeramicaModel? leituraExistente;
  final String nomeSugerido;
  final Future<void> Function(PontoLeituraCeramicaModel leitura, File? fotoEnsaio, File? fotoRuptura) onSalvar;
  final Future<void> Function()? onApagar;

  const ModalPontoLeituraArrancamentoCeramica({
    super.key,
    this.leituraExistente,
    required this.nomeSugerido,
    required this.onSalvar,
    this.onApagar,
  });

  @override
  State<ModalPontoLeituraArrancamentoCeramica> createState() => _ModalPontoLeituraArrancamentoCeramicaState();
}

class _ModalPontoLeituraArrancamentoCeramicaState extends State<ModalPontoLeituraArrancamentoCeramica> {
  int _abaSelecionada = 0; 
  bool _salvando = false;

  late TextEditingController _nomeCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _cargaCtrl;

  File? _fotoEnsaioLocal;
  File? _fotoRupturaLocal;
  String? _urlFotoEnsaio;
  String? _urlFotoRuptura;

  final Map<String, TextEditingController> _porcentagemControllers = {};

  @override
  void initState() {
    super.initState();
    final l = widget.leituraExistente;
    _nomeCtrl = TextEditingController(text: l?.nome ?? widget.nomeSugerido);
    _areaCtrl = TextEditingController(text: l?.area != null ? l!.area.toString() : '');
    _cargaCtrl = TextEditingController(text: l?.carga != null ? l!.carga.toString() : '');

    _urlFotoEnsaio = l?.imagemEnsaio;
    _urlFotoRuptura = l?.imagemRuptura;

    for (var cat in CatalogoRupturasCeramica.itens) {
      final rExistente = l?.rupturas.firstWhere(
        (r) => r.tipoRuptura == cat.titulo || r.tipoRuptura == cat.sigla,
        orElse: () => RupturaCeramicaModel(tipoRuptura: '', porcentagem: 0),
      );
      final initialVal = (rExistente != null && rExistente.porcentagem > 0)
          ? rExistente.porcentagem.toStringAsFixed(0)
          : '';
      _porcentagemControllers[cat.id] = TextEditingController(text: initialVal);
      _porcentagemControllers[cat.id]!.addListener(() => setState(() {}));
    }

    _areaCtrl.addListener(() => setState(() {}));
    _cargaCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _areaCtrl.dispose();
    _cargaCtrl.dispose();
    for (var c in _porcentagemControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _areaCalculada {
    return double.tryParse(_areaCtrl.text.replaceAll(',', '.')) ?? 0.0;
  }

  double get _tensaoCalculada {
    final a = _areaCalculada;
    final carga = double.tryParse(_cargaCtrl.text.replaceAll(',', '.')) ?? 0;
    if (a <= 0 || carga <= 0) return 0.0;
    return carga / a;
  }

  double get _somaPorcentagens {
    double soma = 0.0;
    for (var ctrl in _porcentagemControllers.values) {
      final val = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
      soma += val;
    }
    return soma;
  }

  Future<void> _selecionarFoto(bool isEnsaio) async {
    final picker = ImagePicker();
    final source = origemFotoNoNavegador ?? await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.camera_alt, color: AppColors.primary), title: const Text('Câmera'), onTap: () => Navigator.pop(context, ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library, color: AppColors.primary), title: const Text('Galeria'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ],
        ),
      ),
    );

    if (source != null) {
      final file = await picker.pickImage(source: source, imageQuality: 80);
      if (file != null) {
        setState(() {
          if (isEnsaio) {
            _fotoEnsaioLocal = File(file.path);
          } else {
            _fotoRupturaLocal = File(file.path);
          }
        });
      }
    }
  }

  void _tentarSalvar() {
    if (_somaPorcentagens <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe a porcentagem da ruptura (soma deve ser maior que 0%).'), backgroundColor: Colors.red, duration: Duration(seconds: 4)),
      );
      setState(() => _abaSelecionada = 1); 
      return;
    }
    _submeter();
  }

  Future<void> _submeter() async {
    // Trava síncrona de reentrância — o botão "Salvar" só fica desabilitado
    // (`onPressed: _salvando ? null : _tentarSalvar`) a partir do PRÓXIMO
    // rebuild/frame, e `_tentarSalvar` chama este método sem `await`. Num
    // toque duplo rápido, a segunda chamada ainda acha o botão habilitado e
    // entra aqui de novo antes do rebuild acontecer, disparando dois
    // `widget.onSalvar(...)` — que no ponto de arrancamento faz o
    // INSERT/UPDATE em `ponto_ensaio_arrancamento_leitura` — pro mesmo
    // ponto de leitura, duplicando a linha. Setar `_salvando` aqui é
    // síncrono (setState muda o campo na hora, só o rebuild é adiado), então
    // a segunda chamada já vê `_salvando == true` e sai antes de salvar de
    // novo.
    if (_salvando) return;

    setState(() => _salvando = true);
    try {
      final cargaVal = double.tryParse(_cargaCtrl.text.replaceAll(',', '.'));

      List<RupturaCeramicaModel> rupturas = [];
      for (var cat in CatalogoRupturasCeramica.itens) {
        final pVal = double.tryParse(_porcentagemControllers[cat.id]!.text.replaceAll(',', '.')) ?? 0;
        if (pVal > 0) {
          rupturas.add(RupturaCeramicaModel(tipoRuptura: cat.titulo, porcentagem: pVal));
        }
      }

      final leituraModel = PontoLeituraCeramicaModel(
        id: widget.leituraExistente?.id,
        idPontoArrancamento: widget.leituraExistente?.idPontoArrancamento,
        nome: _nomeCtrl.text.trim().isEmpty ? widget.nomeSugerido : _nomeCtrl.text.trim(),
        imagemEnsaio: _urlFotoEnsaio,
        imagemRuptura: _urlFotoRuptura,
        area: _areaCalculada,
        carga: cargaVal,
        rupturas: rupturas,
      );

      await widget.onSalvar(leituraModel, _fotoEnsaioLocal, _fotoRupturaLocal);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final soma = _somaPorcentagens;
    final bool somaValida = (soma == 100.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ponto de Arrancamento',
                    style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(25)),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _abaSelecionada = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(color: _abaSelecionada == 0 ? const Color(0xFFFFA726) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                          child: Text('Informações', textAlign: TextAlign.center, style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 14, color: _abaSelecionada == 0 ? Colors.white : const Color(0xFF757575))),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _abaSelecionada = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(color: _abaSelecionada == 1 ? const Color(0xFFFFA726) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                          child: Text('Ruptura', textAlign: TextAlign.center, style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 14, color: _abaSelecionada == 1 ? Colors.white : const Color(0xFF757575))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: _abaSelecionada == 0 ? _buildAbaInformacoes() : _buildAbaRuptura(soma, somaValida),
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  if (widget.onApagar != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _salvando ? null : widget.onApagar,
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: Text('Apagar', style: GoogleFonts.lato(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _salvando ? null : _tentarSalvar,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: _salvando
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Salvar', style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAbaInformacoes() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nome do ponto', style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF757575))),
          const SizedBox(height: 4),
          TextField(controller: _nomeCtrl, decoration: _inputDeco()),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(child: _buildCardFotoUpload(titulo: 'Realização do Ensaio', fotoLocal: _fotoEnsaioLocal, urlRemota: _urlFotoEnsaio, onTap: () => _selecionarFoto(true))),
              const SizedBox(width: 12),
              Expanded(child: _buildCardFotoUpload(titulo: 'Superfície Rompida', fotoLocal: _fotoRupturaLocal, urlRemota: _urlFotoRuptura, onTap: () => _selecionarFoto(false))),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(child: _buildInputNumerico('Área (mm²)', _areaCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _buildInputNumerico('Carga (N)', _cargaCtrl)),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFEEEEEE))),
            child: Column(
              children: [
                Text('Tensão', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text('${_tensaoCalculada.toStringAsFixed(2)} MPa', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbaRuptura(double soma, bool somaValida) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Forma de ruptura', style: GoogleFonts.lato(fontSize: 14, color: const Color(0xFF555555))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: somaValida ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(12)),
              child: Text(
                '${soma.toStringAsFixed(0)} %',
                style: GoogleFonts.lato(color: somaValida ? const Color(0xFF2E7D32) : Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Expanded(
          child: GridView.builder(
            itemCount: CatalogoRupturasCeramica.itens.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.88),
            itemBuilder: (context, index) {
              final item = CatalogoRupturasCeramica.itens[index];
              final ctrl = _porcentagemControllers[item.id]!;

              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(item.assetPath, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(item.titulo, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(fontSize: 11, color: const Color(0xFF616161))),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 34,
                      width: 75,
                      child: TextField(
                        controller: ctrl,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: _inputDeco(hintText: '00 %').copyWith(contentPadding: EdgeInsets.zero),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInputNumerico(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: GoogleFonts.lato(fontSize: 11, color: const Color(0xFF757575))),
        const SizedBox(height: 4),
        TextField(controller: controller, textAlign: TextAlign.center, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _inputDeco(hintText: '00')),
      ],
    );
  }

  InputDecoration _inputDeco({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: const Color(0xFFF9F9F9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF9E9E9E), width: 1)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF9E9E9E), width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    );
  }

  Widget _buildCardFotoUpload({required String titulo, File? fotoLocal, String? urlRemota, required VoidCallback onTap}) {
    ImageProvider? image;
    if (fotoLocal != null) {
      image = FileImage(fotoLocal);
    } else if (urlRemota != null && urlRemota.isNotEmpty) {
      image = StorageNetworkImage(urlRemota);
    }

    return Column(
      children: [
        Text(titulo, style: GoogleFonts.lato(fontSize: 11, color: const Color(0xFF757575)), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        // Proporção fixa em vez de altura fixa: a foto não achata em tela larga.
        // Tocar continua trocando a foto.
        FotoEnsaio(
          imagem: image,
          raio: 12,
          aoTocar: onTap,
          vazio: const Center(child: Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 36)),
          acao: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.edit_square, size: 18, color: Color(0xFF3E3E3D)),
          ),
        ),
      ],
    );
  }
}