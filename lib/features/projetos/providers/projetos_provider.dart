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

  final usuarioData = await supabase
      .from('usuarios')
      .select('empresa_id')
      .eq('id', userId)
      .maybeSingle();

  final minhaEmpresaId = usuarioData?['empresa_id'];

  if (minhaEmpresaId == null) return [];

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
        empresas!projetos_empresa_gestora_id_fkey(nome),
        empresa_cliente:empresas!projetos_empresa_cliente_id_fkey(nome)
      ''');

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

  List<ProjetoModel> todosProjetos = (response as List).map((json) {
    return ProjetoModel.fromMap(json);
  }).toList();

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


final projectDetailProvider = FutureProvider.autoDispose
    .family<ProjetoModel, String>((ref, id) async {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('projetos')
          .select('''
        *,
        prioridade(nome),
        status_projeto(nome),
        empresas!projetos_empresa_gestora_id_fkey(nome),
        empresa_cliente:empresas!projetos_empresa_cliente_id_fkey(nome)
      ''')
          .eq('id', id)
          .single();

      return ProjetoModel.fromMap(response);
    });
