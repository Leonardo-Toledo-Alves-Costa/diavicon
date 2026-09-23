import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../auth/providers/auth_provider.dart';
import 'documentos_legais.dart';
import 'repositories/privacidade_repository.dart';
import 'widgets/texto_legal.dart';

/// Pendência de aceite para o usuário logado (por id, para refazer a
/// consulta quando trocar de conta).
final consentimentoPendenteProvider = FutureProvider.family<bool, String>((ref, usuarioId) async {
  try {
    return await ref.read(privacidadeRepositoryProvider).consentimentoPendente();
  } catch (e) {
    // Se o servidor ainda não tem a função (migração não aplicada) ou a rede
    // falhou, não trava o app: a checagem roda de novo no próximo acesso.
    debugPrint('[Consentimento] falha ao consultar: $e');
    return false;
  }
});

/// Envolve o app inteiro (MaterialApp.builder). Enquanto o usuário ativo não
/// tiver aceitado a versão vigente dos Termos de Uso e da Política de
/// Privacidade, mostra a tela de aceite no lugar do app.
///
/// Fica aqui, e não em cada tela de cadastro, porque cobre todos os caminhos
/// de entrada (cadastro por e-mail, Google, convite de colaborador) e também
/// o novo aceite quando um documento muda de versão.
class ConsentimentoGate extends ConsumerStatefulWidget {
  final Widget child;
  const ConsentimentoGate({super.key, required this.child});

  @override
  ConsumerState<ConsentimentoGate> createState() => _ConsentimentoGateState();
}

class _ConsentimentoGateState extends ConsumerState<ConsentimentoGate> with WidgetsBindingObserver {
  // Navigator próprio: o builder do MaterialApp fica acima do Navigator do
  // go_router, e a tela de aceite precisa de Overlay (diálogos) e de pilha
  // para abrir os documentos.
  final _navegador = GlobalKey<NavigatorState>();
  bool _mostrando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Com o aceite na tela, o roteador do app está fora da árvore e ninguém
  // trataria o "voltar" do Android: o app fecharia. Aqui o voltar fecha o
  // documento aberto e, na tela de aceite, não faz nada.
  @override
  Future<bool> didPopRoute() async {
    if (!_mostrando) return false;
    await _navegador.currentState?.maybePop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(authAccessStatusProvider);
    final usuario = ref.watch(currentUserProvider);
    var mostrar = false;
    if (status == AuthAccessStatus.active && usuario != null) {
      mostrar = ref.watch(consentimentoPendenteProvider(usuario.id)).value == true;
    }
    _mostrando = mostrar;
    if (!mostrar) return widget.child;

    return Navigator(
      key: _navegador,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => _TelaConsentimento(usuarioId: usuario!.id),
      ),
    );
  }
}

class _TelaConsentimento extends ConsumerStatefulWidget {
  final String usuarioId;
  const _TelaConsentimento({required this.usuarioId});

  @override
  ConsumerState<_TelaConsentimento> createState() => _TelaConsentimentoState();
}

class _TelaConsentimentoState extends ConsumerState<_TelaConsentimento> {
  bool _aceito = false;
  bool _salvando = false;
  String? _erro;

  void _abrir(DocumentoLegal doc) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: Text(doc.titulo, style: const TextStyle(fontSize: 18)),
        ),
        body: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: TextoLegal(documento: doc)),
        ),
      ),
    ));
  }

  Future<void> _confirmar() async {
    if (!_aceito || _salvando) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await ref.read(privacidadeRepositoryProvider).registrarConsentimento();
      ref.invalidate(consentimentoPendenteProvider(widget.usuarioId));
    } catch (e) {
      if (mounted) setState(() => _erro = 'Não foi possível registrar o aceite. Verifique a conexão e tente de novo.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const estiloLink = TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, decoration: TextDecoration.underline);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              children: [
                Image.asset('assets/images/logo_diavicon.png', height: 56),
                const SizedBox(height: 28),
                const Text(
                  'Termos de Uso e Privacidade',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF3E3E3D), fontFamily: 'Lato'),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Para usar a DIAVICON, leia e aceite os documentos abaixo. Eles explicam quais dados tratamos, para quê, '
                  'com quem compartilhamos e como você controla, baixa ou apaga seus dados.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF3E3E3D)),
                ),
                const SizedBox(height: 24),
                _BotaoDocumento(titulo: DocumentoLegal.termos.titulo, onTap: () => _abrir(DocumentoLegal.termos)),
                const SizedBox(height: 10),
                _BotaoDocumento(titulo: DocumentoLegal.privacidade.titulo, onTap: () => _abrir(DocumentoLegal.privacidade)),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _aceito,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _aceito = v ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(fontSize: 14, height: 1.35, color: Color(0xFF3E3E3D)),
                            children: [
                              const TextSpan(text: 'Li e aceito os '),
                              TextSpan(
                                text: 'Termos de Uso',
                                style: estiloLink,
                                recognizer: TapGestureRecognizer()..onTap = () => _abrir(DocumentoLegal.termos),
                              ),
                              const TextSpan(text: ' e a '),
                              TextSpan(
                                text: 'Política de Privacidade',
                                style: estiloLink,
                                recognizer: TapGestureRecognizer()..onTap = () => _abrir(DocumentoLegal.privacidade),
                              ),
                              const TextSpan(text: '. Declaro ter 18 anos ou mais.'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 8),
                  Text(_erro!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _aceito && !_salvando ? _confirmar : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _salvando
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Aceitar e continuar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _salvando ? null : () => ref.read(authControllerProvider.notifier).logout(),
                  child: const Text('Agora não, sair da conta', style: TextStyle(color: Color(0xFF6B6B6B))),
                ),
                const SizedBox(height: 12),
                Text(
                  'Dúvidas sobre seus dados: ${DocumentosLegais.emailPrivacidade}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF808080)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BotaoDocumento extends StatelessWidget {
  final String titulo;
  final VoidCallback onTap;
  const _BotaoDocumento({required this.titulo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: const BorderSide(color: Color(0xFFD9D9D9)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(children: [
        const Icon(Icons.description_outlined, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF3E3E3D)))),
        const Icon(Icons.chevron_right, color: AppColors.primary),
      ]),
    );
  }
}
