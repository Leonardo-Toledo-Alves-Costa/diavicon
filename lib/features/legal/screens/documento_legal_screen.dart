import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../documentos_legais.dart';
import '../widgets/texto_legal.dart';

/// Tela pública (não exige login) com a Política de Privacidade ou os Termos
/// de Uso. Rotas: /privacidade e /termos.
class DocumentoLegalScreen extends StatelessWidget {
  final DocumentoLegal documento;
  const DocumentoLegalScreen({super.key, required this.documento});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(documento.titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: TextoLegal(documento: documento),
        ),
      ),
    );
  }
}
