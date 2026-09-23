import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthOperationsRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> execute(
    String action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        'auth-operations',
        body: {'action': action, ...payload},
      );

      final data = response.data;
      if (response.status < 200 || response.status >= 300) {
        throw Exception(_traduzir(_mensagem(data)) ?? 'Operação não autorizada.');
      }
      return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    } on FunctionException catch (e) {
      // O cliente do Supabase joga esta exceção em qualquer resposta de erro,
      // e o texto dela é técnico demais para a tela. Aqui sai a mensagem que
      // a própria função escreveu.
      final mensagem = _traduzir(_mensagem(e.details) ?? _mensagem(e.reasonPhrase));
      if (mensagem != null) throw Exception(mensagem);
      if (e.status == 404) {
        throw Exception(
          'A função auth-operations não respondeu a esta operação ($action). '
          'A versão publicada no Supabase pode estar desatualizada.',
        );
      }
      throw Exception('A operação falhou no servidor (código ${e.status}).');
    }
  }

  /// "Não conheço essa operação" só acontece quando a versão publicada no
  /// Supabase é mais antiga que o app. A mensagem crua não ajudava ninguém a
  /// descobrir isso.
  static String? _traduzir(String? mensagem) {
    if (mensagem == null) return null;
    final texto = mensagem.toLowerCase();
    if (texto.contains('desconhecida')) {
      return '$mensagem A função auth-operations publicada no Supabase está '
          'desatualizada — publique a versão nova para esta ação funcionar.';
    }
    return mensagem;
  }

  /// Texto de erro que a função devolve, venha como mapa ou como JSON em
  /// texto.
  static String? _mensagem(dynamic bruto) {
    if (bruto == null) return null;
    if (bruto is Map) {
      final erro = bruto['erro'] ?? bruto['error'] ?? bruto['message'];
      return erro?.toString();
    }
    if (bruto is String) {
      final texto = bruto.trim();
      if (texto.isEmpty) return null;
      try {
        final decodificado = jsonDecode(texto);
        if (decodificado is Map) return _mensagem(decodificado);
      } catch (_) {
        // Não era JSON: vale o texto puro.
      }
      return texto;
    }
    return null;
  }
}
