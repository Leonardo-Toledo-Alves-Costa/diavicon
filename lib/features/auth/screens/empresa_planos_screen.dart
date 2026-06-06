import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../core/widgets/step_progress_bar.dart';

/// Tela de seleção de plano com carrossel.
/// Rota: /empresa/planos
class EmpresaPlanosScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> dadosUsuario;

  const EmpresaPlanosScreen({super.key, required this.dadosUsuario});

  @override
  ConsumerState<EmpresaPlanosScreen> createState() =>
      _EmpresaPlanosScreenState();
}

class _EmpresaPlanosScreenState extends ConsumerState<EmpresaPlanosScreen> {
  final PageController _pageController =
      PageController(viewportFraction: 0.88);
  int _planoPagina = 0;
  String? _planoSelecionado;

  bool get isCliente =>
      (widget.dadosUsuario['tipo'] as String? ?? '') == 'Cliente';

  static const _planosEmpresa = [
    _PlanoData(
      nome: 'Starter',
      preco: '139,90',
      foco: 'Micro-Empresa',
      features: [
        'Análises e gráficos',
        'Relatórios automáticos',
        'Realização de ensaios',
        'RDO e Gastos',
      ],
      destaque: false,
    ),
    _PlanoData(
      nome: 'Basic',
      preco: '390,90',
      foco: 'Pequena Empresa',
      features: [
        'Tudo do Starter',
        'Dashboard completo',
        'Plano de Ensaios',
      ],
      destaque: false,
    ),
    _PlanoData(
      nome: 'Professional',
      preco: '690,90',
      foco: 'Média Empresa',
      features: [
        'Relatórios Editáveis',
        'Catálogo de serviços',
        'Módulo de Monitoramento',
        'Módulo Finanças/gastos',
      ],
      destaque: true,
    ),
    _PlanoData(
      nome: 'Advanced',
      preco: '2.500,90',
      foco: 'Grandes Consultorias',
      features: [
        'Customizações de relatórios',
        'Customizações de dashboards',
        'Suporte dedicado',
      ],
      destaque: false,
    ),
  ];

  static const _planosProprietario = [
    _PlanoData(
      nome: 'Starter',
      preco: '79,90',
      foco: 'Condomínios e pequenas empresas',
      features: [
        'Dashboards básicos',
        'Relatórios em modo leitura',
        'Histórico da estrutura',
        'Visualização de RDOs',
      ],
      destaque: false,
    ),
    _PlanoData(
      nome: 'Pro',
      preco: '139,90',
      foco: 'Indústrias e condomínios médios',
      features: [
        'Tudo do Starter',
        'Setores internos',
        'Criação de planos de ensaio',
      ],
      destaque: false,
    ),
    _PlanoData(
      nome: 'Enterprise',
      preco: '249,90',
      foco: 'Grandes indústrias e prefeituras',
      features: [
        'Módulo de Gerenciamento',
        'Módulo Finanças',
        'Inspeção Visual preliminar',
        'Multiempresa completo',
      ],
      destaque: true,
    ),
  ];

  List<_PlanoData> get _planos =>
      isCliente ? _planosProprietario : _planosEmpresa;

  @override
  void initState() {
    super.initState();
    final idx = _planos.indexWhere((p) => p.destaque);
    if (idx != -1) _planoPagina = idx;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 30, 28, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                StepProgressBar(currentStep: 2, totalSteps: 3),
                SizedBox(height: 20),
                Text(
                  'Escolha seu plano',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Você pode mudar de plano a qualquer momento.',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.greyMedium),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _planos.length,
              onPageChanged: (i) => setState(() => _planoPagina = i),
              itemBuilder: (context, index) {
                final plano = _planos[index];
                return _PlanoCard(
                  plano: plano,
                  isAtivo: index == _planoPagina,
                  selecionado: _planoSelecionado == plano.nome,
                  onSelecionar: () =>
                      setState(() => _planoSelecionado = plano.nome),
                );
              },
            ),
          ),

          // Indicador de páginas
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_planos.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: index == _planoPagina ? 20 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: index == _planoPagina
                        ? AppColors.primary
                        : AppColors.greyVeryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => context.go(
                    '/empresa/servicos',
                    extra: widget.dadosUsuario,
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
          ),
        ],
      ),
    );
  }

  void _avancar() {
    final plano = _planoSelecionado ?? _planos[_planoPagina].nome;
    context.go('/empresa/cadastro', extra: {
      ...widget.dadosUsuario,
      'plano': plano,
    });
  }
}

// ─── Card do plano ────────────────────────────────────────────────────────────
class _PlanoCard extends StatelessWidget {
  final _PlanoData plano;
  final bool isAtivo;
  final bool selecionado;
  final VoidCallback onSelecionar;

  const _PlanoCard({
    required this.plano,
    required this.isAtivo,
    required this.selecionado,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isAtivo ? 1.0 : 0.94,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: plano.destaque ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (plano.destaque) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'MELHOR OFERTA!',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Text(
                'Plano ${plano.nome}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color:
                      plano.destaque ? Colors.white : AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                plano.foco,
                style: TextStyle(
                  fontSize: 12,
                  color: plano.destaque
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppColors.greyMedium,
                ),
              ),
              const SizedBox(height: 12),

              ...plano.features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: plano.destaque
                              ? Colors.white
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 13,
                              color: plano.destaque
                                  ? Colors.white
                                  : AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),

              const Spacer(),

              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'R\$ ${plano.preco}',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: plano.destaque
                            ? Colors.white
                            : AppColors.primary,
                      ),
                    ),
                    TextSpan(
                      text: '/mês',
                      style: TextStyle(
                        fontSize: 14,
                        color: plano.destaque
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppColors.greyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: plano.destaque
                        ? Colors.white
                        : AppColors.primary,
                    foregroundColor: plano.destaque
                        ? AppColors.primary
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: onSelecionar,
                  child: const Text(
                    'Selecionar plano',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Center(
                child: Text(
                  'Experimente por 1 Mês',
                  style: TextStyle(
                    fontSize: 12,
                    color: plano.destaque
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppColors.primary,
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

// ─── Model local ──────────────────────────────────────────────────────────────
class _PlanoData {
  final String nome;
  final String preco;
  final String foco;
  final List<String> features;
  final bool destaque;

  const _PlanoData({
    required this.nome,
    required this.preco,
    required this.foco,
    required this.features,
    required this.destaque,
  });
}