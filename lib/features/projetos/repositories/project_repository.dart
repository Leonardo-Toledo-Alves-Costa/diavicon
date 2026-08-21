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
  Future<List<ProjetoModel>> fetchUserProjects(String userId) async {
    try {
      final response = await _supabase
          .from('projetos')
          .select('''
            *,
            prioridade:prioridade_id(nome),
            status_projeto:status_id(nome),
            empresas:empresa_gestora_id(nome),
            projeto_equipe_interna!inner(usuario_id)
          ''')
          .eq('projeto_equipe_interna.usuario_id', userId);

      final List data = response as List;
      return data.map((json) => ProjetoModel.fromMap(json)).toList();
    } catch (e) {
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
          .or('cnpj.eq.$filtro, id.eq.$filtro')
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

      // UPLOAD DA CAPA DO PROJETO
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
        'criado_por': usuarioId,
      }).select('id').single();

      final String novoProjetoId = respostaProjeto['id'];

      // Cria o Convite com o link da foto do cliente
      if (isNovoCliente && emailNovoCliente != null) {
        // 🔥 CORRIGIDO PARA O NOVO NOME DA TABELA DE CLIENTES: projeto_convites_cliente
        await _supabase.from('projeto_convites_cliente').insert({
          'projeto_id': novoProjetoId,
          'email_convidado': emailNovoCliente,
          'empresa_nome_temp': nomeNovoCliente,
          'criado_por': usuarioId,
          'aceito': false,
          'foto_url': clienteFotoUrl,
        });
      }

      // Garante a inserção do criador na equipe do projeto com sua respectiva empresa
      await _supabase.from('projeto_equipe_interna').insert({
        'projeto_id': novoProjetoId,
        'usuario_id': usuarioId, 
        'empresa_id': empresaGestoraId, 
        'ativo': true, 
        'is_gestor': true,
      });

    } catch (e) {
      throw Exception('Erro crítico ao salvar projeto no banco: $e');
    }
  }

  // 🔥 NOVA FUNÇÃO: ATUALIZA AS INFORMAÇÕES DO PROJETO (TELA INFO)
  Future<void> updateProject({
    required String projetoId,
    required String nome,
    required String descricao,
    required String statusNomeUI, // Vem do Dropdown ('Em Andamento', etc)
    required String prioridadeNomeUI, // Vem do Dropdown ('Alta', etc)
    File? novaImagem,
  }) async {
    try {
      String? imageUrl;

      // 1. Se tem imagem nova, faz o upload e pega o link
      if (novaImagem != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extensao = novaImagem.path.split('.').last;
        final caminhoStorage = 'capas/$timestamp.$extensao';
        
        await _supabase.storage.from('projetos').upload(caminhoStorage, novaImagem);
        imageUrl = _supabase.storage.from('projetos').getPublicUrl(caminhoStorage);
      }

      // 2. Transforma os nomes dos Dropdowns de volta em UUIDs das tabelas auxiliares
      // Buscando o ID do status
      final statusResp = await _supabase
          .from('status_projeto')
          .select('id')
          .eq('nome', statusNomeUI)
          .maybeSingle();
      
      // Buscando o ID da prioridade
      final prioridadeResp = await _supabase
          .from('prioridade')
          .select('id')
          .eq('nome', prioridadeNomeUI)
          .maybeSingle();

      // 3. Monta o pacote de dados (payload) para atualizar
      Map<String, dynamic> updateData = {
        'nome': nome,
        'descricao': descricao,
        if (statusResp != null) 'status_id': statusResp['id'],
        if (prioridadeResp != null) 'prioridade_id': prioridadeResp['id'],
        'image_url': ?imageUrl,
      };

      // 4. Salva tudo no banco
      await _supabase.from('projetos').update(updateData).eq('id', projetoId);

    } catch (e) {
      print('🚨 Erro ao atualizar projeto: $e');
      throw Exception('Não foi possível salvar as alterações do projeto.');
    }
  }
}