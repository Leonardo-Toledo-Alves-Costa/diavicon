import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../modelos_relatorios/models/foto_relatorio.dart';
import '../models/galeria_rdo_model.dart';
import '../models/rdo_realizado_model.dart';

typedef FotoReal = FotoRelatorio;

/// Um RDO já com as fotos da sua galeria resolvidas — o que a seção
/// "Registros" do relatório de RDO realmente itera.
class RegistroRdoReal {
  final RdoRealizadoModel rdo;
  final List<FotoReal> fotos;
  const RegistroRdoReal({required this.rdo, required this.fotos});
}

/// Os 4 blocos de repetição reais de "Informações iniciais" — mesma ideia de
/// `InspecaoVisualReportData.InformacoesIniciaisReal` (tipo local daquele
/// arquivo, não compartilhado), replicada aqui porque o RDO não tem uma
/// única estrutura de referência: `locais` fica sempre vazio.
class InformacoesIniciaisReal {
  final List<Map<String, String>> equipe;
  final List<Map<String, String>> empresas;
  final List<Map<String, String>> estruturas;
  final List<Map<String, String>> locais;

  const InformacoesIniciaisReal({
    required this.equipe,
    required this.empresas,
    required this.estruturas,
    required this.locais,
  });
}

/// Busca os dados reais de um relatório de RDO — mesmo espírito de
/// `InspecaoVisualReportData`, mas próprio (o grafo de tabelas de origem dos
/// "Registros" é `rdo_realizado`/`rdo_galeria`, não `pontos_ensaios_geral`).
/// Cabeçalho/Equipe/Empresas do projeto são buscas genéricas de projeto — a
/// mesma consulta que `InspecaoVisualReportData` usa, replicada aqui em vez
/// de compartilhada (ver comentário equivalente no compositor de
/// Carbonatação: os grafos de join variam demais pra valer uma abstração).
class RdoModeloReportData {
  final SupabaseClient _supabase;
  RdoModeloReportData(this._supabase);

  String _nomeCompleto(Map<String, dynamic> usuario) {
    final nome = usuario['nome']?.toString() ?? '';
    final sobrenome = usuario['sobrenome']?.toString() ?? '';
    return '$nome $sobrenome'.trim();
  }

  Future<Map<String, String>> buscarDadosCabecalho(String projetoId, String? empresaId) async {
    final dados = <String, String>{};

    try {
      final projeto = await _supabase.from('projetos').select('nome, image_url').eq('id', projetoId).maybeSingle();
      if (projeto != null) {
        dados['nome_projeto'] = projeto['nome']?.toString() ?? '';
        final fotoCapa = projeto['image_url']?.toString();
        if (fotoCapa != null && fotoCapa.isNotEmpty) dados['foto_capa'] = fotoCapa;
      }
    } catch (_) {
      // Segue sem nome/foto de capa do projeto se a busca falhar.
    }

    try {
      final projetoCliente = await _supabase
          .from('projetos')
          .select('empresa_cliente:empresa_cliente_id(nome)')
          .eq('id', projetoId)
          .maybeSingle();
      final cliente = projetoCliente?['empresa_cliente'] as Map<String, dynamic>?;
      if (cliente != null) dados['cliente'] = cliente['nome']?.toString() ?? '';
    } catch (_) {
      // Segue sem cliente se o projeto não tiver um vinculado ou a busca falhar.
    }

    if (empresaId != null) {
      try {
        final empresa = await _supabase.from('empresas').select('nome, foto_url').eq('id', empresaId).maybeSingle();
        if (empresa != null) {
          dados['nome_empresa'] = empresa['nome']?.toString() ?? '';
          final logo = empresa['foto_url']?.toString();
          if (logo != null && logo.isNotEmpty) dados['logo_empresa'] = logo;
        }
      } catch (_) {
        // Segue sem nome/logo da empresa se a busca falhar.
      }
    }

    return dados;
  }

