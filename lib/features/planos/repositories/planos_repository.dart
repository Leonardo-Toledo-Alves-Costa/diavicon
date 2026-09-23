import 'package:diavicon/features/planos/model/planos_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlanosRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Catálogo de planos, do mais barato ao mais caro. Vem sempre da tabela
  /// `planos` — nada de nomes fixos no app, a equipe pode mudar os planos.
  Future<List<PlanosModel>> getPlanos() async {
    final data = await _supabase.from('planos').select().order('valor', ascending: true);
    return (data as List).map((map) => PlanosModel.fromMap(map)).toList();
  }

  /// Registra que a empresa do usuário quer mudar para [planoId]. Não troca o
  /// plano: enquanto não há cobrança online, a equipe Diavicon confere e ativa
  /// (RPC `solicitar_plano`, migration 20260919120000_regras_modulos_plano.sql).
  Future<void> solicitarPlano(String planoId) async {
    await _supabase.rpc('solicitar_plano', params: {'p_plano_id': planoId});
  }

  /// Plano pedido e ainda não ativado pela equipe (ou `null`).
  Future<String?> planoSolicitadoPendente() async {
    final data = await _supabase
        .from('empresa_plano_solicitacao')
        .select('plano_id')
        .eq('status', 'pendente')
        .order('criado_em', ascending: false)
        .limit(1)
        .maybeSingle();
    return data?['plano_id'] as String?;
  }
}
