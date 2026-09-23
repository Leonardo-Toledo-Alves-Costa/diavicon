import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:diavicon/features/app_shell/widgets/perfil_header.dart';
import 'package:diavicon/features/legal/documentos_legais.dart';
import 'package:diavicon/features/legal/screens/documento_legal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:url_launcher/url_launcher.dart';

class PerfilCentralAjuda extends StatelessWidget {
  const PerfilCentralAjuda({super.key});

  void _abrirDocumento(BuildContext context, DocumentoLegal doc) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DocumentoLegalScreen(documento: doc)));
  }

  Future<void> _suporte(BuildContext context) async {
    final uri = Uri(scheme: 'mailto', path: DocumentosLegais.emailPrivacidade, query: 'subject=${Uri.encodeComponent('Suporte DIAVICON')}');
    var abriu = false;
    try {
      abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (abriu || !context.mounted) return;
    await Clipboard.setData(const ClipboardData(text: DocumentosLegais.emailPrivacidade));
    if (context.mounted) {
      DiaviconAlerts.show(context, 'E-mail copiado', 'Escreva para ${DocumentosLegais.emailPrivacidade}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: Column(
        children: [
          PerfilHeader(topPadding: topPadding, paginaAtual: 'Ajuda'),
          const SizedBox(height: 35),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -18),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Text(
                          'Central de ajuda',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF3E3E3D), fontFamily: 'Lato'),
                        ),
                      ),
                      const SizedBox(height: 25),
                      _HelpItem(title: 'Política de privacidade', onTap: () => _abrirDocumento(context, DocumentoLegal.privacidade)),
                      const SizedBox(height: 25),
                      _HelpItem(title: 'Termos de uso', onTap: () => _abrirDocumento(context, DocumentoLegal.termos)),
                      const SizedBox(height: 25),
                      _HelpItem(
                        title: 'Licenças de terceiros',
                        onTap: () => showLicensePage(context: context, applicationName: 'DIAVICON'),
                      ),
                      const SizedBox(height: 25),
                      _HelpItem(title: 'Suporte e privacidade', subtitle: DocumentosLegais.emailPrivacidade, onTap: () => _suporte(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _HelpItem({required this.title, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 16, color: Color(0xFF3E3E3D), fontWeight: FontWeight.bold)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B))),
                  ),
              ]),
            ),
            if (onTap != null) const Icon(Icons.open_in_new_outlined, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
