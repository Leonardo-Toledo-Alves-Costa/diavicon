import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  
  // ESTA É A FUNÇÃO "ENVIAR/FINALIZAR" QUE CONECTA COM O BANCO
  Future<void> _finalizarCadastroEmpresa(bool isTrial) async {
    final controller = ref.read(authControllerProvider.notifier);

    // Preparamos o Mapa Final unificando tudo
    final Map<String, dynamic> payloadFinal = {
      ...widget.dadosUsuario, // e-mail, senha, nome, sobrenome, telefone, rua, cep...
      'perfil': 'Empresa',
      'plano_escolhido': isTrial ? 'Trial' : 'Advanced',
      'nome_empresa': widget.dadosUsuario['nome_empresa'] ?? widget.dadosUsuario['nome'],
      'cnpj': widget.dadosUsuario['cnpj'] ?? '00.000.000/0001-00',
    };

    try {
      // 1. Chama o processo de registro (Auth + Endereço + Usuário)
      await controller.registrar(
        email: widget.dadosUsuario['email'],
        password: widget.dadosUsuario['senha'],
        dados: payloadFinal,
      );

      // 2. Se o await terminou sem erro, o cadastro no Supabase foi um sucesso!
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Empresa cadastrada com sucesso!'),
            backgroundColor: AppColors.primary,
          ),
        );
        
        // 3. ENTRADA NO APP: Mata o fluxo de cadastro e vai para a Home
        context.go('/projetos'); 
      }
    } catch (e) {
      if (mounted) {
        // Se der erro de "Rate Limit" (e-mail) ou Coluna Inexistente, aparece aqui
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao finalizar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Monitora o estado de loading do controller para desabilitar o botão enquanto salva
    final isLoading = ref.watch(authControllerProvider);

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
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Card Principal
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildCardHeader(),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Plano Advanced', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 8),
                                    const Text('Destrave o Potencial da Sua Empresa!', style: TextStyle(color: AppColors.textDark, fontSize: 20, fontWeight: FontWeight.w700, height: 1.1)),
                                    const SizedBox(height: 20),
                                    _buildFeatureItem('Acesso a 07 módulos de ensaio'),
                                    _buildFeatureItem('Gerenciamento de Equipes'),
                                    _buildFeatureItem('Relatórios Automáticos'),
                                    _buildFeatureItem('Acompanhamento de RDO\'s'),
                                    const Spacer(),
                                    _buildPriceSection(),
                                    const SizedBox(height: 14),
                                    _buildPrimaryButton(isLoading),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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

  // --- WIDGETS AUXILIARES DE INTERFACE ---

  Widget _buildCardHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: const Text('Melhor oferta', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildPriceSection() {
    return Center(
      child: Column(
        children: [
          RichText(
            text: const TextSpan(
              text: '2499,90',
              style: TextStyle(color: AppColors.primary, fontSize: 36, fontWeight: FontWeight.w900),
              children: [
                TextSpan(text: '/mês', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const Text('+ R\$ 67,92 por usuário adicional', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : () => _finalizarCadastroEmpresa(false),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: isLoading 
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text('Selecionar plano', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTrialButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton(
        onPressed: isLoading ? null : () => _finalizarCadastroEmpresa(true),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Experimente por 1 Mês Grátis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}