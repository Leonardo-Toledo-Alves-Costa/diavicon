import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rdo_realizado_model.dart';

/// Um RDO já vinculado ao nome do projeto a que pertence — usado apenas na
/// listagem "Meus RDOs" (múltiplos projetos), onde isso não é óbvio pelo
/// contexto da tela como é em [RdoRepository.listarRdosDoProjetoEmpresa].
class RdoComProjeto {
  final RdoRealizadoModel rdo;
  final String projetoNome;

  const RdoComProjeto({required this.rdo, required this.projetoNome});
}

class RdoRepository {
  RdoRepository(this._supabase);

  final SupabaseClient _supabase;

  static const _tabela = 'rdo_realizado';

  /// Deriva o papel da empresa do usuário logado dentro do projeto — não há
  /// coluna de papel no banco, só comparação com `empresa_gestora_id`/
  /// `empresa_cliente_id` de `projetos`.
  Future<PapelEmpresaProjeto> resolverPapel({
    required String projetoId,
    required String? empresaUsuarioId,
  }) async {
    if (empresaUsuarioId == null) return PapelEmpresaProjeto.colaboradora;

    try {
      final projeto = await _supabase
          .from('projetos')
          .select('empresa_gestora_id, empresa_cliente_id, status_vinculo_cliente')
          .eq('id', projetoId)
          .maybeSingle();

      if (projeto == null) return PapelEmpresaProjeto.colaboradora;

      if (projeto['empresa_gestora_id']?.toString() == empresaUsuarioId) {
        return PapelEmpresaProjeto.gestora;
      }
      if (projeto['empresa_cliente_id']?.toString() == empresaUsuarioId &&
          projeto['status_vinculo_cliente']?.toString() == 'ativo') {
        return PapelEmpresaProjeto.cliente;
      }
      return PapelEmpresaProjeto.colaboradora;
    } on PostgrestException catch (e) {
      throw Exception('Erro ao verificar permissões do projeto: ${e.message}');
    }
  }

  /// Total de RDOs e data do último, por empresa, dentro de um projeto — para
  /// os badges da lista de empresas. Calculado no cliente (poucas linhas por
  /// projeto), no mesmo espírito de `contagemGeralColaboradoresProvider`.
  Future<Map<String, ({int total, DateTime? ultimo})>> contarRdosPorEmpresa(
    String projetoId,
  ) async {
    try {
      final res = await _supabase
          .from(_tabela)
          .select('empresa_id, criado_em')
          .eq('projeto_id', projetoId);

      final contagem = <String, ({int total, DateTime? ultimo})>{};
      for (final linha in (res as List)) {
        final empresaId = linha['empresa_id']?.toString();
        if (empresaId == null) continue;
        final criadoEm = DateTime.tryParse(linha['criado_em']?.toString() ?? '');
        final atual = contagem[empresaId];
        final ultimoMaisRecente = atual == null || (criadoEm != null && (atual.ultimo == null || criadoEm.isAfter(atual.ultimo!)))
            ? criadoEm
            : atual.ultimo;
        contagem[empresaId] = (total: (atual?.total ?? 0) + 1, ultimo: ultimoMaisRecente);
      }
      return contagem;
    } on PostgrestException catch (e) {
      throw Exception('Erro ao contar RDOs do projeto: ${e.message}');
    }
  }

