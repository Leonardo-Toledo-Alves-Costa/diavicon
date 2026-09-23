import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/gasto_model.dart';
import '../repositories/gastos_repository.dart';

// Sem retry automático. O padrão do Riverpod 3 repete uma consulta que falhou
// até 10 vezes (≈38s no total) e, durante as tentativas, o estado fica
// AsyncLoading — a tela mostrava um spinner "infinito" em vez do erro.
Duration? _semRetry(int tentativa, Object erro) => null;

/// Empresa do usuário logado. Sem empresa, não há gastos a mostrar (e as
/// consultas não podem rodar sem o filtro de empresa — ver GastosRepository).
final _empresaDoUsuarioProvider = Provider<String?>((ref) => ref.watch(currentUserProvider.select((u) => u?.empresaId)));

/// Admin da empresa (gestor principal ou admin): vê gastos de terceiros e a
/// análise geral.
final ehAdminEmpresaProvider = Provider<bool>((ref) {
  final u = ref.watch(currentUserProvider);
  return u != null && u.ativo == true && (u.isAdminEmpresa == true || u.isAdmin == true);
});

final meusGastosProvider = FutureProvider.autoDispose<List<GastoModel>>(
  (ref) async {
    final empresaId = ref.watch(_empresaDoUsuarioProvider);
    if (empresaId == null) return [];
    return ref.watch(gastosRepositoryProvider).listarMeusGastos(empresaId: empresaId);
  },
  retry: _semRetry,
);

/// Gastos de um projeto: admin vê os da empresa inteira; os demais, só os seus.
final gastosDoProjetoProvider = FutureProvider.autoDispose.family<List<GastoModel>, String>(
  (ref, projetoId) async {
    final empresaId = ref.watch(_empresaDoUsuarioProvider);
    if (empresaId == null) return [];
    return ref.watch(gastosRepositoryProvider).listarDoProjeto(
          projetoId: projetoId,
          empresaId: empresaId,
          admin: ref.watch(ehAdminEmpresaProvider),
        );
  },
  retry: _semRetry,
);

typedef FiltroAnaliseGastos = ({String empresaId, DateTime inicio, DateTime fim});

final gastosDaEmpresaProvider = FutureProvider.autoDispose.family<List<GastoModel>, FiltroAnaliseGastos>(
  (ref, f) async {
    // A tela já é só de admin; a checagem aqui garante que ninguém mais
    // consiga puxar a empresa inteira.
    if (!ref.watch(ehAdminEmpresaProvider)) return [];
    if (ref.watch(_empresaDoUsuarioProvider) != f.empresaId) return [];
    return ref.watch(gastosRepositoryProvider).listarDaEmpresa(empresaId: f.empresaId, inicio: f.inicio, fim: f.fim);
  },
  retry: _semRetry,
);

final categoriasGastoProvider = FutureProvider.autoDispose<List<CategoriaGastoModel>>(
  (ref) async {
    final empresaId = ref.watch(_empresaDoUsuarioProvider);
    if (empresaId == null) return [];
    return ref.watch(gastosRepositoryProvider).listarCategorias(empresaId: empresaId);
  },
  retry: _semRetry,
);

/// Recarrega todas as listas depois de criar/editar/excluir um gasto.
void invalidarGastos(WidgetRef ref) {
  ref.invalidate(meusGastosProvider);
  ref.invalidate(gastosDoProjetoProvider);
  ref.invalidate(gastosDaEmpresaProvider);
}
