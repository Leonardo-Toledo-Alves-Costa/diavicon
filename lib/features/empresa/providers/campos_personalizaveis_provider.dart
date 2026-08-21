import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==========================================
// 1. MODEL GENÉRICO PARA TABELAS
// ==========================================
class CampoItemModel {
  final String id;
  final String nome;
  final String? descricao;
  final String? empresaId;

  CampoItemModel({
    required this.id,
    required this.nome,
    this.descricao,
    this.empresaId,
  });

  factory CampoItemModel.fromMap(Map<String, dynamic> map) {
    return CampoItemModel(
      id: map['id'].toString(),
      nome: map['nome']?.toString() ?? '',
      descricao: map.containsKey('descricao') ? map['descricao']?.toString() : null,
      empresaId: map.containsKey('empresa_id') ? map['empresa_id']?.toString() : null,
    );
  }

  // Se não possuir empresa_id atrelado ou for diferente da empresa atual, é Padrão (Diavicon)
  bool isPadrao(String currentEmpresaId) {
    return empresaId == null || empresaId != currentEmpresaId;
  }
}

// ==========================================
// 2. ESTADOS (Usando StateProvider)
// ==========================================

class CampoSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setBusca(String val) {
    state = val;
  }
}

final campoSearchProvider = NotifierProvider<CampoSearchNotifier, String>(
  CampoSearchNotifier.new,
);

class CampoFilterNotifier extends Notifier<String> {
  @override
  String build() => 'Todos'; // 'Todos', 'Padrão', 'Criados'

  void setFiltro(String val) {
    state = val;
  }
}

final campoFilterProvider = NotifierProvider<CampoFilterNotifier, String>(
  CampoFilterNotifier.new,
);
// ==========================================
// 3. PROVIDER DE LISTAGEM GENÉRICA
// ==========================================
final camposListProvider = FutureProvider.family.autoDispose<List<CampoItemModel>, Map<String, String>>((ref, params) async {
  final tabela = params['tabela']!;
  final empresaId = params['empresaId']!;
  
  final busca = ref.watch(campoSearchProvider).toLowerCase();
  final filtro = ref.watch(campoFilterProvider);

  try {
    final response = await Supabase.instance.client
        .from(tabela)
        .select('*')
        .order('nome', ascending: true);

    var lista = response.map((e) => CampoItemModel.fromMap(e)).toList();

    // Aplica Filtro de Busca (Texto)
    if (busca.isNotEmpty) {
      lista = lista.where((item) => item.nome.toLowerCase().contains(busca)).toList();
    }

    // Aplica Filtro de Categoria (Padrão/Criados)
    if (filtro == 'Padrão') {
      lista = lista.where((item) => item.isPadrao(empresaId)).toList();
    } else if (filtro == 'Criados') {
      lista = lista.where((item) => !item.isPadrao(empresaId)).toList();
    }

    return lista;
  } on PostgrestException catch (e) {
    throw Exception('Erro ao carregar $tabela: ${e.message}');
  }
});