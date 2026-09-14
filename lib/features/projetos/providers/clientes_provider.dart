import 'package:diavicon/core/providers/supabase_provider.dart';
import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:diavicon/features/projetos/repositories/cliente_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'projeto_form_provider.dart';

final clienteRepositoryProvider = Provider<ClienteRepository>((ref) {
  return ClienteRepository(ref.watch(supabaseClientProvider));
});

final clientesListaProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final currentUser = ref.watch(currentUserProvider);
      final companyId = currentUser?.empresaId;
      if (companyId == null) return const [];

      return ref.watch(clienteRepositoryProvider).fetchClients(companyId);
    });

final dropdownClientesProvider =
    Provider.autoDispose<AsyncValue<List<Map<String, dynamic>>>>((ref) {
      final clients = ref.watch(clientesListaProvider);
      final draft = ref.watch(projetoFormProvider);

      return clients.whenData((databaseClients) {
        final result = List<Map<String, dynamic>>.from(databaseClients);
        if (draft.clienteId != null && draft.clienteNome != null) {
          final alreadyIncluded = result.any(
            (client) => client['id'] == draft.clienteId,
          );
          if (!alreadyIncluded) {
            result.add({'id': draft.clienteId, 'nome': draft.clienteNome});
          }
        }
        return result;
      });
    });

final buscarTodasEmpresasProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, searchTerm) {
      return ref.watch(clienteRepositoryProvider).searchCompanies(searchTerm);
    });
