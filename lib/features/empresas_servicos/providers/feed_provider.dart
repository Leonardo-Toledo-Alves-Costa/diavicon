import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';

// ==========================================
// 1. MODELS
// ==========================================
class EmpresaFeedModel {
  final String id;
  final String nome;
  final String? descricao;
  final String? fotoUrl;
  final String? fotoCapa;
  final String? ramoAtuacao;
  final String? cidade;
  final String? estado;
  final int qtdServicos;

  EmpresaFeedModel({
    required this.id, required this.nome, this.descricao, this.fotoUrl,
    this.fotoCapa, this.ramoAtuacao, this.cidade, this.estado, required this.qtdServicos,
  });
}

class ServicoFeedModel {
  final String id;
  final String nome;
  final String? objetivo;
  final String? fotoPrincipal;
  final String? categoria;
  final String? linkAnexo;
  final String empresaNome;
  final String? empresaFotoUrl;
  final String? cidade;
  final String? estado;
  final String? nomeAnexo;
  final String? descricao;

  ServicoFeedModel({
    required this.id, required this.nome, this.objetivo, this.fotoPrincipal, this.nomeAnexo, this.descricao,
    this.categoria, this.linkAnexo, required this.empresaNome, this.empresaFotoUrl,
    this.cidade, this.estado,
  });
}

// ==========================================
// 2. NOTIFIERS (Riverpod 3.x - Substitutos do StateProvider)
// ==========================================
class FeedTabNotifier extends Notifier<int> {
  @override int build() => 0;
  void set(int index) => state = index;
}
final feedTabProvider = NotifierProvider<FeedTabNotifier, int>(FeedTabNotifier.new);

class FeedSearchNotifier extends Notifier<String> {
  @override String build() => '';
  void updateBusca(String val) => state = val;
}
final feedSearchProvider = NotifierProvider<FeedSearchNotifier, String>(FeedSearchNotifier.new);

class FeedFilterEmpresaNotifier extends Notifier<String?> {
  @override String? build() => null;
  void setFiltro(String? val) => state = val;
}
final feedFilterEmpresaProvider = NotifierProvider<FeedFilterEmpresaNotifier, String?>(FeedFilterEmpresaNotifier.new);

class FeedFilterServicoNotifier extends Notifier<String?> {
  @override String? build() => null;
  void setFiltro(String? val) => state = val;
}
final feedFilterServicoProvider = NotifierProvider<FeedFilterServicoNotifier, String?>(FeedFilterServicoNotifier.new);

// ==========================================
// 3. REGRAS DE NEGÓCIO E QUERIES
// ==========================================
int _calcularPesoDistancia(String? cid, String? est, String? userCid, String? userEst) {
  if (cid == null || est == null || userCid == null || userEst == null) return 3;
  if (cid.toLowerCase() == userCid.toLowerCase() && est.toLowerCase() == userEst.toLowerCase()) return 1;
  if (est.toLowerCase() == userEst.toLowerCase()) return 2;
  return 3;
}

