import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../utils/cadastro_draft_utils.dart';

class EmailConfirmationScreen extends ConsumerStatefulWidget {
  const EmailConfirmationScreen({super.key});

  @override
  ConsumerState<EmailConfirmationScreen> createState() =>
      _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState
    extends ConsumerState<EmailConfirmationScreen> {
  bool _isLoading = false;

  Future<void> _reenviar() async {
    final draft = ref.read(rascunhoCadastroProvider);
    final email = draft['email']?.toString().trim() ?? '';
    if (email.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).resendSignupConfirmation(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-mail de confirmação reenviado.')),
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verificar() async {
    setState(() => _isLoading = true);
    try {
      if (Supabase.instance.client.auth.currentSession == null) {
        ref.read(currentUserProvider.notifier).clearUser();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entre novamente para confirmar seu e-mail.'),
              backgroundColor: Colors.red,
            ),
          );
          context.go('/login');
        }
        return;
      }
      await Supabase.instance.client.auth.refreshSession();
      if (Supabase.instance.client.auth.currentSession == null) {
        ref.read(currentUserProvider.notifier).clearUser();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sua sessão expirou. Entre novamente para continuar.'),
              backgroundColor: Colors.red,
            ),
          );
          context.go('/login');
        }
        return;
      }
      await ref.read(currentUserProvider.notifier).sincronizarSessaoAtiva();
      if (!mounted) return;
      final status = ref.read(authAccessStatusProvider);
      if (status == AuthAccessStatus.active) {
        context.go('/projetos');
      } else if (status == AuthAccessStatus.invitePending) {
        context.go('/completar-cadastro');
      } else if (status == AuthAccessStatus.registrationPending) {
        context.go('/register/retomar');
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(rascunhoCadastroProvider);
    final email = draft['email']?.toString().trim() ?? '';
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mark_email_unread_outlined,
                    size: 76, color: AppColors.primary),
                const SizedBox(height: 20),
                const Text(
                  'Confirme seu e-mail',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  email.isEmpty
                      ? 'Enviamos um link de confirmação para o seu e-mail.'
                      : 'Enviamos um link de confirmação para $email.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _isLoading ? null : _verificar,
                  child: const Text('Já confirmei meu e-mail'),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _reenviar,
                  child: const Text('Reenviar confirmação'),
                ),
                TextButton(
                  onPressed: () async {
                    await ref
                        .read(authControllerProvider.notifier)
                        .logout();
                    if (context.mounted) context.go('/login');
                  },
                  child: const Text('Voltar para o login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegistrationPendingScreen extends ConsumerWidget {
  const RegistrationPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(rascunhoCadastroProvider);
    final isCompany = draft['perfil_tipo']?.toString() == 'empresa' ||
        draft['empresa'] is Map;
    final target = isCompany ? '/empresa/cadastro' : '/register/academico';
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.assignment_outlined,
                  size: 72, color: AppColors.primary),
              const SizedBox(height: 20),
              const Text(
                'Continue seu cadastro',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                CadastroDraftUtils.hasEmail(draft)
                    ? 'Seu e-mail foi confirmado. Falta apenas concluir os seus dados.'
                    : 'Não encontramos os dados anteriores. Você pode iniciar novamente.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => context.go(
                  CadastroDraftUtils.hasEmail(draft) ? target : '/register',
                ),
                child: Text(CadastroDraftUtils.hasEmail(draft)
                    ? 'Retomar cadastro'
                    : 'Iniciar cadastro'),
              ),
              TextButton(
                onPressed: () => ref
                    .read(authControllerProvider.notifier)
                    .logout(),
                child: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InactiveAccountScreen extends ConsumerWidget {
  const InactiveAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block_outlined, size: 72, color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                'Acesso indisponível',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Este perfil está inativo. Entre em contato com o administrador da sua empresa.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => ref
                    .read(authControllerProvider.notifier)
                    .logout(),
                child: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthUnavailableScreen extends ConsumerWidget {
  const AuthUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authAccessStatusProvider);
    final retrying = status == AuthAccessStatus.loading;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 72, color: AppColors.primary),
              const SizedBox(height: 20),
              const Text(
                'Não foi possível verificar seu acesso',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Confira sua conexão e tente novamente. O aplicativo permanece bloqueado até a verificação ser concluída.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: retrying
                    ? null
                    : () => ref
                        .read(currentUserProvider.notifier)
                        .sincronizarSessaoAtiva(),
                child: Text(retrying ? 'Verificando...' : 'Tentar novamente'),
              ),
              TextButton(
                onPressed: retrying
                    ? null
                    : () async {
                        await ref
                            .read(authControllerProvider.notifier)
                            .logout();
                        if (context.mounted) context.go('/login');
                      },
                child: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
