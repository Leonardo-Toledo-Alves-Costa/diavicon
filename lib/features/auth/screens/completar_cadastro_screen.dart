import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/diavicon_alerts.dart';

class CompletarCadastroScreen extends ConsumerStatefulWidget {
  const CompletarCadastroScreen({super.key});

  @override
  ConsumerState<CompletarCadastroScreen> createState() => _CompletarCadastroScreenState();
}

class _CompletarCadastroScreenState extends ConsumerState<CompletarCadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nomeController = TextEditingController();
  final _sobrenomeController = TextEditingController();
  final _cargoController = TextEditingController();
  final _celularController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  
  bool _isLoading = false;
  bool _dadosCarregados = false;

  @override
  void initState() {
    super.initState();
    // Carrega os dados que já vieram do convite
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarDadosIniciais();
    });
  }

  void _carregarDadosIniciais() {
    final usuario = ref.read(currentUserProvider);
    if (usuario != null) {
      _nomeController.text = usuario.nome ?? '';
      _sobrenomeController.text = usuario.sobrenome ?? '';
      _cargoController.text = usuario.cargo ?? '';
      _celularController.text = usuario.celular ?? '';
      setState(() {
        _dadosCarregados = true;
      });
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _sobrenomeController.dispose();
    _cargoController.dispose();
    _celularController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _finalizarCadastro() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) throw Exception('Usuário não autenticado.');

      // 1. Atualiza a senha no Supabase Auth (O usuário do convite não tem senha ainda)
      await supabase.auth.updateUser(
        UserAttributes(password: _senhaController.text),
      );

      // 2. Atualiza os dados na tabela 'usuarios' e muda para ATIVO = true
      await supabase.from('usuarios').update({
        'nome': _nomeController.text.trim(),
        'sobrenome': _sobrenomeController.text.trim(),
        'cargo': _cargoController.text.trim(),
        'celular': _celularController.text.trim(),
        'ativo': true, // 🔥 LIBERA O ACESSO
      }).eq('id', user.id);

      // 3. Atualiza o Provider local para refletir a mudança imediatamente
      final repo = ref.read(authRepositoryProvider);
      final perfilAtualizado = await repo.getUsuarioPerfil(user.id);
      if (perfilAtualizado != null) {
        ref.read(currentUserProvider.notifier).setUser(perfilAtualizado);
      }

      if (!mounted) return;

      DiaviconAlerts.show(
        context, 
        'Cadastro Completo!', 
        'Bem-vindo à equipe! Seu acesso foi liberado.'
      );

      // 4. O GoRouter vai detectar a mudança no currentUserProvider (ativo = true)
      // e vai redirecionar automaticamente para /projetos.
      // Mas por garantia, podemos forçar:
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.go('/projetos');
      });

    } catch (e) {
      if (!mounted) return;
      DiaviconAlerts.show(context, 'Erro', e.toString().replaceAll('Exception: ', ''), isErro: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete seu Perfil', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // Não pode voltar, tem que completar!
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.card_membership, size: 60, color: AppColors.primary),
                const SizedBox(height: 16),
                const Text(
                  'Bem-vindo à equipe!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                Text(
                  'Confirme seus dados e crie uma senha para acessar a plataforma.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 32),

                // --- DADOS PESSOAIS ---
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'Nome',
                        hint: 'Seu nome', // 🔥 HINT ADICIONADO AQUI
                        controller: _nomeController,
                        validator: (val) => val == null || val.isEmpty ? 'Obrigatório' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        label: 'Sobrenome',
                        hint: 'Seu sobrenome', // 🔥 HINT ADICIONADO AQUI
                        controller: _sobrenomeController,
                        validator: (val) => val == null || val.isEmpty ? 'Obrigatório' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
 
                CustomTextField(
                  label: 'Cargo / Função',
                  hint: 'Ex: Desenvolvedor', // 🔥 HINT ADICIONADO AQUI
                  controller: _cargoController,
                  validator: (val) => val == null || val.isEmpty ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Celular (com DDD)',
                  hint: '(11) 99999-9999',
                  controller: _celularController,
                  keyboardType: TextInputType.phone,
                  validator: (val) => val == null || val.isEmpty ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 32),
                
                const Divider(),
                const SizedBox(height: 16),
                
                const Text(
                  'Segurança',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 16),

                // --- SENHA ---
                CustomTextField(
                  label: 'Criar Senha',
                  hint: 'Mínimo de 6 caracteres',
                  controller: _senhaController,
                  obscureText: true,
                  validator: (val) {
                    if (val == null || val.length < 6) return 'A senha deve ter no mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Confirmar Senha',
                  hint: 'Digite a senha novamente',
                  controller: _confirmarSenhaController,
                  obscureText: true,
                  validator: (val) {
                    if (val != _senhaController.text) return 'As senhas não coincidem';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : CustomButton(
                        text: 'Salvar e Acessar',
                        onPressed: _finalizarCadastro,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}