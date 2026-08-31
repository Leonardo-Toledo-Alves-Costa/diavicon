import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'empresa_plano_atual_provider.dart';

/// Quantos "tokens" de estrutura monitorada a empresa tem contratado e
/// quantos já estão em uso.
///
/// - [limite]: vem de `empresa_plano_assinatura.tokens_estrutura` quando a
///   empresa já tem uma assinatura própria ativa (pode incluir adicionais
///   contratados além do plano base); se não houver linha de assinatura
///   ainda, cai pro `tokens_estrutura` padrão do plano base
///   (`empresaPlanoAtualProvider`).
/// - [consumido]: contado AO VIVO — quantidade de `estruturas` com
///   `monitorada = true` onde a empresa é a gestora. Não depende de nenhum
///   contador gravado em `empresa_plano_consumo` (evita dessincronizar).
typedef TokensEstruturaInfo = ({int limite, int consumido, int disponivel});

final tokensEstruturaInfoProvider = FutureProvider.autoDispose<TokensEstruturaInfo>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return (limite: 0, consumido: 0, disponivel: 0);

  final usuarioResp = await supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
  final empresaId = usuarioResp?['empresa_id'] as String?;
  if (empresaId == null) return (limite: 0, consumido: 0, disponivel: 0);

  int limite;
  final assinaturaResp = await supabase
      .from('empresa_plano_assinatura')
      .select('tokens_estrutura')
      .eq('empresa_id', empresaId)
      .eq('status', 'ativo')
      .order('criado_em', ascending: false)
      .limit(1)
      .maybeSingle();

  if (assinaturaResp != null && assinaturaResp['tokens_estrutura'] != null) {
    limite = (assinaturaResp['tokens_estrutura'] as num).toInt();
  } else {
    final plano = await ref.watch(empresaPlanoAtualProvider.future);
    limite = plano.tokensEstrutura ?? 0;
  }

  final consumidoResp = await supabase
      .from('estruturas')
      .select('id')
      .eq('empresa_gestora_id', empresaId)
      .eq('monitorada', true)
      .count(CountOption.exact);
  final consumido = consumidoResp.count;

  return (limite: limite, consumido: consumido, disponivel: consumido < limite ? limite - consumido : 0);
});
