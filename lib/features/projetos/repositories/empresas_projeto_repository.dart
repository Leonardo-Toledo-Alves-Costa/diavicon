import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

class EmpresasProjetoRepository {
  EmpresasProjetoRepository(this._supabase);

  final SupabaseClient _supabase;

  Stream<List<Map<String, dynamic>>> watchLinkedCompanies(String projectId) {
    return _supabase
        .from('projeto_empresas_colaboradoras')
        .stream(primaryKey: ['id'])
        .eq('projeto_id', projectId)
        .asyncMap((links) async {
          final companies = <Map<String, dynamic>>[];

          for (final link in links) {
            try {
              final companyId = link['empresa_id'];
              final company = await _supabase
                  .from('empresas')
                  .select('id, nome, foto_url, enderecos(cidade, estado)')
                  .eq('id', companyId)
                  .maybeSingle();
              if (company == null) continue;

              final address = _firstMap(company['enderecos']);
              final memberCount = await _supabase
                  .from('projeto_equipe_interna')
                  .count(CountOption.exact)
                  .eq('projeto_id', projectId)
                  .eq('empresa_id', companyId)
                  .eq('ativo', true);

              companies.add({
                'id': company['id'],
                'nome': company['nome'] ?? 'Empresa sem nome',
                'foto_url': company['foto_url'] ?? '',
                'cidade': address?['cidade'] ?? 'Não informada',
                'uf': address?['estado'] ?? '--',
                'status_vinculo': link['status'],
                'is_gestora': false,
                'convite_id': link['id'],
                'total_colaboradores': memberCount,
              });
            } catch (error, stackTrace) {
              developer.log(
                'Falha ao carregar empresa vinculada ao projeto.',
                name: 'EmpresasProjetoRepository',
                error: error,
                stackTrace: stackTrace,
              );
            }
          }

          return companies;
        });
  }

  Future<Map<String, dynamic>?> fetchCurrentCompany() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final user = await _supabase
        .from('usuarios')
        .select('empresa_id')
        .eq('id', userId)
        .maybeSingle();
    final companyId = user?['empresa_id'];
    if (companyId == null) return null;

