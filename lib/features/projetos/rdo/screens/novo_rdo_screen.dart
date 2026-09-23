import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';
import 'package:diavicon/features/planos/acesso_plano.dart';

import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/custom_appbar.dart';
import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../../equipe/providers/equipe_provider.dart';
import '../models/rdo_realizado_model.dart';
import '../providers/rdo_provider.dart';
import '../repositories/galeria_rdo_repository.dart';
import '../widgets/rdo_modals.dart';
import '../../../../core/web/escolher_foto.dart';

enum PeriodoRdo { manha, tarde, noite }

/// Foto da galeria ainda não enviada — o RDO só existe (tem `id`) depois de
/// salvo, então a foto fica local até o `_salvar()` final, quando é enviada
/// e vinculada ao `rdo_id` recém-criado. Depois de salvo, a galeria do RDO
/// vira só consulta (ver `RdoDetalheScreen`).
class _FotoRdoDraft {
  final File arquivo;
  String descricao = '';
  _FotoRdoDraft({required this.arquivo});
}

class NovoRdoScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String projetoNome;

  const NovoRdoScreen({super.key, required this.projetoId, this.projetoNome = 'Projeto'});

  @override
  ConsumerState<NovoRdoScreen> createState() => _NovoRdoScreenState();
}

class _NovoRdoScreenState extends ConsumerState<NovoRdoScreen> {
  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _atividadesController = TextEditingController();
  final TextEditingController _equipamentosController = TextEditingController();
  final TextEditingController _observacoesController = TextEditingController();

  final TextEditingController _chegadaController = TextEditingController();
  final TextEditingController _inicioController = TextEditingController();
  final TextEditingController _saidaController = TextEditingController();

  PeriodoRdo _periodoSelecionado = PeriodoRdo.manha;
  bool _salvando = false;
  bool _importando = false;

  final Map<PeriodoRdo, TurnoRealizado> _turnos = {
    PeriodoRdo.manha: const TurnoRealizado(),
    PeriodoRdo.tarde: const TurnoRealizado(),
    PeriodoRdo.noite: const TurnoRealizado(),
  };

  static const List<String> _opcoesCondicaoTrabalho = ['Praticável', 'Impraticável', 'Parcial'];
  static const List<String> _opcoesCondicaoClima = ['Ensolarado', 'Nublado', 'Chuvoso', 'Tempestade', 'N.A.'];

  final List<String> _equipeSelecionada = [];
  final List<_FotoRdoDraft> _fotos = [];

  String _nomeMembro(Map<String, dynamic> membro) {
    final usuario = membro['usuario'] as Map<String, dynamic>?;
    final nome = usuario?['nome']?.toString() ?? '';
    final sobrenome = usuario?['sobrenome']?.toString() ?? '';
    return '$nome $sobrenome'.trim();
  }

  String _cargoMembro(Map<String, dynamic> membro) {
    final usuario = membro['usuario'] as Map<String, dynamic>?;
    return usuario?['cargo']?.toString() ?? '';
  }

  String? _fotoMembro(Map<String, dynamic> membro) {
    final usuario = membro['usuario'] as Map<String, dynamic>?;
    final foto = usuario?['foto_url']?.toString();
    return (foto == null || foto.isEmpty) ? null : foto;
  }

  @override
  void initState() {
    super.initState();
    _carregarCamposDoTurno();
  }

  @override
  void dispose() {
    _dataController.dispose();
    _atividadesController.dispose();
    _equipamentosController.dispose();
    _observacoesController.dispose();
    _chegadaController.dispose();
    _inicioController.dispose();
    _saidaController.dispose();
    super.dispose();
  }

  void _carregarCamposDoTurno() {
    final turno = _turnos[_periodoSelecionado]!;
    _chegadaController.text = turno.chegada;
    _inicioController.text = turno.inicio;
    _saidaController.text = turno.saida;
  }

  void _atualizarTurnoAtual({
    String? chegada,
    String? inicio,
    String? saida,
    String? condTrabalho,
    String? condClima,
  }) {
    final atual = _turnos[_periodoSelecionado]!;
    _turnos[_periodoSelecionado] = atual.copyWith(
      chegada: chegada,
      inicio: inicio,
      saida: saida,
      condTrabalho: condTrabalho,
      condClima: condClima,
    );
  }

