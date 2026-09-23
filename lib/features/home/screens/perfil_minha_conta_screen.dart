import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/custom_text_field.dart';
import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:diavicon/core/utils/validators/validators_cadastro.dart';
import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:diavicon/features/app_shell/widgets/perfil_header.dart';
import 'package:diavicon/features/auth/models/usuario_model.dart';
import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:diavicon/features/legal/documentos_legais.dart';
import 'package:diavicon/features/legal/repositories/privacidade_repository.dart';
import 'package:diavicon/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _corTexto = Color(0xFF3E3E3D);

/// Perfil > Minha conta: dados de acesso, troca de senha e exclusão da conta.
class PerfilMinhaConta extends ConsumerStatefulWidget {
  final Map<String, dynamic> dadosCadastro;

  const PerfilMinhaConta({super.key, required this.dadosCadastro});

  @override
  ConsumerState<PerfilMinhaConta> createState() => _PerfilMinhaContaState();
}

class _PerfilMinhaContaState extends ConsumerState<PerfilMinhaConta> {
  final _senhaCtrl = TextEditingController();
  final _confirmarSenhaCtrl = TextEditingController();
  bool _salvandoSenha = false;

  @override
  void dispose() {
    _senhaCtrl.dispose();
    _confirmarSenhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _trocarSenha() async {
    final senha = _senhaCtrl.text;
    // Mesma regra do cadastro (8+ caracteres, maiúscula, minúscula e número).
    final problema = ValidatorsCadastro.senha(senha);
    if (problema != null) {
      DiaviconAlerts.show(context, 'Senha fraca', problema, isAviso: true);
      return;
    }
    if (senha != _confirmarSenhaCtrl.text) {
      DiaviconAlerts.show(context, 'Senhas diferentes', 'A confirmação não é igual à nova senha.', isAviso: true);
      return;
    }
    setState(() => _salvandoSenha = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(senha);
      _senhaCtrl.clear();
      _confirmarSenhaCtrl.clear();
      if (mounted) DiaviconAlerts.show(context, 'Senha alterada', 'Sua nova senha já está valendo.');
    } catch (e) {
      if (mounted) {
        DiaviconAlerts.show(context, 'Não foi possível trocar a senha', e.toString().replaceFirst('Exception: ', ''), isErro: true);
      }
    } finally {
      if (mounted) setState(() => _salvandoSenha = false);
    }
  }

  Future<void> _excluirConta(UsuarioModel usuario) async {
    final excluiu = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoExcluirConta(ehAdministradorPrincipal: usuario.isAdminEmpresa == true),
    );
    if (excluiu != true || !mounted) return;
    // A conta não existe mais: encerra a sessão e o roteador volta ao início.
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final usuario = ref.watch(currentUserProvider);
    final nomeCompleto = [usuario?.nome, usuario?.sobrenome].where((p) => p != null && p.trim().isNotEmpty).join(' ');

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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Text(
                          'Minha conta',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _corTexto, fontFamily: 'Lato'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(child: _FotoPerfil(url: usuario?.fotoUrl)),
                      const SizedBox(height: 14),
                      Text(
                        nomeCompleto.isEmpty ? 'Usuário' : nomeCompleto,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1C)),
                      ),
                      if ((usuario?.cargo ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(usuario!.cargo!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF6B6B6B))),
                        ),
                      const SizedBox(height: 24),
                      const _Titulo('Acesso'),
                      _Linha(icone: Icons.mail_outline, rotulo: 'E-mail de acesso', valor: usuario?.email ?? '—'),
                      if ((usuario?.celular ?? '').trim().isNotEmpty)
                        _Linha(icone: Icons.phone_outlined, rotulo: 'Celular', valor: usuario!.celular!),
                      _Linha(
                        icone: Icons.badge_outlined,
                        rotulo: 'Perfil na empresa',
                        valor: usuario?.isAdminEmpresa == true
                            ? 'Gestor'
                            : usuario?.isAdmin == true
                                ? 'Administrador'
                                : 'Colaborador',
                      ),
                      const SizedBox(height: 4),
                      _Acao(
                        icone: Icons.edit_outlined,
                        texto: 'Editar meus dados',
                        onTap: () => context.pushNamed(AppRouteNames.profileData),
                      ),
                      _Acao(
                        icone: Icons.shield_outlined,
                        texto: 'Privacidade e cópia dos meus dados',
                        onTap: () => context.pushNamed(AppRouteNames.profilePrivacy),
                      ),
                      const Divider(height: 32),
                      Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 8),
                          title: const Text('Trocar senha', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _corTexto)),
                          children: [
                            CustomTextField(label: 'Nova senha', hint: 'mínimo de 8 caracteres', obscureText: true, controller: _senhaCtrl),
                            const SizedBox(height: 14),
                            CustomTextField(label: 'Confirmar nova senha', hint: 'repita a senha', obscureText: true, controller: _confirmarSenhaCtrl),
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                onPressed: _salvandoSenha ? null : _trocarSenha,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: _salvandoSenha
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Salvar nova senha', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 32),
                      if (usuario != null) _ZonaExclusao(usuario: usuario, onExcluir: () => _excluirConta(usuario)),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.chevron_left, color: AppColors.primary),
                          label: const Text('Voltar', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w500)),
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
}

