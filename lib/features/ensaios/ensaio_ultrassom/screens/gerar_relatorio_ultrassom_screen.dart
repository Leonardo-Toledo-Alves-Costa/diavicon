import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../modelos_relatorios/models/modelo_relatorio_model.dart';
import '../../../modelos_relatorios/providers/modelos_relatorio_provider.dart';
import '../../ensaios_geral/providers/relatorio_ensaio_provider.dart';
import '../reports/modelo/ultrassom_modelo_report_service.dart';

// Escolhe um modelo cadastrado (Padrões da empresa > Modelos de Relatórios >
// Ultrassonografia) e o formato, e dispara a geração — mesmo fluxo dos
// demais compositores (sem "inspeção geral": o relatório cobre todos os
// pontos de ensaio já cadastrados pra estrutura, dos 3 modos de coleta).
class GerarRelatorioUltrassomScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String estruturaId;
  final String tipoEnsaioId;
  final String estruturaNome;

  const GerarRelatorioUltrassomScreen({
    super.key,
    required this.projetoId,
    required this.estruturaId,
    required this.tipoEnsaioId,
    required this.estruturaNome,
  });

  @override
  ConsumerState<GerarRelatorioUltrassomScreen> createState() => _GerarRelatorioUltrassomScreenState();
}

class _GerarRelatorioUltrassomScreenState extends ConsumerState<GerarRelatorioUltrassomScreen> {
  late final TextEditingController _nomeCtrl;
  ModeloRelatorioModel? _modeloSelecionado;
  String _formato = 'pdf';
  bool _gerando = false;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: 'Relatório de Ultrassonografia - ${widget.estruturaNome}');
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _gerar() async {
    if (_modeloSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um modelo.'), backgroundColor: Colors.orange));
      return;
    }
    if (_nomeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dê um nome ao relatório.'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _gerando = true);
    final nomeRelatorio = _nomeCtrl.text.trim();
    final modeloId = _modeloSelecionado!.id;
    final formato = _formato;

    try {
      final relatorioId = await ref.read(relatorioEnsaioRepositoryProvider).criarRelatorioPendente(
            projetoId: widget.projetoId,
            estruturaId: widget.estruturaId,
            tipoEnsaioId: widget.tipoEnsaioId,
            conteudo: {'nome_relatorio': nomeRelatorio, 'modelo_id': modeloId, 'formato': formato},
          );

      // Fire-and-forget, igual aos outros geradores.
      UltrassomModeloReportService(Supabase.instance.client).gerar(
        relatorioId: relatorioId,
        modeloId: modeloId,
        formato: formato,
        projetoId: widget.projetoId,
        estruturaId: widget.estruturaId,
        tipoEnsaioId: widget.tipoEnsaioId,
        nomeRelatorio: nomeRelatorio,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gerando relatório em segundo plano...'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _gerando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final empresaId = ref.watch(currentUserProvider)?.empresaId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const CustomAppBar(title: 'Criar relatório', showBackButton: true, showMenuButton: false),
      body: empresaId == null
          ? const Center(child: Text('Não foi possível identificar a empresa.'))
          : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nome do relatório', style: TextStyle(fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nomeCtrl,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Modelo', style: TextStyle(fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 6),
                    Consumer(
                      builder: (context, ref, _) {
                        final modelosAsync = ref.watch(
                          modelosPorTipoEnsaioProvider(ModelosPorTipoParams(empresaId: empresaId, tipoEnsaioId: widget.tipoEnsaioId)),
                        );
                        return modelosAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                          error: (e, _) => Text('Erro ao carregar modelos: $e'),
                          data: (modelos) {
                            if (modelos.isEmpty) {
                              return const Text(
                                'Nenhum modelo cadastrado para Ultrassonografia ainda. Crie um em Padrões da empresa > Modelos de Relatórios.',
                                style: TextStyle(fontSize: 13, color: Colors.black54),
                              );
                            }
                            return Column(
                              children: modelos.map((modelo) {
                                final selecionado = _modeloSelecionado?.id == modelo.id;
                                return RadioListTile<String>(
                                  contentPadding: EdgeInsets.zero,
                                  value: modelo.id,
                                  groupValue: _modeloSelecionado?.id,
                                  activeColor: AppColors.primary,
                                  title: Text(modelo.nome, style: TextStyle(fontWeight: selecionado ? FontWeight.bold : FontWeight.normal)),
                                  subtitle: modelo.descricao?.isNotEmpty == true ? Text(modelo.descricao!) : null,
                                  onChanged: (_) => setState(() => _modeloSelecionado = modelo),
                                );
                              }).toList(),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Formato', style: TextStyle(fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: _buildFormatoChip('pdf', 'PDF')),
                        const SizedBox(width: 8),
                        Expanded(child: _buildFormatoChip('html', 'HTML')),
                        const SizedBox(width: 8),
                        const Expanded(child: _FormatoIndisponivelChip(rotulo: 'Word')),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _gerando ? null : _gerar,
                        style:
                            ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        child: _gerando
                            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Gerar relatório', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildFormatoChip(String valor, String rotulo) {
    final ativo = _formato == valor;
    return ChoiceChip(
      label: Text(rotulo),
      selected: ativo,
      onSelected: (_) => setState(() => _formato = valor),
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
    );
  }
}

class _FormatoIndisponivelChip extends StatelessWidget {
  final String rotulo;
  const _FormatoIndisponivelChip({required this.rotulo});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: Tooltip(
        message: 'Em breve',
        child: ChoiceChip(label: Text(rotulo), selected: false, onSelected: null),
      ),
    );
  }
}
