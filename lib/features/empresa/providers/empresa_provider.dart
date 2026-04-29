import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/empresa_model.dart';
import '../repositories/empresa_repository.dart';

final empresaRepositoryProvider = Provider((ref) => EmpresaRepository());

// O Estado da Empresa Atual (para usar no resto do app via ref.watch)
final empresaAtualProvider = StateProvider<EmpresaModel?>((ref) => null);

// O Controller que gerencia o estado de loading (bool) e a lógica de cadastro
final empresaControllerProvider =
    StateNotifierProvider<EmpresaController, bool>((ref) {
      return EmpresaController(ref);
    });

class EmpresaController extends StateNotifier<bool> {
  final Ref _ref;

  EmpresaController(this._ref) : super(false);


  Future<void> cadastrarEmpresa(Map<String, dynamic> dados) async {
    state = true;
    try {
      // Cria o usuário (Auth + Tabela Usuarios)
      await _ref
          .read(authControllerProvider.notifier)
          .registrar(
            email: dados['email'],
            password: dados['senha'],
            dados: dados,
          );

      // Recupera o ID do usuário recém-criado
      final usuario = _ref.read(currentUserProvider);
      if (usuario == null)
        throw Exception('Usuário não autenticado após registro.');

      // Pega o mapa da empresa (onde estão CNPJ, Rua, etc)
      final empresaDados = dados['empresa'] as Map<String, dynamic>;

      // Salva Empresa + Endereço e ATUALIZA o empresa_id no usuário
      final repo = _ref.read(empresaRepositoryProvider);
      final empresaId = await repo.salvarEmpresa(
        dadosEmpresa: {
          ...empresaDados,
          'plano_id': dados['plano_escolhido_id'], // Vem da tela de planos
          'tipo': dados['tipo'] ?? 'Profissional',
        },
        userId: usuario.id,
      );

      // Atualiza o estado global
      final empresa = await repo.getEmpresa(empresaId);
      if (empresa != null) {
        _ref.read(empresaAtualProvider.notifier).state = empresa;
      }
    } catch (e) {
      print("ERRO NO FLUXO: $e");
      rethrow;
    } finally {
      state = false;
    }
  }
}
