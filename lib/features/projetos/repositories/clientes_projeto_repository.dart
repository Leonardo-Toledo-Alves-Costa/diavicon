import 'package:supabase_flutter/supabase_flutter.dart';

class ClientesProjetoRepository {
  ClientesProjetoRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<void> inviteExistingClient({
    required String projectId,
    required String clientCompanyId,
  }) async {
    final userId = _requireUserId();
    final project = await _supabase
        .from('projetos')
        .select('nome, image_url, empresa_cliente_id, status_vinculo_cliente')
        .eq('id', projectId)
        .single();

    if (project['empresa_cliente_id'] == clientCompanyId) {
      if (project['status_vinculo_cliente'] == 'ativo') {
        throw StateError('Esta empresa já é cliente deste projeto.');
      }
      if (project['status_vinculo_cliente'] == 'pendente') {
        throw StateError('Um convite já foi enviado para esta empresa.');
      }
    }

    final admins = await _supabase
        .from('usuarios')
        .select('id')
        .eq('empresa_id', clientCompanyId)
        .eq('ativo', true)
        .eq('is_admin_empresa', true);
    if ((admins as List).isEmpty) {
      throw StateError(
        'Esta empresa não possui um administrador cadastrado para receber o convite.',
      );
    }

    await _supabase.from('projetos').update({
      'empresa_cliente_id': clientCompanyId,
      'status_vinculo_cliente': 'pendente',
    }).eq('id', projectId);

    final sender = await _supabase
        .from('usuarios')
        .select('nome, sobrenome, empresa_id')
        .eq('id', userId)
        .single();
    final senderCompany = sender['empresa_id'] == null
        ? null
        : await _supabase
            .from('empresas')
            .select('nome')
            .eq('id', sender['empresa_id'])
            .maybeSingle();
    final senderName = '${sender['nome'] ?? ''} ${sender['sobrenome'] ?? ''}'
        .trim();
    final companyName = senderCompany?['nome'] ?? 'uma empresa';

    await _supabase.from('notificacoes').insert(
      (admins as List).map((admin) {
        return {
          'usuario_id': admin['id'],
          'titulo': 'Convite de Cliente',
          'mensagem':
              '${senderName.isEmpty ? 'Um usuário' : senderName}, da empresa $companyName, está te convidando para ser cliente do projeto ${project['nome'] ?? 'Projeto sem nome'}.',
          'tipo': 'convite_cliente',
          'lida': false,
          'dados_extras': {
            'projeto_id': projectId,
            'foto_url': project['image_url'],
          },
        };
      }).toList(),
    );
  }

  Future<void> respondToInvite({
    required String projectId,
    required String notificationId,
    required bool accept,
  }) async {
    final userId = _requireUserId();
    final user = await _supabase
        .from('usuarios')
        .select('empresa_id')
        .eq('id', userId)
        .maybeSingle();
    final companyId = user?['empresa_id'];
    if (companyId == null) {
      throw StateError('Seu usuário não está vinculado a uma empresa.');
    }

    final project = await _supabase
        .from('projetos')
        .select('empresa_cliente_id, status_vinculo_cliente')
        .eq('id', projectId)
        .maybeSingle();
    if (project == null ||
        project['empresa_cliente_id'] != companyId ||
        project['status_vinculo_cliente'] != 'pendente') {
      throw StateError('Este convite não é mais válido.');
    }

    if (accept) {
      await _supabase
          .from('projetos')
          .update({'status_vinculo_cliente': 'ativo'})
          .eq('id', projectId);
    } else {
      await _supabase.from('projetos').update({
        'empresa_cliente_id': null,
        'status_vinculo_cliente': 'nao_vinculado',
      }).eq('id', projectId);
    }
    await _markNotificationAsRead(notificationId, userId);
  }

  Future<void> removeCurrentClient(String projectId) async {
    await _supabase.from('projetos').update({
      'empresa_cliente_id': null,
      'status_vinculo_cliente': 'nao_vinculado',
    }).eq('id', projectId);
  }

  String _requireUserId() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sessão expirada. Faça login novamente.');
    }
    return userId;
  }

  Future<void> _markNotificationAsRead(
    String notificationId,
    String userId,
  ) {
    return _supabase
        .from('notificacoes')
        .update({'lida': true})
        .eq('id', notificationId)
        .eq('usuario_id', userId);
  }
}
