import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:diavicon/features/app_shell/widgets/perfil_header.dart';
import 'package:diavicon/features/legal/documentos_legais.dart';
import 'package:diavicon/features/legal/repositories/privacidade_repository.dart';
import 'package:diavicon/features/legal/salvar_exportacao.dart';
import 'package:diavicon/features/legal/screens/documento_legal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

const _corTexto = Color(0xFF3E3E3D);

final _preferenciasPrivacidadeProvider = FutureProvider.autoDispose<PreferenciasPrivacidade>((ref) {
  return ref.read(privacidadeRepositoryProvider).lerPreferencias();
});

/// Perfil > Privacidade: preferências do titular (gravadas no servidor),
/// cópia dos dados (portabilidade) e canal de privacidade.
class PerfilMinhaPrivacidade extends ConsumerStatefulWidget {
  const PerfilMinhaPrivacidade({super.key});

  @override
  ConsumerState<PerfilMinhaPrivacidade> createState() => _PerfilMinhaPrivacidadeState();
}

class _PerfilMinhaPrivacidadeState extends ConsumerState<PerfilMinhaPrivacidade> {
  // Valores locais enquanto o servidor confirma (a chave não "volta" no meio
  // do toque); null = usar o que veio do servidor.
  bool? _ia;
  bool? _visivel;
  bool _salvando = false;
  bool _exportando = false;

