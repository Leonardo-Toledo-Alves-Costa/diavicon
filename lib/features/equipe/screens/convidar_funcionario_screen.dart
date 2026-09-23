import 'dart:convert';

import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:diavicon/core/security/entrada_segura.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_text_field.dart'; 
import '../../../../core/widgets/custom_button.dart';

// 🔥 IMPORTANTE: Ajuste o caminho abaixo para apontar para o seu equipe_provider onde está o planLimitByProjectProvider
import '../../equipe/providers/equipe_provider.dart';
import '../../empresa/providers/colaboradores_provider.dart';
import '../../../core/widgets/aviso_topo.dart';

class ConvidarFuncionarioScreen extends ConsumerStatefulWidget {
  // Nulo = convite de empresa (sem vínculo com projeto). A Edge Function
  // `convidar-funcionario` trata a ausência dessa chave como "sem projeto" —
  // só passe um valor aqui quando o convite realmente for feito de dentro
  // de um projeto (ver `edit_team_body.dart`).
  final String? projetoId;

  const ConvidarFuncionarioScreen({super.key, this.projetoId});

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

      final email = _emailController.text.trim();
      final response = await Supabase.instance.client.functions.invoke(
        'convidar-funcionario',
        body: {
          'email': email,
          'nome': _nomeController.text.trim(),
          'sobrenome': _sobrenomeController.text.trim(),
          'cargo': _cargoController.text.trim(),
          'empresa_id': usuarioAtual.empresaId,
          if (widget.projetoId != null) 'projeto_id': widget.projetoId,
        },
      );

      final data = response.data;
      if (response.status < 200 || response.status >= 300) {
        throw Exception(_mensagemErro(data) ?? 'Erro desconhecido ao convidar.');
      }

      if (!mounted) return;

      // Invalida o cache do limite do plano pra forçar a atualização
      // imediata do gráfico — tem DOIS sistemas de contagem de vagas
      // separados que não se invalidam entre si (planLimitByProjectProvider,
      // usado só aqui, e equipeEmpresaProvider/limitePlanoProvider, usados
      // na tela de Colaboradores da Empresa): sem invalidar os dois, quem
      // convida por aqui e volta pra "Colaboradores" vê a contagem antiga
      // até reabrir a tela do zero.
      ref.invalidate(planLimitByProjectProvider(widget.projetoId ?? ''));
      final empresaId = usuarioAtual.empresaId;
      if (empresaId != null) {
        ref.invalidate(equipeEmpresaProvider((empresaId: empresaId)));
        ref.invalidate(limitePlanoProvider((empresaId: empresaId)));
      }

