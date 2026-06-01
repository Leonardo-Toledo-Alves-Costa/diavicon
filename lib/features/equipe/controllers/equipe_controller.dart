import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final equipeControllerProvider = Provider<EquipeController>((ref) {
  return EquipeController();
});

class EquipeController {
  final _supabase = Supabase.instance.client;

  Future<void> convidarFuncionarioInterno({
    required String nome,
    required String sobrenome,
    required String email,
    required String cargo,
    String? setorId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Sessão expirada. Faça login novamente.');
    }

    // Descobre o ID da empresa do Gestor que está logado agora
    final userRes = await _supabase
        .from('usuarios')
        .select('empresa_id')
        .eq('id', userId)
        .maybeSingle();
        
    final empresaId = userRes?['empresa_id'];
    if (empresaId == null) {
      throw Exception('Erro de integridade: Sua conta não está vinculada a uma empresa.');
    }

    // 2.Dispara a Edge Function passando os dados empacotados
    try {
      final response = await _supabase.functions.invoke(
        'convidar-funcionario', // Tem que ser o nome exato da função que subimos
        body: {
          'email': email.trim(),
          'nome': nome.trim(),
          'sobrenome': sobrenome.trim(),
          'cargo': cargo.trim(),
          'setor_id': setorId,
          'empresa_id': empresaId,
        },
      );

      // O Supabase retorna status 200 quando a Edge Function roda com sucesso
      if (response.status != 200) {
        throw Exception('O servidor recusou o convite. Verifique se o e-mail já existe.');
      }
      
    } catch (e) {
      // Captura erros de rede ou falhas na própria Edge Function
      throw Exception('Falha ao processar o convite: $e');
    }
  }
}