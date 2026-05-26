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
    bool isNovoCliente = false,
    String? emailNovoCliente,
    String? nomeNovoCliente,
  }) async {
    try {
      // DEFINIR O STATUS DO VÍNCULO
      // Se não informou cliente, assume que a gestora é a própria cliente ('proprio')
      // Se informou um cliente novo, fica 'pendente'. Se for um ID existente, 'vinculado'.
      String statusVinculo = 'proprio';
      if (isNovoCliente) {
        statusVinculo = 'pendente';
      } else if (empresaClienteId != null &&
          empresaClienteId != empresaGestoraId) {
        statusVinculo = 'vinculado';
      }

      //  CRIAR O PROJETO
      final projectResponse = await _supabase
          .from('projetos')
          .insert({
            'nome': nome,
            'empresa_gestora_id': empresaGestoraId,
            'empresa_cliente_id': isNovoCliente
                ? null
                : (empresaClienteId ?? empresaGestoraId),
            'status_vinculo_cliente': statusVinculo,
            'status_id':
                'bfcbba38-b20a-4e50-98b0-cc36f9c17d9a', 
            'prioridade_id':
                '57434e9b-2825-4b8e-9fb2-4d8b9e03283f',
            'progresso': 0.0,
          })
          .select()
          .single();

      final String newProjectId = projectResponse['id'];

      // TRATAR NOVO CLIENTE (CONVITE)
      // Se for um novo cliente, salvamos na tabela de convites que criamos no SQL
      if (isNovoCliente && emailNovoCliente != null) {
        await _supabase.from('projeto_convites').insert({
          'projeto_id': newProjectId,
          'email_convidado': emailNovoCliente,
          'empresa_nome_temp': nomeNovoCliente,
          'criado_por': usuarioId,
        });
      }

      // VINCULAR O CRIADOR COMO COLABORADOR
      // Isso garante que o projeto apareça na lista de quem criou imediatamente
      await _supabase.from('projeto_colaboradores').insert({
        'projeto_id': newProjectId,
        'usuario_id': usuarioId,
        'empresa_id': empresaGestoraId,
      });
    } catch (e) {
      print('🚨 ERRO AO CRIAR PROJETO: $e');
      rethrow;
    }
  }
}
