import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/estrutura_repository.dart';
import '../models/estrutura_model.dart';

// --- REPOSITORY PROVIDER ---
final estruturaRepositoryProvider = Provider<EstruturaRepository>((ref) {
  return EstruturaRepository(Supabase.instance.client);
});

// --- PROVIDER: ESTRUTURAS DO PROJETO (VINCULADAS) ---
final projetoEstruturasProvider = StreamProvider.family<List<EstruturaModel>, String>((ref, projetoId) {
  final supabase = Supabase.instance.client;
  final repo = ref.watch(estruturaRepositoryProvider);

  // O Supabase vigia a tabela de ligação. Sempre que houver INSERT ou DELETE nela,
  // esse fluxo dispara e nós chamamos o repo.buscarEstruturasPorProjeto()
  return supabase
      .from('projeto_estruturas')
      .stream(primaryKey: ['projeto_id', 'estrutura_id'])
      .eq('projeto_id', projetoId)
      .asyncMap((event) => repo.buscarEstruturasPorProjeto(projetoId));
});

// --- PROVIDER: TODAS AS ESTRUTURAS DA PLATAFORMA ---
final todasEstruturasProvider = StreamProvider.autoDispose<List<EstruturaModel>>((ref) {
  final supabase = Supabase.instance.client;
  
  return supabase
      .from('estruturas')
      .stream(primaryKey: ['id'])
      .asyncMap((_) async {
        // 👇 O .select() COM OS JOINS ENTRA AQUI 👇
        final response = await supabase
            .from('estruturas')
            .select('''
              *,
              conjuntos_estruturais(nome),
              utilizacoes_estrutura(nome),
              tipos_estrutura(nome),
              tipologias_estrutura(nome)
            ''')
            .order('criado_em', ascending: false);

        return response.map((item) => EstruturaModel.fromJson(item)).toList();
      });
});


/// --- PROVIDER: APENAS AS ESTRUTURAS QUE A EMPRESA TEM ACESSO FILTRADAS PELO DONO DO PROJETO ---
final minhasEstruturasProvider = StreamProvider.autoDispose.family<List<EstruturaModel>, String>((ref, projetoId) {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) {
    return Stream.value([]);
  }

  return supabase
      .from('estruturas')
      .stream(primaryKey: ['id'])
      .asyncMap((_) async {
        // 1. Descobre a empresa do usuário logado 
        final usuarioData = await supabase
            .from('usuarios')
            .select('empresa_id')
            .eq('id', userId)
            .maybeSingle();
        final minhaEmpresaId = usuarioData?['empresa_id'];
        if (minhaEmpresaId == null) return [];

        // 2. Descobre quem é o proprietário (Dono/Cliente) do projeto atual
        final projData = await supabase
            .from('projetos')
            .select('empresa_cliente_id, empresa_gestora_id')
            .eq('id', projetoId)
            .maybeSingle();
            
        // Se o projeto não tiver um cliente definido, o dono é a própria gestora
        final donoProjetoId = projData?['empresa_cliente_id'] ?? projData?['empresa_gestora_id'];
        if (donoProjetoId == null) return [];

        // 3. Busca as estruturas aplicando o filtro duplo cruzado
        final response = await supabase
            .from('estruturas')
            .select('''
              *,
              conjuntos_estruturais(nome),
              utilizacoes_estrutura(nome),
              tipos_estrutura(nome),
              tipologias_estrutura(nome)
            ''')
            // REGRA A: A estrutura DEVE pertencer ao mesmo proprietário do projeto 
            .eq('proprietaria_id', donoProjetoId)
            // REGRA B: A sua empresa deve ser a gestora OU a proprietária dela para ter acesso
            .or('empresa_gestora_id.eq.$minhaEmpresaId,proprietaria_id.eq.$minhaEmpresaId')
            .order('criado_em', ascending: false);

        return response.map((item) => EstruturaModel.fromJson(item)).toList();
      });
});