final feedEmpresasProvider = FutureProvider.autoDispose<List<EmpresaFeedModel>>((ref) async {
  final search = ref.watch(feedSearchProvider).trim();
  final filter = ref.watch(feedFilterEmpresaProvider);
  final user = ref.watch(currentUserProvider);
  final supabase = Supabase.instance.client;

  try {
    String? userCidade, userEstado;
    
    // 🔥 Uso seguro do maybeSingle() para bancos vazios
    if (user?.enderecoId != null) {
      final userEnd = await supabase
          .from('enderecos')
          .select('cidade, estado')
          .eq('id', user!.enderecoId!)
          .maybeSingle(); 
          
      userCidade = userEnd?['cidade'] as String?;
      userEstado = userEnd?['estado'] as String?;
    }

    var query = supabase.from('empresas').select('*, enderecos(cidade, estado), empresa_servicos(id)');
    
    if (search.isNotEmpty) query = query.ilike('nome', '%$search%');
    if (filter != null && filter != 'Todos') query = query.eq('ramo_atuacao', filter);

    final response = await query;

    // Se o banco estiver vazio, response será [], e o .map retornará uma lista vazia sem quebrar.
    List<EmpresaFeedModel> empresas = response.map((e) {
      final endereco = e['enderecos'] as Map<String, dynamic>?;
      final servicos = e['empresa_servicos'] as List<dynamic>?;
      return EmpresaFeedModel(
        id: e['id'], 
        nome: e['nome'] ?? 'Empresa sem nome', 
        descricao: e['descricao'],
        fotoUrl: e['foto_url'], 
        fotoCapa: e['foto_capa'], 
        ramoAtuacao: e['ramo_atuacao'],
        cidade: endereco?['cidade'], 
        estado: endereco?['estado'], 
        qtdServicos: servicos?.length ?? 0,
      );
    }).toList();

    empresas.sort((a, b) {
      int pesoA = _calcularPesoDistancia(a.cidade, a.estado, userCidade, userEstado);
      int pesoB = _calcularPesoDistancia(b.cidade, b.estado, userCidade, userEstado);
      if (pesoA != pesoB) return pesoA.compareTo(pesoB);
      return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
    });
    
    return empresas;
    
  } on PostgrestException catch (e) {
    throw Exception('Erro ao buscar empresas no banco de dados: ${e.message}');
  } on AuthException catch (e) {
    throw Exception('Sessão expirada: ${e.message}');
  }
});

final feedServicosProvider = FutureProvider.autoDispose<List<ServicoFeedModel>>((ref) async {
  final search = ref.watch(feedSearchProvider).trim();
  final filter = ref.watch(feedFilterServicoProvider);
  final user = ref.watch(currentUserProvider);
  final supabase = Supabase.instance.client;

  try {
    String? userCidade, userEstado;
    
    // 🔥 Uso seguro do maybeSingle()
    if (user?.enderecoId != null) {
      final userEnd = await supabase
          .from('enderecos')
          .select('cidade, estado')
          .eq('id', user!.enderecoId!)
          .maybeSingle();
          
      userCidade = userEnd?['cidade'] as String?;
      userEstado = userEnd?['estado'] as String?;
    }

    // A cláusula !inner garante que só traga serviços que tenham uma empresa vinculada
    var query = supabase.from('empresa_servicos').select('*, empresas!inner(nome, foto_url, enderecos(cidade, estado))');
    
    if (search.isNotEmpty) query = query.ilike('nome', '%$search%');
    if (filter != null && filter != 'Todos') query = query.eq('categoria', filter);

    final response = await query;

    List<ServicoFeedModel> servicos = response.map((e) {
      final empresaData = e['empresas'] as Map<String, dynamic>? ?? {};
      final endereco = empresaData['enderecos'] as Map<String, dynamic>?;
      
      return ServicoFeedModel(
        id: e['id'], 
        nome: e['nome'] ?? 'Serviço sem nome', 
        objetivo: e['objetivo'],
        fotoPrincipal: e['foto_principal'], 
        categoria: e['categoria'], 
        linkAnexo: e['link_anexo'],
        nomeAnexo: e['nome_anexo'],
        descricao: e['descricao'],
        empresaNome: empresaData['nome'] ?? 'Empresa desconhecida', 
        empresaFotoUrl: empresaData['foto_url'],
        cidade: endereco?['cidade'], 
        estado: endereco?['estado'],
      );
    }).toList();

    servicos.sort((a, b) {
      int pesoA = _calcularPesoDistancia(a.cidade, a.estado, userCidade, userEstado);
      int pesoB = _calcularPesoDistancia(b.cidade, b.estado, userCidade, userEstado);
      if (pesoA != pesoB) return pesoA.compareTo(pesoB);
      return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
    });
    
    return servicos;
    
  } on PostgrestException catch (e) {
    throw Exception('Erro ao buscar serviços/produtos: ${e.message}');
  }
});