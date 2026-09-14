import 'package:diavicon/core/providers/supabase_provider.dart';
import 'package:diavicon/features/projetos/repositories/clientes_projeto_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final clientesProjetoRepositoryProvider = Provider<ClientesProjetoRepository>((
  ref,
) {
  return ClientesProjetoRepository(ref.watch(supabaseClientProvider));
});
