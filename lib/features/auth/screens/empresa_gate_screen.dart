import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/auth_layout.dart';

/// Tela de entrada do fluxo de empresa.
/// Pergunta se a empresa já está cadastrada ou se o usuário quer criar uma.
/// Rota: /empresa/gate
class EmpresaGateScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> dadosUsuario;

  const EmpresaGateScreen({super.key, required this.dadosUsuario});

  @override
  ConsumerState<EmpresaGateScreen> createState() => _EmpresaGateScreenState();
}

class _EmpresaGateScreenState extends ConsumerState<EmpresaGateScreen> {
  final _codigoController = TextEditingController();
  bool _mostrarCampoCode = false;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sua empresa já é cadastrada da DIAVICON?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 32),

            // Botão: Quero cadastrar minha empresa
            _OpcaoButton(
              icone: Icons.domain,
              texto: 'Quero cadastrar minha empresa',
              onTap: () => context.go(
                '/empresa/onboarding',
                extra: widget.dadosUsuario,
              ),
            ),
            const SizedBox(height: 16),

            // Botão: Sou membro de uma empresa
            _OpcaoButton(
              icone: Icons.group,
              texto: 'Sou membro de uma empresa',
              subtexto: 'Entre com o código de acesso enviado por sua empresa',
              onTap: () => setState(() => _mostrarCampoCode = true),
            ),

            // Campo de código (aparece ao clicar em "Sou membro")
            if (_mostrarCampoCode) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _codigoController,
                decoration: InputDecoration(
                  hintText: 'AbCD123',
                  hintStyle:
                      const TextStyle(color: AppColors.hintText, fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward,
                        color: AppColors.primary),
                    onPressed: _entrarComCodigo,
                  ),
                ),
              ),
            ],

            const Spacer(),

            TextButton(
              onPressed: () =>
                  context.go('/empresa/onboarding', extra: widget.dadosUsuario),
              child: const Text(
                '< Voltar',
                style: TextStyle(color: AppColors.greyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _entrarComCodigo() {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o código de acesso.')),
      );
      return;
    }
    // TODO: validar código com o backend
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Entrando com código: $codigo')),
    );
  }
}

/// Botão de opção estilizado para a tela de gate.
class _OpcaoButton extends StatelessWidget {
  final IconData icone;
  final String texto;
  final String? subtexto;
  final VoidCallback onTap;

  const _OpcaoButton({
    required this.icone,
    required this.texto,
    this.subtexto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icone, color: Colors.white, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texto,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (subtexto != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtexto!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
