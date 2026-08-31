import 'package:diavicon/features/equipe/providers/equipe_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'projetos_provider.dart';

// Provider que escuta em tempo real as empresas colaboradoras no projeto
final empresasVinculadasProjetoProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, projetoId) {
  final supabase = Supabase.instance.client;
  
  return supabase
      .from('projeto_empresas_colaboradoras') 
      .stream(primaryKey: ['id'])
      .eq('projeto_id', projetoId)
      .asyncMap((maps) async {
        List<Map<String, dynamic>> listaCompleta = [];
        
        for (var vinculo in maps) {
          final empresaId = vinculo['empresa_id']; 
          
          try {
            final empData = await supabase
                .from('empresas')
                .select('id, nome, foto_url, enderecos(cidade, estado)')
                .eq('id', empresaId)
                .maybeSingle();
                
            if (empData != null) {
              final endereco = empData['enderecos'] is Map ? empData['enderecos'] : null;
              
              final int qtdColaboradores = await supabase
                  .from('projeto_equipe_interna')
                  .count(CountOption.exact)
                  .eq('projeto_id', projetoId)
                  .eq('empresa_id', empresaId)
                  .eq('ativo', true);
              
              listaCompleta.add({
                'id': empData['id'],
                'nome': empData['nome'] ?? 'Empresa Sem Nome',
                'foto_url': empData['foto_url'] ?? '',
                'cidade': endereco != null ? endereco['cidade'] ?? 'Não informada' : 'Não informada',
                'uf': endereco != null ? endereco['estado'] ?? '--' : '--',
                'status_vinculo': vinculo['status'], 
                'is_gestora': false,
                'convite_id': vinculo['id'], 
                'total_colaboradores': qtdColaboradores,
              });
            }
          } catch (e) {
            print('Erro ao buscar detalhes da empresa colaboradora: $e');
          }
        }
        return listaCompleta;
      });
});

final minhaEmpresaProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  // Acha qual é a empresa do usuário
  final userResp = await supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
  final empresaId = userResp?['empresa_id'];
  if (empresaId == null) return null;

  //  Busca os dados da empresa e o endereço dela
  final empResp = await supabase.from('empresas').select('*, enderecos(*)').eq('id', empresaId).maybeSingle();
  return empResp;
});

// Busca todas as empresas que participam do projeto: a gestora + as
// colaboradoras já aceitas + a empresa cliente (quando vinculada 'ativo') —
// usado tanto em TrocarGestoraBody (filtrando fora a gestora atual) quanto
// no fluxo de transferir a propriedade de uma estrutura (filtrando fora a
// proprietária atual).
final projetoEmpresasIntegrantesProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, projetoId) async {
  final supabase = Supabase.instance.client;

  Map<String, dynamic> mapearEmpresa(Map<String, dynamic> emp) {
    final enderecoData = emp['enderecos'];
    Map? endereco;
    if (enderecoData is List && enderecoData.isNotEmpty) {
      endereco = enderecoData.first;
    } else if (enderecoData is Map) {
      endereco = enderecoData;
    }

    return {
      'id': emp['id'],
      'nome': emp['nome'] ?? 'Sem Nome',
      'foto_url': emp['foto_url'],
      'cidade': endereco != null ? endereco['cidade'] : null,
      'estado': endereco != null ? endereco['estado'] : null,
    };
  }

  final colaboradoras = await supabase
      .from('projeto_empresas_colaboradoras')
      .select('empresas:empresa_id(id, nome, foto_url, enderecos(cidade, estado))')
      .eq('projeto_id', projetoId)
      .eq('status', 'aceito');

  final projeto = await supabase
      .from('projetos')
      .select('''
        empresa_cliente_id,
        status_vinculo_cliente,
        empresa_cliente:empresas!projetos_empresa_cliente_id_fkey(id, nome, foto_url, enderecos(cidade, estado)),
        empresa_gestora:empresas!projetos_empresa_gestora_id_fkey(id, nome, foto_url, enderecos(cidade, estado))
      ''')
      .eq('id', projetoId)
      .maybeSingle();

  final lista = colaboradoras.map((item) => mapearEmpresa(item['empresas'] as Map<String, dynamic>)).toList();

  void adicionarSeNovo(Map<String, dynamic> empresaMapeada) {
    final jaNaLista = lista.any((e) => e['id'] == empresaMapeada['id']);
    if (!jaNaLista) lista.add(empresaMapeada);
  }

  if (projeto != null && projeto['empresa_gestora'] != null) {
    adicionarSeNovo(mapearEmpresa(projeto['empresa_gestora'] as Map<String, dynamic>));
  }

  if (projeto != null && projeto['status_vinculo_cliente'] == 'ativo' && projeto['empresa_cliente'] != null) {
    adicionarSeNovo(mapearEmpresa(projeto['empresa_cliente'] as Map<String, dynamic>));
  }

  return lista;
});

