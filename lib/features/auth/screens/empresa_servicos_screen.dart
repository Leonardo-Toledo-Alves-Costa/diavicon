import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../core/widgets/step_progress_bar.dart';
import '../utils/cadastro_freemium.dart';

/// Tela de seleção de serviços/atividades.
/// Rota: /empresa/servicos
class EmpresaServicosScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> dadosUsuario;

  const EmpresaServicosScreen({super.key, required this.dadosUsuario});

  @override
  ConsumerState<EmpresaServicosScreen> createState() =>
      _EmpresaServicosScreenState();
}

class _EmpresaServicosScreenState extends ConsumerState<EmpresaServicosScreen> {
  final List<String> _servicosEngenheiro = [
    'Inspeção e Diagnóstico Estrutural',
    'Ensaios Não Destrutivos (END)',
    'Monitoramento Estrutural',
    'Perícia e Laudo Técnico',
    'Recuperação e Reforço Estrutural',
    'Consultoria em Patologias',
  ];

  final List<String> _tiposAtivo = [
    'Edifícios Residenciais',
    'Edifícios Comerciais',
    'Pontes e Viadutos',
    'Galpões Industriais',
    'Prefeituras e Órgãos Públicos',
    'Outros',
  ];

  final Set<String> _selecionados = {};

  bool get isCliente =>
      (dadosUsuario['tipo'] as String? ?? '') == 'Cliente';

  List<String> get _itens =>
      isCliente ? _tiposAtivo : _servicosEngenheiro;

  String get _titulo => isCliente
      ? 'Que tipo de ativo você deseja monitorar?'
      : 'Quais serviços que você realiza?';

  Map<String, dynamic> get dadosUsuario => widget.dadosUsuario;

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StepProgressBar(currentStep: 1, totalSteps: 3),
            const SizedBox(height: 24),

            Text(
              _titulo,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                itemCount: _itens.length,
                itemBuilder: (context, index) {
                  final item = _itens[index];
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
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: selecionado
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : Colors.white,
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
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 14)
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
            const SizedBox(height: 16),

            Row(
              children: [
                TextButton(
                  onPressed: () => context.go(
                    '/empresa/onboarding',
                    extra: dadosUsuario,
                  ),
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
                    onPressed: _avancar,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _avancar() {
    if (_selecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Selecione pelo menos um item para continuar.')),
      );
      return;
    }
    // Sem a escolha de plano: a empresa começa no gratuito (ver
    // cadastro_freemium.dart).
    irParaCadastroDaEmpresa(context, {
      ...dadosUsuario,
      'servicos': _selecionados.toList(),
    });
  }
}