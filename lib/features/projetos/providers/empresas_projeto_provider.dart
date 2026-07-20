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
              
              // 🔥 CORREÇÃO DA SINTAXE NOVA DO SUPABASE COUNT:
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

// Busca as empresas que já colaboram no projeto (para poder transferir a gestão)
final projetoEmpresasIntegrantesProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, projetoId) async {
  final supabase = Supabase.instance.client;
  
  final response = await supabase
      .from('projeto_empresas_colaboradoras')
      .select('empresas:empresa_id(id, nome, foto_url, enderecos(cidade, estado))')
      .eq('projeto_id', projetoId)
      .eq('status', 'aceito');

  final List data = response as List;
  
  return data.map((item) {
    final emp = item['empresas'] as Map<String, dynamic>;
    
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
  }).toList();
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

    if (response == null) {
      response = await supabase.from('empresas').select('id, nome, cnpj, foto_url, enderecos(cidade, estado)').eq('cnpj', cnpjLimpo).maybeSingle();
    }

    if (response == null) {
      response = await supabase.from('empresas').select('id, nome, cnpj, foto_url, enderecos(cidade, estado)').eq('cnpj', filtroTrimmed).maybeSingle();
    }

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

    if (empresa == null) {
      empresa = await _supabase
          .from('empresas')
          .select('id, nome, foto_url, enderecos(cidade, estado)')
          .eq('cnpj', cnpjLimpo)
          .maybeSingle();
    }

    if (empresa == null) {
      empresa = await _supabase
          .from('empresas')
          .select('id, nome, foto_url, enderecos(cidade, estado)')
          .eq('cnpj', filtroTrimmed)
          .maybeSingle();
    }

    if (empresa == null) {
      throw Exception('Nenhuma empresa encontrada com este CNPJ.');
    }
    
    return empresa;
  }

  Future<void> enviarConviteEmpresa({required String projetoId, required String empresaConvidadaId}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Sessão expirada. Faça login novamente.');

    final jaVinculada = await _supabase
        .from('projeto_empresas_colaboradoras') 
        .select('status')
        .eq('projeto_id', projetoId)
        .eq('empresa_id', empresaConvidadaId)   
        .maybeSingle();

    if (jaVinculada != null) {
      if (jaVinculada['status'] == 'aceito') {
        throw Exception('Esta empresa já é colaboradora activa do projeto.');
      } else {
        throw Exception('Um convite pendente já foi enviado para esta empresa.');
      }
    }

    await _supabase.from('projeto_empresas_colaboradoras').insert({
      'projeto_id': projetoId,
      'empresa_id': empresaConvidadaId,
      'criado_por': userId,
      'status': 'pendente'
    });
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