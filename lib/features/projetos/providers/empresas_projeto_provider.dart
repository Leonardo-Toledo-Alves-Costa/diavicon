import 'package:diavicon/core/providers/supabase_provider.dart';
import 'package:diavicon/features/projetos/repositories/empresas_projeto_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final empresasProjetoRepositoryProvider = Provider<EmpresasProjetoRepository>((
  ref,
) {
  return EmpresasProjetoRepository(ref.watch(supabaseClientProvider));
});

final empresasVinculadasProjetoProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, projectId) {
      return ref
          .watch(empresasProjetoRepositoryProvider)
          .watchLinkedCompanies(projectId);
    });

final minhaEmpresaProvider = FutureProvider.autoDispose<Map<String, dynamic>?>(
  (ref) {
    return ref.watch(empresasProjetoRepositoryProvider).fetchCurrentCompany();
  },
);

final projetoEmpresasIntegrantesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, projectId) {
      return ref
          .watch(empresasProjetoRepositoryProvider)
          .fetchAcceptedCompanies(projectId);
    });

final buscarEmpresaPorCnpjProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, filter) {
      return ref.watch(empresasProjetoRepositoryProvider).findCompany(filter);
    });
