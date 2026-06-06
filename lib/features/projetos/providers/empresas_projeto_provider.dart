import 'package:diavicon/features/equipe/providers/equipe_provider.dart';
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

// Controller para gerenciar a ação das empresas colaboradoras
final empresasProjetoControllerProvider = Provider((ref) => EmpresasProjetoController(ref));

class EmpresasProjetoController {
  final _supabase = Supabase.instance.client;
  final Ref _ref;

  EmpresasProjetoController(this._ref);

  // 1. Busca a empresa pelo CNPJ para mostrar no Modal
  Future<Map<String, dynamic>> buscarEmpresaParaPreview(String cnpj) async {
    final cnpjLimpo = cnpj.replaceAll(RegExp(r'[^0-9]'), '');

    final empresa = await _supabase
        .from('empresas')
        .select('id, nome, foto_url, enderecos(cidade, estado)')
        .eq('cnpj', cnpjLimpo)
        .maybeSingle();

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
        .from('projeto_empresas_colaboradoras') // 🔥 TABELA NOVA
        .update({'status': 'aceito'})
        .eq('id', conviteId);

    // Garante que quem aceitou o convite (o dono/gestor da empresa parceira) 
    // entre na equipe interna do projeto para poder acessá-lo.
    final jaNaEquipe = await _supabase
        .from('projeto_equipe_interna') // 🔥 TABELA NOVA
        .select('usuario_id')
        .eq('projeto_id', projetoId)
        .eq('usuario_id', userId)
        .maybeSingle();

    if (jaNaEquipe != null) {
      // Reativa caso estivesse inativo
      await _supabase
          .from('projeto_equipe_interna')
          .update({'ativo': true})
          .eq('projeto_id', projetoId)
          .eq('usuario_id', userId);
    } else {
      // Insere o usuário na equipe do projeto
      await _supabase.from('projeto_equipe_interna').insert({
        'projeto_id': projetoId,
        'empresa_id': empresaId,
        'usuario_id': userId,
        'ativo': true,
      });
    }

    // Invalida os providers para a UI reagir na hora!
    _ref.invalidate(filteredProjectsProvider); 
    _ref.invalidate(empresasVinculadasProjetoProvider(projetoId));
    _ref.invalidate(colaboradoresProjetoProvider(projetoId)); // 🔥 Atualiza a tela de equipe tbm
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