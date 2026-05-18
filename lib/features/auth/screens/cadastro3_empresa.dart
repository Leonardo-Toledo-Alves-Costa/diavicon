import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diavicon/features/planos/model/planos_model.dart';
import 'package:diavicon/features/planos/providers/planos_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class Cadastro3Empresa extends ConsumerStatefulWidget {
  // Recebe o "pacotão" de dados acumulado de todas as telas anteriores (R0, R1, R2)
  final Map<String, dynamic> dadosUsuario;

  const Cadastro3Empresa({super.key, required this.dadosUsuario});

  @override
  ConsumerState<Cadastro3Empresa> createState() => _Cadastro3EmpresaState();
}

class _Cadastro3EmpresaState extends ConsumerState<Cadastro3Empresa> {
  int _planoPagina = 0;
  bool _planoInicializado = false;

  int _indicePlanoPadrao(List<PlanosModel> planos) {
    final indiceAdvanced = planos.indexWhere(
      (plano) => plano.nome.toLowerCase() == 'advanced',
    );

    if (indiceAdvanced != -1) {
      return indiceAdvanced;
    }

    var melhorIndex = 0;
    for (var i = 1; i < planos.length; i++) {
      if (planos[i].valor > planos[melhorIndex].valor) {
        melhorIndex = i;
      }
    }

    return melhorIndex;
  }

  PlanosModel _planoAtivo(List<PlanosModel> planos) {
    final index = _planoInicializado
        ? _planoPagina.clamp(0, planos.length - 1).toInt()
        : _indicePlanoPadrao(planos);
    return planos[index];
  }

  void _garantirPlanoInicial(List<PlanosModel> planos) {
    if (_planoInicializado || planos.isEmpty) {
      return;
    }

    _planoInicializado = true;
    final indicePadrao = _indicePlanoPadrao(planos);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (_planoPagina != indicePadrao) {
        setState(() => _planoPagina = indicePadrao);
      }
    });
  }

  void _irParaPlanoAnterior(int totalPlanos) {
    if (totalPlanos <= 1) {
      return;
    }

    setState(() {
      _planoPagina = _planoPagina == 0 ? totalPlanos - 1 : _planoPagina - 1;
    });
  }

  void _irParaProximoPlano(int totalPlanos) {
    if (totalPlanos <= 1) {
      return;
    }

    setState(() {
      _planoPagina = (_planoPagina + 1) % totalPlanos;
    });
  }

  void _finalizarCadastroEmpresa(PlanosModel plano) {
    final Map<String, dynamic> dadosComPlano = {
      ...widget.dadosUsuario,
      'perfil': 'Empresa',
      'plano': plano.nome,
      'plano_escolhido': plano.nome,
      'plano_escolhido_id': plano.id,
      'plano_escolhido_valor': plano.valor,
      'plano_escolhido_vigencia_dias': plano.vigenciaDias,
      'plano_escolhido_armazenamento_mb': plano.armazenamentoMb,
    };

    context.push('/empresa/cadastro', extra: dadosComPlano);
  }

  void _finalizarTrial() {
    final Map<String, dynamic> dadosComPlano = {
      ...widget.dadosUsuario,
      'perfil': 'Empresa',
      'plano': 'freemium',
      'plano_escolhido': 'freemium',
      'plano_escolhido_id': null,
    };

    context.push('/empresa/cadastro', extra: dadosComPlano);
  }

  String _formatarValor(double valor) {
    return valor.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _formatarVigencia(PlanosModel plano) {
    if (plano.vigenciaDias == 30) {
      return '/mês';
    }

    return '/${plano.vigenciaDias} dias';
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider);
    final planosAsync = ref.watch(planosListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(
            children: [
              Image.asset(
                'assets/images/logo_diavicon.png',
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 10),
              const SizedBox(height: 8),
              Expanded(
                child: planosAsync.when(
                  loading: _buildLoadingState,
                  error: (error, stackTrace) => _buildErrorState(error),
                  data: (planos) {
                    if (planos.isEmpty) {
                      return _buildEmptyState();
                    }

                    _garantirPlanoInicial(planos);
                    final planoAtivo = _planoAtivo(planos);

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildArrowButton(
                          icon: Icons.chevron_left_rounded,
                          onPressed: planos.length > 1
                              ? () => _irParaPlanoAnterior(planos.length)
                              : null,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: _buildPlanCard(
                              key: ValueKey(planoAtivo.id),
                              plano: planoAtivo,
                              isLoading: isLoading,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        _buildArrowButton(
                          icon: Icons.chevron_right_rounded,
                          onPressed: planos.length > 1
                              ? () => _irParaProximoPlano(planos.length)
                              : null,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildTrialButton(isLoading),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.primary,
            size: 44,
          ),
          const SizedBox(height: 10),
          const Text(
            'Não foi possível carregar os planos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => ref.invalidate(planosListProvider),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        'Nenhum plano disponível no momento.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textDark,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildArrowButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 20,
      child: Center(
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          iconSize: 30,
          color: Colors.grey.shade500,
          onPressed: onPressed,
          icon: Icon(icon),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required Key key,
    required PlanosModel plano,
    required bool isLoading,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildCardHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plano ${plano.nome}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    plano.descricao.isNotEmpty
                        ? plano.descricao
                        : 'Escolha o plano ideal para continuar o cadastro.',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildFeatureList(),
                  const SizedBox(height: 18),
                  Center(
                    child: RichText(
                      textAlign: TextAlign.end,
                      text: TextSpan(
                        text: _formatarValor(plano.valor),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                        children: [
                          TextSpan(
                            text: _formatarVigencia(plano),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: _buildPrimaryButton(isLoading, plano),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: const Text(
        'MELHOR OFERTA!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildFeatureList() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 8),
        ),
      ),
      padding: const EdgeInsets.only(left: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFeatureItem('Acesso a 07 módulos de ensaio'),
          _buildFeatureItem('Gerenciamento de Equipes'),
          _buildFeatureItem('Relatórios Automáticos'),
          _buildFeatureItem('Acompanhamento de RDO\'s'),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade700,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(bool isLoading, PlanosModel plano) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : () => _finalizarCadastroEmpresa(plano),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Selecionar plano',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildTrialButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton(
        onPressed: isLoading ? null : _finalizarTrial,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
        child: const Text(
          'Experimente por 1 Mês',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
