import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/repositories/auth_operations_repository.dart';

// ==========================================
// 1. MODELO DE DADOS
// ==========================================
class ColaboradorModel {
  final String id;
  final String nome;
  final String cargo;
  final String email;
  final String? fotoUrl;
  final bool isMaster; 
  final bool isAdmin;  
  final String status; 

  ColaboradorModel({
    required this.id,
    required this.nome,
    required this.cargo,
    required this.email,
    this.fotoUrl,
    required this.isMaster,
    required this.isAdmin,
    required this.status,
  });

  factory ColaboradorModel.fromMap(Map<String, dynamic> map) {
    final statusRecebido = map['status']?.toString();
    final ativo = map['ativo'] == true;
    final nomeAusente = map['nome'] == null || map['nome'].toString().isEmpty;
    final statusAtual = statusRecebido == 'ativo' ||
            statusRecebido == 'inativo' ||
            statusRecebido == 'convidado'
        ? statusRecebido!
        : (nomeAusente ? 'convidado' : (ativo ? 'ativo' : 'inativo'));

    final nomeCompleto = '${map['nome'] ?? ''} ${map['sobrenome'] ?? ''}'.trim();

    return ColaboradorModel(
      id: map['id'].toString(),
      nome: nomeCompleto.isEmpty ? (map['email'] ?? 'Sem nome') : nomeCompleto,
      cargo: map['cargo'] ?? 'Colaborador',
      email: map['email'] ?? '',
      fotoUrl: map['foto_url'],
      isMaster: map['is_admin_empresa'] ?? false,
      isAdmin: map['is_admin'] ?? false, 
      status: statusAtual,
    );
  }
}

// ==========================================
// 2. PROVIDERS DE BUSCA (RIVERPOD 3)
// ==========================================
typedef EmpresaParams = ({String empresaId});

final limitePlanoProvider = FutureProvider.family.autoDispose<int, EmpresaParams>((ref, params) async {
  final res = await Supabase.instance.client
      .from('empresas')
      .select('planos(qtd_user)')
      .eq('id', params.empresaId)
      .maybeSingle();
      
  return (res?['planos'] as Map?)?['qtd_user'] ?? 0;
});

final equipeEmpresaProvider = FutureProvider.family.autoDispose<List<ColaboradorModel>, EmpresaParams>((ref, params) async {
  final empresaAtualId = ref.watch(currentUserProvider)?.empresaId;
  if (empresaAtualId == null || empresaAtualId != params.empresaId) {
    return [];
  }

  try {
    final data = await AuthOperationsRepository().execute(
      'list_company_members_admin',
      const {},
    );
    final membros = data['membros'];
    if (membros is! List) {
      throw Exception('Resposta inválida ao carregar colaboradores.');
    }

    return membros
        .whereType<Map>()
        .map((member) => ColaboradorModel.fromMap(
              Map<String, dynamic>.from(member),
            ))
        .toList();
  } on Exception catch (e) {
    throw Exception('Erro ao carregar colaboradores: $e');
  }
});

// ==========================================
// 3. CONTROLLER DE AÇÕES (ADMIN & REMOÇÃO)
// ==========================================
// CORREÇÃO: Utilizando Notifier ao invés de AutoDisposeNotifier
class EquipeActionNotifier extends Notifier<bool> {
  @override
  bool build() => false; 

  Future<void> alternarAdmin(String empresaId, ColaboradorModel user) async {
    if (user.isMaster) return; 

    state = true;
    try {
      await AuthOperationsRepository().execute('manage_collaborator', {
        'operation': 'set_admin',
        'empresa_id': empresaId,
        'usuario_id': user.id,
        'is_admin': !user.isAdmin,
      });
          
      ref.invalidate(equipeEmpresaProvider((empresaId: empresaId)));
    } on PostgrestException catch (e) {
      throw Exception('Erro ao atualizar permissão: ${e.message}');
    } finally {
      state = false;
    }
  }

  // Adicione este método dentro de EquipeActionNotifier
  Future<void> deletarColaborador(String empresaId, ColaboradorModel user) async {
    if (user.isMaster) return; // Trava de segurança

    state = true;
    try {
      // Desvincula totalmente o usuário da empresa
      await AuthOperationsRepository().execute('manage_collaborator', {
        'operation': 'unlink',
        'empresa_id': empresaId,
        'usuario_id': user.id,
      });
          
      ref.invalidate(equipeEmpresaProvider((empresaId: empresaId)));
      ref.invalidate(limitePlanoProvider((empresaId: empresaId)));
    } on PostgrestException catch (e) {
      throw Exception('Erro ao deletar colaborador: ${e.message}');
    } finally {
      state = false;
    }
  }

  Future<void> removerAcesso(String empresaId, ColaboradorModel user) async {
    if (user.isMaster) return; 

    state = true;
    try {
      await AuthOperationsRepository().execute('manage_collaborator', {
        'operation': 'deactivate',
        'empresa_id': empresaId,
        'usuario_id': user.id,
      });
          
      ref.invalidate(equipeEmpresaProvider((empresaId: empresaId)));
      ref.invalidate(limitePlanoProvider((empresaId: empresaId)));
    } on PostgrestException catch (e) {
      throw Exception('Erro ao remover colaborador: ${e.message}');
    } finally {
      state = false;
    }
  }

  // NOVO MÉTOD0: Devolve o acesso ao usuário
  Future<void> reativarAcesso(String empresaId, ColaboradorModel user) async {
    if (user.isMaster) return;
    state = true;
    try {
      await AuthOperationsRepository().execute('manage_collaborator', {
        'operation': 'reactivate',
        'empresa_id': empresaId,
        'usuario_id': user.id,
      });
          
      ref.invalidate(equipeEmpresaProvider((empresaId: empresaId)));
      ref.invalidate(limitePlanoProvider((empresaId: empresaId)));
    } on PostgrestException catch (e) {
      throw Exception('Erro ao reativar colaborador: ${e.message}');
    } finally {
      state = false;
    }
  }
}

final equipeActionProvider = NotifierProvider<EquipeActionNotifier, bool>(
  EquipeActionNotifier.new,
);