  Future<void> _salvar({bool? ia, bool? visivel}) async {
    final antesIa = _ia;
    final antesVisivel = _visivel;
    setState(() {
      if (ia != null) _ia = ia;
      if (visivel != null) _visivel = visivel;
      _salvando = true;
    });
    try {
      await ref.read(privacidadeRepositoryProvider).salvarPreferencias(permiteUsoIa: ia, perfilVisivel: visivel);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ia = antesIa;
        _visivel = antesVisivel;
      });
      DiaviconAlerts.show(context, 'Não foi possível salvar', 'Verifique a conexão e tente de novo.', isErro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _exportar() async {
    if (_exportando) return;
    setState(() => _exportando = true);
    try {
      final json = await ref.read(privacidadeRepositoryProvider).exportarMeusDados();
      final data = DateTime.now();
      final nome = 'diavicon_meus_dados_${data.year}${data.month.toString().padLeft(2, '0')}${data.day.toString().padLeft(2, '0')}.json';
      final onde = await salvarExportacaoDados(json, nome);
      if (mounted) DiaviconAlerts.show(context, 'Cópia gerada', 'Arquivo salvo em $onde.');
    } catch (e) {
      if (mounted) {
        DiaviconAlerts.show(context, 'Não foi possível gerar a cópia', e.toString().replaceFirst('Exception: ', ''), isErro: true);
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _escrever() async {
    final uri = Uri(scheme: 'mailto', path: DocumentosLegais.emailPrivacidade, query: 'subject=${Uri.encodeComponent('Privacidade - pedido do titular')}');
    var abriu = false;
    try {
      abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (abriu || !mounted) return;
    await Clipboard.setData(const ClipboardData(text: DocumentosLegais.emailPrivacidade));
    if (mounted) DiaviconAlerts.show(context, 'E-mail copiado', '${DocumentosLegais.emailPrivacidade} foi copiado.');
  }

  void _abrirDocumento(DocumentoLegal doc) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DocumentoLegalScreen(documento: doc)));
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final prefs = ref.watch(_preferenciasPrivacidadeProvider);
    final servidor = prefs.value ?? PreferenciasPrivacidade.padrao;
    final carregado = prefs.hasValue;
    final ia = _ia ?? servidor.permiteUsoIa;
    final visivel = _visivel ?? servidor.perfilVisivel;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: Column(
        children: [
          PerfilHeader(topPadding: topPadding, paginaAtual: 'Privacidade'),
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
                        child: Text('Privacidade', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _corTexto, fontFamily: 'Lato')),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Controle como seus dados são usados e quem vê seu perfil na DIAVICON. As escolhas ficam gravadas na sua conta e valem no app e no site.',
                        style: TextStyle(fontSize: 14, height: 1.35, color: _corTexto),
                      ),
                      if (prefs.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(children: [
                            const Expanded(
                              child: Text('Não foi possível carregar suas preferências agora.', style: TextStyle(color: AppColors.error, fontSize: 13)),
                            ),
                            TextButton(
                              onPressed: () => ref.invalidate(_preferenciasPrivacidadeProvider),
                              child: const Text('Tentar de novo'),
                            ),
                          ]),
                        ),
                      const SizedBox(height: 24),
                      _Preferencia(
                        titulo: 'Visibilidade do perfil',
                        descricao: visivel
                            ? 'Usuários de outras empresas veem seu nome e sua foto nas suas publicações e na página da sua empresa. Colegas da sua empresa sempre veem.'
                            : 'Só colegas da sua empresa veem seu nome e sua foto. Para outras empresas você aparece sem foto nas publicações e não é listado na página da empresa.',
                        valor: visivel,
                        habilitado: carregado && !_salvando,
                        onChanged: (v) => _salvar(visivel: v),
                      ),
                      const _Separador(),
                      _Preferencia(
                        titulo: 'Ajudar a aprimorar recursos com IA',
                        descricao: 'Com esta opção ligada, a DIAVICON pode usar seus dados de ensaio, sem identificar você ou seus clientes, '
                            'para desenvolver e treinar modelos de IA da plataforma. Fica desligada até você ligar, e você pode desligar quando quiser.',
                        valor: ia,
                        habilitado: carregado && !_salvando,
                        onChanged: (v) => _salvar(ia: v),
                        link: 'Saiba mais na Política de Privacidade',
                        onLink: () => _abrirDocumento(DocumentoLegal.privacidade),
                      ),
                      const _Separador(),
                      const Text('Seus dados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _corTexto, fontFamily: 'Lato')),
                      const SizedBox(height: 8),
                      const Text(
                        'Baixe uma cópia (arquivo JSON) com seu cadastro, seus aceites, suas preferências, suas publicações e a lista do que você registrou na plataforma.',
                        style: TextStyle(fontSize: 14, height: 1.35, color: _corTexto),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _exportando ? null : _exportar,
                        icon: _exportando
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.download_outlined, color: AppColors.primary),
                        label: const Text('Baixar meus dados', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Para corrigir dados, use Perfil > Meus dados. Para apagar a conta, use Perfil > Minha conta.',
                        style: TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF6B6B6B)),
                      ),
                      const _Separador(),
                      const Text('Fale com a DIAVICON sobre privacidade', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _corTexto, fontFamily: 'Lato')),
                      const SizedBox(height: 8),
                      const Text(
                        'Pedidos sobre seus dados (acesso, correção, exclusão, informação sobre compartilhamento, revogação de consentimento) '
                        'são respondidos em até 15 dias.',
                        style: TextStyle(fontSize: 14, height: 1.35, color: _corTexto),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: _escrever,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Icon(Icons.mail_outline, color: AppColors.primary, size: 20),
                            SizedBox(width: 10),
                            Text(DocumentosLegais.emailPrivacidade, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(spacing: 16, runSpacing: 4, children: [
                        TextButton(onPressed: () => _abrirDocumento(DocumentoLegal.privacidade), child: const Text('Política de Privacidade')),
                        TextButton(onPressed: () => _abrirDocumento(DocumentoLegal.termos), child: const Text('Termos de Uso')),
                      ]),
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

class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFD0D0D0)),
      );
}

class _Preferencia extends StatelessWidget {
  final String titulo;
  final String descricao;
  final bool valor;
  final bool habilitado;
  final ValueChanged<bool> onChanged;
  final String? link;
  final VoidCallback? onLink;

  const _Preferencia({
    required this.titulo,
    required this.descricao,
    required this.valor,
    required this.habilitado,
    required this.onChanged,
    this.link,
    this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _corTexto, fontFamily: 'Lato')),
              const SizedBox(height: 8),
              Text(descricao, style: const TextStyle(fontSize: 13.5, height: 1.35, color: _corTexto)),
              if (link != null && onLink != null)
                GestureDetector(
                  onTap: onLink,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(link!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, color: _corTexto)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Switch.adaptive(
            value: valor,
            activeThumbColor: AppColors.primary,
            onChanged: habilitado ? onChanged : null,
          ),
        ),
      ],
    );
  }
}