  @override
  Widget build(BuildContext context) {
    final turnoAtual = _turnos[_periodoSelecionado]!;
    final equipeAsync = ref.watch(colaboradoresAtivosProjetoProvider(widget.projetoId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'RDO',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.projetoNome,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
            ),
            const Text('Novo RDO', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRotulo('Equipe'),
              const SizedBox(height: 6),
              _buildSeletorEquipe(context, equipeAsync),
              const SizedBox(height: 10),
              _buildAvataresEquipe(equipeAsync.value ?? const []),
              const SizedBox(height: 20),
              _buildRotulo('Data'),
              const SizedBox(height: 6),
              _buildCampoData(context),
              const SizedBox(height: 20),
              _buildSeletorPeriodo(),
              const SizedBox(height: 12),
              _buildBoxTurno(turnoAtual),
              const SizedBox(height: 20),
              _buildRotuloAtividades(context),
              const SizedBox(height: 6),
              _buildTextarea(_atividadesController, 'Medição de abc...'),
              const SizedBox(height: 20),
              _buildRotulo('Equipamentos utilizados'),
              const SizedBox(height: 6),
              _buildTextarea(_equipamentosController, 'Ultrassom...'),
              const SizedBox(height: 20),
              _buildRotulo('Observações'),
              const SizedBox(height: 6),
              _buildTextarea(_observacoesController, 'No momento do uso do equipamento...'),
              const SizedBox(height: 20),
              _buildRotulo('Galeria'),
              const SizedBox(height: 6),
              _buildGaleriaDraft(),
              const SizedBox(height: 28),
              _buildBotaoSalvar(context),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRotulo(String texto) {
    return Text(texto, style: GoogleFonts.lato(fontSize: 14, color: const Color(0xFF3E3E3D), fontWeight: FontWeight.w600));
  }

  Widget _buildRotuloAtividades(BuildContext context) {
    final bool dataPreenchida = _dataController.text.isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildRotulo('Atividades realizadas'),
        if (dataPreenchida)
          TextButton.icon(
            onPressed: _importando ? null : () => _importarAtividadesDaData(context),
            icon: _importando
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.download_rounded, size: 16, color: AppColors.primary),
            label: Text(
              'Importar atividades da data',
              style: GoogleFonts.lato(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
            ),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFCE7CC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ),
      ],
    );
  }

  Widget _buildSeletorEquipe(BuildContext context, AsyncValue<List<Map<String, dynamic>>> equipeAsync) {
    final carregando = equipeAsync.isLoading;
    final membros = equipeAsync.value ?? const <Map<String, dynamic>>[];
    final semEquipe = !carregando && membros.isEmpty;

    String rotulo;
    if (carregando) {
      rotulo = 'Carregando equipe do projeto...';
    } else if (equipeAsync.hasError) {
      rotulo = 'Não foi possível carregar a equipe';
    } else if (semEquipe) {
      rotulo = 'Nenhum membro disponível neste projeto';
    } else {
      rotulo = _equipeSelecionada.isEmpty ? 'Selecione' : '${_equipeSelecionada.length} selecionado(s)';
    }

    return InkWell(
      onTap: (carregando || semEquipe || equipeAsync.hasError) ? null : () => _abrirSeletorEquipe(context, membros),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(rotulo, style: GoogleFonts.lato(color: AppColors.hintText)),
            ),
            if (carregando)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
            else
              const Icon(Icons.keyboard_arrow_down, color: AppColors.greyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildAvataresEquipe(List<Map<String, dynamic>> membros) {
    if (_equipeSelecionada.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (final nome in _equipeSelecionada)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              children: [
                _buildAvatar(_fotoDoNome(membros, nome), radius: 20),
                const SizedBox(height: 4),
                Text(nome, style: GoogleFonts.lato(fontSize: 11, color: const Color(0xFF3E3E3D))),
              ],
            ),
          ),
      ],
    );
  }

  String? _fotoDoNome(List<Map<String, dynamic>> membros, String nome) {
    for (final membro in membros) {
      if (_nomeMembro(membro) == nome) return _fotoMembro(membro);
    }
    return null;
  }

