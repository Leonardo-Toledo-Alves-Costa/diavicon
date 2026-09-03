import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==========================================
// 1. MODELS
// ==========================================
class ServicoEmpresaModel {
  final String id;
  final String empresaId;
  final String nome;
  final String? descricao;
  final String? objetivo;
  final String? categoria;
  final String? fotoPrincipal;
  final String? linkAnexo;
  final String? nomeAnexo; // 🔥 Novo campo baseado no seu layout do Figma

  ServicoEmpresaModel({
    required this.id,
    required this.empresaId,
    required this.nome,
    this.descricao,
    this.objetivo,
    this.categoria,
    this.fotoPrincipal,
    this.linkAnexo,
    this.nomeAnexo,
  });

  factory ServicoEmpresaModel.fromMap(Map<String, dynamic> map) {
    return ServicoEmpresaModel(
      id: map['id'],
      empresaId: map['empresa_id'],
      nome: map['nome'],
      descricao: map['descricao'],
      objetivo: map['objetivo'],
      categoria: map['categoria'],
      fotoPrincipal: map['foto_principal'],
      linkAnexo: map['link_anexo'],
      nomeAnexo: map['nome_anexo'],
    );
  }
}

class ServicoGaleriaModel {
  final String id;
  final String servicoId;
  final String fotoUrl;

  ServicoGaleriaModel({required this.id, required this.servicoId, required this.fotoUrl});

  factory ServicoGaleriaModel.fromMap(Map<String, dynamic> map) {
    return ServicoGaleriaModel(
      id: map['id'],
      servicoId: map['servico_id'],
      fotoUrl: map['foto_url'],
    );
  }
}

// ==========================================
// 2. CONTROLES DE ESTADO (Filtros da Lista)
// ==========================================
class PainelServicoSearchNotifier extends Notifier<String> {
  @override String build() => '';
  void setBusca(String val) => state = val;
}
final painelServicoSearchProvider = NotifierProvider<PainelServicoSearchNotifier, String>(PainelServicoSearchNotifier.new);

class PainelServicoFilterNotifier extends Notifier<String?> {
  @override String? build() => null;
  void setFiltro(String? val) => state = val;
}
final painelServicoFilterProvider = NotifierProvider<PainelServicoFilterNotifier, String?>(PainelServicoFilterNotifier.new);

// ==========================================
// 3. PROVIDERS DE DADOS (Supabase)
// ==========================================
final painelServicosListProvider = FutureProvider.family.autoDispose<List<ServicoEmpresaModel>, String>((ref, empresaId) async {
  final busca = ref.watch(painelServicoSearchProvider).trim();
  final filtro = ref.watch(painelServicoFilterProvider);

  try {
    var query = Supabase.instance.client
        .from('empresa_servicos')
        .select('*')
        .eq('empresa_id', empresaId);

    if (busca.isNotEmpty) query = query.ilike('nome', '%$busca%');
    if (filtro != null && filtro != 'Todos') query = query.eq('categoria', filtro);

    final response = await query.order('criado_em', ascending: false);
    return response.map((e) => ServicoEmpresaModel.fromMap(e)).toList();
  } on PostgrestException catch (e) {
    throw Exception('Erro ao buscar serviços: ${e.message}');
  }
});

final servicoGaleriaProvider = FutureProvider.family.autoDispose<List<ServicoGaleriaModel>, String>((ref, servicoId) async {
  try {
    final response = await Supabase.instance.client.rpc(
      'list_public_service_gallery',
      params: {'p_servico_id': servicoId},
    );
        
    return (response as List)
        .whereType<Map>()
        .map((e) => ServicoGaleriaModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  } on PostgrestException catch (e) {
    throw Exception('Erro ao carregar galeria: ${e.message}');
  }
});
