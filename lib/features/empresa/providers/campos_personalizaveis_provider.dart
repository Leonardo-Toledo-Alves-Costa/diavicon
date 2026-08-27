import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ID Fixo da Diavicon (Matriz)
const String DIAVICON_EMPRESA_ID = '96b9a6b9-32d0-453e-9f69-74a2691ac5cc';

// ==========================================
// 1. MODEL GENÉRICO PARA TABELAS
// ==========================================
class CampoItemModel {
  final String id;
  final String nome;
  final String? descricao;
  final String? empresaId;
  final String? sistemaId;

  CampoItemModel({
    required this.id,
    required this.nome,
    this.descricao,
    this.empresaId,
    this.sistemaId,
  });

  factory CampoItemModel.fromMap(Map<String, dynamic> map) {
    return CampoItemModel(
      id: map['id'].toString(),
      nome: map['nome']?.toString() ?? '',
      descricao: map.containsKey('descricao') ? map['descricao']?.toString() : null,
      empresaId: map.containsKey('empresa_id') ? map['empresa_id']?.toString() : null,
      sistemaId: map.containsKey('sistemas_id') ? map['sistemas_id']?.toString() : null,
    );
  }

  bool isPadrao() {
    return empresaId == DIAVICON_EMPRESA_ID;
  }

  bool canEdit(String currentEmpresaId) {
    if (currentEmpresaId == DIAVICON_EMPRESA_ID) {
      return true;
    }
    return !isPadrao() && empresaId == currentEmpresaId;
  }
}

// ==========================================
// 2. ESTADOS DOS FILTROS
// ==========================================
class CampoSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setBusca(String val) => state = val;
}
final campoSearchProvider = NotifierProvider<CampoSearchNotifier, String>(CampoSearchNotifier.new);

class CampoFilterNotifier extends Notifier<String> {
  @override
  String build() => 'Todos'; 
  void setFiltro(String val) => state = val;
}
final campoFilterProvider = NotifierProvider<CampoFilterNotifier, String>(CampoFilterNotifier.new);

// NOVO: Controle de Estado para o Filtro de Sistema Estrutural
class SistemaFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setFiltro(String? val) => state = val;
}
final sistemaFilterProvider = NotifierProvider<SistemaFilterNotifier, String?>(SistemaFilterNotifier.new);

// ==========================================
// 3. PROVIDER DE LISTAGEM GENÉRICA
// ==========================================
typedef CamposParams = ({String tabela, String empresaId});

final camposListProvider = FutureProvider.family.autoDispose<List<CampoItemModel>, CamposParams>((ref, params) async {
  final tabela = params.tabela;
  final empresaId = params.empresaId;
  
  final busca = ref.watch(campoSearchProvider).toLowerCase();
  final filtro = ref.watch(campoFilterProvider);
  final filtroSistema = ref.watch(sistemaFilterProvider); // Escuta o filtro selecionado

  try {
    final response = await Supabase.instance.client
        .from(tabela)
        .select('*')
        .or('empresa_id.eq.$empresaId, empresa_id.eq.$DIAVICON_EMPRESA_ID')
        .order('nome', ascending: true);

    var lista = response.map((e) => CampoItemModel.fromMap(e)).toList();

    // 1. Filtragem básica de segurança (Apenas da empresa ou Diavicon)
    lista = lista.where((item) {
      return item.empresaId == empresaId || item.isPadrao();
    }).toList();

    // 2. Filtragem de Busca
    if (busca.isNotEmpty) {
      lista = lista.where((item) => item.nome.toLowerCase().contains(busca)).toList();
    }

    // 3. Filtragem de Tipos (Todos, Padrão, Criados)
    if (filtro == 'Padrão') {
      lista = lista.where((item) => item.isPadrao()).toList();
    } else if (filtro == 'Criados') {
      lista = lista.where((item) => !item.isPadrao()).toList();
    }

    // 4. Filtragem específica para Tipos de Elemento baseado no Sistema Habitacional
    if (tabela == 'tipos_elemento' && filtroSistema != null) {
      lista = lista.where((item) => item.sistemaId == filtroSistema).toList();
    }

    return lista;
  } on PostgrestException catch (e) {
    throw Exception('Erro de banco de dados ao carregar $tabela: ${e.message}');
  } on AuthException catch (e) {
    throw Exception('Erro de autenticação: ${e.message}');
  } catch (e) {
    throw Exception('Erro inesperado: $e');
  }
});