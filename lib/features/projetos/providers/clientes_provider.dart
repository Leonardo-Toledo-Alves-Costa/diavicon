import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';
import 'projeto_form_provider.dart';

// Busca a carteira de clientes no Supabase
final clientesListaProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final usuarioLogado = ref.watch(currentUserProvider);
  if (usuarioLogado == null || usuarioLogado.empresaId == null) return [];

  final String minhaEmpresaId = usuarioLogado.empresaId!; 
  final supabase = Supabase.instance.client;

  final data = await supabase
      .from('empresa_clientes')
      .select('cliente_id, empresas!cliente_id (id, nome)')
      .eq('gestora_id', minhaEmpresaId);

  final List<Map<String, dynamic>> lista = data.map((vinculo) {
    final empresaInfo = vinculo['empresas'] as Map<String, dynamic>;
    return {'id': empresaInfo['id'], 'nome': empresaInfo['nome']};
  }).toList();

  lista.insert(0, {'id': minhaEmpresaId, 'nome': 'Minha Empresa'});
  return lista;
});

// Ele observa a lista do banco E o rascunho. Se o cliente da busca global não estiver
// na lista, ele o injeta aqui antes de mandar para a UI.
final dropdownClientesProvider = Provider.autoDispose<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final listaAsync = ref.watch(clientesListaProvider);
  final rascunho = ref.watch(projetoFormProvider);

  return listaAsync.whenData((clientesDoBanco) {
    //cópia da lista
    List<Map<String, dynamic>> listaFinal = List.from(clientesDoBanco);

    // Verificamos se existe um cliente no rascunho que NÃO está na lista do banco
    if (rascunho.clienteId != null && rascunho.clienteNome != null) {
      final bool jaExiste = listaFinal.any((c) => c['id'] == rascunho.clienteId);
      
      if (!jaExiste) {
        // Injeta o cliente da busca global na lista para o Dropdown não quebrar
        listaFinal.add({
          'id': rascunho.clienteId,
          'nome': rascunho.clienteNome,
        });
      }
    }
    return listaFinal;
  });
});

//Provider de Busca Global (Lupa)
final buscarTodasEmpresasProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, termoBusca) async {
  if (termoBusca.trim().isEmpty) return [];
  final supabase = Supabase.instance.client;
  final data = await supabase
      .from('empresas')
      .select('id, nome, cnpj, foto_url, criado_em')
      .or('nome.ilike.%$termoBusca%,cnpj.ilike.%$termoBusca%')
      .limit(20);
  return List<Map<String, dynamic>>.from(data);
});