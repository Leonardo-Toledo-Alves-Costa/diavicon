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

  // 🔥 A MUDANÇA ESTÁ AQUI: Agora ele SÓ busca se o Gestor tiver marcado o checkbox (ativo = true)
  final colaboradoresData = await supabase
      .from('projeto_empresas_colaboradoras')
      .select('projeto_id')
      .eq('empresa_id', minhaEmpresaId)
      .eq('status', 'aceito');

  final List<String> projetosComoColaborador = colaboradoresData
      .map((e) => e['projeto_id'].toString())
      .toList();

  String filtroOr =
      'empresa_gestora_id.eq.$minhaEmpresaId,empresa_cliente_id.eq.$minhaEmpresaId';
  if (projetosComoColaborador.isNotEmpty) {
    filtroOr += ',id.in.(${projetosComoColaborador.join(',')})';
  }

  final response = await supabase
      .from('projetos')
      .select('''
        *,
        prioridade(nome),
        status_projeto(nome),
        empresas!projetos_empresa_gestora_id_fkey(nome),
        empresa_cliente:empresas!projetos_empresa_cliente_id_fkey(nome)
      ''')
      .or(filtroOr);

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
