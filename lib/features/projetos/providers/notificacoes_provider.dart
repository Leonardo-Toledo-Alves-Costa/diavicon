import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'projetos_provider.dart'; 
import '../../projetos/providers/empresas_projeto_provider.dart'; 
import '../../equipe/providers/equipe_provider.dart';

// PROVIDER PARA O BADGE DO SININHO (Em tempo real)
final contadorNaoLidasProvider = StreamProvider.autoDispose<int>((ref) {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) return Stream.value(0);

  return supabase
      .from('notificacoes')
      .stream(primaryKey: ['id'])
      .map((lista) {
        // Garante que campos nulos também sejam contados como "não lidos"
        return lista.where((n) => n['lida'] != true).length;
      });
});

// PROVIDER DA TELA DE NOTIFICAÇÕES (Em tempo real)
final notificacoesProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) return Stream.value([]);

  return supabase
      .from('notificacoes')
      .stream(primaryKey: ['id'])
      .map((lista) {
        final listaOrdenada = List<Map<String, dynamic>>.from(lista);
        
        listaOrdenada.sort((a, b) {
          final dataA = DateTime.tryParse(a['criado_em']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dataB = DateTime.tryParse(b['criado_em']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dataB.compareTo(dataA); 
        });
        
        return listaOrdenada;
      });
});

final notificacoesControllerProvider = Provider((ref) => NotificacoesController(ref));

class NotificacoesController {
  final Ref _ref;
  final _supabase = Supabase.instance.client;

  NotificacoesController(this._ref);

  // MARCAR COMO LIDA
  Future<void> marcarComoLida(String idNotificacao) async {
    await _supabase
        .from('notificacoes')
        .update({'lida': true})
        .eq('id', idNotificacao);
  }

  Future<void> aceitarConvite({
    required String conviteId,
    required String projetoId,
    required String notificacaoId,
  }) async {
    if (_supabase.auth.currentUser?.id == null) {
      throw Exception('Sessão expirada.');
    }

    // Aceita o convite com a validação de destinatário no banco.
    await _supabase.rpc('set_project_company_invite_status', params: {
      'p_convite_id': conviteId,
      'p_status': 'aceito',
    });

    //Marca a notificação como lida
    await marcarComoLida(notificacaoId);

    _ref.invalidate(filteredProjectsProvider); 
    _ref.invalidate(empresasVinculadasProjetoProvider(projetoId)); 
    _ref.invalidate(colaboradoresAtivosProjetoProvider(projetoId));
  }

  Future<void> recusarConvite(String conviteId, String notificacaoId) async {
    await _supabase.rpc('set_project_company_invite_status', params: {
      'p_convite_id': conviteId,
      'p_status': 'recusado',
    });

    await marcarComoLida(notificacaoId);
  }

  // ==========================================================================
  // CONVITE DE CLIENTE PARA O PROJETO
  //
  // O "convite" aqui não precisa de uma tabela própria: `projetos` já tem
  // `empresa_cliente_id` + `status_vinculo_cliente`, então o convite pendente
  // É o próprio projeto com status_vinculo_cliente = 'pendente'. Notifica só
  // os administradores (`is_admin_empresa = true`) da empresa convidada.
  // ==========================================================================

  Future<void> enviarConviteCliente({
    required String projetoId,
    required String empresaClienteId,
  }) async {
    final projeto = await _supabase
        .from('projetos')
        .select('nome, image_url, empresa_cliente_id, status_vinculo_cliente')
        .eq('id', projetoId)
        .single();

    if (projeto['empresa_cliente_id'] == empresaClienteId) {
      if (projeto['status_vinculo_cliente'] == 'ativo') {
        throw Exception('Esta empresa já é cliente deste projeto.');
      }
      if (projeto['status_vinculo_cliente'] == 'pendente') {
        throw Exception('Um convite já foi enviado para esta empresa.');
      }
    }

    // Valida se há admin ANTES de mexer no projeto, pra não deixar o
    // vínculo pendente "travado" sem ninguém pra aceitar.
    final admins = await _supabase
        .from('usuarios')
        .select('id')
        .eq('empresa_id', empresaClienteId)
        .eq('is_admin_empresa', true);

    if ((admins as List).isEmpty) {
      throw Exception('Esta empresa não possui um administrador cadastrado para receber o convite.');
    }

    await _supabase.from('projetos').update({
      'empresa_cliente_id': empresaClienteId,
      'status_vinculo_cliente': 'pendente',
    }).eq('id', projetoId);

    await enviarNotificacaoConviteCliente(
      projetoId: projetoId,
      empresaClienteId: empresaClienteId,
      nomeProjeto: projeto['nome'] ?? 'Projeto sem nome',
      imageUrl: projeto['image_url'],
      adminsJaBuscados: admins,
    );

    _ref.invalidate(projectDetailProvider(projetoId));
  }

