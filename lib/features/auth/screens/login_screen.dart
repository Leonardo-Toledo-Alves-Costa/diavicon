import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/security/entrada_segura.dart';
import '../../../core/security/limite_tentativas.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';
import '../utils/auth_error_messages.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _ocultarSenha = true;
  bool _lembrarMe = false;

  // Espera após muitas tentativas erradas (contagem regressiva no botão).
  DateTime? _liberadoEm;
  Timer? _relogio;

  Duration get _esperaRestante {
    final ate = _liberadoEm;
    if (ate == null) return Duration.zero;
    final r = ate.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  @override
  void dispose() {
    _relogio?.cancel();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _iniciarEspera(Duration espera) {
    _relogio?.cancel();
    setState(() => _liberadoEm = DateTime.now().add(espera));
    _relogio = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_esperaRestante == Duration.zero) {
        t.cancel();
        _liberadoEm = null;
      }
      setState(() {});
    });
  }

  Future<void> _fazerLogin() async {
    if (_esperaRestante > Duration.zero) return;
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(_emailController.text, _senhaController.text);
    } catch (e) {
      if (e is TentativasExcedidasException) _iniciarEspera(e.espera);
      if (mounted) {
        final message = authErrorMessage(
          e,
          fallback: 'Erro ao entrar. Verifique suas credenciais.',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider);
    final aviso = ref.watch(avisoAcessoProvider);

    return AuthLayout(
      logoHeight: 220,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 35, 28, 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Bem vindo!',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 25),

                if (aviso != null) ...[
                  _FaixaAviso(aviso),
                  const SizedBox(height: 20),
                ],

                CustomTextField(
                  label: 'Login',
                  hint: 'Seu email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(EntradaSegura.maxEmail),
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Obrigatório';
                    if (!EntradaSegura.emailValido(val)) return 'E-mail inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                CustomTextField(
                  label: 'Senha',
                  hint: 'Sua senha',
                  controller: _senhaController,
                  obscureText: _ocultarSenha,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _ocultarSenha ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _ocultarSenha = !_ocultarSenha),
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(EntradaSegura.maxSenha),
                  ],
                  validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Checkbox(
                      value: _lembrarMe,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _lembrarMe = val!),
                    ),
                    TextButton(
                      onPressed: () {
                        context.push('/recuperar-senha');
                      },
                      child: const Text(
                        'Resgatar Senha',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                CustomButton(
                  text: _esperaRestante > Duration.zero
                      ? 'Aguarde ${formatarEspera(_esperaRestante)}'
                      : 'Entrar  →',
                  isLoading: isLoading,
                  onPressed: isLoading || _esperaRestante > Duration.zero
                      ? null
                      : _fazerLogin,
                ),

                const SizedBox(height: 50),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Image.asset('assets/images/ic_linkedin.png', height: 45),
                    const SizedBox(width: 35),
                    GestureDetector(
                      onTap: () {
                        ref
                            .read(authControllerProvider.notifier)
                            .autenticarComGoogle(context);
                      },
                      child: Image.asset(
                        'assets/images/ic_google.png',
                        height: 45,
                      ),
                    ),
                  ],
                ),

                // ---> inicio do cadastro
                //
                // O "CADASTRE-SE" está desligado de propósito: por enquanto
                // as contas são abertas pela equipe Diavicon, para não entrar
                // gente sem qualificação. A tela de cadastro continua de pé
                // (rota /register) — para voltar a oferecê-la aqui, basta
                // descomentar o bloco abaixo e importar
                // '../widgets/boas_vindas_cadastro.dart' (pop-up que separa
                // empresa nova, empresa já cadastrada e área acadêmica).
                //
                // const SizedBox(height: 20),
                // Column(
                //   children: [
                //     const Text(
                //       'AINDA NÃO POSSUI UMA CONTA?',
                //       style: TextStyle(
                //         fontSize: 10,
                //         fontWeight: FontWeight.bold,
                //         color: Colors.grey,
                //         letterSpacing: 0.8,
                //         fontFamily: 'Lato',
                //       ),
                //     ),
                //     GestureDetector(
                //       onTap: () => abrirBoasVindasCadastro(context),
                //       child: const Padding(
                //         padding: EdgeInsets.symmetric(vertical: 4),
                //         child: Text(
                //           'CADASTRE-SE',
                //           style: TextStyle(
                //             color: AppColors.primary,
                //             fontWeight: FontWeight.w900,
                //             fontSize: 15,
                //             fontFamily: 'Lato',
                //           ),
                //         ),
                //       ),
                //     ),
                //   ],
                // ),
              ],// ---> aqui é o fim do cadastro
            ),
          ),
        ),
      ),
    );
  }
}


/// Faixa que explica por que a sessão caiu (acesso suspenso, por exemplo).
class _FaixaAviso extends StatelessWidget {
  final String texto;

  const _FaixaAviso(this.texto);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3C6C6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 20, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