  Future<List<RdoRealizadoModel>> listarRdosDoProjetoEmpresa({
    required String projetoId,
    required String empresaId,
  }) async {
    try {
      final res = await _supabase
          .from(_tabela)
          .select('*')
          .eq('projeto_id', projetoId)
          .eq('empresa_id', empresaId)
          .order('criado_em', ascending: false);

      return (res as List)
          .map((e) => RdoRealizadoModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Erro ao carregar RDOs: ${e.message}');
    }
  }

  /// RDOs da empresa no projeto dentro de um período (inclusive nas duas
  /// pontas; `dataInicio == dataFim` = um único dia) — usado por "Gerar
  /// relatório" pra verificar se há RDO antes de liberar a geração, e pelo
  /// próprio serviço de geração pra montar os "Registros" do relatório.
  /// `data` é texto livre (`dd/mm/yyyy`, ver `NovoRdoScreen`), então o
  /// filtro é feito no cliente após buscar todos os RDOs do projeto+empresa.
  Future<List<RdoRealizadoModel>> buscarPorPeriodo({
    required String projetoId,
    required String empresaId,
    required DateTime dataInicio,
    required DateTime dataFim,
  }) async {
    final todos = await listarRdosDoProjetoEmpresa(projetoId: projetoId, empresaId: empresaId);
    final inicio = DateTime(dataInicio.year, dataInicio.month, dataInicio.day);
    final fim = DateTime(dataFim.year, dataFim.month, dataFim.day, 23, 59, 59);
    return todos.where((rdo) {
      final data = _parseData(rdo.data);
      if (data == null) return false;
      return !data.isBefore(inicio) && !data.isAfter(fim);
    }).toList();
  }

  DateTime? _parseData(String data) {
    final partes = data.split('/');
    if (partes.length != 3) return null;
    return DateTime.tryParse('${partes[2]}-${partes[1]}-${partes[0]}');
  }

  /// RDOs da empresa do usuário em todos os projetos — usado pela entrada
  /// "Meus RDOs" do menu lateral.
  Future<List<RdoComProjeto>> listarRdosDaEmpresa(String empresaId) async {
    try {
      final res = await _supabase
          .from(_tabela)
          .select('*, projetos(nome)')
          .eq('empresa_id', empresaId)
          .order('criado_em', ascending: false);

      return (res as List).map((linha) {
        final mapa = linha as Map<String, dynamic>;
        final projeto = mapa['projetos'] as Map<String, dynamic>?;
        return RdoComProjeto(
          rdo: RdoRealizadoModel.fromJson(mapa),
          projetoNome: projeto?['nome']?.toString() ?? 'Projeto',
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Erro ao carregar seus RDOs: ${e.message}');
    }
  }

  Future<RdoRealizadoModel> salvar(RdoRealizadoModel rdo) async {
    try {
      final payload = rdo.toJson();
      final Map<String, dynamic> res;
      if (rdo.id == null) {
        res = await _supabase.from(_tabela).insert(payload).select().single();
      } else {
        res = await _supabase
            .from(_tabela)
            .update(payload)
            .eq('id', rdo.id!)
            .select()
            .single();
      }
      return RdoRealizadoModel.fromJson(res);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao salvar RDO: ${e.message}');
    }
  }

  Future<void> atualizarStatus({
    required String rdoId,
    required RdoStatus status,
  }) async {
    try {
      await _supabase.from(_tabela).update({'status': status.valor}).eq('id', rdoId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao atualizar status do RDO: ${e.message}');
    }
  }

  Future<void> excluir(String rdoId) async {
    try {
      await _supabase.from(_tabela).delete().eq('id', rdoId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao excluir RDO: ${e.message}');
    }
  }

  /// Ensaios que a empresa executou naquele projeto num dia — usado pelo
  /// "Importar atividades da data" do Novo RDO. `empresa_autora_id` é
  /// preenchida por trigger no insert de `pontos_ensaios_geral` (migration
  /// 20260909100000_remaining_rls.sql), então já reflete a empresa certa
  /// sem precisar juntar com `usuarios`.
  Future<List<String>> listarAtividadesDoDia({
    required String projetoId,
    required String empresaId,
    required DateTime data,
  }) async {
    try {
      final inicio = DateTime(data.year, data.month, data.day);
      final fim = inicio.add(const Duration(days: 1));

      final res = await _supabase
          .from('pontos_ensaios_geral')
          .select('''
            id, nome_ponto, criado_em,
            tipos_ensaio(nome),
            elementos_estruturais(nome, tipo, local)
          ''')
          .eq('projeto_id', projetoId)
          .eq('empresa_autora_id', empresaId)
          .gte('criado_em', inicio.toIso8601String())
          .lt('criado_em', fim.toIso8601String())
          .order('criado_em', ascending: true);

      return (res as List).map((linha) {
        final mapa = linha as Map<String, dynamic>;
        final tipoEnsaio = (mapa['tipos_ensaio'] as Map?)?['nome']?.toString();
        final elemento = (mapa['elementos_estruturais'] as Map?)?['nome']?.toString();
        final nomePonto = mapa['nome_ponto']?.toString();

        final descricao = StringBuffer();
        descricao.write(tipoEnsaio != null && tipoEnsaio.isNotEmpty ? 'Ensaio de $tipoEnsaio' : 'Ensaio');
        if (elemento != null && elemento.isNotEmpty) {
          descricao.write(' no elemento $elemento');
        } else if (nomePonto != null && nomePonto.isNotEmpty) {
          descricao.write(' — $nomePonto');
        }
        return descricao.toString();
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Erro ao buscar atividades do dia: ${e.message}');
    }
  }
}
