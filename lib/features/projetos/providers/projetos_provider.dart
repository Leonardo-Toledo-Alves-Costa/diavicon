import 'package:diavicon/core/widgets/status_badge.dart';
import 'package:diavicon/features/projetos/repositories/project_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/projeto_model.dart';

final projetoRepositoryProvider = Provider<ProjectRepository>((ref) {
  final client = Supabase.instance.client;
  return ProjectRepository(client);
});

final searchQueryProvider = StateProvider<String>((ref) => '');
final filtroStatusProvider = StateProvider<String>((ref) => 'Todos');
final filtroRecentesProvider = StateProvider<bool>((ref) => true);

final filteredProjectsProvider = FutureProvider.autoDispose<List<ProjetoModel>>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) return [];

  // Busca a empresa e se o usuário é Admin Global
  final usuarioData = await supabase
      .from('usuarios')
      .select('empresa_id, is_admin_empresa')
      .eq('id', userId)
      .maybeSingle();

  final minhaEmpresaId = usuarioData?['empresa_id'];
  final bool isAdminGlobal = usuarioData?['is_admin_empresa'] ?? false;

  if (minhaEmpresaId == null) return [];

  List<ProjetoModel> todosProjetos = [];

  // =========================================================
  // ROTA 1: VISÃO DO CHEFE (Vê todos os projetos da Empresa)
  // =========================================================
  if (isAdminGlobal) {
    // Busca todos os projetos onde a MINHA empresa é colaboradora com status 'aceito'
    final colaboradoresData = await supabase
        .from('projeto_empresas_colaboradoras') 
        .select('projeto_id')
        .eq('empresa_id', minhaEmpresaId) 
        .eq('status', 'aceito'); 

    final List<String> idsColaborador = colaboradoresData
        .map((e) => e['projeto_id'].toString())
        .toList();

    var query = supabase
        .from('projetos')
        .select('''
          *,
          prioridade(nome),
          status_projeto(nome),
          empresas!projetos_empresa_gestora_id_fkey(nome, foto_url),
          empresa_cliente:empresas!projetos_empresa_cliente_id_fkey(nome),
          projeto_equipe_interna(
            empresa_id, 
            usuarios(foto_url)
          )
        ''')
        // 🔥 A MÁGICA AQUI: Filtra direto no banco quem é ativo e da empresa
        .eq('projeto_equipe_interna.empresa_id', minhaEmpresaId)
        .eq('projeto_equipe_interna.ativo', true);

    // Se ela for colaboradora de algo, inclui os IDs na busca!
    if (idsColaborador.isNotEmpty) {
      query = query.or(
        'empresa_gestora_id.eq.$minhaEmpresaId,'
        'empresa_cliente_id.eq.$minhaEmpresaId,'
        'id.in.(${idsColaborador.join(',')})'
      );
    } else {
      query = query.or(
        'empresa_gestora_id.eq.$minhaEmpresaId,'
        'empresa_cliente_id.eq.$minhaEmpresaId'
      );
    }

    final response = await query;
    todosProjetos = (response as List).map((json) => ProjetoModel.fromMap(json, minhaEmpresaId: minhaEmpresaId)).toList();
  } 
  // =========================================================
  // ROTA 2: VISÃO DO FUNCIONÁRIO (Vê apenas os próprios projetos)
  // =========================================================
  else {
    // Busca na equipe interna apenas onde ele está ativo
    final equipeData = await supabase
        .from('projeto_equipe_interna')
        .select('projeto_id')
        .eq('usuario_id', userId)
        .eq('ativo', true);

    final List<String> meusIdsDeProjeto = equipeData
        .map((e) => e['projeto_id'].toString())
        .toList();

    // Só faz a busca na tabela projetos se ele tiver ao menos um crachá
    if (meusIdsDeProjeto.isNotEmpty) {
      final response = await supabase
          .from('projetos')
          .select('''
          *,
          prioridade(nome),
          status_projeto(nome),
          empresas!projetos_empresa_gestora_id_fkey(nome, foto_url),
          empresa_cliente:empresas!projetos_empresa_cliente_id_fkey(nome),
          projeto_equipe_interna(
            empresa_id,
            usuarios(foto_url)
          )
        ''')
        // 🔥 A MÁGICA AQUI: Filtra direto no banco quem é ativo e da empresa
        .eq('projeto_equipe_interna.empresa_id', minhaEmpresaId)
        .eq('projeto_equipe_interna.ativo', true)
        .inFilter('id', meusIdsDeProjeto);

      todosProjetos = (response as List).map((json) => ProjetoModel.fromMap(json, minhaEmpresaId: minhaEmpresaId)).toList();
    }
  }

  // =========================================================
  // FILTROS DA TELA (Pesquisa, Status, Recentes)
  // =========================================================
  final busca = ref.watch(searchQueryProvider).toLowerCase();
  final statusFiltro = ref.watch(filtroStatusProvider);
  final isRecente = ref.watch(filtroRecentesProvider);

  var listaFiltrada = todosProjetos.where((p) {
    final matchBusca =
        p.nome.toLowerCase().contains(busca) ||
        p.empresaNome.toLowerCase().contains(busca);

    bool matchStatus = true;
    if (statusFiltro != 'Todos') {
      if (statusFiltro == 'Em andamento')
        matchStatus = p.statusBadge == BadgeStatus.emAndamento;
      if (statusFiltro == 'Concluído')
        matchStatus = p.statusBadge == BadgeStatus.concluido;
    }

    return matchBusca && matchStatus;
  }).toList();

  if (isRecente) {
    listaFiltrada.sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
  } else {
    listaFiltrada.sort((a, b) => a.criadoEm.compareTo(b.criadoEm));
  }

  return listaFiltrada;
});

// Busca o ID da empresa do usuário logado para lógica de permissões
final loggedUserCompanyIdProvider = FutureProvider.autoDispose<String?>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) return null;

  final usuarioData = await supabase
      .from('usuarios')
      .select('empresa_id')
      .eq('id', userId)
      .maybeSingle();

  return usuarioData?['empresa_id'];
});

// Busca a empresa do usuário logado e adiciona a coluna na query
final projectDetailProvider = FutureProvider.autoDispose.family<ProjetoModel, String>((ref, id) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  // Descobre a empresa logada
  final user = await supabase.from('usuarios').select('empresa_id').eq('id', userId!).maybeSingle();
  final minhaEmpresaId = user?['empresa_id'];
  
  final response = await supabase
      .from('projetos')
      .select('''
          *,
          prioridade(nome),
          status_projeto(nome),
          empresas!projetos_empresa_gestora_id_fkey(nome, foto_url),
          empresa_cliente:empresas!projetos_empresa_cliente_id_fkey(nome),
          projeto_equipe_interna(
            empresa_id,
            usuarios(foto_url)
          )
        ''') 
      // 🔥 A MÁGICA AQUI: Filtra direto no banco quem é ativo e da empresa
      .eq('projeto_equipe_interna.empresa_id', minhaEmpresaId)
      .eq('projeto_equipe_interna.ativo', true)
      .eq('id', id)
      .single();
      
  return ProjetoModel.fromMap(response, minhaEmpresaId: minhaEmpresaId);
});