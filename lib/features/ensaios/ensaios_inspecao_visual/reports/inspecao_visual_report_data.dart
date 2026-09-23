import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../../../modelos_relatorios/models/foto_relatorio.dart';
import '../../../modelos_relatorios/models/modelo_relatorio_schema.dart';
import '../../../modelos_relatorios/models/quadro_model.dart';
import '../utils/risco_gut_calculo.dart';

// Alias pro tipo compartilhado (ver modelos_relatorios/models/foto_relatorio.dart)
// — mantém o nome já usado neste arquivo sem duplicar a classe.
typedef FotoReal = FotoRelatorio;

// Um registro real da inspeção, já resolvido em texto puro nas mesmas chaves
// do catálogo `camposRegistro`, mais suas anomalias (cada uma nas chaves de
// `camposAnomalia`) e as fotos da galeria do registro (com legenda).
class RegistroReal {
  final Map<String, String> dados;
  final List<Map<String, String>> anomalias;
  final List<FotoReal> fotos;

  const RegistroReal({required this.dados, required this.anomalias, required this.fotos});
}

// Dados reais da seção "Referencial": pra cada catálogo configurado no
// modelo (chave de `CatalogoReferencial`), a lista deduplicada dos itens
// daquele catálogo REALMENTE usados neste relatório (não o catálogo inteiro
// da empresa) — funciona como um glossário do que foi citado.
class ReferencialReal {
  final Map<String, List<Map<String, String>>> porCatalogo;
  const ReferencialReal(this.porCatalogo);

  List<Map<String, String>> paraCatalogo(String chave) => porCatalogo[chave] ?? const [];
}

// Os 4 blocos de repetição reais de "Informações iniciais". Um relatório de
// ensaio sempre se refere a uma única estrutura, então `estruturas` tem no
// máximo 1 item — mas continua sendo uma lista pra reaproveitar o mesmo
// mecanismo de "bloco de repetição" dos outros 3.
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

// Busca e resolve os dados reais de uma inspeção visual (uma "inspecaoGeral")
// para alimentar o gerador de relatório: cabeçalho (empresa/projeto/cliente),
// informações iniciais (equipe/empresas/estruturas do projeto) e a lista de
// registros com suas anomalias e fotos.
class InspecaoVisualReportData {
  final SupabaseClient _supabase;
  InspecaoVisualReportData(this._supabase);

  // `empresaId` aqui é a empresa que está GERANDO o relatório (dona do
  // modelo usado) — não necessariamente a mesma coisa que `projetos.empresa_id`
  // (que pode ser nula/outra empresa gestora). Cada campo é resolvido com seu
  // próprio try/catch: se um falhar (ex: nome de FK errado, cliente não
  // vinculado), os outros continuam aparecendo em vez de a seção inteira
  // ficar em branco.
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

  String _nomeCompleto(Map<String, dynamic> usuario) =>
      '${usuario['nome'] ?? ''} ${usuario['sobrenome'] ?? ''}'.trim();

