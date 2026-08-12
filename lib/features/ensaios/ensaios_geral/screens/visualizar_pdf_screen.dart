import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart'; 
import 'package:internet_file/internet_file.dart'; 
import 'package:open_filex/open_filex.dart'; // 👈 NOVO IMPORT PARA ABRIR O ARQUIVO

import '../../../../core/widgets/custom_appbar.dart';

class VisualizarPdfScreen extends StatefulWidget {
  final String url;
  final String titulo;

  const VisualizarPdfScreen({
    super.key, 
    required this.url, 
    required this.titulo
  });

  @override
  State<VisualizarPdfScreen> createState() => _VisualizarPdfScreenState();
}

class _VisualizarPdfScreenState extends State<VisualizarPdfScreen> {
  late PdfController _pdfController;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _inicializarPdf();
  }

  Future<void> _inicializarPdf() async {
    try {
      _pdfController = PdfController(
        document: PdfDocument.openData(InternetFile.get(widget.url)),
      );
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _baixarPdf() async {
    setState(() => _isDownloading = true);

    try {
      final response = await http.get(Uri.parse(widget.url));

      if (response.statusCode == 200) {
        Directory? diretorio;
        
        if (Platform.isAndroid) {
          diretorio = Directory('/storage/emulated/0/Download');
          if (!await diretorio.exists()) {
            diretorio = await getExternalStorageDirectory();
          }
        } else {
          diretorio = await getApplicationDocumentsDirectory();
        }

        final nomeSeguro = widget.titulo.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
        final caminhoSalvar = '${diretorio?.path}/$nomeSeguro.pdf';
        final arquivo = File(caminhoSalvar);

        // 1. Salva o arquivo fisicamente no aparelho
        await arquivo.writeAsBytes(response.bodyBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF salvo! Abrindo o documento...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // 2. 👇 MÁGICA AQUI: Solicita ao OS para abrir a gaveta de "Abrir com..."
        final result = await OpenFilex.open(caminhoSalvar);
        
        // Trata erro caso o usuário não tenha nenhum leitor de PDF instalado no celular
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao abrir: ${result.message}'),
              backgroundColor: Colors.orange,
            ),
          );
        }

      } else {
        throw Exception('Falha ao obter o arquivo do servidor.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao baixar o PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: CustomAppBar(
        title: 'Documento',
        showBackButton: true,
        titleWidget: Text(
          widget.titulo, 
          style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFA726)))
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text('Não foi possível carregar o PDF.\nVerifique a conexão ou a URL.', 
                        textAlign: TextAlign.center, 
                        style: TextStyle(color: Colors.grey.shade700)
                      ),
                    ],
                  )
                )
              : PdfView(
                  controller: _pdfController,
                  scrollDirection: Axis.vertical,
                  backgroundDecoration: const BoxDecoration(color: Color(0xFFE0E0E0)),
                ),
      floatingActionButton: (!_isLoading && !_hasError) 
          ? FloatingActionButton.extended(
              onPressed: _isDownloading ? null : _baixarPdf,
              backgroundColor: const Color(0xFFFFA726),
              icon: _isDownloading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.download, color: Colors.white),
              label: Text(
                _isDownloading ? 'Baixando...' : 'Baixar PDF',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}