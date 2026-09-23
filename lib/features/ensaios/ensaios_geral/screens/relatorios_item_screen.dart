import 'package:diavicon/core/services/storage_urls.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../repositories/relatorios_item_repository.dart';
import 'visualizar_pdf_screen.dart';

/// Tela única de relatórios de um elemento, estrutura ou projeto: reúne
/// todos os relatórios gerados para o item, de todos os ensaios (e os RDOs,
/// no projeto), com busca por título ou ensaio.
///
/// Substitui as maquetes que existiam para elemento e estrutura (com dados
/// fixos) e os itens "Relatórios" que estavam desativados nos menus.
class RelatoriosItemScreen extends StatefulWidget {
  const RelatoriosItemScreen({
    super.key,
    required this.nivel,
    required this.nomeItem,
    this.projetoId,
    this.estruturaId,
    this.elementoId,
  });

  final NivelRelatorios nivel;

  /// Nome do elemento/estrutura/projeto, para o cabeçalho.
  final String nomeItem;
  final String? projetoId;
  final String? estruturaId;
  final String? elementoId;

  @override
  State<RelatoriosItemScreen> createState() => _RelatoriosItemScreenState();
}

class _RelatoriosItemScreenState extends State<RelatoriosItemScreen> {
  final _busca = TextEditingController();
  late Future<List<RelatorioItem>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _carregar();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<List<RelatorioItem>> _carregar() => RelatoriosItemRepository(Supabase.instance.client).buscar(
        nivel: widget.nivel,
        projetoId: widget.projetoId,
        estruturaId: widget.estruturaId,
        elementoId: widget.elementoId,
      );

  Future<void> _recarregar() async {
    setState(() => _futuro = _carregar());
    await _futuro;
  }

  String get _rotuloNivel => switch (widget.nivel) {
        NivelRelatorios.elemento => 'Relatórios do elemento',
        NivelRelatorios.estrutura => 'Relatórios da estrutura',
        NivelRelatorios.projeto => 'Relatórios do projeto',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: CustomAppBar(
        title: 'Relatórios',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_rotuloNivel, style: const TextStyle(fontSize: 11, color: Colors.white70)),
            Text(
              widget.nomeItem,
              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              controller: _busca,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar por título ou ensaio',
                prefixIcon: const Icon(Icons.search, color: AppColors.greyMedium),
                suffixIcon: _busca.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _busca.clear()),
                      ),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
          ),
          if (widget.nivel == NivelRelatorios.elemento)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
              child: Text(
                'Os relatórios são gerados por estrutura. Aqui aparecem os da estrutura deste elemento, '
                'dos ensaios feitos nele — cada relatório cobre a estrutura inteira.',
                style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<RelatorioItem>>(
              future: _futuro,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (snap.hasError) {
                  return _centro('Erro ao carregar os relatórios:\n${snap.error}');
                }
                final todos = snap.data ?? const <RelatorioItem>[];
                final lista = filtrarRelatorios(todos, _busca.text);
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _recarregar,
                  child: lista.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 120),
                          _centro(todos.isEmpty ? 'Nenhum relatório gerado ainda.' : 'Nenhum relatório encontrado para "${_busca.text}".'),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                          itemCount: lista.length,
                          itemBuilder: (_, i) => _CardRelatorio(
                            item: lista[i],
                            onAbrir: () => _abrir(lista[i].url!, lista[i].formato, lista[i].titulo),
                            onAbrirResumo: lista[i].urlResumo == null
                                ? null
                                : () => _abrir(lista[i].urlResumo!, lista[i].formato, '${lista[i].titulo} - Resumo'),
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

  Widget _centro(String texto) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(texto, textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade600)),
        ),
      );

  /// PDF no visualizador interno; HTML baixado e aberto pelo app do sistema
  /// (não há visualizador de HTML embutido) — mesmo comportamento das telas
  /// de relatório de cada ensaio.
  Future<void> _abrir(String url, String? formato, String titulo) async {
    if (formato == 'pdf') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VisualizarPdfScreen(url: url, titulo: titulo)));
      return;
    }
    try {
      final resposta = await StorageUrls.baixarHtml(url);
      final dir = await getApplicationDocumentsDirectory();
      // O título vira nome de arquivo: "/" ou ":" quebrariam o caminho.
      final nome = titulo.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final arquivo = File('${dir.path}/$nome.html');
      await arquivo.writeAsBytes(resposta.bodyBytes);
      await OpenFilex.open(arquivo.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao abrir: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

class _CardRelatorio extends StatelessWidget {
  const _CardRelatorio({required this.item, required this.onAbrir, this.onAbrirResumo});

  final RelatorioItem item;
  final VoidCallback onAbrir;
  final VoidCallback? onAbrirResumo;

  @override
  Widget build(BuildContext context) {
    final (corStatus, fundoStatus) = switch (item.status) {
      'Concluído' => (Colors.green.shade800, const Color(0xFFE8F5E9)),
      'Erro' => (Colors.red.shade700, const Color(0xFFFFEBEE)),
      _ => (Colors.orange.shade800, const Color(0xFFFFF3E0)),
    };
    final data = item.criadoEm;
    final dataTexto = '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: item.concluido ? onAbrir : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              Icon(item.formato == 'pdf' ? Icons.picture_as_pdf_outlined : Icons.description_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.titulo,
                        style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _chip(item.ensaio, AppColors.primary, AppColors.primary.withValues(alpha: 0.12)),
                        _chip(item.status, corStatus, fundoStatus),
                        Text(dataTexto, style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                  ],
                ),
              ),
              if (onAbrirResumo != null && item.concluido)
                IconButton(
                  tooltip: 'Abrir tabela resumo',
                  icon: const Icon(Icons.table_chart_outlined, color: AppColors.greyMedium),
                  onPressed: onAbrirResumo,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String texto, Color cor, Color fundo) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(10)),
        child: Text(texto, style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.w700, color: cor)),
      );
}