// =========================================================================
// PROVIDER DE BUSCA DE EMPRESA COLABORADORA
// =========================================================================
final buscarEmpresaPorCnpjProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, filtro) async {
  final String filtroTrimmed = filtro.trim();
  if (filtroTrimmed.isEmpty) return null;
  
  final supabase = Supabase.instance.client;
  try {
    final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(filtroTrimmed);

    if (isUuid) {
      return await supabase.from('empresas').select('id, nome, cnpj, foto_url, enderecos(cidade, estado)').eq('id', filtroTrimmed).maybeSingle();
    }

    final String cnpjLimpo = filtroTrimmed.replaceAll(RegExp(r'[^0-9]'), '');
    String cnpjFormatado = filtroTrimmed;
    if (cnpjLimpo.length == 14) {
      cnpjFormatado = '${cnpjLimpo.substring(0,2)}.${cnpjLimpo.substring(2,5)}.${cnpjLimpo.substring(5,8)}/${cnpjLimpo.substring(8,12)}-${cnpjLimpo.substring(12,14)}';
    }

    var response = await supabase.from('empresas').select('id, nome, cnpj, foto_url, enderecos(cidade, estado)').eq('cnpj', cnpjFormatado).maybeSingle();

    response ??= await supabase.from('empresas').select('id, nome, cnpj, foto_url, enderecos(cidade, estado)').eq('cnpj', cnpjLimpo).maybeSingle();

    response ??= await supabase.from('empresas').select('id, nome, cnpj, foto_url, enderecos(cidade, estado)').eq('cnpj', filtroTrimmed).maybeSingle();

    return response;
    
  } catch (e) {
    debugPrint('🚨 Erro crítico na busca de empresa: $e');
    return null;
  }
});


// Controller para gerenciar a ação das empresas colaboradoras
final empresasProjetoControllerProvider = Provider((ref) => EmpresasProjetoController(ref));

class EmpresasProjetoController {
  final _supabase = Supabase.instance.client;
  final Ref _ref;

  EmpresasProjetoController(this._ref);

  Future<Map<String, dynamic>> buscarEmpresaParaPreview(String cnpj) async {
    final String filtroTrimmed = cnpj.trim();
    if (filtroTrimmed.isEmpty) {
      throw Exception('O CNPJ não pode estar vazio.');
    }

    final String cnpjLimpo = filtroTrimmed.replaceAll(RegExp(r'[^0-9]'), '');

    String cnpjFormatado = filtroTrimmed;
    if (cnpjLimpo.length == 14) {
      cnpjFormatado = '${cnpjLimpo.substring(0,2)}.${cnpjLimpo.substring(2,5)}.${cnpjLimpo.substring(5,8)}/${cnpjLimpo.substring(8,12)}-${cnpjLimpo.substring(12,14)}';
    }

    var empresa = await _supabase
        .from('empresas')
        .select('id, nome, foto_url, enderecos(cidade, estado)')
        .eq('cnpj', cnpjFormatado)
        .maybeSingle();

    empresa ??= await _supabase
          .from('empresas')
          .select('id, nome, foto_url, enderecos(cidade, estado)')
          .eq('cnpj', cnpjLimpo)
          .maybeSingle();

    empresa ??= await _supabase
          .from('empresas')
          .select('id, nome, foto_url, enderecos(cidade, estado)')
          .eq('cnpj', filtroTrimmed)
          .maybeSingle();

    if (empresa == null) {
      throw Exception('Nenhuma empresa encontrada com este CNPJ.');
    }
    
    return empresa;
  }

