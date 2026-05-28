import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/auth_layout.dart';

class CadastroR2Screen extends ConsumerWidget {
  final Map<String, dynamic> dadosUsuario;

  const CadastroR2Screen({super.key, required this.dadosUsuario});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthLayout(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Qual perfil melhor\nte descreve?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 32),

            //Engenheiro Diagnóstico
            _PerfilButton(
              icone: Icons.engineering,
              texto: 'Engenheiro Diagnóstico',
              onTap: () => _irParaProximaEtapa(
                context,
                'Engenheiro/Pesquisador',
              ),
            ),
            const SizedBox(height: 16),

            // Proprietário/gestor de ativos
            _PerfilButton(
              icone: Icons.domain,
              texto: 'Proprietário/gestor\nde ativos',
              onTap: () => _irParaProximaEtapa(
                context,
                'Cliente',
              ),
            ),
            const SizedBox(height: 16),

            // Pesquisador Acadêmico
            _PerfilButton(
              icone: Icons.school,
              texto: 'Pesquisador Acadêmico',
              onTap: () => _irParaProximaEtapa(
                context,
                'Acadêmico',
              ),
            ),

            const Spacer(),

            // Botão Voltar
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.pop(),
                child: const Text(
                  '< Voltar',
                  style: TextStyle(color: AppColors.greyMedium),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _irParaProximaEtapa(BuildContext context, String tipo) {
    // Adiciona o tipo escolhido ao mapa de dados que veio das telas anteriores
    final dadosAtualizados = {...dadosUsuario, 'tipo': tipo};
    print(tipo); // Para debug: ver qual tipo foi selecionado
    if (tipo == 'Acadêmico') {
      // Vai para a tela de dados acadêmicos
      context.go('/register/academico', extra: dadosAtualizados);
    }
    else if (tipo == 'Cliente') {
      // Vai para a tela de dados do cliente
      context.go('/register/cliente/gate', extra: dadosAtualizados);
    }
    else {
      // Engenheiro e Proprietário seguem para o Onboarding de Empresa
      context.go('/empresa/gate', extra: dadosAtualizados);
    }
  }
}

// Widget auxiliar para os botões grandes de perfil
class _PerfilButton extends StatelessWidget {
  final IconData icone;
  final String texto;
  final VoidCallback onTap;

  const _PerfilButton({
    required this.icone,
    required this.texto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icone, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}