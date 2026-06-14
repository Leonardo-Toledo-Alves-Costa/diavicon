import 'package:diavicon/features/equipe/providers/equipe_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'projetos_provider.dart';

// Provider que escuta em tempo real as empresas colaboradoras no projeto
final empresasVinculadasProjetoProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, projetoId) {
  final supabase = Supabase.instance.client;
  
  return supabase
      .from('projeto_empresas_colaboradoras') // 🔥 TABELA NOVA
      .stream(primaryKey: ['id'])
      .eq('projeto_id', projetoId)
      .asyncMap((maps) async {
        List<Map<String, dynamic>> listaCompleta = [];
        
        for (var vinculo in maps) {
          final empresaId = vinculo['empresa_id']; // 🔥 COLUNA NOVA
          
          try {
            final empData = await supabase
                .from('empresas')
                .select('id, nome, foto_url, enderecos(cidade, estado)')
                .eq('id', empresaId)
                .maybeSingle();
                
            if (empData != null) {
              final endereco = empData['enderecos'] is Map ? empData['enderecos'] : null;
              
              listaCompleta.add({
                'id': empData['id'],
                'nome': empData['nome'] ?? 'Empresa Sem Nome',
                'foto_url': empData['foto_url'] ?? '',
                'cidade': endereco != null ? endereco['cidade'] ?? 'Não informada' : 'Não informada',
                'uf': endereco != null ? endereco['estado'] ?? '--' : '--',
                'status_vinculo': vinculo['status'], 
                'is_gestora': false,
                'convite_id': vinculo['id'], // 🔥 Útil para usar na hora de aceitar!
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
// Busca as empresas que já colaboram no projeto (para poder transferir a gestão)
final projetoEmpresasIntegrantesProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, projetoId) async {
  final supabase = Supabase.instance.client;
  
  // 🔥 CORREÇÃO: Buscando cidade e estado dentro do relacionamento enderecos()
  final response = await supabase
      .from('projeto_empresas_colaboradoras')
      .select('empresas:empresa_id(id, nome, foto_url, enderecos(cidade, estado))')
      .eq('projeto_id', projetoId)
      .eq('status', 'aceito');

  final List data = response as List;
  
  return data.map((item) {
    final emp = item['empresas'] as Map<String, dynamic>;
    
    // O Supabase pode retornar o endereço como lista (se for 1:N) ou mapa (1:1)
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
    // 1. É um ID de empresa?
    final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(filtroTrimmed);

    if (isUuid) {
      return await supabase.from('empresas').select('id, nome, cnpj, foto_url').eq('id', filtroTrimmed).maybeSingle();
    }

    // 2. Prepara as duas versões do CNPJ
    final String cnpjLimpo = filtroTrimmed.replaceAll(RegExp(r'[^0-9]'), '');
    String cnpjFormatado = filtroTrimmed;
    if (cnpjLimpo.length == 14) {
      cnpjFormatado = '${cnpjLimpo.substring(0,2)}.${cnpjLimpo.substring(2,5)}.${cnpjLimpo.substring(5,8)}/${cnpjLimpo.substring(8,12)}-${cnpjLimpo.substring(12,14)}';
    }

    // 🔥 BUSCA CASCATA BLINDADA (Usa .eq que nunca quebra com caracteres especiais)
    
    // Tentativa 1: Busca a versão COM máscara (que é como está no seu banco de dados)
    var response = await supabase.from('empresas').select('id, nome, cnpj, foto_url').eq('cnpj', cnpjFormatado).maybeSingle();

    // Tentativa 2: Se não achou, tenta a versão SÓ com números
    if (response == null) {
      response = await supabase.from('empresas').select('id, nome, cnpj, foto_url').eq('cnpj', cnpjLimpo).maybeSingle();
    }

    // Tentativa 3: Se ainda assim não achou, busca do exato jeito maluco que o usuário digitou
    if (response == null) {
      response = await supabase.from('empresas').select('id, nome, cnpj, foto_url').eq('cnpj', filtroTrimmed).maybeSingle();
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

  // 1. Busca a empresa pelo CNPJ para mostrar no Modal
  Future<Map<String, dynamic>> buscarEmpresaParaPreview(String cnpj) async {
    final String filtroTrimmed = cnpj.trim();
    if (filtroTrimmed.isEmpty) {
      throw Exception('O CNPJ não pode estar vazio.');
    }

    // Extrai APENAS os números
    final String cnpjLimpo = filtroTrimmed.replaceAll(RegExp(r'[^0-9]'), '');

    // Monta o CNPJ formatado exatamente como está no seu banco
    String cnpjFormatado = filtroTrimmed;
    if (cnpjLimpo.length == 14) {
      cnpjFormatado = '${cnpjLimpo.substring(0,2)}.${cnpjLimpo.substring(2,5)}.${cnpjLimpo.substring(5,8)}/${cnpjLimpo.substring(8,12)}-${cnpjLimpo.substring(12,14)}';
    }

    // Tentativa 1: Busca a versão COM máscara (igualzinho está no seu banco)
    var empresa = await _supabase
        .from('empresas')
        .select('id, nome, foto_url, enderecos(cidade, estado)')
        .eq('cnpj', cnpjFormatado)
        .maybeSingle();

    // Tentativa 2: Se não achou, tenta a versão SÓ com números
    if (empresa == null) {
      empresa = await _supabase
          .from('empresas')
          .select('id, nome, foto_url, enderecos(cidade, estado)')
          .eq('cnpj', cnpjLimpo)
          .maybeSingle();
    }

    // Tentativa 3: Se ainda assim falhar, tenta o texto exato digitado
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

  // 2. Envia o convite para a Empresa Colaboradora
  Future<void> enviarConviteEmpresa({required String projetoId, required String empresaConvidadaId}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Sessão expirada. Faça login novamente.');

    final jaVinculada = await _supabase
        .from('projeto_empresas_colaboradoras') // 🔥 TABELA NOVA
        .select('status')
        .eq('projeto_id', projetoId)
        .eq('empresa_id', empresaConvidadaId)   // 🔥 COLUNA NOVA
        .maybeSingle();

    if (jaVinculada != null) {
      if (jaVinculada['status'] == 'aceito') {
        throw Exception('Esta empresa já é colaboradora ativa do projeto.');
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


  // 3. A Empresa aceita o convite
  // 3. A Empresa aceita o convite
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

    // Atualiza o convite na tabela de empresas colaboradoras para 'aceito'
    await _supabase
        .from('projeto_empresas_colaboradoras') 
        .update({'status': 'aceito'})
        .eq('id', conviteId);

    // Garante que quem aceitou o convite (o dono/gestor da empresa parceira) 
    // entre na equipe interna do projeto com poderes para gerir a sua própria equipe.
    final jaNaEquipe = await _supabase
        .from('projeto_equipe_interna') 
        .select('usuario_id')
        .eq('projeto_id', projetoId)
        .eq('usuario_id', userId)
        .maybeSingle();

    if (jaNaEquipe != null) {
      // Reativa caso estivesse inativo e injeta o poder de gestor
      await _supabase
          .from('projeto_equipe_interna')
          .update({
            'ativo': true,
            'is_gestor': true, // 🔥 AGORA SIM! Ele vira chefe da equipe dele.
          })
          .eq('projeto_id', projetoId)
          .eq('usuario_id', userId);
    } else {
      // Insere o usuário na equipe do projeto já como gestor
      await _supabase.from('projeto_equipe_interna').insert({
        'projeto_id': projetoId,
        'empresa_id': empresaId,
        'usuario_id': userId,
        'ativo': true,
        'is_gestor': true, // 🔥 AGORA SIM! Ele já entra mandando na própria equipe.
      });
    }

    // Invalida os providers para a UI reagir na hora!
    _ref.invalidate(filteredProjectsProvider); 
    _ref.invalidate(empresasVinculadasProjetoProvider(projetoId));
    _ref.invalidate(colaboradoresProjetoProvider(projetoId)); 
  }

  
  // 🔥 ADICIONE NO SEU EmpresasProjetoController
  Future<void> alterarEmpresaGestora({
    required String projetoId, 
    required String novaEmpresaGestoraId,
  }) async {
    // 1. Atualiza quem é a dona do projeto na tabela 'projetos'
    await _supabase
        .from('projetos')
        .update({'empresa_gestora_id': novaEmpresaGestoraId})
        .eq('id', projetoId);

    // 2. Invalida os providers para a tela atualizar
    // (Lembre-se de importar o gestaoProjetoProvider e filteredProjectsProvider no topo do arquivo)
    _ref.invalidate(gestaoProjetoProvider(projetoId));
    _ref.invalidate(filteredProjectsProvider);
  }
}