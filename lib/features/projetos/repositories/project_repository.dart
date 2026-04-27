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
}