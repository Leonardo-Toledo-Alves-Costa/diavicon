import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../core/widgets/step_progress_bar.dart';

/// Fluxo acadêmico completo — 3 etapas:
///   Etapa 1: Onboarding com mascote
///   Etapa 2: Seleção de serviços (checkboxes)
///   Etapa 3: Dados acadêmicos
/// Rota: /register/academico
class CadastroAcademicoScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> dadosUsuario;

  const CadastroAcademicoScreen({super.key, required this.dadosUsuario});

  @override
  ConsumerState<CadastroAcademicoScreen> createState() =>
      _CadastroAcademicoScreenState();
}

class _CadastroAcademicoScreenState
    extends ConsumerState<CadastroAcademicoScreen> {
  int _etapaAtual = 0;

  final List<String> _servicos = [
    'Pesquisa em Patologias',
    'Ensaios Não Destrutivos',
    'Monitoramento Estrutural',
    'Carbonatação e Corrosão',
    'Análise de Resistividade',
    'Outros',
  ];
  final Set<String> _selecionados = {};

  final _formKey = GlobalKey<FormState>();
  final _universidadeController = TextEditingController();
  final _motivoController = TextEditingController();
  final _lattesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _universidadeController.dispose();
    _motivoController.dispose();
    _lattesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildEtapa(_etapaAtual),
      ),
    );
  }

  Widget _buildEtapa(int etapa) {
    switch (etapa) {
      case 0:
        return _buildEtapa1();
      case 1:
        return _buildEtapa2();
      case 2:
        return _buildEtapa3();
      default:
        return _buildEtapa1();
    }
  }

  // Onboarding
  Widget _buildEtapa1() {
    return Padding(
      key: const ValueKey('etapa1'),
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Queremos te conhecer melhor!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Assim conseguimos personalizar sua experiência e oferecer soluções adequadas ao seu tipo de necessidade.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  'assets/images/cachorro.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.school,
                    size: 120,
                    color: AppColors.greyLight,
                  ),
                ),
                Positioned(
                  right: 16,
                  top: 30,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.greyVeryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Vamos\nComeçar?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              TextButton(
                onPressed: () =>
                    context.go('/register/perfil', extra: widget.dadosUsuario),
                child: const Text(
                  '< Voltar',
                  style: TextStyle(color: AppColors.greyMedium),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 160,
                child: CustomButton(
                  text: 'Começar',
                  onPressed: () => setState(() => _etapaAtual = 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Checkboxes 
  Widget _buildEtapa2() {
    return Padding(
      key: const ValueKey('etapa2'),
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StepProgressBar(currentStep: 1, totalSteps: 2),
          const SizedBox(height: 24),

          const Text(
            'Quais serviços que você realiza?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: ListView.builder(
              itemCount: _servicos.length,
              itemBuilder: (context, index) {
                final item = _servicos[index];
                final selecionado = _selecionados.contains(item);
                return GestureDetector(
                  onTap: () => setState(() {
                    selecionado
                        ? _selecionados.remove(item)
                        : _selecionados.add(item);
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: selecionado
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selecionado
                            ? AppColors.primary
                            : AppColors.inputBorder,
                        width: selecionado ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: selecionado
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: selecionado
                                  ? AppColors.primary
                                  : AppColors.greyLight,
                            ),
                          ),
                          child: selecionado
                              ? const Icon(
                                  Icons.check,
                                  color: AppColors.white,
                                  size: 14,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 14,
                              color: selecionado
                                  ? AppColors.textDark
                                  : AppColors.greyMediumDark,
                              fontWeight: selecionado
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _etapaAtual = 0),
                child: const Text(
                  '< Voltar',
                  style: TextStyle(color: AppColors.greyMedium),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 160,
                child: CustomButton(
                  text: 'Avançar',
                  onPressed: () {
                    if (_selecionados.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Selecione pelo menos um item para continuar.',
                          ),
                        ),
                      );
                      return;
                    }
                    setState(() => _etapaAtual = 2);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  //  Dados acadêmicos
  Widget _buildEtapa3() {
    return SingleChildScrollView(
      key: const ValueKey('etapa3'),
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text:
                        'Nos envie seus dados para que possamos te introduzir no ecossistema da ',
                  ),
                  TextSpan(
                    text: 'DIAVICON',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Informe um pouco mais sobre você',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),

            CustomTextField(
              label: 'Universidade',
              hint: 'Ex: UFMG',
              controller: _universidadeController,
              validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 16),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Por quê usar o DIAVICON?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _motivoController,
                  maxLines: 4,
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Obrigatório' : null,
                  decoration: InputDecoration(
                    hintText: 'Descreva sua pesquisa ou objetivo...',
                    hintStyle: const TextStyle(
                      color: AppColors.hintText,
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppColors.inputBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppColors.inputBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            CustomTextField(
              label: 'Informe o link do seu currículo Lattes',
              hint: 'www.lattes.com.br/seunome',
              controller: _lattesController,
              keyboardType: TextInputType.url,
              validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 30),

            CustomButton(
              text: '  Enviar',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _enviar,
            ),
            const SizedBox(height: 12),

            TextButton(
              onPressed: () => setState(() => _etapaAtual = 1),
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

  // Esta função vai dentro da sua Screen (CadastroAcademico ou Cadastro3)

  Future<void> _enviar() async {
    final controller = ref.read(authControllerProvider.notifier);

    // Preparamos o MAPA com todos os dados coletados desde a R0
    // Certifique-se que as chaves batem com o que o Repositorio espera
    final Map<String, dynamic> dadosParaSalvar = {
      ...widget.dadosUsuario, // Traz e-mail, senha, nome, sobrenome, etc.
      // Dados de Endereço (Vêm dos controllers da R2)
      'rua': widget.dadosUsuario['rua'],
      'cidade': widget.dadosUsuario['cidade'],
      'estado': widget.dadosUsuario['estado'],
      'cep': widget.dadosUsuario['cep'],

      // Dados específicos desta tela final
      'formacao': _universidadeController.text, // ou o que for o caso
      'perfil': widget.dadosUsuario['perfil'], // 'Acadêmico' ou 'Empresa'
    };

    try {
      //  Dispara o processo de salvamento (Auth -> Endereço -> Usuário)
      await controller.registrar(
        email: widget.dadosUsuario['email'],
        password: widget.dadosUsuario['senha'],
        dados: dadosParaSalvar,
      );

      // SE DEU CERTO: Navega para a Home
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cadastro finalizado com sucesso!'),
            backgroundColor: AppColors.primary,
          ),
        );

        // context.go mata a pilha de cadastro e te joga no app
        context.go('/projetos');
      }
    } catch (e) {
      // TRATAMENTO DE ERRO
      if (mounted) {
        String erroMsg = 'Erro ao salvar dados.';
        if (e.toString().contains('429'))
          erroMsg = 'Muitas tentativas. Aguarde 1h.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(erroMsg), backgroundColor: Colors.redAccent),
        );
        print("ERRO COMPLETO: $e");
      }
    }
  }
}
