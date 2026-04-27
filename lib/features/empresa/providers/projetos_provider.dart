import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart'; // Importa para sabermos quem está logado
import '../../projetos/models/projeto_model.dart';
import '../repositories/projeto_repository.dart';

// Provider do Repositório
final projetoRepositoryProvider = Provider((ref) => ProjetoRepository());

// Provider que busca e guarda a lista de projetos
final projetosProvider = FutureProvider<List<ProjetoModel>>((ref) async {
  // 1. Pega o usuário que acabou de fazer login
  final usuario = ref.watch(currentUserProvider);

  // 2. Se não tem usuário ou ele não tem empresa, retorna lista vazia
  if (usuario == null || usuario.empresaId == null) {
    return [];
  }

  // 3. Se está tudo certo, chama o repositório
  final repo = ref.watch(projetoRepositoryProvider);
  return await repo.getProjetosPorEmpresa(usuario.empresaId!);
});