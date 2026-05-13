import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/empresa_model.dart';
import '../repositories/empresa_repository.dart';
import '../../auth/providers/auth_provider.dart';

final empresaRepositoryProvider = Provider((ref) => EmpresaRepository());

// O Estado da Empresa Atual
final empresaAtualProvider = StateProvider<EmpresaModel?>((ref) => null);

// O Controller que gerencia o estado de loading e a lógica de cadastro
final empresaControllerProvider = StateNotifierProvider<EmpresaController, bool>((ref) {
  return EmpresaController(ref);
});

class EmpresaController extends StateNotifier<bool> {
  final Ref _ref;

  EmpresaController(this._ref) : super(false);

  Future<void> cadastrarEmpresa(Map<String, dynamic> dados) async {
    state = true;
    try {
      // 1. Cria o usuário (Auth + Tabela Usuarios)
      await _ref.read(authControllerProvider.notifier).registrar(
            email: dados['email'],
            password: dados['senha'],
            dados: dados,
          );

      // 2. Recupera o ID do usuário recém-criado
      final usuario = _ref.read(currentUserProvider);
      if (usuario == null) {
        throw Exception('Usuário não autenticado após registro.');
      }

      // 3. Salva Empresa + Endereço e vincula ao ID do usuário no banco
      final empresaDados = dados['empresa'] as Map<String, dynamic>;
      final repo = _ref.read(empresaRepositoryProvider);
      
      final empresaId = await repo.salvarEmpresa(
        dadosEmpresa: {
          ...empresaDados,
          'plano_id': dados['plano_escolhido_id'],
          'tipo': dados['tipo'] ?? 'Profissional',
        },
        userId: usuario.id,
      );

      // 🚨 A SINCRONIZAÇÃO DE ESTADO ACONTECE AQUI:
      // Como o banco de dados foi atualizado com o empresa_id, precisamos
      // buscar o perfil de novo para o App "saber" que o usuário agora tem empresa.
      final authRepo = _ref.read(authRepositoryProvider);
      final perfilAtualizado = await authRepo.getUsuarioPerfil(usuario.id);

      if (perfilAtualizado != null) {
        // Atualiza o currentUserProvider com o perfil completo (contendo o empresa_id)
        _ref.read(currentUserProvider.notifier).setUser(perfilAtualizado);
      }

      // 4. Atualiza o estado da empresa atual no provider específico
      final empresa = await repo.getEmpresa(empresaId);
      if (empresa != null) {
        _ref.read(empresaAtualProvider.notifier).state = empresa;
      }
      
    } catch (e) {
      print("🚨 ERRO NO FLUXO DE CADASTRO: $e");
      rethrow;
    } finally {
      state = false;
    }
  }
}