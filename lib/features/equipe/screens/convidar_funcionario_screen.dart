  import 'package:diavicon/features/auth/providers/auth_provider.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';
  import 'package:supabase_flutter/supabase_flutter.dart';

  import '../../../../core/constants/app_colors.dart';
  import '../../../../core/widgets/custom_text_field.dart'; 
  import '../../../../core/widgets/custom_button.dart';

  class ConvidarFuncionarioScreen extends ConsumerStatefulWidget {
    // 🔥 AGORA ELA RECEBE O PROJETO ID
    final String projetoId;

    const ConvidarFuncionarioScreen({super.key, required this.projetoId});

    @override
    ConsumerState<ConvidarFuncionarioScreen> createState() => _ConvidarFuncionarioScreenState();
  }

  class _ConvidarFuncionarioScreenState extends ConsumerState<ConvidarFuncionarioScreen> {
    final _formKey = GlobalKey<FormState>();
    final _nomeController = TextEditingController();
    final _sobrenomeController = TextEditingController();
    final _emailController = TextEditingController();
    final _cargoController = TextEditingController();
    
    bool _isLoading = false;

    @override
    void dispose() {
      _nomeController.dispose();
      _sobrenomeController.dispose();
      _emailController.dispose();
      _cargoController.dispose();
      super.dispose();
    }

    Future<void> _enviarConvite() async {
      if (!_formKey.currentState!.validate()) return;

      setState(() => _isLoading = true);

      try {
        final usuarioAtual = ref.read(currentUserProvider);
        if (usuarioAtual == null || usuarioAtual.empresaId == null) {
          throw Exception('Erro: Empresa não identificada.');
        }

        // 🔥 ENVIANDO O projeto_id PARA A EDGE FUNCTION
        final response = await Supabase.instance.client.functions.invoke(
          'convidar-funcionario',
          body: {
            'email': _emailController.text.trim(),
            'nome': _nomeController.text.trim(),
            'sobrenome': _sobrenomeController.text.trim(),
            'cargo': _cargoController.text.trim(),
            'empresa_id': usuarioAtual.empresaId, 
            'projeto_id': widget.projetoId, // Passando o ID aqui!
          },
        );
  /*ta, e agr la no cadastro precisamos mudar o jeito que o cep ta funcionando, quando ele acha o cep, ele ta deixando os campos de rua e etc tudo sem poder editar, mas como tem ceps que nao acham rua, bairo, ai fica ruim, entao, se nao achou rua nem bairro, ai os campos ficam editaveis, se achou  eles nao podem ser editados e ficam como ta aualmente */
        if (response.status == 200) {
          final data = response.data;
          final senhaTemporaria = data['senhaProvisoria'];

          if (!mounted) return;

          showDialog(
            context: context,
            barrierDismissible: false, 
            builder: (context) => AlertDialog(
              title: const Text('✅ Cadastro Realizado!', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('O acesso do funcionário foi criado com sucesso. Envie esta senha temporária para ele:'),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: SelectableText(
                      senhaTemporaria,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ele precisará trocar essa senha no primeiro login.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); 
                    context.pop(); 
                  },
                  child: const Text('Entendi'),
                ),
              ],
            ),
          );
        } else {
          throw Exception(response.data['erro'] ?? 'Erro desconhecido ao convidar.');
        }

      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text(
            'Convidar Funcionário',
            style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.of(context).pop(),
          ),
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
                  const Text(
                    'Dados do Funcionário',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ele receberá um link por e-mail para definir a própria senha e completar o cadastro.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Nome',
                          hint: 'Ex: João',
                          controller: _nomeController,
                          validator: (val) => val == null || val.isEmpty ? 'Obrigatório' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomTextField(
                          label: 'Sobrenome',
                          hint: 'Ex: Silva',
                          controller: _sobrenomeController,
                          validator: (val) => val == null || val.isEmpty ? 'Obrigatório' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    label: 'E-mail Corporativo',
                    hint: 'joao.silva@suaempresa.com.br',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'O e-mail é obrigatório';
                      if (!val.contains('@')) return 'Digite um e-mail válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    label: 'Cargo / Função',
                    hint: 'Ex: Engenheiro Civil',
                    controller: _cargoController,
                    validator: (val) => val == null || val.isEmpty ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 32),

                  _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : CustomButton(
                          text: 'Enviar Convite',
                          onPressed: _enviarConvite,
                        ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }