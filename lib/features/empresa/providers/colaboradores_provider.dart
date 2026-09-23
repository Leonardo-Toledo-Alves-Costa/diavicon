import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/repositories/auth_operations_repository.dart';
import '../../equipe/providers/equipe_provider.dart';

// ==========================================
// 1. MODELO DE DADOS
// ==========================================
class ColaboradorModel {
  final String id;
  final String nome;
  final String cargo;

  /// Nível do cargo (coluna `titulo_principal`): Júnior, Pleno, Sênior…
  final String? nivel;
  final String email;
  final String? fotoUrl;
  final bool isMaster;
  final bool isAdmin;
  final String status;
  final bool podeVisualizarEmpresa;

  ColaboradorModel({
    required this.id,
    required this.nome,
    required this.cargo,
    this.nivel,
    required this.email,
    this.fotoUrl,
    required this.isMaster,
    required this.isAdmin,
    required this.status,
    this.podeVisualizarEmpresa = false,
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
      nivel: (map['titulo_principal']?.toString().trim().isEmpty ?? true) ? null : map['titulo_principal'].toString(),
      email: map['email'] ?? '',
      fotoUrl: map['foto_url'],
      isMaster: map['is_admin_empresa'] ?? false,
      isAdmin: map['is_admin'] ?? false,
      status: statusAtual,
      podeVisualizarEmpresa: map['pode_visualizar_empresa'] ?? false,
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
  // Antes isso devolvia [] silenciosamente sempre que o perfil local ainda
  // não tinha carregado/atualizado o empresa_id (ex: race logo após criar a
  // empresa) — na tela isso parecia "nenhum colaborador", inclusive o
  // próprio usuário sumindo da lista, sem nenhum erro visível. Agora isso
  // aparece como erro de verdade, distinguível de "a empresa realmente não
  // tem colaboradores".
  if (empresaAtualId == null) {
    throw Exception('Perfil do usuário ainda não carregado — tente novamente em instantes.');
  }
  if (empresaAtualId != params.empresaId) {
    throw Exception('Você não pertence a esta empresa (perfil vinculado a outra empresa).');
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

    final lista = membros
        .whereType<Map>()
        .map((member) => ColaboradorModel.fromMap(
              Map<String, dynamic>.from(member),
            ))
        .toList();

    // Rede de segurança: se por qualquer motivo (drift entre o Edge Function
    // deployado e o esperado, atraso de replicação, etc.) a própria linha do
    // usuário logado não vier na resposta do servidor, ele ainda assim
    // pertence à empresa (é o requisito pra sequer chegar até aqui, ver o
    // guard acima) — então garantimos ele visível na lista em vez de deixar
    // o próprio usuário sumir da tela de colaboradores da empresa dele.
    final usuarioAtual = ref.read(currentUserProvider);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (usuarioAtual != null && currentUserId != null && !lista.any((c) => c.id == currentUserId)) {
      lista.insert(
        0,
        ColaboradorModel(
          id: currentUserId,
          nome: '${usuarioAtual.nome ?? ''} ${usuarioAtual.sobrenome ?? ''}'.trim().isEmpty ? (usuarioAtual.email ?? 'Você') : '${usuarioAtual.nome ?? ''} ${usuarioAtual.sobrenome ?? ''}'.trim(),
          cargo: usuarioAtual.cargo ?? 'Colaborador',
          email: usuarioAtual.email ?? '',
          fotoUrl: usuarioAtual.fotoUrl,
          isMaster: usuarioAtual.isAdminEmpresa ?? false,
          isAdmin: usuarioAtual.isAdmin ?? false,
          status: usuarioAtual.ativo == true ? 'ativo' : (usuarioAtual.convitePendente == true ? 'convidado' : 'inativo'),
          podeVisualizarEmpresa: usuarioAtual.podeVisualizarEmpresa ?? false,
        ),
      );
    }

    return lista;
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
    // Estes `return` mudos viraram aviso: antes o clique não fazia nada e
    // não explicava nada.
    if (user.isMaster) {
      throw Exception('O Gestor da empresa já tem todas as permissões de admin.');
    }

    state = true;
    try {
      await AuthOperationsRepository().execute('manage_collaborator', {
        'operation': 'set_admin',
        'empresa_id': empresaId,
        'usuario_id': user.id,
        'is_admin': !user.isAdmin,
      });

      ref.invalidate(equipeEmpresaProvider((empresaId: empresaId)));

      await _conferir(
        empresaId: empresaId,
        usuarioId: user.id,
        oQue: 'a permissão de admin',
        conferencia: (c) => c.isAdmin == !user.isAdmin,
      );
    } catch (e) {
      throw Exception('Erro ao atualizar permissão: ${_limpar(e)}');
    } finally {
      state = false;
    }
  }

  // Concede/remove só o acesso de VISUALIZAÇÃO ao painel da empresa — não dá
  // nenhuma permissão de gerenciar colaboradores/serviços/etc, diferente de
  // "Tornar admin".
  Future<void> alternarVisualizacaoPainel(String empresaId, ColaboradorModel user) async {
    // Gestor da empresa enxerga o painel por definição: não há o que liberar
    // ou tirar aqui, e a própria função do servidor recusa a operação.
    if (user.isMaster) {
      throw Exception('Gestores da empresa já enxergam o painel.');
    }
    if (user.status != 'ativo') {
      throw Exception('Só colaboradores ativos podem receber acesso ao painel.');
    }

    state = true;
    try {
      await AuthOperationsRepository().execute('manage_collaborator', {
        'operation': 'set_pode_visualizar',
        'empresa_id': empresaId,
        'usuario_id': user.id,
        'pode_visualizar': !user.podeVisualizarEmpresa,
      });

      await _conferir(
        empresaId: empresaId,
        usuarioId: user.id,
        oQue: 'o acesso ao painel',
        conferencia: (c) => c.podeVisualizarEmpresa == !user.podeVisualizarEmpresa,
      );
    } catch (e) {
      throw Exception('Erro ao atualizar permissão de visualização: ${_limpar(e)}');
    } finally {
      state = false;
    }
  }

  /// Relê a lista no servidor e confirma que a mudança pegou. Sem isso, uma
  /// função publicada desatualizada responde "sucesso" e nada muda na tela,
  /// o que parece um botão quebrado.
  Future<void> _conferir({
    required String empresaId,
    required String usuarioId,
    required String oQue,
    required bool Function(ColaboradorModel) conferencia,
  }) async {
    final lista = await ref.refresh(equipeEmpresaProvider((empresaId: empresaId)).future);
    ColaboradorModel? alvo;
    for (final c in lista) {
      if (c.id == usuarioId) alvo = c;
    }
    if (alvo == null || conferencia(alvo)) return;
    throw Exception(
      'O servidor respondeu sem erro, mas $oQue continua como estava. '
      'A função auth-operations publicada no Supabase provavelmente está desatualizada.',
    );
  }

  static String _limpar(Object e) => e.toString().replaceFirst('Exception: ', '');

  // Concede o papel de Gestor da empresa (is_admin_empresa = true) ao
  // colaborador alvo. Mais de um colaborador pode ser Gestor ao mesmo tempo
  // — não é mais uma troca de cargo único, só quem já é Gestor pode conceder
  // esse papel a outro colaborador (validado também no servidor).
  Future<void> tornarGestor(String empresaId, ColaboradorModel user) async {
    if (user.isMaster) {
      throw Exception('${user.nome} já é Gestor da empresa.');
    }
    if (!user.isAdmin) {
      throw Exception('Só um administrador pode virar Gestor. Torne ${user.nome} admin antes.');
    }

    state = true;
    try {
      await AuthOperationsRepository().execute('manage_collaborator', {
        'operation': 'set_admin_empresa',
        'empresa_id': empresaId,
        'usuario_id': user.id,
        'is_admin_empresa': true,
      });

      await _conferir(
        empresaId: empresaId,
        usuarioId: user.id,
        oQue: 'o papel de Gestor',
        conferencia: (c) => c.isMaster,
      );
    } catch (e) {
      throw Exception('Erro ao conceder gestão: ${_limpar(e)}');
    } finally {
      state = false;
    }
  }

  /// Muda cargo e nível. Só o Gestor faz isso (conferido no servidor).
  Future<void> editarCargo(String empresaId, ColaboradorModel user, {required String cargo, String? nivel}) async {
    final cargoLimpo = cargo.trim();
    if (cargoLimpo.isEmpty) throw Exception('Informe o cargo.');

    state = true;
    try {
      await AuthOperationsRepository().execute('manage_collaborator', {
        'operation': 'set_cargo',
        'empresa_id': empresaId,
        'usuario_id': user.id,
        'cargo': cargoLimpo,
        'nivel': nivel,
      });

      await _conferir(
        empresaId: empresaId,
        usuarioId: user.id,
        oQue: 'o cargo',
        conferencia: (c) => c.cargo == cargoLimpo,
      );
    } catch (e) {
      throw Exception('Erro ao editar cargo e nível: ${_limpar(e)}');
    } finally {
      state = false;
    }
  }

  /// Tira o papel de Gestor. Só outro Gestor faz isso, e a empresa precisa
  /// continuar com pelo menos um — as duas regras são conferidas no servidor.
  Future<void> removerGestor(String empresaId, ColaboradorModel user) async {
    if (!user.isMaster) {
      throw Exception('${user.nome} não é Gestor da empresa.');
    }

    state = true;
    try {
      await AuthOperationsRepository().execute('manage_collaborator', {
        'operation': 'set_admin_empresa',
        'empresa_id': empresaId,
        'usuario_id': user.id,
        'is_admin_empresa': false,
      });

      await _conferir(
        empresaId: empresaId,
        usuarioId: user.id,
        oQue: 'o papel de Gestor',
        conferencia: (c) => !c.isMaster,
      );
    } catch (e) {
      throw Exception('Erro ao remover a gestão: ${_limpar(e)}');
    } finally {
      state = false;
    }
  }

  // Exclusão definitiva de verdade: apaga a linha de `usuarios` e a conta em
  // auth.users (via a operação 'delete_permanently' da Edge Function), ao
  // contrário de 'unlink' (usada em removerAcesso/reativarAcesso), que só
  // desvincula da empresa e mantém a conta — o que bloqueava reconvidar esse
  // e-mail depois (Supabase Auth recusa um e-mail já cadastrado). Só é
  // permitida pra colaborador já inativo (mesma trava da Edge Function).
  Future<void> deletarColaborador(String empresaId, ColaboradorModel user) async {

    state = true;
    try {
      await AuthOperationsRepository().execute('manage_collaborator', {
        'operation': 'delete_permanently',
        'empresa_id': empresaId,
        'usuario_id': user.id,
      });
          
      ref.invalidate(equipeEmpresaProvider((empresaId: empresaId)));
      ref.invalidate(limitePlanoProvider((empresaId: empresaId)));
      // Sem parâmetro invalida TODAS as instâncias da family — não dá pra
      // saber daqui em qual projetoId o usuário vai abrir "convidar" depois.
      ref.invalidate(planLimitByProjectProvider);

      // Sem esta conferência, uma função publicada desatualizada responde
      // "sucesso", a pessoa continua na lista e ninguém entende o que houve.
      final lista = await ref.refresh(equipeEmpresaProvider((empresaId: empresaId)).future);
      if (lista.any((c) => c.id == user.id)) {
        throw Exception(
          'O servidor respondeu sem erro, mas o colaborador continua na lista. '
          'A função auth-operations publicada no Supabase provavelmente está desatualizada.',
        );
      }
    } catch (e) {
      throw Exception('Erro ao excluir colaborador: ${_limpar(e)}');
    } finally {
      state = false;
    }
  }

  Future<void> removerAcesso(String empresaId, ColaboradorModel user) async {

    state = true;
    try {
      await AuthOperationsRepository().execute('manage_collaborator', {
        'operation': 'deactivate',
        'empresa_id': empresaId,
        'usuario_id': user.id,
      });
          
      ref.invalidate(equipeEmpresaProvider((empresaId: empresaId)));
      ref.invalidate(limitePlanoProvider((empresaId: empresaId)));
      ref.invalidate(planLimitByProjectProvider);

      await _conferir(
        empresaId: empresaId,
        usuarioId: user.id,
        oQue: 'o acesso do colaborador',
        conferencia: (c) => c.status != 'ativo',
      );
    } catch (e) {
      throw Exception('Erro ao suspender o acesso: ${_limpar(e)}');
    } finally {
      state = false;
    }
  }

  // NOVO MÉTOD0: Devolve o acesso ao usuário
  Future<void> reativarAcesso(String empresaId, ColaboradorModel user) async {
    state = true;
    try {
      await AuthOperationsRepository().execute('manage_collaborator', {
        'operation': 'reactivate',
        'empresa_id': empresaId,
        'usuario_id': user.id,
      });
          
      ref.invalidate(equipeEmpresaProvider((empresaId: empresaId)));
      ref.invalidate(limitePlanoProvider((empresaId: empresaId)));
      ref.invalidate(planLimitByProjectProvider);

      await _conferir(
        empresaId: empresaId,
        usuarioId: user.id,
        oQue: 'o acesso do colaborador',
        conferencia: (c) => c.status == 'ativo',
      );
    } catch (e) {
      throw Exception('Erro ao restaurar o acesso: ${_limpar(e)}');
    } finally {
      state = false;
    }
  }
}

final equipeActionProvider = NotifierProvider<EquipeActionNotifier, bool>(
  EquipeActionNotifier.new,
);

