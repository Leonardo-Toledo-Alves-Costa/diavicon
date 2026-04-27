import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/empresa_model.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../repositories/empresa_repository.dart';
import '../../auth/providers/auth_provider.dart';

final empresaRepositoryProvider = Provider((ref) => EmpresaRepository());

final empresaControllerProvider =
    StateNotifierProvider<EmpresaController, bool>((ref) {
  return EmpresaController(ref);
});

final empresaAtualProvider = StateProvider<EmpresaModel?>((ref) => null);

class EmpresaController extends StateNotifier<bool> {
  final Ref _ref;

  EmpresaController(this._ref) : super(false);

  /// Cadastra o usuário + empresa de forma integrada.
  /// Chamado na última tela do fluxo (EmpresaCadastroScreen).
  Future<void> cadastrarEmpresa(Map<String, dynamic> dados) async {
    state = true;
    try {
      // 1. Registra o usuário no Supabase Auth e salva perfil
      await _ref.read(authControllerProvider.notifier).register(dados);

      // 2. Pega o ID do usuário recém-criado
      final usuario = _ref.read(currentUserProvider);
      if (usuario == null) throw Exception('Usuário não encontrado.');

      // 3. Salva a empresa e vincula ao usuário
      final repo = _ref.read(empresaRepositoryProvider);
      final empresaDados = dados['empresa'] as Map<String, dynamic>? ?? {};

      final empresaId = await repo.salvarEmpresa(
        dadosEmpresa: {
          ...empresaDados,
          'tipo': dados['tipo'] ?? 'Profissional',
        },
        userId: usuario.id,
      );

      // 4. Busca e armazena a empresa no provider
      final empresa = await repo.getEmpresa(empresaId);
      if (empresa != null) {
        _ref.read(empresaAtualProvider.notifier).state = empresa;
      }
    } catch (e) {
      rethrow;
    } finally {
      state = false;
    }
  }
}