  /// Só envia a notificação de "Convite de Cliente" pros admins da empresa
  /// convidada — não mexe em `projetos.empresa_cliente_id`/`status_vinculo_cliente`
  /// (isso já deve ter sido feito por quem chamou, ver `enviarConviteCliente`
  /// e o fluxo de criação de projeto em `ProjectRepository.createProject`).
  Future<void> enviarNotificacaoConviteCliente({
    required String projetoId,
    required String empresaClienteId,
    required String nomeProjeto,
    String? imageUrl,
    List<dynamic>? adminsJaBuscados,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Sessão expirada. Faça login novamente.');

    final admins = adminsJaBuscados ??
        await _supabase
            .from('usuarios')
            .select('id')
            .eq('empresa_id', empresaClienteId)
            .eq('is_admin_empresa', true);

    if (admins.isEmpty) {
      throw Exception('Esta empresa não possui um administrador cadastrado para receber o convite.');
    }

    final remetente = await _supabase.from('usuarios').select('nome, sobrenome, empresa_id').eq('id', userId).single();
    final remetenteEmpresa = remetente['empresa_id'] != null
        ? await _supabase.from('empresas').select('nome').eq('id', remetente['empresa_id']).maybeSingle()
        : null;

    final remetenteNome = '${remetente['nome'] ?? ''} ${remetente['sobrenome'] ?? ''}'.trim();
    final nomeEmpresaGestora = remetenteEmpresa?['nome'] ?? 'uma empresa';

    final notificacoes = admins.map((a) => {
          'usuario_id': a['id'],
          'titulo': 'Convite de Cliente',
          'mensagem': '$remetenteNome, da empresa $nomeEmpresaGestora, está te convidando para ser cliente do projeto $nomeProjeto.',
          'tipo': 'convite_cliente',
          'lida': false,
          'dados_extras': {
            'projeto_id': projetoId,
            'foto_url': imageUrl,
          },
        }).toList();

    await _supabase.from('notificacoes').insert(notificacoes);
  }

  /// Desvincula o cliente atual do projeto, decidido pela empresa GESTORA
  /// (diferente de `recusarConviteCliente`, que é a própria empresa
  /// convidada recusando) — usado no fluxo de "Trocar cliente proprietário".
  Future<void> removerClienteAtual({required String projetoId}) async {
    await _supabase.from('projetos').update({
      'empresa_cliente_id': null,
      'status_vinculo_cliente': 'nao_vinculado',
    }).eq('id', projetoId);

    _ref.invalidate(projectDetailProvider(projetoId));
  }

  Future<void> aceitarConviteCliente({required String projetoId, required String notificacaoId}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Sessão expirada.');

    final usuarioData = await _supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
    final empresaId = usuarioData?['empresa_id'];
    if (empresaId == null) throw Exception('Seu usuário não está vinculado a uma empresa.');

    final projeto = await _supabase.from('projetos').select('empresa_cliente_id, status_vinculo_cliente').eq('id', projetoId).maybeSingle();
    if (projeto == null || projeto['empresa_cliente_id'] != empresaId || projeto['status_vinculo_cliente'] != 'pendente') {
      throw Exception('Este convite não é mais válido.');
    }

    await _supabase.from('projetos').update({'status_vinculo_cliente': 'ativo'}).eq('id', projetoId);
    await marcarComoLida(notificacaoId);

    _ref.invalidate(filteredProjectsProvider);
    _ref.invalidate(projectDetailProvider(projetoId));
  }

  Future<void> recusarConviteCliente({required String projetoId, required String notificacaoId}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      final usuarioData = await _supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
      final empresaId = usuarioData?['empresa_id'];
      final projeto = await _supabase.from('projetos').select('empresa_cliente_id').eq('id', projetoId).maybeSingle();
      if (projeto != null && projeto['empresa_cliente_id'] == empresaId) {
        await _supabase.from('projetos').update({
          'empresa_cliente_id': null,
          'status_vinculo_cliente': 'nao_vinculado',
        }).eq('id', projetoId);
      }
    }
    await marcarComoLida(notificacaoId);
  }
}
