import 'dart:async';

import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/custom_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/modelos_rdo_provider.dart';
import '../providers/rdo_provider.dart';
import '../providers/relatorio_rdo_provider.dart';
import '../reports/rdo_modelo_report_service.dart';

/// Escolhe um período de datas, verifica quantos RDOs existem nele, escolhe
/// modelo + formato e dispara a geração — um único dia (De == Até) gera o
/// relatório de só aquele RDO; um período maior junta todos num relatório
/// só. Mesmo fluxo de fundo de `GerarRelatorioInspecaoScreen`: cria a linha
/// de status já "Gerando", chama o serviço SEM esperar (roda em segundo
/// plano, sobrevive à navegação) e fecha a tela na hora.
class GerarRelatorioRdoScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String projetoNome;
  final String empresaId;
  final DateTime? dataInicialPadrao;
  final DateTime? dataFinalPadrao;

  const GerarRelatorioRdoScreen({
    super.key,
    required this.projetoId,
    required this.empresaId,
    this.projetoNome = 'Projeto',
    this.dataInicialPadrao,
    this.dataFinalPadrao,
  });

  @override
  ConsumerState<GerarRelatorioRdoScreen> createState() => _GerarRelatorioRdoScreenState();
}

class _GerarRelatorioRdoScreenState extends ConsumerState<GerarRelatorioRdoScreen> {
  final TextEditingController _nomeController = TextEditingController();
  String? _modeloSelecionadoId;
  String _formato = 'pdf';
  DateTime? _dataInicio;
  DateTime? _dataFim;

  bool _verificando = false;
  int? _quantidadeEncontrada; // null = ainda não verificado
  bool _gerando = false;

