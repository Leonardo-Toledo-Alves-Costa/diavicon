import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/report_factory.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/custom_appbar.dart';
import '../providers/relatorio_ensaio_provider.dart';

class GerarRelatorioScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String estruturaId;
  final String projetoNome;
  final String estruturaNome;
  final String tipoEnsaioId;

  const GerarRelatorioScreen({
    super.key, 
    required this.projetoId, 
    required this.estruturaId, 
    required this.projetoNome, 
    required this.estruturaNome,
    required this.tipoEnsaioId
  });

  @override
  ConsumerState<GerarRelatorioScreen> createState() => _GerarRelatorioScreenState();
}

class _GerarRelatorioScreenState extends ConsumerState<GerarRelatorioScreen> {
  late TextEditingController _nomeCtrl;
  
  // Opções vindas do BD
  List<String> _opcoesLocais = [];
  List<String> _opcoesTipos = [];
  final List<String> _opcoesEmpresas = ['Empresa Execução A', 'Empresa Supervisão B']; // Exemplo

  // Seleções do usuário
  List<String> _locaisSelecionados = [];
  List<String> _tiposSelecionados = [];
  List<String> _empresasSelecionadas = [];
  
  DateTime? _dataInicio;
  DateTime? _dataFim;

  // Checkboxes
  bool _cbResumo = false;
  bool _cbResultados = false;
  bool _cbGraficos = false;
  bool _cbGaleria = false;
  final bool _cbDemarcacao = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    String dataAtual = DateFormat('dd_MM_yyyy_HHmm').format(DateTime.now());
    _nomeCtrl = TextEditingController(text: '${widget.projetoNome}_${widget.estruturaNome}_$dataAtual'.replaceAll('-', '_',).replaceAll('-', '/',));
    _carregarFiltros();
  }

  Future<void> _carregarFiltros() async {
    final filtros = await ref.read(relatorioEnsaioRepositoryProvider).buscarOpcoesFiltros(widget.estruturaId);
    setState(() {
      _opcoesLocais = filtros['locais']!;
      _opcoesTipos = filtros['tipos']!;
    });
  }

  // Multi-Select Bottom Sheet Genérico
  void _mostrarMultiSelect(String titulo, List<String> opcoes, List<String> selecionados, Function(List<String>) onConfirm) {
    List<String> tempSelected = List.from(selecionados);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(24),
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: opcoes.map((opcao) {
                      return CheckboxListTile(
                        title: Text(opcao),
                        value: tempSelected.contains(opcao),
                        onChanged: (val) {
                          setModalState(() {
                            val == true ? tempSelected.add(opcao) : tempSelected.remove(opcao);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    onConfirm(tempSelected);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), minimumSize: const Size.fromHeight(45)),
                  child: const Text('Confirmar Seleção', style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _selecionarData(BuildContext context, bool isInicio) async {
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (data != null) {
      setState(() {
        if (isInicio) {
          _dataInicio = data;
        } else {
          _dataFim = data;
        }
      });
    }
  }

  Future<void> _gerarRelatorio() async {
    if (_nomeCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dê um nome ao relatório.')));
      return;
    }

    setState(() => _isLoading = true);
    
    final configuracoes = {
      'nome_relatorio': (_nomeCtrl.text).replaceAll('-', '_',).replaceAll('-', '/',),
      'locais': _locaisSelecionados,
      'tipos_elemento': _tiposSelecionados,
      'empresas': _empresasSelecionadas,
      'data_inicio': _dataInicio?.toIso8601String(),
      'data_fim': _dataFim?.toIso8601String(),
      'incluir_resumo': _cbResumo,
      'incluir_resultados': _cbResultados,
      'incluir_graficos': _cbGraficos,
      'incluir_galeria': _cbGaleria,
      'incluir_demarcacao': _cbDemarcacao,
    };

    try {
      // 1. O Factory constrói o HTML e converte para PDF File local
      final File pdfFile = await RelatorioFactory.gerarEConverterRelatorio(
        ref: ref,
        tipoEnsaioNome: 'Carbonatação', // Passe o nome dinâmico ou faça uma query do nome pelo tipoEnsaioId
        projetoId: widget.projetoId,
        estruturaId: widget.estruturaId,
        config: configuracoes,
      );

      // 2. Faz o Upload do PDF para o Supabase Storage
      final supabase = Supabase.instance.client;
      final fileName = '${_nomeCtrl.text}.pdf';
      final storagePath = 'relatorios/$fileName';
      
      await supabase.storage.from('projetos').upload(storagePath, pdfFile);
      final pdfUrl = supabase.storage.from('projetos').getPublicUrl(storagePath);

      // 3. Salva os metadados do relatório e o link do PDF na tabela 'relatorios'[cite: 29]
      await ref.read(relatorioEnsaioRepositoryProvider).criarRelatorio(
        projetoId: widget.projetoId, 
        estruturaId: widget.estruturaId, 
        tipoEnsaioId: widget.tipoEnsaioId,
        configuracoes: {
          ...configuracoes,
          'url_pdf': pdfUrl, // Injeta o link permanente do PDF salvo
        },
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Relatório gerado com sucesso!'), backgroundColor: Colors.green));
      }
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro no banco: ${e.message}'), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildFiltroInput(String label, String valueDisplay, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(valueDisplay, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
                const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChips(List<String> itens, Function(String) onRemove) {
    if (itens.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(
        spacing: 8, runSpacing: 4,
        children: itens.map((i) => Chip(
          label: Text(i, style: const TextStyle(fontSize: 11, color: Color(0xFFFFA726), fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFFFFF3E0),
          deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFFFFA726)),
          onDeleted: () => onRemove(i),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.transparent)),
          padding: EdgeInsets.zero,
        )).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(
        title: 'Relatórios',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Text('Ensaio', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dados a serem utilizados', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            const SizedBox(height: 16),
            
            // Nome
            const Text('Nome do Relatório', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 4),
            TextField(
              controller: _nomeCtrl,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12)),
            ),
            const SizedBox(height: 16),

            // Local
            _buildFiltroInput('Local', _locaisSelecionados.isEmpty ? 'Todos (Padrão)' : '${_locaisSelecionados.length} selecionados', () {
              _mostrarMultiSelect('Selecione os Locais', _opcoesLocais, _locaisSelecionados, (sel) => setState(() => _locaisSelecionados = sel));
            }),
            _buildChips(_locaisSelecionados, (item) => setState(() => _locaisSelecionados.remove(item))),
            const SizedBox(height: 12),

            // Tipo
            _buildFiltroInput('Tipo de Elemento', _tiposSelecionados.isEmpty ? 'Todos (Padrão)' : '${_tiposSelecionados.length} selecionados', () {
              _mostrarMultiSelect('Selecione os Tipos', _opcoesTipos, _tiposSelecionados, (sel) => setState(() => _tiposSelecionados = sel));
            }),
            _buildChips(_tiposSelecionados, (item) => setState(() => _tiposSelecionados.remove(item))),
            const SizedBox(height: 12),

            // Empresas
            _buildFiltroInput('Dados das Empresas', _empresasSelecionadas.isEmpty ? 'Todas (Padrão)' : '${_empresasSelecionadas.length} selecionadas', () {
              _mostrarMultiSelect('Selecione as Empresas', _opcoesEmpresas, _empresasSelecionadas, (sel) => setState(() => _empresasSelecionadas = sel));
            }),
            _buildChips(_empresasSelecionadas, (item) => setState(() => _empresasSelecionadas.remove(item))),
            const SizedBox(height: 16),

            // Período
            const Text('Período dos ensaios', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: InkWell(
                  onTap: () => _selecionarData(context, true),
                  child: Container(
                    padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: Text(_dataInicio == null ? 'Data Início' : DateFormat('dd/MM/yyyy').format(_dataInicio!)),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: InkWell(
                  onTap: () => _selecionarData(context, false),
                  child: Container(
                    padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: Text(_dataFim == null ? 'Data Final' : DateFormat('dd/MM/yyyy').format(_dataFim!)),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 24),

            Text('Itens a serem incluídos', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            const SizedBox(height: 8),
            CheckboxListTile(title: const Text('Análise geral dos dados', style: TextStyle(fontSize: 14)), value: _cbResumo, onChanged: (v) => setState(() => _cbResumo = v!), dense: true, contentPadding: EdgeInsets.zero, activeColor: const Color(0xFFFFA726)),
            CheckboxListTile(title: const Text('Análise individual dos dados', style: TextStyle(fontSize: 14)), value: _cbResultados, onChanged: (v) => setState(() => _cbResultados = v!), dense: true, contentPadding: EdgeInsets.zero, activeColor: const Color(0xFFFFA726)),
            CheckboxListTile(title: const Text('Tabela geral de dados', style: TextStyle(fontSize: 14)), value: _cbGraficos, onChanged: (v) => setState(() => _cbGraficos = v!), dense: true, contentPadding: EdgeInsets.zero, activeColor: const Color(0xFFFFA726)),
            CheckboxListTile(title: const Text('Galeria do ensaio', style: TextStyle(fontSize: 14)), value: _cbGaleria, onChanged: (v) => setState(() => _cbGaleria = v!), dense: true, contentPadding: EdgeInsets.zero, activeColor: const Color(0xFFFFA726)),
            //CheckboxListTile(title: const Text('Demarcação em plantas', style: TextStyle(fontSize: 14)), value: _cbDemarcacao, onChanged: (v) => setState(() => _cbDemarcacao = v!), dense: true, contentPadding: EdgeInsets.zero, activeColor: const Color(0xFFFFA726)),
            
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _gerarRelatorio,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA726), minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text('Gerar Relatório →', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }
}