  Future<List<Map<String, String>>> buscarEquipe(String projetoId) async {
    try {
      final equipe = await _supabase.from('projeto_equipe_interna').select('usuario_id').eq('projeto_id', projetoId).eq('ativo', true);
      final ids = (equipe as List).map((e) => e['usuario_id'].toString()).toSet().toList();
      if (ids.isEmpty) return [];

      final usuarios = await _supabase.from('usuarios').select('nome, sobrenome, cargo').inFilter('id', ids);
      return (usuarios as List)
          .map((u) => <String, String>{
                'nome_user_equipe': _nomeCompleto(u),
                'funcao_user_equipe': u['cargo']?.toString() ?? '',
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, String>>> buscarEmpresasProjeto(String projetoId) async {
    try {
      final colaboradoras = await _supabase
          .from('projeto_empresas_colaboradoras')
          .select('empresa_id, empresas(nome)')
          .eq('projeto_id', projetoId)
          .eq('status', 'aceito');

      final linhas = <Map<String, String>>[];
      for (final c in (colaboradoras as List)) {
        final empresaId = c['empresa_id']?.toString();
        final nomeEmpresa = (c['empresas'] as Map?)?['nome']?.toString() ?? '';
        if (empresaId == null) continue;

        final equipeEmpresa = await _supabase
            .from('projeto_equipe_interna')
            .select('usuario_id')
            .eq('projeto_id', projetoId)
            .eq('empresa_id', empresaId)
            .eq('ativo', true);
        final ids = (equipeEmpresa as List).map((e) => e['usuario_id'].toString()).toList();

        if (ids.isEmpty) {
          linhas.add({'nome_empresa_projeto': nomeEmpresa, 'user_empresa_projeto': '', 'funcao_user_empresa_projeto': ''});
          continue;
        }
        final usuarios = await _supabase.from('usuarios').select('nome, sobrenome, cargo').inFilter('id', ids);
        for (final u in (usuarios as List)) {
          linhas.add({
            'nome_empresa_projeto': nomeEmpresa,
            'user_empresa_projeto': _nomeCompleto(u),
            'funcao_user_empresa_projeto': u['cargo']?.toString() ?? '',
          });
        }
      }
      return linhas;
    } catch (_) {
      return [];
    }
  }

  // "Estruturas" de Informações Iniciais pro RDO é o conjunto de estruturas
  // do PROJETO inteiro (o RDO não é de uma estrutura específica, diferente
  // da Inspeção Visual) — uma linha simples por estrutura, sem o mesmo nível
  // de detalhe do relatório de Inspeção Visual (que resolve pra 1 estrutura só).
  Future<List<Map<String, String>>> buscarEstruturasProjeto(String projetoId) async {
    try {
      final estruturas = await _supabase.from('estruturas').select('nome, descricao, caa').eq('projeto_id', projetoId);
      return (estruturas as List)
          .map((e) => <String, String>{
                'nome_estrutura_ip': e['nome']?.toString() ?? '',
                'descricao_estrutura_ip': e['descricao']?.toString() ?? '',
                'caa_estrutura_ip': e['caa']?.toString() ?? '',
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<InformacoesIniciaisReal> buscarInformacoesIniciais(String projetoId) async {
    return InformacoesIniciaisReal(
      equipe: await buscarEquipe(projetoId),
      empresas: await buscarEmpresasProjeto(projetoId),
      estruturas: await buscarEstruturasProjeto(projetoId),
      locais: const [],
    );
  }

  DateTime? _parseData(String data) {
    final partes = data.split('/');
    if (partes.length != 3) return null;
    return DateTime.tryParse('${partes[2]}-${partes[1]}-${partes[0]}');
  }

  /// RDOs da empresa no projeto dentro de um período (inclusive), já com a
  /// galeria resolvida — um período de um único dia (`dataInicio == dataFim`)
  /// gera o relatório de só aquele dia. `data` é texto livre, então o
  /// filtro é feito no cliente.
  Future<List<RegistroRdoReal>> buscarRegistros({
    required String projetoId,
    required String empresaId,
    required DateTime dataInicio,
    required DateTime dataFim,
  }) async {
    final res = await _supabase
        .from('rdo_realizado')
        .select('*')
        .eq('projeto_id', projetoId)
        .eq('empresa_id', empresaId)
        .order('criado_em', ascending: false);

    final inicio = DateTime(dataInicio.year, dataInicio.month, dataInicio.day);
    final fim = DateTime(dataFim.year, dataFim.month, dataFim.day, 23, 59, 59);
    final rdos = (res as List)
        .map((e) => RdoRealizadoModel.fromJson(e as Map<String, dynamic>))
        .where((rdo) {
          final data = _parseData(rdo.data);
          if (data == null) return false;
          return !data.isBefore(inicio) && !data.isAfter(fim);
        })
        .toList();

    final registros = <RegistroRdoReal>[];
    for (final rdo in rdos) {
      if (rdo.id == null) continue;
      List<FotoReal> fotos = const [];
      try {
        final fotosResp = await _supabase.from('rdo_galeria').select('foto, descricao').eq('rdo_id', rdo.id!);
        fotos = (fotosResp as List)
            .map((f) => GaleriaRdoModel.fromJson({
                  'id': '',
                  'criado_em': DateTime.now().toIso8601String(),
                  'rdo_id': rdo.id,
                  ...f as Map<String, dynamic>,
                }))
            .map((g) => FotoReal(url: g.foto, descricao: g.descricao ?? ''))
            .toList();
      } catch (_) {
        // Segue sem fotos deste RDO se a busca falhar.
      }
      registros.add(RegistroRdoReal(rdo: rdo, fotos: fotos));
    }
    return registros;
  }
}
