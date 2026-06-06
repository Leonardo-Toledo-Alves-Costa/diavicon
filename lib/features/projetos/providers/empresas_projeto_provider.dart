import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provider que escuta em tempo real os convites de empresas no projeto
final empresasVinculadasProjetoProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, projetoId) {
  final supabase = Supabase.instance.client;
  
  return supabase
      .from('projeto_convites_equipe')
      .stream(primaryKey: ['id'])
      .eq('projeto_id', projetoId)
      .asyncMap((maps) async {
        List<Map<String, dynamic>> listaCompleta = [];
        
        for (var vinculo in maps) {
          final empresaId = vinculo['empresa_convidada_id'];
          
          try {
            // Busca apenas a empresa primeiro, sem forçar o join do endereço caso ele não exista
            final empData = await supabase
                .from('empresas')
                .select('id, nome, foto_url, enderecos(cidade, estado)')
                .eq('id', empresaId)
                .maybeSingle();
                
            if (empData != null) {
              // Proteção contra nulos se a tabela de endereço estiver vazia para esta empresa
              final endereco = empData['enderecos'] is Map ? empData['enderecos'] : null;
              
              listaCompleta.add({
                'id': empData['id'],
                'nome': empData['nome'] ?? 'Empresa Sem Nome',
                'foto_url': empData['foto_url'] ?? '',
                'cidade': endereco != null ? endereco['cidade'] ?? 'Não informada' : 'Não informada',
                'uf': endereco != null ? endereco['estado'] ?? '--' : '--',
                'status_vinculo': vinculo['status'], 
                'is_gestora': false,
              });
            }
          } catch (e) {
            // Se der erro de RLS em uma empresa específica, ele ignora e continua desenhando as outras
            print('Erro ao buscar detalhes da empresa convidada: $e');
          }
        }
        return listaCompleta;
      });
});

// Controller para gerenciar a ação do botão de incluir por CNPJ
final empresasProjetoControllerProvider = Provider((ref) => EmpresasProjetoController());

class EmpresasProjetoController {
  final _supabase = Supabase.instance.client;

  // 1. Apenas busca a empresa para mostrar na tela
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

  // 2. Efetiva o convite de fato
  Future<void> confirmarVinculo({
    required String projetoId,
    required String empresaConvidadaId,
    required String criadoPorUsuarioId,
  }) async {
    final jaExiste = await _supabase
        .from('projeto_convites_equipe')
        .select('id')
        .eq('projeto_id', projetoId)
        .eq('empresa_convidada_id', empresaConvidadaId)
        .maybeSingle();

    if (jaExiste != null) {
      throw Exception('Esta empresa já possui um vínculo ou convite para este projeto.');
    }

    await _supabase.from('projeto_convites_equipe').insert({
      'projeto_id': projetoId,
      'empresa_convidada_id': empresaConvidadaId,
      'status': 'pendente', 
      'criado_por': criadoPorUsuarioId,
    });
  }
}