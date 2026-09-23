import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

/// Leva o cadastro de empresa direto para "Cadastre sua empresa", no plano
/// gratuito — sem a tela de escolha de plano.
///
/// A escolha de plano não chegava a lugar nenhum: o servidor ignora qualquer
/// plano enviado pelo app e sempre abre a empresa no plano padrão da tabela
/// `planos` (ver `createCompany` em supabase/functions/auth-operations). A
/// tela só fazia a pessoa escolher algo que não valia. A troca de plano
/// acontece depois, em Meu Plano, pela equipe Diavicon.
///
/// O rótulo "freemium" abaixo só marca o rascunho do cadastro; quem decide o
/// plano de verdade continua sendo o servidor.
void irParaCadastroDaEmpresa(BuildContext context, Map<String, dynamic> dados) {
  final dadosDoCadastro = <String, dynamic>{
    ...dados,
    'perfil': 'Empresa',
    'plano': 'freemium',
    'plano_escolhido': 'freemium',
    'plano_escolhido_id': null,
    'plano_escolhido_features': null,
  };

  // O rascunho fica guardado para a tela de cadastro sobreviver a um
  // recarregamento da página (web) — é o que a rota lê primeiro.
  ProviderScope.containerOf(context, listen: false)
      .read(rascunhoCadastroProvider.notifier)
      .state = dadosDoCadastro;
  context.go('/empresa/cadastro', extra: dadosDoCadastro);
}
