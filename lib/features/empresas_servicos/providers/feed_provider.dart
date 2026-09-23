import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Semente do embaralhamento da lista de serviços.
///
/// A ordem é aleatória para dar visibilidade rotativa às empresas, mas a
/// semente precisa ser ESTÁVEL enquanto a tela está aberta: o provider de
/// serviços re-executa a cada tecla digitada na busca e a cada troca de
/// filtro, e uma semente nova a cada execução faria a lista dançar embaixo
/// do dedo do usuário. [renovar] é chamado ao entrar na tela — é isso que
/// dá uma ordem diferente a cada visita.
class FeedServicosSeedNotifier extends Notifier<int> {
  @override
  int build() => DateTime.now().millisecondsSinceEpoch;

  void renovar() => state = DateTime.now().millisecondsSinceEpoch;
}

final feedServicosSeedProvider =
    NotifierProvider<FeedServicosSeedNotifier, int>(FeedServicosSeedNotifier.new);

// ==========================================
// 3. REGRAS DE NEGÓCIO E QUERIES
// ==========================================
int _asInt(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;

final feedEmpresasProvider = FutureProvider.autoDispose<List<EmpresaFeedModel>>((ref) async {
  final search = ref.watch(feedSearchProvider).trim();
  final filter = ref.watch(feedFilterEmpresaProvider);

  try {
    final response = await Supabase.instance.client.rpc(
      'list_public_companies',
      params: {
        'p_search': search.isEmpty ? null : search,
        'p_ramo': filter == null || filter == 'Todos' ? null : filter,
        'p_limit': 100,
        'p_offset': 0,
      },
    );
    return (response as List).whereType<Map>().map((raw) {
      final e = Map<String, dynamic>.from(raw);
      return EmpresaFeedModel(
        id: e['empresa_id'].toString(),
        nome: e['nome']?.toString() ?? 'Empresa sem nome',
        descricao: e['descricao']?.toString(),
        fotoUrl: e['foto_url']?.toString(),
        fotoCapa: e['foto_capa']?.toString(),
        ramoAtuacao: e['ramo_atuacao']?.toString(),
        cidade: e['cidade']?.toString(),
        estado: e['estado']?.toString(),
        qtdServicos: _asInt(e['qtd_servicos']),
      );
    }).toList();
  } on PostgrestException catch (e) {
    throw Exception('Erro ao buscar empresas no banco de dados: ${e.message}');
  }
});

final feedServicosProvider = FutureProvider.autoDispose<List<ServicoFeedModel>>((ref) async {
  final search = ref.watch(feedSearchProvider).trim();
  final filter = ref.watch(feedFilterServicoProvider);
  final seed = ref.watch(feedServicosSeedProvider);

  try {
    final response = await Supabase.instance.client.rpc(
      'list_public_company_services',
      params: {
        'p_empresa_id': null,
        'p_search': search.isEmpty ? null : search,
        'p_categoria': filter == null || filter == 'Todos' ? null : filter,
        'p_limit': 100,
        'p_offset': 0,
      },
    );
    return (response as List).whereType<Map>().map((raw) {
      final e = Map<String, dynamic>.from(raw);
      return ServicoFeedModel(
        id: e['servico_id'].toString(),
        nome: e['nome']?.toString() ?? 'Serviço sem nome',
        objetivo: e['objetivo']?.toString(),
        fotoPrincipal: e['foto_principal']?.toString(),
        categoria: e['categoria']?.toString(),
        linkAnexo: e['link_anexo']?.toString(),
        nomeAnexo: e['nome_anexo']?.toString(),
        descricao: e['descricao']?.toString(),
        empresaNome: e['empresa_nome']?.toString() ?? 'Empresa desconhecida',
        empresaFotoUrl: e['empresa_foto_url']?.toString(),
        cidade: e['cidade']?.toString(),
        estado: e['estado']?.toString(),
      );
    }).toList()
      // Ordem rotativa: sem isso, quem aparece no topo hoje aparece no topo
      // sempre, e as últimas empresas da lista nunca são vistas.
      ..shuffle(Random(seed));
  } on PostgrestException catch (e) {
    throw Exception('Erro ao buscar serviços/produtos: ${e.message}');
  }
});