  @override
  void initState() {
    super.initState();
    if (widget.dataInicialPadrao != null) {
      _dataInicio = widget.dataInicialPadrao;
      _dataFim = widget.dataFinalPadrao ?? widget.dataInicialPadrao;
      WidgetsBinding.instance.addPostFrameCallback((_) => _verificarPeriodo());
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  String _formatarData(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String get _rotuloPeriodo {
    final inicio = _dataInicio!;
    final fim = _dataFim!;
    final mesmoDia = inicio.year == fim.year && inicio.month == fim.month && inicio.day == fim.day;
    return mesmoDia ? _formatarData(inicio) : '${_formatarData(inicio)} a ${_formatarData(fim)}';
  }

  Future<void> _selecionarData({required bool inicio}) async {
    final data = await showDatePicker(
      context: context,
      initialDate: (inicio ? _dataInicio : _dataFim) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data == null) return;

    setState(() {
      if (inicio) {
        _dataInicio = data;
        if (_dataFim == null || _dataFim!.isBefore(data)) _dataFim = data;
      } else {
        _dataFim = data;
        if (_dataInicio == null || _dataInicio!.isAfter(data)) _dataInicio = data;
      }
    });
    await _verificarPeriodo();
  }

  Future<void> _verificarPeriodo() async {
    if (_dataInicio == null || _dataFim == null) return;

    setState(() {
      _quantidadeEncontrada = null;
      _verificando = true;
    });

    try {
      final encontrados = await ref.read(rdoRepositoryProvider).buscarPorPeriodo(
            projetoId: widget.projetoId,
            empresaId: widget.empresaId,
            dataInicio: _dataInicio!,
            dataFim: _dataFim!,
          );
      if (!mounted) return;
      setState(() {
        _quantidadeEncontrada = encontrados.length;
        _verificando = false;
        if (encontrados.isNotEmpty && _nomeController.text.trim().isEmpty) {
          _nomeController.text = 'RDO - ${widget.projetoNome} - $_rotuloPeriodo';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _verificando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
      );
    }
  }

  bool get _rdoExiste => (_quantidadeEncontrada ?? 0) > 0;

  Future<void> _gerar() async {
    if (_dataInicio == null || _dataFim == null || !_rdoExiste) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um período com RDO registrado.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_modeloSelecionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um modelo.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_nomeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dê um nome ao relatório.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final rotuloPeriodo = _rotuloPeriodo;

    setState(() => _gerando = true);
    try {
      final relatorioId = await ref.read(relatorioRdoRepositoryProvider).criarRelatorioPendente(
            projetoId: widget.projetoId,
            projetoNome: widget.projetoNome,
            empresaId: widget.empresaId,
            nomeRelatorio: _nomeController.text.trim(),
            modeloId: _modeloSelecionadoId!,
            formato: _formato,
            data: rotuloPeriodo,
          );

      // Fire-and-forget deliberado: a geração roda desacoplada desta tela.
      unawaited(RdoModeloReportService(Supabase.instance.client).gerar(
        relatorioId: relatorioId,
        projetoId: widget.projetoId,
        empresaId: widget.empresaId,
        modeloId: _modeloSelecionadoId!,
        nomeRelatorio: _nomeController.text.trim(),
        formato: _formato,
        dataInicio: _dataInicio!,
        dataFim: _dataFim!,
        dataRotulo: rotuloPeriodo,
      ));

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gerando relatório em segundo plano...'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _gerando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final modelosAsync = ref.watch(modelosRdoProvider(widget.empresaId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const CustomAppBar(title: 'Gerar relatório de RDO', showBackButton: true, showMenuButton: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Período dos RDOs', style: GoogleFonts.lato(fontSize: 13, color: AppColors.greyMedium)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _buildCampoData('De', _dataInicio, () => _selecionarData(inicio: true))),
                const SizedBox(width: 10),
                Expanded(child: _buildCampoData('Até', _dataFim, () => _selecionarData(inicio: false))),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Um único dia (De = Até) gera o relatório de só aquele RDO; um período maior junta todos num relatório só.',
              style: GoogleFonts.lato(fontSize: 11, color: AppColors.greyLight),
            ),
            const SizedBox(height: 6),
            _buildFeedbackVerificacao(),
            if (_rdoExiste) ...[
              const SizedBox(height: 20),
              Text('Nome do relatório', style: GoogleFonts.lato(fontSize: 13, color: AppColors.greyMedium)),
              const SizedBox(height: 6),
              TextField(
                controller: _nomeController,
                style: GoogleFonts.lato(fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Formato', style: GoogleFonts.lato(fontSize: 13, color: AppColors.greyMedium)),
              const SizedBox(height: 6),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('PDF'),
                    selected: _formato == 'pdf',
                    onSelected: (_) => setState(() => _formato = 'pdf'),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('HTML'),
                    selected: _formato == 'html',
                    onSelected: (_) => setState(() => _formato = 'html'),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Modelo', style: GoogleFonts.lato(fontSize: 13, color: AppColors.greyMedium)),
              const SizedBox(height: 6),
              modelosAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (err, _) => Text('Erro ao carregar modelos: $err', style: GoogleFonts.lato(color: AppColors.error)),
                data: (modelos) {
                  if (modelos.isEmpty) {
                    return Text(
                      'Nenhum modelo de RDO cadastrado. Crie um em Padrões da empresa → Modelos de RDO.',
                      style: GoogleFonts.lato(fontSize: 13, color: AppColors.greyLight),
                    );
                  }
                  return Column(
                    children: [
                      for (final modelo in modelos)
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.primary,
                          value: modelo.id,
                          groupValue: _modeloSelecionadoId,
                          onChanged: (v) => setState(() => _modeloSelecionadoId = v),
                          title: Text(modelo.nome, style: GoogleFonts.lato(fontWeight: FontWeight.w600)),
                          subtitle: modelo.descricao?.isNotEmpty == true ? Text(modelo.descricao!, style: GoogleFonts.lato(fontSize: 12)) : null,
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              Center(
                child: ElevatedButton(
                  onPressed: _gerando ? null : _gerar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    elevation: 0,
                  ),
                  child: _gerando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Gerar relatório', style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoData(String rotulo, DateTime? valor, VoidCallback onTap) {
    return InkWell(
      onTap: _verificando ? null : onTap,
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
                valor == null ? rotulo : _formatarData(valor),
                style: GoogleFonts.lato(color: valor == null ? AppColors.hintText : const Color(0xFF3E3E3D)),
              ),
            ),
            if (_verificando)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
            else
              const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.greyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackVerificacao() {
    if (_dataInicio == null || _dataFim == null || _verificando) return const SizedBox.shrink();
    if (_quantidadeEncontrada == null) return const SizedBox.shrink();

    if (_rdoExiste) {
      final quantidade = _quantidadeEncontrada!;
      return Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Color(0xFF3AA655)),
          const SizedBox(width: 6),
          Text(
            quantidade == 1 ? '1 RDO encontrado no período.' : '$quantidade RDOs encontrados no período.',
            style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF3AA655), fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.error_outline, size: 16, color: AppColors.error),
        const SizedBox(width: 6),
        Text(
          'Nenhum RDO encontrado no período.',
          style: GoogleFonts.lato(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