  Widget _buildAvatar(String? fotoUrl, {required double radius}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.greyVeryLight,
      backgroundImage: fotoUrl != null ? StorageNetworkImage(fotoUrl) : null,
      child: fotoUrl == null ? Icon(Icons.person, color: AppColors.greyMedium, size: radius) : null,
    );
  }

  Widget _buildCampoData(BuildContext context) {
    return InkWell(
      onTap: () => _selecionarData(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _dataController.text.isEmpty ? 'dd/mm/yyyy' : _dataController.text,
                style: GoogleFonts.lato(color: _dataController.text.isEmpty ? AppColors.hintText : const Color(0xFF3E3E3D)),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.greyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildSeletorPeriodo() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          _buildBotaoPeriodo('Manhã', PeriodoRdo.manha),
          _buildBotaoPeriodo('Tarde', PeriodoRdo.tarde),
          _buildBotaoPeriodo('Noite', PeriodoRdo.noite),
        ],
      ),
    );
  }

  Widget _buildBotaoPeriodo(String texto, PeriodoRdo periodo) {
    final bool selecionado = _periodoSelecionado == periodo;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _periodoSelecionado = periodo;
          _carregarCamposDoTurno();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selecionado ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            texto,
            style: GoogleFonts.lato(
              color: selecionado ? Colors.white : AppColors.greyMedium,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoxTurno(TurnoRealizado turno) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildHorario('Chegada', _chegadaController, (v) => _atualizarTurnoAtual(chegada: v))),
              const SizedBox(width: 10),
              Expanded(child: _buildHorario('Início ativ.', _inicioController, (v) => _atualizarTurnoAtual(inicio: v))),
              const SizedBox(width: 10),
              Expanded(child: _buildHorario('Saída', _saidaController, (v) => _atualizarTurnoAtual(saida: v))),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.greyVeryLight),
          const SizedBox(height: 14),
          _buildRotulo('Condições de trabalho'),
          const SizedBox(height: 6),
          _buildDropdown(
            valor: turno.condTrabalho.isEmpty ? null : turno.condTrabalho,
            opcoes: _opcoesCondicaoTrabalho,
            onChanged: (v) => setState(() => _atualizarTurnoAtual(condTrabalho: v)),
          ),
          const SizedBox(height: 14),
          _buildRotulo('Condições climáticas'),
          const SizedBox(height: 6),
          _buildDropdown(
            valor: turno.condClima.isEmpty ? null : turno.condClima,
            opcoes: _opcoesCondicaoClima,
            onChanged: (v) => setState(() => _atualizarTurnoAtual(condClima: v)),
          ),
        ],
      ),
    );
  }

  Widget _buildHorario(String rotulo, TextEditingController controller, ValueChanged<String> aoSelecionar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo, style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyMedium)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _selecionarHorario(controller, aoSelecionar),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)),
            alignment: Alignment.center,
            child: Text(
              controller.text.isEmpty ? '09:00' : controller.text,
              style: GoogleFonts.lato(fontSize: 13, color: controller.text.isEmpty ? AppColors.hintText : const Color(0xFF3E3E3D)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? valor,
    required List<String> opcoes,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.inputBorder)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valor,
          isExpanded: true,
          hint: Text('Selecione', style: GoogleFonts.lato(color: AppColors.hintText)),
          items: opcoes.map((opcao) => DropdownMenuItem(value: opcao, child: Text(opcao, style: GoogleFonts.lato()))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextarea(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      maxLines: 4,
      style: GoogleFonts.lato(fontSize: 13.5),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: GoogleFonts.lato(color: AppColors.hintText, fontSize: 13),
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
      ),
    );
  }

  Widget _buildGaleriaDraft() {
    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (int i = 0; i < _fotos.length; i++) ...[
            _buildFotoDraftThumb(i),
            const SizedBox(width: 10),
          ],
          _buildBotaoAdicionarFotoDraft(),
        ],
      ),
    );
  }

  Widget _buildFotoDraftThumb(int index) {
    final foto = _fotos[index];
    return GestureDetector(
      onTap: () => _editarFotoDraft(index),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(foto.arquivo, width: 80, height: 80, fit: BoxFit.cover),
          ),
          Positioned(
            top: 3,
            right: 3,
            child: GestureDetector(
              onTap: () => setState(() => _fotos.removeAt(index)),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 13, color: Colors.white),
              ),
            ),
          ),
          if (foto.descricao.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: const Icon(Icons.notes, size: 13, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBotaoAdicionarFotoDraft() {
    return InkWell(
      onTap: _adicionarFotoDraft,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 22),
            const SizedBox(height: 4),
            Text('Foto', style: GoogleFonts.lato(fontSize: 10, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Future<void> _adicionarFotoDraft() async {
    final source = origemFotoNoNavegador ?? await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: Text('Tirar foto com a câmera', style: GoogleFonts.lato()),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: Text('Escolher da galeria', style: GoogleFonts.lato()),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final imagem = await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (imagem == null) return;

    setState(() => _fotos.add(_FotoRdoDraft(arquivo: File(imagem.path))));
    if (mounted) _editarFotoDraft(_fotos.length - 1);
  }

  Future<void> _editarFotoDraft(int index) async {
    final foto = _fotos[index];
    final descCtrl = TextEditingController(text: foto.descricao);

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(foto.arquivo, height: 160, width: 160, fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                style: GoogleFonts.lato(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Descrição da foto',
                  hintStyle: GoogleFonts.lato(fontSize: 13, color: AppColors.hintText),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _fotos.removeAt(index));
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Remover', style: GoogleFonts.lato(color: AppColors.error, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => foto.descricao = descCtrl.text);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('OK', style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.w700)),
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

  Widget _buildBotaoSalvar(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: _salvando ? null : () => _salvar(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
          elevation: 0,
        ),
        child: _salvando
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text('Salvar', style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _abrirSeletorEquipe(BuildContext context, List<Map<String, dynamic>> membros) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Text('Quem participou?', style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  for (final membro in membros)
                    Builder(builder: (context) {
                      final nome = _nomeMembro(membro);
                      final cargo = _cargoMembro(membro);
                      final selecionado = _equipeSelecionada.contains(nome);
                      return CheckboxListTile(
                        secondary: _buildAvatar(_fotoMembro(membro), radius: 18),
                        title: Text(nome, style: GoogleFonts.lato(fontWeight: FontWeight.w600)),
                        subtitle: cargo.isEmpty ? null : Text(cargo, style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyMedium)),
                        value: selecionado,
                        activeColor: AppColors.primary,
                        onChanged: (marcado) {
                          setModalState(() {
                            setState(() {
                              if (marcado == true) {
                                _equipeSelecionada.add(nome);
                              } else {
                                _equipeSelecionada.remove(nome);
                              }
                            });
                          });
                        },
                      );
                    }),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _selecionarData(BuildContext context) async {
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data != null) {
      setState(() {
        _dataController.text = '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
      });
    }
  }

  Future<void> _selecionarHorario(TextEditingController controller, ValueChanged<String> aoSelecionar) async {
    final horario = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (horario != null) {
      final texto = '${horario.hour.toString().padLeft(2, '0')}:${horario.minute.toString().padLeft(2, '0')}';
      setState(() {
        controller.text = texto;
        aoSelecionar(texto);
      });
    }
  }

  /// Busca os ensaios que a empresa realizou no projeto naquela data e
  /// substitui o texto de atividades por eles — clicar de novo sempre
  /// reimporta do zero (descarta edições manuais anteriores), em vez de
  /// acumular texto repetido a cada clique.
  Future<void> _importarAtividadesDaData(BuildContext context) async {
    final partes = _dataController.text.split('/');
    if (partes.length != 3) return;
    final data = DateTime.tryParse('${partes[2]}-${partes[1]}-${partes[0]}');
    if (data == null) return;

    final empresaId = ref.read(currentUserProvider)?.empresaId;
    if (empresaId == null) return;

    setState(() => _importando = true);
    try {
      final atividades = await ref.read(rdoRepositoryProvider).listarAtividadesDoDia(
            projetoId: widget.projetoId,
            empresaId: empresaId,
            data: data,
          );

      if (!context.mounted) return;
      setState(() => _importando = false);

      if (atividades.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum ensaio encontrado para essa data.')));
        return;
      }

      setState(() {
        _atividadesController.text = atividades.map((e) => '- $e').join('\n');
      });
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _importando = false);
      DiaviconAlerts.show(context, 'Erro ao importar', '$e', isErro: true);
    }
  }

  Future<void> _salvar(BuildContext context) async {
    if (_salvando) return;
    // Plano sem espaço: nenhuma criação nova (o servidor também recusa).
    if (!await verificarArmazenamento(context, ref)) return;
    if (!context.mounted || _salvando) return;
    if (_dataController.text.isEmpty) {
      DiaviconAlerts.show(context, 'Data obrigatória', 'Selecione a data do RDO antes de salvar.', isAviso: true);
      return;
    }

    final usuario = ref.read(currentUserProvider);
    final empresaId = usuario?.empresaId;
    if (empresaId == null) {
      DiaviconAlerts.show(context, 'Erro', 'Não foi possível identificar sua empresa.', isErro: true);
      return;
    }

    setState(() => _salvando = true);
    try {
      final rdo = RdoRealizadoModel(
        projetoId: widget.projetoId,
        empresaId: empresaId,
        criadoUserId: usuario?.id,
        equipe: _equipeSelecionada,
        data: _dataController.text,
        manha: _turnos[PeriodoRdo.manha]!,
        tarde: _turnos[PeriodoRdo.tarde]!,
        noite: _turnos[PeriodoRdo.noite]!,
        atividadesRealizadas: _atividadesController.text,
        equipamentosUtilizados: _equipamentosController.text,
        observacoes: _observacoesController.text,
      );
      final rdoSalvo = await ref.read(rdoRepositoryProvider).salvar(rdo);

      final galeriaRepo = ref.read(galeriaRdoRepositoryProvider);
      for (final foto in _fotos) {
        await galeriaRepo.adicionarFoto(rdoId: rdoSalvo.id!, fotoLocal: foto.arquivo, descricao: foto.descricao);
      }

      if (!context.mounted) return;
      await RdoConfirmDialogs.mostrarSalvo(context);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _salvando = false);
      DiaviconAlerts.show(context, 'Erro ao salvar', '$e', isErro: true);
    }
  }
}
