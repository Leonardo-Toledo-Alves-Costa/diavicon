import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/auth_layout.dart';

class _PerfilData {
  final IconData icon;
  final String label;
  final String key;

  const _PerfilData({
    required this.icon,
    required this.label,
    required this.key,
  });
}

const _perfis = [
  _PerfilData(
    icon: Icons.engineering_outlined,
    label: 'Engenheiro Diagnóstico',
    key: 'engenheiro',
  ),
  _PerfilData(
    icon: Icons.business_outlined,
    label: 'Proprietário/gestor de ativos',
    key: 'proprietario',
  ),
  _PerfilData(
    icon: Icons.school_outlined,
    label: 'Pesquisador Acadêmico',
    key: 'academico',
  ),
];

class CadastroR2Screen extends StatelessWidget {
  final Map<String, dynamic> dadosCadastro;

  const CadastroR2Screen({super.key, required this.dadosCadastro});

  void _selecionarPerfil(BuildContext context, String perfilKey) {
    final extra = {...dadosCadastro, 'perfil': perfilKey};
    switch (perfilKey) {
      case 'engenheiro':
      case 'proprietario':
        context.go('/empresa/gate', extra: extra);
        break;
      case 'academico':
        context.go('/register/academico', extra: extra);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Qual perfil melhor',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C1C1C),
                height: 1.3,
              ),
            ),
            const Text(
              'te descreve?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C1C1C),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 36),
            ..._perfis.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _PerfilCard(
                  icon: p.icon,
                  label: p.label,
                  onTap: () => _selecionarPerfil(context, p.key),
                ),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.chevron_left, color: AppColors.primary),
              label: const Text(
                'Voltar',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PerfilCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PerfilCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.white.withValues(alpha: 0.2),
        highlightColor: Colors.white.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}