import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ponto único de injeção do cliente Supabase.
///
/// Repositórios devem depender deste provider em vez de acessar o singleton
/// diretamente. Isso mantém a camada de estado testável e sem I/O próprio.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