    return _supabase
        .from('empresas')
        .select('*, enderecos(*)')
        .eq('id', companyId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> fetchAcceptedCompanies(
    String projectId,
  ) async {
    final collaborationResponse = await _supabase
        .from('projeto_empresas_colaboradoras')
        .select(
          'empresas:empresa_id(id, nome, foto_url, enderecos(cidade, estado))',
        )
        .eq('projeto_id', projectId)
        .eq('status', 'aceito');

    final project = await _supabase
        .from('projetos')
        .select('''
          status_vinculo_cliente,
          empresa_gestora:empresas!projetos_empresa_gestora_id_fkey(
            id, nome, foto_url, enderecos(cidade, estado)
          ),
          empresa_cliente:empresas!projetos_empresa_cliente_id_fkey(
            id, nome, foto_url, enderecos(cidade, estado)
          )
        ''')
        .eq('id', projectId)
        .maybeSingle();

    Map<String, dynamic> mapCompany(Map<String, dynamic> company) {
      final address = _firstMap(company['enderecos']);
      return <String, dynamic>{
        'id': company['id'],
        'nome': company['nome'] ?? 'Sem nome',
        'foto_url': company['foto_url'],
        'cidade': address?['cidade'],
        'estado': address?['estado'],
      };
    }

    final companies = <Map<String, dynamic>>[];
    void addIfMissing(Object? value) {
      final company = _firstMap(value);
      if (company == null || company['id'] == null) return;
      final mapped = mapCompany(company);
      if (!companies.any((item) => item['id'] == mapped['id'])) {
        companies.add(mapped);
      }
    }

    for (final item in collaborationResponse as List) {
      addIfMissing((item as Map<String, dynamic>)['empresas']);
    }
    if (project != null) {
      addIfMissing(project['empresa_gestora']);
      if (project['status_vinculo_cliente'] == 'ativo') {
        addIfMissing(project['empresa_cliente']);
      }
    }

    return companies;
  }

  Future<Map<String, dynamic>?> findCompany(String value) async {
    final filter = value.trim();
    if (filter.isEmpty) return null;

    final isUuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(filter);
    if (isUuid) return _findCompanyBy('id', filter);

    final digits = filter.replaceAll(RegExp('[^0-9]'), '');
    final candidates = <String>{filter};
    if (digits.length == 14) {
      candidates.add(
        '${digits.substring(0, 2)}.${digits.substring(2, 5)}.'
        '${digits.substring(5, 8)}/${digits.substring(8, 12)}-'
        '${digits.substring(12, 14)}',
      );
      candidates.add(digits);
    }

    for (final candidate in candidates) {
      final company = await _findCompanyBy('cnpj', candidate);
      if (company != null) return company;
    }
    return null;
  }

  Future<String> inviteCompany({
    required String projectId,
    required String invitedCompanyId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sessão expirada. Faça login novamente.');
    }

    final existing = await _supabase
        .from('projeto_empresas_colaboradoras')
        .select('status')
        .eq('projeto_id', projectId)
        .eq('empresa_id', invitedCompanyId)
        .maybeSingle();

    if (existing != null) {
      if (existing['status'] == 'aceito') {
        throw StateError('Esta empresa já é colaboradora ativa do projeto.');
      }
      throw StateError('Um convite pendente já foi enviado para esta empresa.');
    }

    final invitation = await _supabase
        .from('projeto_empresas_colaboradoras')
        .insert({
          'projeto_id': projectId,
          'empresa_id': invitedCompanyId,
          'criado_por': userId,
          'status': 'pendente',
        })
        .select('id')
        .single();

    final project = await _supabase
        .from('projetos')
        .select('nome, image_url')
        .eq('id', projectId)
        .single();
    final sender = await _supabase
        .from('usuarios')
        .select('nome, sobrenome')
        .eq('id', userId)
        .single();
    final admins = await _supabase
        .from('usuarios')
        .select('id')
        .eq('empresa_id', invitedCompanyId)
        .eq('ativo', true)
        .eq('is_admin_empresa', true);

    if ((admins as List).isNotEmpty) {
      final senderName = '${sender['nome'] ?? ''} ${sender['sobrenome'] ?? ''}'
          .trim();
      await _supabase.from('notificacoes').insert(
        (admins as List).map((admin) {
          return {
            'usuario_id': admin['id'],
            'titulo': 'Novo Convite de Colaboração',
            'mensagem':
                '${senderName.isEmpty ? 'Um gestor' : senderName} convidou sua empresa para o projeto ${project['nome'] ?? 'Projeto sem nome'}.',
            'tipo': 'convite_projeto',
            'lida': false,
            'dados_extras': {
              'projeto_id': projectId,
              'convite_id': invitation['id'],
              'foto_url': project['image_url'],
            },
          };
        }).toList(),
      );
    }

    return invitation['id'].toString();
  }

  Future<void> respondToInvite({
    required String invitationId,
    required String notificationId,
    required bool accept,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sessão expirada. Faça login novamente.');
    }

    await _supabase.rpc(
      'set_project_company_invite_status',
      params: {
        'p_convite_id': invitationId,
        'p_status': accept ? 'aceito' : 'recusado',
      },
    );

    await _supabase
        .from('notificacoes')
        .update({'lida': true})
        .eq('id', notificationId)
        .eq('usuario_id', userId);
  }

  Future<void> transferManagement({
    required String projectId,
    required String newManagerCompanyId,
  }) async {
    await _supabase
        .from('projetos')
        .update({'empresa_gestora_id': newManagerCompanyId})
        .eq('id', projectId);
  }

  Future<Map<String, dynamic>?> _findCompanyBy(String column, String value) {
    return _supabase
        .from('empresas')
        .select('id, nome, cnpj, foto_url, enderecos(cidade, estado)')
        .eq(column, value)
        .maybeSingle();
  }

  static Map<String, dynamic>? _firstMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
