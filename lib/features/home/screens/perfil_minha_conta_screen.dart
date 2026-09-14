import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/custom_text_field.dart';
import 'package:diavicon/features/app_shell/widgets/perfil_header.dart';
import 'package:diavicon/features/auth/models/usuario_model.dart';
import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:diavicon/routes/app_routes.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PerfilMinhaConta extends ConsumerStatefulWidget {
  final Map<String, dynamic> dadosCadastro;
  

  const PerfilMinhaConta({super.key, required this.dadosCadastro});

  @override
  ConsumerState<PerfilMinhaConta> createState() => _PerfilMinhaContaState();
}

class _PerfilMinhaContaState extends ConsumerState<PerfilMinhaConta> {
  final _senhaCtrl = TextEditingController();
  final _confirmarSenhaCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final usuario = ref.read(currentUserProvider);
      if (usuario != null) {
        _nomeCtrl.text = usuario.nome ?? '';
        _emailCtrl.text = usuario.email ?? '';
        _telefoneCtrl.text = usuario.celular ?? '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final usuario = ref.watch(currentUserProvider);
    return Scaffold(
      body: Column(
        children: [
          PerfilHeader(topPadding: topPadding, paginaAtual: 'Conta'),
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
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Minha conta',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3E3E3D),
                          fontFamily: 'Lato',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: AssetImage('assets/images/user.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Detalhes da conta',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3E3E3D),
                                fontFamily: 'Lato',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              usuario?.nome ?? '',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1C1C1C),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    usuario?.email ?? '',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1C1C1C),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {},
                                  icon: const Icon(
                                    Icons.open_in_new,
                                    color: Color(0xFF4C39F1),
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const Divider(
                              height: 24,
                              thickness: 1,
                              color: Colors.black,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Plano Atual',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1C1C1C),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Ver planos disponíveis',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1C1C1C),
                              ),
                            ),
                            const Divider(height: 24, thickness: 2),
                            const SizedBox(height: 16),
                            ExpansionTile(
                              initiallyExpanded: true,
                              title: const Text(
                                'Trocar senha',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              children: [
                                CustomTextField(
                                  label: 'Senha',
                                  hint: 'sua senha',
                                  obscureText: true,
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  label: 'Confirmar senha',
                                  hint: 'sua senha',
                                  obscureText: true,
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                            const SizedBox(height: 16),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3E3E3D),
                                  height: 1.3,
                                ),
                                children: [
                                  const TextSpan(
                                    text:
                                        'Caso queira excluir seus dados, encerre\nsua conta ',
                                  ),
                                  TextSpan(
                                    text: 'por aqui.',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        context.pop(); // Close the drawer
                                        // Open the delete account flow here
                                      },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  onPressed: () => context.pop(),
                                  icon: const Icon(
                                    Icons.chevron_left,
                                    color: AppColors.primary,
                                  ),
                                  label: const Text(
                                    'Voltar',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => _salvar(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 4,
                                  ),
                                  child: const Text(
                                    'Salvar',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
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

  Future<void> _salvar() async {
    final usuarioAtual = ref.read(currentUserProvider);
    if (usuarioAtual == null) return;

    if (_senhaCtrl.text.isNotEmpty || _confirmarSenhaCtrl.text.isNotEmpty) {
      if (_senhaCtrl.text != _confirmarSenhaCtrl.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('As senhas não coincidem')),
        );
        return;
      }
      await ref.read(authRepositoryProvider).updatePassword(_senhaCtrl.text);
    }

    final atualizado = UsuarioModel(
      id: usuarioAtual.id,
      nome: _nomeCtrl.text.trim(),
      sobrenome: usuarioAtual.sobrenome,
      email: _emailCtrl.text.trim(),
      celular: _telefoneCtrl.text.trim(),
      cargo: usuarioAtual.cargo,
      empresaId: usuarioAtual.empresaId,
      setorId: usuarioAtual.setorId,
      ativo: usuarioAtual.ativo,
      tituloPrincipal: usuarioAtual.tituloPrincipal,
      escolaridade: usuarioAtual.escolaridade,
      fotoUrl: usuarioAtual.fotoUrl,
      linkedin: usuarioAtual.linkedin,
      instagram: usuarioAtual.instagram,
      criadoEm: usuarioAtual.criadoEm,
      isAdminEmpresa: usuarioAtual.isAdminEmpresa,
    );

    await ref.read(authRepositoryProvider).salvarPerfil(atualizado);
    ref.read(currentUserProvider.notifier).setUserIfSessionMatches(atualizado);

    if (mounted) context.goNamed(AppRouteNames.projects);
  }
}