  Future<void> enviarConviteEmpresa({required String projetoId, required String empresaConvidadaId}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Sessão expirada. Faça login novamente.');

    // Verifica se já existe um convite ou se já é colaboradora
    final jaVinculada = await _supabase
        .from('projeto_empresas_colaboradoras') 
        .select('status')
        .eq('projeto_id', projetoId)
        .eq('empresa_id', empresaConvidadaId)   
        .maybeSingle();

    if (jaVinculada != null) {
      if (jaVinculada['status'] == 'aceito') {
        throw Exception('Esta empresa já é colaboradora ativa do projeto.');
      } else {
        throw Exception('Um convite pendente já foi enviado para esta empresa.');
      }
    }

    //  Cria o convite e pega o ID dele de volta
    final conviteResp = await _supabase.from('projeto_empresas_colaboradoras').insert({
      'projeto_id': projetoId,
      'empresa_id': empresaConvidadaId,
      'criado_por': userId,
      'status': 'pendente'
    }).select('id').single();

    final conviteId = conviteResp['id'];

    // busca as informações visuais para deixar a notificação bonita
    final projetoInfo = await _supabase.from('projetos').select('nome, image_url').eq('id', projetoId).single();
    final remetenteInfo = await _supabase.from('usuarios').select('nome, sobrenome').eq('id', userId).single();
    
    final nomeProjeto = projetoInfo['nome'] ?? 'Projeto Sem Nome';
    final remetenteNome = '${remetenteInfo['nome'] ?? ''} ${remetenteInfo['sobrenome'] ?? ''}'.trim();

    // Busca TODOS os usuários da empresa que foi convidada
    final usuariosConvidada = await _supabase
        .from('usuarios')
        .select('id')
        .eq('empresa_id', empresaConvidadaId);

    // Dispara a notificação nova para cada um dos usuários daquela empresa
    if (usuariosConvidada.isNotEmpty) {
      final List<Map<String, dynamic>> notificacoesToInsert = (usuariosConvidada as List).map((u) {
        return {
          'usuario_id': u['id'],
          'titulo': 'Novo Convite de Colaboração',
          'mensagem': '$remetenteNome convidou sua empresa para o projeto $nomeProjeto.',
          'tipo': 'convite_projeto',
          'lida': false,
          'dados_extras': {
            'projeto_id': projetoId,
            'convite_id': conviteId,
            'foto_url': projetoInfo['image_url'], 
          }
        };
      }).toList();

      await _supabase.from('notificacoes').insert(notificacoesToInsert);
    }
  }

  Future<void> aceitarConviteEmpresa({
    required String conviteId, 
    required String projetoId, 
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Sessão expirada.');

    final usuarioData = await _supabase
        .from('usuarios')
        .select('empresa_id')
        .eq('id', userId)
        .maybeSingle();

    final empresaId = usuarioData?['empresa_id'];
    if (empresaId == null) throw Exception('Seu usuário não está vinculado a uma empresa.');

    await _supabase
        .from('projeto_empresas_colaboradoras') 
        .update({'status': 'aceito'})
        .eq('id', conviteId);

    final jaNaEquipe = await _supabase
        .from('projeto_equipe_interna') 
        .select('usuario_id')
        .eq('projeto_id', projetoId)
        .eq('usuario_id', userId)
        .maybeSingle();

    if (jaNaEquipe != null) {
      await _supabase
          .from('projeto_equipe_interna')
          .update({
            'ativo': true,
            'is_gestor': true, 
          })
          .eq('projeto_id', projetoId)
          .eq('usuario_id', userId);
    } else {
      await _supabase.from('projeto_equipe_interna').insert({
        'projeto_id': projetoId,
        'empresa_id': empresaId,
        'usuario_id': userId,
        'ativo': true,
        'is_gestor': true, 
      });
    }

    _ref.invalidate(filteredProjectsProvider); 
    _ref.invalidate(empresasVinculadasProjetoProvider(projetoId));
    _ref.invalidate(colaboradoresProjetoProvider(projetoId)); 
  }

  Future<void> alterarEmpresaGestora({
    required String projetoId, 
    required String novaEmpresaGestoraId,
  }) async {
    await _supabase
        .from('projetos')
        .update({'empresa_gestora_id': novaEmpresaGestoraId})
        .eq('id', projetoId);

    _ref.invalidate(gestaoProjetoProvider(projetoId));
    _ref.invalidate(filteredProjectsProvider);
  }
}