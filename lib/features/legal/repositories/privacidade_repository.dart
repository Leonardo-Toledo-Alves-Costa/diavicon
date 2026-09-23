import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/repositories/auth_operations_repository.dart';
import '../documentos_legais.dart';

class PreferenciasPrivacidade {
  /// Uso dos dados para aprimorar recursos de IA (consentimento, LGPD art. 7º I).
  final bool permiteUsoIa;

  /// Nome e foto visíveis para usuários de outras empresas.
  final bool perfilVisivel;

  const PreferenciasPrivacidade({required this.permiteUsoIa, required this.perfilVisivel});

  static const padrao = PreferenciasPrivacidade(permiteUsoIa: false, perfilVisivel: true);

  factory PreferenciasPrivacidade.fromMap(Map<String, dynamic> m) => PreferenciasPrivacidade(
        permiteUsoIa: m['permite_uso_ia'] == true,
        perfilVisivel: m['perfil_visivel'] != false,
      );
}

/// Operações de privacidade do titular (LGPD art. 18): consentimento,
/// preferências, exportação e exclusão da conta.
class PrivacidadeRepository {
  final SupabaseClient _db;
  PrivacidadeRepository(this._db);

  String get _plataforma => kIsWeb ? 'web' : 'app';

  /// true quando o usuário logado ainda não aceitou a versão vigente dos
  /// Termos ou da Política.
  Future<bool> consentimentoPendente() async {
    final r = await _db.rpc('consentimento_pendente', params: {
      'p_versao_termos': DocumentosLegais.versaoTermos,
      'p_versao_privacidade': DocumentosLegais.versaoPrivacidade,
    });
    return r == true;
  }

  Future<void> registrarConsentimento() async {
    await _db.rpc('registrar_consentimento', params: {
      'p_versao_termos': DocumentosLegais.versaoTermos,
      'p_versao_privacidade': DocumentosLegais.versaoPrivacidade,
      'p_plataforma': _plataforma,
    });
  }

  Future<PreferenciasPrivacidade> lerPreferencias() async {
    final r = await _db.rpc('minhas_preferencias_privacidade');
    final linha = r is List && r.isNotEmpty ? r.first : r;
    if (linha is Map) return PreferenciasPrivacidade.fromMap(Map<String, dynamic>.from(linha));
    return PreferenciasPrivacidade.padrao;
  }

  Future<void> salvarPreferencias({bool? permiteUsoIa, bool? perfilVisivel}) async {
    await _db.rpc('atualizar_preferencias_privacidade', params: {
      'p_permite_uso_ia': permiteUsoIa,
      'p_perfil_visivel': perfilVisivel,
    });
  }

  /// Cópia dos dados do titular (portabilidade), em JSON formatado.
  Future<String> exportarMeusDados() async {
    final r = await _db.rpc('exportar_meus_dados');
    return const JsonEncoder.withIndent('  ').convert(r);
  }

  /// Exclui a conta do usuário logado (edge function auth-operations).
  /// Para o administrador principal sem colegas, apaga também a empresa.
  Future<Map<String, dynamic>> excluirMinhaConta({required String confirmacao}) {
    return AuthOperationsRepository().execute('delete_own_account', {'confirmacao': confirmacao});
  }
}

final privacidadeRepositoryProvider = Provider<PrivacidadeRepository>((ref) {
  return PrivacidadeRepository(Supabase.instance.client);
});