class _FotoPerfil extends StatelessWidget {
  final String? url;
  const _FotoPerfil({this.url});

  @override
  Widget build(BuildContext context) {
    final temFoto = url != null && url!.trim().startsWith('http');
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      padding: const EdgeInsets.all(3),
      child: ClipOval(
        child: temFoto
            ? ImagemStorage.network(
                url!,
                fit: BoxFit.cover,
                cacheWidth: 300,
                errorBuilder: (_, __, ___) => Image.asset('assets/images/user.png', fit: BoxFit.cover),
              )
            : Image.asset('assets/images/user.png', fit: BoxFit.cover),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;
  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(texto, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _corTexto, fontFamily: 'Lato')),
      );
}

class _Linha extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String valor;
  const _Linha({required this.icone, required this.rotulo, required this.valor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icone, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rotulo, style: const TextStyle(fontSize: 12, color: Color(0xFF808080))),
              const SizedBox(height: 2),
              Text(valor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1C))),
            ]),
          ),
        ]),
      );
}

class _Acao extends StatelessWidget {
  final IconData icone;
  final String texto;
  final VoidCallback onTap;
  const _Acao({required this.icone, required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Icon(icone, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(texto, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primary))),
            const Icon(Icons.chevron_right, color: AppColors.primary),
          ]),
        ),
      );
}

class _ZonaExclusao extends StatelessWidget {
  final UsuarioModel usuario;
  final VoidCallback onExcluir;
  const _ZonaExclusao({required this.usuario, required this.onExcluir});

  @override
  Widget build(BuildContext context) {
    final principal = usuario.isAdminEmpresa == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF2C7C7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Excluir minha conta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFB3261E))),
        const SizedBox(height: 8),
        Text(
          principal
              ? 'Você é Gestor da empresa. Se for o único Gestor e houver outros usuários, passe a gestão para alguém antes de '
                  'excluir sua conta. Se você for o único usuário, a empresa e todos os dados dela também serão apagados.'
              : 'Apaga seu cadastro, sua foto, suas publicações no feed e seu acesso. Os projetos, ensaios, fotos e relatórios '
                  'que você criou para a empresa continuam com ela, sem o seu nome.',
          style: const TextStyle(fontSize: 13.5, height: 1.4, color: _corTexto),
        ),
        const SizedBox(height: 6),
        const Text(
          'Antes, se quiser, baixe uma cópia dos seus dados em Privacidade.',
          style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF6B6B6B)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onExcluir,
          icon: const Icon(Icons.delete_forever_outlined, color: Color(0xFFB3261E)),
          label: const Text('Excluir minha conta', style: TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFB3261E))),
        ),
      ]),
    );
  }
}

/// Confirmação com digitação de EXCLUIR. Chama o servidor e só fecha com
/// `true` quando a conta foi de fato apagada.
class _DialogoExcluirConta extends ConsumerStatefulWidget {
  final bool ehAdministradorPrincipal;
  const _DialogoExcluirConta({required this.ehAdministradorPrincipal});

  @override
  ConsumerState<_DialogoExcluirConta> createState() => _DialogoExcluirContaState();
}

class _DialogoExcluirContaState extends ConsumerState<_DialogoExcluirConta> {
  static const _palavra = 'EXCLUIR';
  final _ctrl = TextEditingController();
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _confere => _ctrl.text.trim().toUpperCase() == _palavra;

  Future<void> _confirmar() async {
    if (!_confere || _enviando) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await ref.read(privacidadeRepositoryProvider).excluirMinhaConta(confirmacao: _palavra);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _erro = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Excluir sua conta?'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            widget.ehAdministradorPrincipal
                ? 'Seu cadastro, sua foto e suas publicações serão apagados. Se você for o único usuário da empresa, a empresa, os projetos, ensaios, fotos e relatórios dela também serão apagados. Isso não pode ser desfeito.'
                : 'Seu cadastro, sua foto e suas publicações serão apagados e você perderá o acesso. Isso não pode ser desfeito.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 14),
          const Text('Digite EXCLUIR para confirmar:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            enabled: !_enviando,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, hintText: _palavra),
            onChanged: (_) => setState(() {}),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 10),
            Text(_erro!, style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13)),
          ],
          const SizedBox(height: 10),
          Text('Dúvidas: ${DocumentosLegais.emailPrivacidade}', style: const TextStyle(fontSize: 12, color: Color(0xFF808080))),
        ]),
      ),
      actions: [
        TextButton(onPressed: _enviando ? null : () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        TextButton(
          onPressed: _confere && !_enviando ? _confirmar : null,
          child: _enviando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Excluir definitivamente', style: TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