  // Toda a equipe interna do projeto (todas as empresas), uma linha por pessoa.
  Future<List<Map<String, String>>> buscarEquipe(String projetoId) async {
    try {
      final equipe = await _supabase
          .from('projeto_equipe_interna')
          .select('usuario_id')
          .eq('projeto_id', projetoId)
          .eq('ativo', true);
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

  // Empresas colaboradoras do projeto, uma linha por (empresa, pessoa dessa
  // empresa que também está na equipe do projeto).
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

  // Gera uma imagem de mapa de verdade a partir de lat/long usando o Yandex
  // Static Maps (sem chave de API) — a chave do Google Maps do app é
  // restrita ao pacote Android/iOS e não funcionaria embutida num
  // relatório. staticmap.openstreetmap.de (usado antes) tem o domínio fora
  // do ar (falha de DNS) e o serviço legado da Wikimedia retorna 403 (foi
  // desativado pra uso externo) — o Yandex foi testado e responde 200 com
  // PNG válido, além de suportar marcador/pino. Nota: `ll` é
  // longitude,latitude (ordem invertida em relação ao resto do app).
  String _urlMapaEstatico(double lat, double long) =>
      'https://static-maps.yandex.ru/1.x/?ll=$long,$lat&z=15&l=map&size=500,300&pt=$long,$lat,pm2rdl';

  // Um relatório de ensaio sempre se refere a uma única estrutura (a que está
  // sendo inspecionada) — busca só ela, não todas as estruturas do projeto.
  Future<List<Map<String, String>>> buscarEstrutura(String estruturaId) async {
    try {
      final e = await _supabase.from('estruturas').select('''
            nome, descricao, caa, ano_concepcao, endereco, numero, cidade, uf, pais, cep, latitude, longitude, proprietaria_id,
            conjuntos_estruturais(nome), utilizacoes_estrutura(nome), tipos_estrutura(nome), tipologias_estrutura(nome)
          ''').eq('id', estruturaId).maybeSingle();
      if (e == null) return [];

      String proprietario = '';
      final propId = e['proprietaria_id']?.toString();
      if (propId != null) {
        try {
          final empresa = await _supabase.from('empresas').select('nome').eq('id', propId).maybeSingle();
          proprietario = empresa?['nome']?.toString() ?? '';
        } catch (_) {
          // Segue sem o nome do proprietário se a busca falhar.
        }
      }

      final anoConcepcao = e['ano_concepcao'] as int?;
      var anoIdade = '';
      var idadeAnos = '';
      if (anoConcepcao != null) {
        final idade = DateTime.now().year - anoConcepcao;
        final idadeClamp = idade < 0 ? 0 : idade;
        anoIdade = '$anoConcepcao ($idadeClamp anos)';
        idadeAnos = idadeClamp.toString();
      }

      final enderecoPartes = [e['endereco'], e['numero'], e['cidade'], e['uf'], e['pais']]
          .where((p) => p != null && p.toString().isNotEmpty)
          .join(', ');
      final cep = e['cep']?.toString();
      final enderecoCompleto =
          [enderecoPartes, if (cep != null && cep.isNotEmpty) 'CEP $cep'].where((p) => p.isNotEmpty).join(' — ');

      final lat = (e['latitude'] as num?)?.toDouble();
      final long = (e['longitude'] as num?)?.toDouble();

      return [
        {
          'nome_estrutura_ip': e['nome']?.toString() ?? '',
          'descricao_estrutura_ip': e['descricao']?.toString() ?? '',
          'proprietario_estrutura_ip': proprietario,
          'caa_estrutura_ip': e['caa']?.toString() ?? '',
          'ano_construcao_estrutura_ip': anoIdade,
          'idade_estrutura_ip': idadeAnos,
          'conjunto_estrutural_ip': (e['conjuntos_estruturais'] as Map?)?['nome']?.toString() ?? '',
          'utilizacao_estrutura_ip': (e['utilizacoes_estrutura'] as Map?)?['nome']?.toString() ?? '',
          'tipo_estrutura_ip': (e['tipos_estrutura'] as Map?)?['nome']?.toString() ?? '',
          'tipologia_estrutural_ip': (e['tipologias_estrutura'] as Map?)?['nome']?.toString() ?? '',
          'endereco_estrutura_ip': enderecoCompleto,
          if (lat != null && long != null) 'lat_long_estrutura_ip': '$lat, $long',
          if (lat != null && long != null) 'mapa_estrutura_ip': _urlMapaEstatico(lat, long),
        },
      ];
    } catch (_) {
      return [];
    }
  }

  // Locais da estrutura (`estruturas_locais`): nome/tipologia/condição de
  // exposição/descrição são colunas de texto simples direto na tabela.
  Future<List<Map<String, String>>> buscarLocaisEstrutura(String estruturaId) async {
    try {
      final resp = await _supabase
          .from('estruturas_locais')
          .select('nome, tipologia, condicao_exposicao, descricao')
          .eq('estrutura_id', estruturaId)
          .order('nome');
      return (resp as List)
          .map((l) => <String, String>{
                'nome_local': l['nome']?.toString() ?? '',
                'tipologia_local': l['tipologia']?.toString() ?? '',
                'condicao_local': l['condicao_exposicao']?.toString() ?? '',
                'descricao_local': l['descricao']?.toString() ?? '',
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<InformacoesIniciaisReal> buscarInformacoesIniciais(String projetoId, String estruturaId) async {
    return InformacoesIniciaisReal(
      equipe: await buscarEquipe(projetoId),
      empresas: await buscarEmpresasProjeto(projetoId),
      estruturas: await buscarEstrutura(estruturaId),
      locais: await buscarLocaisEstrutura(estruturaId),
    );
  }

  Map<String, String> _linhaCatalogoPadrao(Map<String, dynamic> item) => {
        'nome': item['nome']?.toString() ?? '',
        'descricao': item['descricao']?.toString() ?? '',
      };

  Map<String, String> _linhaAnomaliaReferencial(Map<String, dynamic> item) => {
        'nome': item['nome']?.toString() ?? '',
        'descricao': item['descricao']?.toString() ?? '',
        'categoria': item['categoria']?.toString() ?? '',
        'sistema_construtivo': item['sistema_construtivo']?.toString() ?? '',
        'gravidade_valor': item['gravidade_valor']?.toString() ?? '',
        'gravidade_descricao': item['gravidade_descricao']?.toString() ?? '',
        'urgencia_valor': item['urgencia_valor']?.toString() ?? '',
        'urgencia_descricao': item['urgencia_descricao']?.toString() ?? '',
        'tendencia_valor': item['tendencia_valor']?.toString() ?? '',
        'tendencia_descricao': item['tendencia_descricao']?.toString() ?? '',
        'risco_tipo': item['risco_tipo']?.toString() ?? '',
        'risco_descricao': item['risco_descricao']?.toString() ?? '',
        'risco_valor': item['risco_valor']?.toString() ?? '',
        'risco_major': item['risco_major']?.toString() ?? '',
      };

  // "Condições do local"/"Tipologia do local"/"Tipologias de elemento"/
  // "Revestimento de elemento" são guardados como TEXTO puro (o nome do
  // item escolhido) nas tabelas de origem, não como FK — então, pra achar
  // a descrição de cada um, casamos pelo `nome` no catálogo correspondente,
  // preferindo os itens da própria empresa (ou o padrão Diavicon).
  Future<List<Map<String, String>>> _buscarCatalogoPorNome(String tabela, Set<String> nomes, String? empresaId) async {
    if (nomes.isEmpty) return [];
    try {
      final query = _supabase.from(tabela).select('nome, descricao').inFilter('nome', nomes.toList());
      final resp = empresaId != null ? await query.or('empresa_id.eq.$empresaId,empresa_id.eq.$DIAVICON_EMPRESA_ID') : await query;
      return (resp as List).map((r) => _linhaCatalogoPadrao((r as Map).cast<String, dynamic>())).toList();
    } catch (_) {
      return [];
    }
  }

  // Monta os dados da seção "Referencial": só busca o que o modelo pede
  // (`catalogosNecessarios`) e só traz os itens realmente usados na
  // estrutura/locais/registros/anomalias deste relatório.
  Future<ReferencialReal> buscarReferencial({
    required List<String> catalogosNecessarios,
    required String estruturaId,
    required String inspecaoGeralId,
    required List<Map<String, String>> locais,
    String? empresaId,
  }) async {
    final necessarios = catalogosNecessarios.toSet();
    if (necessarios.isEmpty) return const ReferencialReal({});
    final resultado = <String, List<Map<String, String>>>{};

    final catalogosEstrutura = {'tipos_estrutura', 'tipologias_estrutura', 'utilizacoes_estrutura'}.intersection(necessarios);
    if (catalogosEstrutura.isNotEmpty) {
      try {
        final e = await _supabase
            .from('estruturas')
            .select('tipos_estrutura(nome, descricao), tipologias_estrutura(nome, descricao), utilizacoes_estrutura(nome, descricao)')
            .eq('id', estruturaId)
            .maybeSingle();
        if (e != null) {
          for (final chave in catalogosEstrutura) {
            final item = e[chave] as Map<String, dynamic>?;
            if (item != null) resultado[chave] = [_linhaCatalogoPadrao(item)];
          }
        }
      } catch (_) {
        // Segue sem esses catálogos se a busca falhar.
      }
    }

    if (necessarios.contains('condicoes_local')) {
      final valores = locais.map((l) => l['condicao_local'] ?? '').where((v) => v.isNotEmpty).toSet();
      resultado['condicoes_local'] = await _buscarCatalogoPorNome('condicoes_local', valores, empresaId);
    }
    if (necessarios.contains('tipologias_local')) {
      final valores = locais.map((l) => l['tipologia_local'] ?? '').where((v) => v.isNotEmpty).toSet();
      resultado['tipologias_local'] = await _buscarCatalogoPorNome('tipologias_local', valores, empresaId);
    }

    final catalogosPonto =
        {'tipos_elemento', 'sistemas_habitacionais', 'tipologias_elemento', 'revestimentos_elemento', 'anomalias'}.intersection(necessarios);
    if (catalogosPonto.isNotEmpty) {
      try {
        final resp = await _supabase.from('ponto_inspecao_visual').select('''
              elementos_estruturais(topologia, revestimento),
              tipos_elemento(id, nome, descricao, sistemas_habitacionais(id, nome, descricao)),
              ponto_inspecao_visual_anomalia(anomalias(id, nome, descricao, categoria, sistema_construtivo,
                gravidade_valor, gravidade_descricao, urgencia_valor, urgencia_descricao,
                tendencia_valor, tendencia_descricao, risco_tipo, risco_descricao, risco_valor, risco_major))
            ''').eq('id_ponto_geral', inspecaoGeralId);

        final tiposElementoMap = <String, Map<String, String>>{};
        final sistemasMap = <String, Map<String, String>>{};
        final anomaliasMap = <String, Map<String, String>>{};
        final tipologiasElementoTexto = <String>{};
        final revestimentosTexto = <String>{};

        for (final ponto in (resp as List)) {
          final elemento = ponto['elementos_estruturais'] as Map<String, dynamic>?;
          final tipoElemento = ponto['tipos_elemento'] as Map<String, dynamic>?;
          final sistema = tipoElemento?['sistemas_habitacionais'] as Map<String, dynamic>?;

          final topologia = elemento?['topologia']?.toString();
          if (topologia != null && topologia.isNotEmpty) tipologiasElementoTexto.add(topologia);
          final revestimento = elemento?['revestimento']?.toString();
          if (revestimento != null && revestimento.isNotEmpty) revestimentosTexto.add(revestimento);

          final idTipoElemento = tipoElemento?['id']?.toString();
          if (idTipoElemento != null) {
            tiposElementoMap[idTipoElemento] = {
              ..._linhaCatalogoPadrao(tipoElemento!),
              'sistema': sistema?['nome']?.toString() ?? '',
            };
          }

          final idSistema = sistema?['id']?.toString();
          if (idSistema != null) sistemasMap[idSistema] = _linhaCatalogoPadrao(sistema!);

          final anomaliasResp = ponto['ponto_inspecao_visual_anomalia'] as List? ?? const [];
          for (final a in anomaliasResp) {
            final catalogo = a['anomalias'] as Map<String, dynamic>?;
            final idAnomalia = catalogo?['id']?.toString();
            if (catalogo != null && idAnomalia != null) anomaliasMap[idAnomalia] = _linhaAnomaliaReferencial(catalogo);
          }
        }

        if (necessarios.contains('tipos_elemento')) resultado['tipos_elemento'] = tiposElementoMap.values.toList();
        if (necessarios.contains('sistemas_habitacionais')) resultado['sistemas_habitacionais'] = sistemasMap.values.toList();
        if (necessarios.contains('anomalias')) resultado['anomalias'] = anomaliasMap.values.toList();
        if (necessarios.contains('tipologias_elemento')) {
          resultado['tipologias_elemento'] = await _buscarCatalogoPorNome('tipologias_elemento', tipologiasElementoTexto, empresaId);
        }
        if (necessarios.contains('revestimentos_elemento')) {
          resultado['revestimentos_elemento'] = await _buscarCatalogoPorNome('revestimentos_elemento', revestimentosTexto, empresaId);
        }
      } catch (_) {
        // Segue sem esses catálogos se a busca falhar.
      }
    }

    return ReferencialReal(resultado);
  }

  Future<List<RegistroReal>> buscarRegistros({required String inspecaoGeralId, required String estruturaId}) async {
    String nomeEstrutura = '';
    try {
      final estrutura = await _supabase.from('estruturas').select('nome').eq('id', estruturaId).maybeSingle();
      nomeEstrutura = estrutura?['nome']?.toString() ?? '';
    } catch (_) {
      // Segue sem o nome da estrutura se a busca falhar.
    }

    final resp = await _supabase.from('ponto_inspecao_visual').select('''
          id, registro, descricao, id_local, id_elemento,
          estruturas_locais(nome, condicao_exposicao),
          elementos_estruturais(nome, topologia),
          tipos_elemento(nome, sistemas_id, sistemas_habitacionais(nome)),
          ponto_inspecao_regiao(foto_marcacao),
          ponto_inspecao_visual_galeria(foto_url, descricao),
          ponto_inspecao_visual_anomalia(area_afetada, risco_tipo, risco_valor, risco_descricao, anomalia_descricao, risco_maj,
            anomalias(nome, gravidade_valor, urgencia_valor, tendencia_valor))
        ''').eq('id_ponto_geral', inspecaoGeralId);

    final registros = <RegistroReal>[];
    for (final ponto in (resp as List)) {
      final local = ponto['estruturas_locais'] as Map<String, dynamic>?;
      final elemento = ponto['elementos_estruturais'] as Map<String, dynamic>?;
      final tipoElemento = ponto['tipos_elemento'] as Map<String, dynamic>?;
      final sistema = tipoElemento?['sistemas_habitacionais'] as Map<String, dynamic>?;
      final regiao = ponto['ponto_inspecao_regiao'];
      final fotoMarcacao = (regiao is List && regiao.isNotEmpty)
          ? regiao.first['foto_marcacao']?.toString()
          : (regiao is Map ? regiao['foto_marcacao']?.toString() : null);

      final dados = <String, String>{
        'nome_registro': ponto['registro']?.toString() ?? '',
        'descricao_registro': ponto['descricao']?.toString() ?? '',
        'estrutura': nomeEstrutura,
        'local': local?['nome']?.toString() ?? '',
        'condicao_exposicao_registro': local?['condicao_exposicao']?.toString() ?? '',
        'sistema': sistema?['nome']?.toString() ?? '',
        'tipo_elemento': tipoElemento?['nome']?.toString() ?? '',
        'elemento': elemento?['nome']?.toString() ?? '',
        'tipologia_elemento': elemento?['topologia']?.toString() ?? '',
        if (fotoMarcacao != null) 'marcacao_planta': fotoMarcacao,
      };

      final anomaliasResp = ponto['ponto_inspecao_visual_anomalia'] as List? ?? const [];
      final anomalias = anomaliasResp.map((a) {
        final catalogo = a['anomalias'] as Map<String, dynamic>?;
        final gut = calcularPontuacaoRiscoGut(
          gravidadeValor: catalogo?['gravidade_valor'],
          urgenciaValor: catalogo?['urgencia_valor'],
          tendenciaValor: catalogo?['tendencia_valor'],
          majoracao: a['risco_maj'],
          areaAfetada: a['area_afetada'],
        );
        return <String, String>{
          'nome_anomalia': catalogo?['nome']?.toString() ?? '',
          'area_afetada': a['area_afetada']?.toString() ?? '',
          'majoracao': a['risco_maj']?.toString() ?? '',
          'gravidade_valor': catalogo?['gravidade_valor']?.toString() ?? '',
          'urgencia_valor': catalogo?['urgencia_valor']?.toString() ?? '',
          'tendencia_valor': catalogo?['tendencia_valor']?.toString() ?? '',
          'gut': gut.toStringAsFixed(2),
          'descricao_anomalia': a['anomalia_descricao']?.toString() ?? '',
          'tipo_risco': a['risco_tipo']?.toString() ?? '',
          'classe_risco': a['risco_valor']?.toString() ?? '',
          'descricao_risco': a['risco_descricao']?.toString() ?? '',
        };
      }).toList();

      final galeriaResp = ponto['ponto_inspecao_visual_galeria'] as List? ?? const [];
      final fotos = galeriaResp
          .map((f) => FotoReal(url: f['foto_url']?.toString() ?? '', descricao: f['descricao']?.toString() ?? ''))
          .where((f) => f.url.isNotEmpty)
          .toList();

      registros.add(RegistroReal(dados: dados, anomalias: anomalias, fotos: fotos));
    }

    return registros;
  }
}

// Agrega registros/anomalias reais em linhas de contagem pra Tabela Resumo,
// agrupando pelas colunas configuradas (exceto "Quantidade", que é a contagem).
// `dadosCabecalho` traz os campos da tabela "Projeto" (nome_projeto, cliente)
// — não vêm de `registros`, então precisam ser mesclados em toda linha pra
// que colunas vinculadas à tabela Projeto também funcionem.
List<Map<String, String>> agregarResumo(
  List<ResumoColuna> colunas,
  List<RegistroReal> registros, {
  Map<String, String> dadosCabecalho = const {},
  Map<String, String> dadosEstrutura = const {},
}) {
  final dimensoes = colunas.where((c) => c.campoVinculado != null).toList();
  // Uma coluna personalizada não precisa estar "na tabela" (não é dimensão de
  // agrupamento) pra usar um dado — ela só referencia a chave do campo direto
  // no `operandos`. Sem isso, o valor nunca chegaria em `linha` (se o campo é
  // da anomalia) nem sobreviveria na linha agregada devolvida abaixo.
  final camposCalculados = colunas.where((c) => c.ehCalculada).expand((c) => c.operandos).toSet();
  final usaAnomalia =
      dimensoes.any((c) => c.tabela == 'anomalia') || camposCalculados.any((chave) => camposAnomalia.any((c) => c.chave == chave));

  // Uma linha por anomalia se alguma coluna vem da tabela anomalia; senão, uma linha por registro.
  final linhasBase = <Map<String, String>>[];
  for (final registro in registros) {
    if (usaAnomalia) {
      if (registro.anomalias.isEmpty) continue;
      for (final anomalia in registro.anomalias) {
        linhasBase.add({...dadosCabecalho, ...dadosEstrutura, ...registro.dados, ...anomalia});
      }
    } else {
      linhasBase.add({...dadosCabecalho, ...dadosEstrutura, ...registro.dados});
    }
  }

  final contagem = <String, Map<String, String>>{};
  for (final linha in linhasBase) {
    final chaveGrupo = dimensoes.map((c) => linha[c.campoVinculado] ?? '').join('|');
    final grupo = contagem.putIfAbsent(chaveGrupo, () {
      final base = <String, String>{};
      for (final c in dimensoes) {
        base[c.campoVinculado!] = linha[c.campoVinculado] ?? '';
      }
      for (final chave in camposCalculados) {
        base[chave] = linha[chave] ?? '';
      }
      base['quantidade'] = '0';
      return base;
    });
    grupo['quantidade'] = ((int.tryParse(grupo['quantidade'] ?? '0') ?? 0) + 1).toString();
  }

  return contagem.values.toList();
}

// GUT — Somatório de risco: soma o GUT (já calculado por anomalia em
// `buscarRegistros`, chave 'gut') agrupando pelo campo indicado de
// `RegistroReal.dados` ('estrutura' ou 'local') — reaproveita a hierarquia
// projeto > estruturas > locais > anomalias já usada no resto do relatório.
// Um relatório de Inspeção Visual é sempre escopado a 1 estrutura, então
// "por Estrutura" sempre resulta numa única linha; "por Local" resulta numa
// linha por local distinto citado nos registros.
List<Map<String, String>> gutSomatorioPorEstrutura(List<RegistroReal> registros) =>
    _gutSomatorioPorChave(registros, 'estrutura', 'nome_estrutura_gut');

List<Map<String, String>> gutSomatorioPorLocal(List<RegistroReal> registros) =>
    _gutSomatorioPorChave(registros, 'local', 'nome_local_gut');

List<Map<String, String>> _gutSomatorioPorChave(List<RegistroReal> registros, String campoAgrupador, String rotuloChave) {
  final somas = <String, double>{};
  for (final registro in registros) {
    final chave = registro.dados[campoAgrupador] ?? '';
    if (chave.isEmpty) continue;
    for (final anomalia in registro.anomalias) {
      final gut = double.tryParse(anomalia['gut'] ?? '') ?? 0;
      somas[chave] = (somas[chave] ?? 0) + gut;
    }
  }
  final chavesOrdenadas = somas.keys.toList()..sort();
  return chavesOrdenadas.map((chave) => {rotuloChave: chave, 'gut_somatorio': somas[chave]!.toStringAsFixed(2)}).toList();
}
