import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/empresa_model.dart';
import '../repositories/empresa_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/repositories/auth_operations_repository.dart';

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

  Future<bool> cadastrarEmpresa(Map<String, dynamic> dados) async {
    state = true;
    //ATIVA O ESCUDO DO ROTEADOR: O App_Router agora vai ignorar qualquer mudança
    _ref.read(bloqueioDeRotaProvider.notifier).state = true;
    try {
      //  PROTEÇÃO 1: Conversão segura (Safe Cast) dos dados de Autenticação.
      // Se a chave vier nula ou com nome diferente (ex: 'password' em vez de 'senha'),
      // o '.toString() ?? ''' impede o erro "Null is not a subtype of String".
      final emailSeguro = dados['email']?.toString() ?? '';
      final senhaSegura = (dados['senha'] ?? dados['password'])?.toString() ?? '';

      //  Cria o usuário (Auth + Tabela Usuarios)
      final cadastroConfirmado = await _ref.read(authControllerProvider.notifier).registrar(
            email: emailSeguro,
            password: senhaSegura,
            dados: dados,
          );
      if (!cadastroConfirmado) return false;

      //  Recupera o ID do usuário recém-criado
      final usuario = _ref.read(currentUserProvider);
      final usuarioId = usuario?.id ?? Supabase.instance.client.auth.currentUser?.id;
      if (usuarioId == null) {
        throw Exception('Usuário não autenticado após registro.');
      }

      //  Salva Empresa + Endereço e vincula ao ID do usuário no banco
      //  PROTEÇÃO 2: Garante que os dados da empresa não venham nulos
      final empresaDados = (dados['empresa'] as Map<String, dynamic>?) ?? {};
      final repo = _ref.read(empresaRepositoryProvider);
      
      final empresaId = await repo.salvarEmpresa(
        dadosEmpresa: {
          ...empresaDados,
          'nome_pessoa': dados['nome'],
          'sobrenome': dados['sobrenome'],
          'telefone': dados['telefone'],
          'perfil': dados['perfil'],
          'escolaridade': dados['escolaridade'],
          'formacao': dados['formacao'],
          'foto_usuario_path': dados['fotoPath'],
          // Mantém a possibilidade de ser null, mas protege a tipagem
          'tipo': dados['tipo']?.toString() ?? 'Profissional',
        },
        dadosUsuario: dados,
        userId: usuarioId,
      );

      
      final authRepo = _ref.read(authRepositoryProvider);
      final perfilAtualizado = await authRepo.getUsuarioPerfil(usuarioId);

      if (perfilAtualizado != null) {
        // Atualiza o currentUserProvider com o perfil completo (contendo o empresa_id)
        _ref.read(currentUserProvider.notifier).setUser(perfilAtualizado);
      }

      // 4. Atualiza o estado da empresa atual no provider específico
      final empresa = await repo.getEmpresa(empresaId);
      if (empresa != null) {
        _ref.read(empresaAtualProvider.notifier).state = empresa;
      }
      return true;
      
    } catch (e) {
      print("🚨 ERRO NO FLUXO DE CADASTRO: $e");
      rethrow;
    } finally {
      state = false;
      _ref.read(bloqueioDeRotaProvider.notifier).state = false;
    }
  }

  Future<void> carregarEmpresaAtual(String empresaId) async {
    final repo = _ref.read(empresaRepositoryProvider);
    final empresa = await repo.getEmpresa(empresaId);
    _ref.read(empresaAtualProvider.notifier).state = empresa;
  }
  
}

final colaboradoresEmpresaProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, empresaId) async {
  final empresaAtualId = ref.watch(currentUserProvider)?.empresaId;
  if (empresaAtualId == null || empresaAtualId != empresaId) {
    return [];
  }

  final data = await AuthOperationsRepository().execute(
    'list_company_colleagues',
    const {},
  );
  final colegas = data['colegas'];
  if (colegas is! List) {
    throw Exception('Resposta inválida ao carregar colaboradores.');
  }

  return colegas
      .whereType<Map>()
      .map((colaborador) => Map<String, dynamic>.from(colaborador))
      .toList();
});
