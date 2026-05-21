import 'dart:io';

import 'package:diavicon/features/projetos/models/projeto_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectRepository {
  final SupabaseClient _supabase;
  ProjectRepository(this._supabase);

  

  // BUSCA A LISTA PARA A HOME
  Future<List<ProjetoModel>> getProjects() async {
    final response = await _supabase
        .from('projetos')
        .select('''
          *,
          prioridade:prioridade_id(nome),
          status_projeto:status_id(nome)
        ''')
        .order('criado_em', ascending: false);

    return (response as List).map((map) => ProjetoModel.fromMap(map)).toList();
  }

  // BUSCA O DETALHE COMPLETO
  Future<ProjetoModel> getProjectById(String id) async {
    final response = await _supabase
        .from('projetos')
        .select('''
          *,
          prioridade:prioridade_id(nome),
          status_projeto:status_id(nome),
          empresas:empresa_gestora_id(nome)
        ''')
        .eq('id', id)
        .single();

    return ProjetoModel.fromMap(response);
  }

  /// Busca a lista de projetos onde o usuário logado tem permissão de acesso.
  /// Realiza joins para trazer nomes de status, prioridade e empresa gestora.
  Future<List<ProjetoModel>> fetchUserProjects(String userId) async {
    try {
      //  A query usa !inner na tabela de relação para filtrar apenas os que o usuário participa.
      //  Usa aliases (nome:coluna) para bater com as chaves do ProjetoModel.fromMap.
      final response = await _supabase
          .from('projetos')
          .select('''
            *,
            prioridade:prioridade_id(nome),
            status_projeto:status_id(nome),
            empresas:empresa_gestora_id(nome),
            projeto_colaboradores!inner(usuario_id)
          ''')
          .eq('projeto_colaboradores.usuario_id', userId)
          .order('criado_em', ascending: false);

      final List data = response as List;
      return data.map((json) => ProjetoModel.fromMap(json)).toList();
    } catch (e) {
      // Log de erro para facilitar o debug em ambiente de desenvolvimento
      print('🚨 ERRO ProjetoRepository.fetchUserProjects: $e');
      rethrow;
    }
  }

  /// BUSCA EMPRESA POR CÓDIGO OU CNPJ 
  Future<Map<String, dynamic>?> buscarEmpresaPorFiltro(String filtro) async {
    try {
      final response = await _supabase
          .from('empresas')
          .select('id, nome, foto_url')
          .or('cnpj.eq.$filtro, id.eq.$filtro') // Busca por CNPJ ou ID (Código)
          .maybeSingle();
      return response;
    } catch (e) {
      print('🚨 Erro ao buscar empresa: $e');
      return null;
    }
  }

  /// CRIAÇÃO COMPLETA DO PROJETO
  Future<void> createProject({
    required String nome,
    required String empresaGestoraId,
    required String usuarioId,
    String? empresaClienteId,
    required bool isNovoCliente,
    String? emailNovoCliente,
    String? nomeNovoCliente,
    File? imagemProjeto, 
    File? fotoNovoCliente,
  }) async {
    try {
      String? imageUrl;
      String? clienteFotoUrl; 

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      //  UPLOAD DA CAPA DO PROJETO
      if (imagemProjeto != null) {
        try {
          final extensao = imagemProjeto.path.split('.').last;
          final caminhoStorage = 'capas/$timestamp.$extensao';
          await _supabase.storage.from('projetos').upload(caminhoStorage, imagemProjeto);
          imageUrl = _supabase.storage.from('projetos').getPublicUrl(caminhoStorage);
        } catch (e) {
          print('⚠️ Erro no upload da capa do projeto: $e');
        }
      }

      // UPLOAD DA FOTO DO CLIENTE NOVO
      if (isNovoCliente && fotoNovoCliente != null) {
        try {
          final extensao = fotoNovoCliente.path.split('.').last;
          // Salva na pasta 'clientes/' dentro do mesmo bucket para organizar
          final caminhoStorage = 'clientes/$timestamp.$extensao';
          await _supabase.storage.from('projetos').upload(caminhoStorage, fotoNovoCliente);
          clienteFotoUrl = _supabase.storage.from('projetos').getPublicUrl(caminhoStorage);
        } catch (e) {
          print('⚠️ Erro no upload da foto do cliente: $e');
        }
      }

      // Cria o Projeto no Banco
      final respostaProjeto = await _supabase.from('projetos').insert({
        'nome': nome,
        'empresa_gestora_id': empresaGestoraId,
        'empresa_cliente_id': isNovoCliente ? null : empresaClienteId,
        'status_vinculo_cliente': isNovoCliente ? 'nao_vinculado' : 'ativo',
        'image_url': imageUrl, 
      }).select('id').single();

      final String novoProjetoId = respostaProjeto['id'];

      //  Cria o Convite com o link da foto do cliente
      if (isNovoCliente && emailNovoCliente != null) {
        await _supabase.from('projeto_convites').insert({
          'projeto_id': novoProjetoId,
          'email_convidado': emailNovoCliente,
          'empresa_nome_temp': nomeNovoCliente,
          'criado_por': usuarioId,
          'aceito': false,
          'foto_url': clienteFotoUrl, // SALVA O LINK GERADO NA SUA NOVA COLUNA
        });
      }

      //  Adiciona o Gestor à equipe
      await _supabase.from('projeto_colaboradores').insert({
        'projeto_id': novoProjetoId,
        'usuario_id': usuarioId, 
        'empresa_id': empresaGestoraId, 
      });

    } catch (e) {
      throw Exception('Erro crítico ao salvar projeto no banco: $e');
    }
  }
}
