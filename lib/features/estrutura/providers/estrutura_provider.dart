import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/estrutura_repository.dart';
import '../models/estrutura_model.dart';
import '../../projetos/models/projeto_model.dart';



// --- REPOSITORY PROVIDER ---
final estruturaRepositoryProvider = Provider<EstruturaRepository>((ref) {
  return EstruturaRepository(Supabase.instance.client);
});

//  ESTRUTURAS DO PROJETO (VINCULADAS) 
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

final estruturasDoProjetoProvider = FutureProvider.autoDispose.family<List<EstruturaModel>, String>((ref, projetoId) async {
  final repository = ref.read(estruturaRepositoryProvider);
  
  // Chama a função que já está pronta lá no EstruturaRepository
  return await repository.buscarEstruturasPorProjeto(projetoId);
});

final estruturaResumoProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, id) async {
  final resp = await Supabase.instance.client
      .from('estruturas')
      .select('nome, image_url, conjuntos_estruturais(nome)')
      .eq('id', id)
      .maybeSingle();
  return resp;
});

// --- PROVIDER: TODAS AS ESTRUTURAS DA PLATAFORMA ---
final todasEstruturasProvider = StreamProvider.autoDispose<List<EstruturaModel>>((ref) {
  final supabase = Supabase.instance.client;
  
  return supabase
      .from('estruturas')
      .stream(primaryKey: ['id'])
      .asyncMap((_) async {
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

// --- PROVIDER: ESTRUTURAS DA ABA PRINCIPAL (aba "Estruturas"/monitor) ---
// Lista as estruturas que a empresa logada GERENCIA (empresa_gestora_id) —
// diferente de "proprietaria_id", que é quem é dona da estrutura (ver
// funcionalidade de trocar propriedade). O monitoramento é por gestão.
// Só entram aqui as estruturas marcadas como `monitorada = true` (consome
// um token do plano — ver tokens_estrutura_provider.dart) — isso também
// habilita as funcionalidades futuras de monitoramento.
final estruturasDaMinhaEmpresaProvider = StreamProvider.autoDispose<List<EstruturaModel>>((ref) {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) return Stream.value([]);

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

        // 2. Busca APENAS as estruturas onde minha empresa é a gestora
        final response = await supabase
            .from('estruturas')
            .select('''
              *,
              conjuntos_estruturais(nome),
              utilizacoes_estrutura(nome),
              tipos_estrutura(nome),
              tipologias_estrutura(nome)
            ''')
            .eq('empresa_gestora_id', minhaEmpresaId)
            .eq('monitorada', true)
            .order('criado_em', ascending: false);

        return response.map((item) => EstruturaModel.fromJson(item)).toList();
      });
});

// --- PROVIDER: TODAS AS ESTRUTURAS DA EMPRESA (monitoradas ou não) ---
// Igual a `estruturasDaMinhaEmpresaProvider`, mas sem o filtro `monitorada`
// — usado pra navegação por Conjunto Estrutural (ver estruturas_tab_screen.dart),
// que precisa listar TODAS as estruturas de um conjunto e mostrar se cada
// uma é monitorada ou não.
final todasEstruturasDaMinhaEmpresaProvider = StreamProvider.autoDispose<List<EstruturaModel>>((ref) {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) return Stream.value([]);

  return supabase
      .from('estruturas')
      .stream(primaryKey: ['id'])
      .asyncMap((_) async {
        final usuarioData = await supabase
            .from('usuarios')
            .select('empresa_id')
            .eq('id', userId)
            .maybeSingle();
        final minhaEmpresaId = usuarioData?['empresa_id'];

        if (minhaEmpresaId == null) return [];

        final response = await supabase
            .from('estruturas')
            .select('''
              *,
              conjuntos_estruturais(nome),
              utilizacoes_estrutura(nome),
              tipos_estrutura(nome),
              tipologias_estrutura(nome)
            ''')
            .eq('empresa_gestora_id', minhaEmpresaId)
            .order('criado_em', ascending: false);

        return response.map((item) => EstruturaModel.fromJson(item)).toList();
      });
});

// --- PROVIDER: CONTADORES DINÂMICOS DO PREVIEW DA ESTRUTURA ---
typedef EstruturaEstatisticas = ({int elementos, int ensaios, int projetos});

final estruturaEstatisticasProvider = FutureProvider.autoDispose.family<EstruturaEstatisticas, String>((ref, estruturaId) async {
  final supabase = Supabase.instance.client;

  final results = await Future.wait([
    supabase.from('elementos_estruturais').select('id').eq('estrutura_id', estruturaId).count(CountOption.exact),
    supabase.from('pontos_ensaios_geral').select('id').eq('estrutura_id', estruturaId).count(CountOption.exact),
    supabase.from('projeto_estruturas').select('estrutura_id').eq('estrutura_id', estruturaId).count(CountOption.exact),
  ]);

  return (
    elementos: results[0].count,
    ensaios: results[1].count,
    projetos: results[2].count,
  );
});

// --- PROVIDER: PROJETOS EM QUE A ESTRUTURA ESTÁ SENDO TRABALHADA ---
final projetosPorEstruturaProvider = FutureProvider.autoDispose.family<List<ProjetoModel>, String>((ref, estruturaId) async {
  final supabase = Supabase.instance.client;

  final response = await supabase
      .from('projeto_estruturas')
      .select('''
        projetos(
          *,
          prioridade:prioridade_id(nome),
          status_projeto:status_id(nome)
        )
      ''')
      .eq('estrutura_id', estruturaId);

  return (response as List)
      .where((item) => item['projetos'] != null)
      .map((item) => ProjetoModel.fromMap(item['projetos']))
      .toList();
});