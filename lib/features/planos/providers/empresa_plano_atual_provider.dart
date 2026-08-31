import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/planos_model.dart';

/// Plano atualmente contratado pela empresa do usuário logado. Segue o
/// mesmo caminho já usado em `planLimitByProjectProvider`
/// (equipe_provider.dart): `usuarios -> empresas -> planos`. Se a empresa
/// não tiver `plano_id` definido (estado alcançável no cadastro
/// "freemium"), cai no fallback `PlanosModel.semPlano()` — tudo travado,
/// em vez de liberar tudo ou quebrar a tela.
final empresaPlanoAtualProvider = FutureProvider.autoDispose<PlanosModel>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return PlanosModel.semPlano();

  final userResp = await supabase
      .from('usuarios')
      .select('empresa_id, empresas(planos(*))')
      .eq('id', userId)
      .maybeSingle();

  final empresasData = userResp?['empresas'];
  if (empresasData is! Map) return PlanosModel.semPlano();

  final planosData = empresasData['planos'];
  if (planosData is! Map) return PlanosModel.semPlano();

  return PlanosModel.fromMap(Map<String, dynamic>.from(planosData));
});