      final emailEnviado =
          data is Map && data.containsKey('emailEnviado') ? data['emailEnviado'] == true : null;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _DialogoConviteCriado(
          email: email,
          senha: data is Map ? '${data['senhaProvisoria']}' : '',
          // A função tenta mandar a senha por e-mail depois de criar a conta.
          // Se o envio falhar, o convite continua valendo: a senha aparece
          // aqui do mesmo jeito, junto com o motivo da falha. Nulo quer dizer
          // que a função publicada ainda é a antiga, que não manda e-mail —
          // nesse caso a janela não fala de e-mail nenhum.
          emailEnviado: emailEnviado,
          emailErro: data is Map ? data['emailErro']?.toString() : null,
        ),
      );

      // Além da faixa dentro da janela, o resultado do e-mail aparece no topo
      // da tela — a faixa sozinha passava despercebida.
      if (emailEnviado == true) {
        mostrarAviso(context, 'Senha enviada por e-mail para $email.', tipo: TipoAviso.sucesso);
      } else if (emailEnviado == false) {
        mostrarAviso(
          context,
          'O acesso foi criado, mas o e-mail não saiu. Passe a senha por outro caminho.',
          tipo: TipoAviso.erro,
          duracao: const Duration(seconds: 6),
        );
      }
    } on FunctionException catch (e) {
      // O cliente do Supabase joga esta exceção em qualquer resposta de erro,
      // e o texto dela é técnico demais para a tela. Aqui sai a mensagem que
      // a própria função escreveu.
      if (!mounted) return;
      final mensagem = _mensagemErro(e.details) ??
          _mensagemErro(e.reasonPhrase) ??
          'O convite falhou no servidor (código ${e.status}).';
      mostrarAviso(context, mensagem, tipo: TipoAviso.erro, duracao: const Duration(seconds: 6));
    } on PostgrestException catch (e) {
      if (!mounted) return;
      mostrarAviso(context, 'Erro no banco de dados: ${e.message}', tipo: TipoAviso.erro);
    } catch (e) {
      if (!mounted) return;
      mostrarAviso(context, e.toString().replaceAll('Exception: ', ''), tipo: TipoAviso.erro);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Texto de erro que a função devolve, venha como mapa ou como JSON em
  /// texto.
  static String? _mensagemErro(dynamic bruto) {
    if (bruto == null) return null;
    if (bruto is Map) return (bruto['erro'] ?? bruto['error'] ?? bruto['message'])?.toString();
    if (bruto is String) {
      final texto = bruto.trim();
      if (texto.isEmpty) return null;
      try {
        final decodificado = jsonDecode(texto);
        if (decodificado is Map) return _mensagemErro(decodificado);
      } catch (_) {
        // Não era JSON: vale o texto puro.
      }
      return texto;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Escuta o limite do plano da empresa (o provider ignora o projetoId
    // internamente — é usado só como chave de cache; ver `equipe_provider.dart`).
    final planLimitAsync = ref.watch(planLimitByProjectProvider(widget.projetoId ?? ''));
    final int cadastrados = planLimitAsync.value?.cadastrados ?? 0;
    final int permitidos = planLimitAsync.value?.permitidos ?? 0;
    final bool isPlanoEsgotado = permitidos > 0 && cadastrados >= permitidos;

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
                
                // ========================================================
                // COMPONENTE GRÁFICO: Mini Dashboard Acoplado
                // ========================================================
                planLimitAsync.when(
                  data: (info) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _MiniDashboardCard(
                      cadastrados: info.cadastrados, 
                      permitidos: info.permitidos
                    ),
                  ),
                  loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
                  error: (e, __) => Text('Falha ao processar limites: $e', style: const TextStyle(color: Colors.red)),
                ),

                const Text(
                  'Dados do Funcionário',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                Text(
                  'O acesso é criado na hora e a senha provisória vai por e-mail para ele. '
                  'Ela também aparece aqui, caso você precise passar por outro caminho.',
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
                    if (!EntradaSegura.emailValido(val)) return 'Digite um e-mail válido';
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

                // ========================================================
                // BOTÃO COM TRAVA DE LIMITE DO PLANO
                // ========================================================
                _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : CustomButton(
                        text: isPlanoEsgotado ? 'Limite do plano excedido' : 'Enviar Convite',
                        // Se esgotou, anula a função (desabilita o botão)
                        onPressed: isPlanoEsgotado ? null : _enviarConvite,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========================================================
// ESTRUTURA MODULAR: Mini Dashboard de Consumo
// ========================================================
class _MiniDashboardCard extends StatelessWidget {
  final int cadastrados;
  final int permitidos;

  const _MiniDashboardCard({required this.cadastrados, required this.permitidos});

  @override
  Widget build(BuildContext context) {
    final double progresso = permitidos == 0 ? 0 : (cadastrados / permitidos).clamp(0.0, 1.0);
    final Color progressColor = cadastrados >= permitidos && permitidos > 0 ? Colors.redAccent : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03), 
            blurRadius: 8, 
            offset: const Offset(0, 3)
          )
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            height: 48,
            width: 48,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progresso,
                  strokeWidth: 5,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    '$cadastrados/${permitidos == 0 ? '∞' : permitidos}', 
                    style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold)
                  )
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Uso do plano na empresa gestora', 
                  style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF333333))
                ),
                const SizedBox(height: 2),
                Text(
                  '$cadastrados de ${permitidos == 0 ? 'ilimitados' : permitidos} usuários cadastrados', 
                  style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// Confirmação do convite: mostra a senha provisória e conta se o e-mail
/// com ela saiu ou não.
class _DialogoConviteCriado extends StatelessWidget {
  final String email;
  final String senha;
  final bool? emailEnviado;
  final String? emailErro;

  const _DialogoConviteCriado({
    required this.email,
    required this.senha,
    required this.emailEnviado,
    this.emailErro,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Acesso criado', style: TextStyle(fontWeight: FontWeight.bold)),
      // Rolagem porque o aviso de falha do e-mail pode trazer um texto longo,
      // e em tela de celular a janela não teria altura para ele.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Esta é a senha provisória do funcionário:'),
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
                senha,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ),
            if (emailEnviado != null) ...[
              const SizedBox(height: 12),
              _AvisoEmail(email: email, enviado: emailEnviado!, erro: emailErro),
            ],
            const SizedBox(height: 12),
            const Text(
              'Ele precisará trocar essa senha no primeiro login.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      // Botões de verdade, um embaixo do outro: em janela estreita os dois
      // lado a lado ficavam apertados e pareciam links.
      actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: senha));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Senha copiada.')),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textDark,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar senha', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Entendi', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

/// Linha que diz se a senha chegou ao e-mail — e, quando não chegou, por quê.
class _AvisoEmail extends StatelessWidget {
  final String email;
  final bool enviado;
  final String? erro;

  const _AvisoEmail({required this.email, required this.enviado, this.erro});

  @override
  Widget build(BuildContext context) {
    final cor = enviado ? const Color(0xFF1B7F4B) : const Color(0xFFA85A00);
    final fundo = enviado ? const Color(0xFFE8F5EE) : const Color(0xFFFDF2E3);
    final texto = enviado
        ? 'Enviamos a senha para $email.'
        : 'Não conseguimos enviar o e-mail para $email — passe a senha por outro caminho.'
            '${erro == null || erro!.isEmpty ? '' : '\n\n$erro'}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            enviado ? Icons.mark_email_read_outlined : Icons.report_gmailerrorred_outlined,
            size: 18,
            color: cor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto, style: TextStyle(fontSize: 12.5, height: 1.4, color: cor)),
          ),
        ],
      ),
    );
  }
}
