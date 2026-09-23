import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ensaios/ensaio_ultrassom/utils/ultrassom_math.dart';
import '../../ensaios/ensaios_geral/models/tipos_ensaio_ids.dart';
import '../../ensaios/ensaios_inspecao_visual/utils/risco_gut_calculo.dart';
import 'bi_data_point.dart';

/// Mesma semântica do prompt original: `estatistica` abre um segundo
/// seletor (Média/Desvio padrão/Coef. de variação) no construtor de eixos —
/// são 3 variáveis derivadas do mesmo campo base, não 3 campos catalogados
/// à parte. `bruto` é o valor direto, sem segundo seletor. `categorico` vira
/// contagem (pizza/barra) ou campo de agrupamento. `galeria`/`planta` não
/// entram no seletor de eixos — alimentam cards de Galeria/marcadores.
enum CategoriaDadoBi { estatistica, bruto, categorico, galeria, planta }

enum EstatisticaBi {
  media('Média'),
  desvioPadrao('Desvio padrão'),
  coefVariacao('Coef. de variação (%)');

  final String rotulo;
  const EstatisticaBi(this.rotulo);
}

/// Como os valores de um campo se combinam quando um grupo (local, tipo,
/// estrutura...) reúne vários pontos.
///
/// `media` é o normal para medições (velocidade, resistividade...).
/// `soma` é para pontuações que se acumulam — o GUT da inspeção visual:
/// o risco de um local é a soma do risco das suas anomalias, não a média
/// (a média faria um local com 20 anomalias parecer igual a um com uma).
enum AgregacaoBi { media, soma }

typedef BiFetcher = Future<List<BiDataPoint>> Function(BiContexto ctx, {EstatisticaBi? estatistica});

class CampoBiCatalogo {
  final String chave;
  final String rotulo;
  final CategoriaDadoBi categoria;
  final String? unidade;
  final BiFetcher buscar;
  // Dimensões de "Agrupar por" que fazem sentido pra esse campo. Vazio pros
  // campos cujo valor NÃO varia por local/tipo/elemento/data dentro do escopo
  // do dashboard (Idade/CAA são da estrutura inteira, não do elemento; RDO
  // clima/trabalho já são categóricos ao longo do tempo por natureza) —
  // agrupar um valor constante só produz uma barra ou um balde "tudo junto"
  // sem sentido nenhum. RDO horas trabalhadas só faz sentido agrupado por
  // 'data' (o ponto não tem local/tipo/elemento — é por dia de obra, não por
  // ponto de ensaio), daí a lista restrita em vez do padrão local/tipo/elemento.
  final List<String> opcoesAgrupamento;
  final AgregacaoBi agregacao;
  const CampoBiCatalogo({
    required this.chave,
    required this.rotulo,
    required this.categoria,
    this.unidade,
    required this.buscar,
    this.opcoesAgrupamento = const ['local', 'tipoElemento', 'elemento', 'estrutura'],
    this.agregacao = AgregacaoBi.media,
  });
}

class FonteBiCatalogo {
  final String chave;
  final String rotulo;
  // null = sempre disponível (Dados gerais/RDO); senão, o ID do tipo de
  // ensaio (ver TipoEnsaioId). Enquanto o id de uma fonte não for
  // confirmado no banco, aceita também um trecho do nome — ver
  // [resolverTipoEnsaioIdBi].
  final String? tipoEnsaio;
  // Fontes cujos fetchers ainda não foram implementados nesta primeira
  // entrega (ver plano) — aparecem no catálogo (pra já valer como
  // documentação do que falta) mas com um aviso "Fonte ainda não
  // conectada" em vez de dado de verdade.
  final bool implementado;
  final List<CampoBiCatalogo> campos;
  const FonteBiCatalogo({
    required this.chave,
    required this.rotulo,
    this.tipoEnsaio,
    this.implementado = true,
    required this.campos,
  });
}

final SupabaseClient _s = Supabase.instance.client;

// ==========================================================================
// Helpers compartilhados de resolução de contexto/estatística
// ==========================================================================

final RegExp _ehIdTipoEnsaio = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
List<Map<String, dynamic>>? _tiposEnsaioCache;

/// Id de `tipos_ensaio` de uma fonte do dashboard.
///
/// O certo é o dashboard já receber o ID (ver [TipoEnsaioId]) — e é o que
/// esta função faz quando o que chega é um id: devolve na hora, sem ir ao
/// banco. Nome é texto editável e não serve de chave: o dashboard da
/// inspeção visual vinha "sem dados suficientes" porque procurava por
/// "inspeção visual" e o nome gravado não batia letra por letra. E
/// "prova de carga" casa também com "Prova de carga dinâmica", que é outro
/// ensaio.
///
/// A busca por nome fica só para as fontes cujo id ainda não foi preenchido,
/// agora ignorando acento e maiúsculas.
Future<String?> resolverTipoEnsaioIdBi(String idOuNome) async {
  if (_ehIdTipoEnsaio.hasMatch(idOuNome)) return idOuNome;
  try {
    _tiposEnsaioCache ??= [
      for (final t in await _s.from('tipos_ensaio').select('id, nome')) (t as Map).cast<String, dynamic>(),
    ];
    final alvo = _semAcentoBi(idOuNome);
    for (final t in _tiposEnsaioCache!) {
      if (_semAcentoBi(t['nome']?.toString() ?? '').contains(alvo)) return t['id']?.toString();
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Minúsculas e sem acento: "Inspeção Visual" e "inspecao visual" viram o
/// mesmo texto.
String _semAcentoBi(String texto) {
  const comAcento = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const semAcento = 'aaaaaeeeeiiiiooooouuuuc';
  final b = StringBuffer();
  for (final c in texto.toLowerCase().split('')) {
    final i = comAcento.indexOf(c);
    b.write(i < 0 ? c : semAcento[i]);
  }
  return b.toString();
}

/// Postgrest às vezes serializa colunas `numeric`/`decimal` como STRING (pra
/// preservar precisão), enquanto `int4`/`float8` vêm como number de verdade
/// — um `as num?` direto quebra pra qualquer coluna do primeiro tipo (foi
/// exatamente o crash reportado em `ponto_ensaio_ultrassom.alfa_e`). Este
/// helper aceita os dois formatos, então nunca importa qual dos dois o
/// Postgres realmente usa pra uma coluna.
/// Texto aproveitável, ou null quando vem vazio/só espaços — assim o `??`
/// cai na próxima opção em vez de gravar um rótulo em branco no gráfico.
String? _textoOuNulo(dynamic v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

double? _numDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

double _media(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
double _desvioPadrao(List<double> v) {
  if (v.length < 2) return 0;
  final m = _media(v);
  return sqrt(v.map((x) => pow(x - m, 2)).reduce((a, b) => a + b) / v.length);
}

double _coefVariacao(List<double> v) {
  final m = _media(v);
  return m == 0 ? 0 : _desvioPadrao(v) / m * 100;
}

double _resolverEstatistica(List<double> v, EstatisticaBi? e) {
  switch (e) {
    case EstatisticaBi.desvioPadrao:
      return _desvioPadrao(v);
    case EstatisticaBi.coefVariacao:
      return _coefVariacao(v);
    case EstatisticaBi.media:
    case null:
      return _media(v);
  }
}

/// Resolve quais `tipos_elemento.nome` pertencem aos sistemas escolhidos —
/// `elementos_estruturais` só guarda `tipo` (texto), o Sistema é sempre um
/// salto a mais via `tipos_elemento.sistemas_id`.
Future<List<String>> _resolverTiposPorSistema(List<String> sistemaIds) async {
  if (sistemaIds.isEmpty) return [];
  try {
    final resp = await _s.from('tipos_elemento').select('nome').inFilter('sistemas_id', sistemaIds);
    return (resp as List).map((e) => e['nome'].toString()).toList();
  } catch (_) {
    return [];
  }
}

/// Ids de estrutura dentro do escopo de um `projeto`, já aplicando os
/// filtros de Conjunto estrutural e/ou Estrutura (só fazem sentido nesse
/// nível — uma estrutura sempre pertence a um único projeto/conjunto).
Future<List<String>> _estruturaIdsDoProjeto(BiContexto ctx) async {
  final estrResp = await _s.from('projeto_estruturas').select('estrutura_id').eq('projeto_id', ctx.projetoId!);
  var estrIds = (estrResp as List).map((e) => e['estrutura_id'].toString()).toList();
  if (estrIds.isEmpty) return [];
  if (ctx.filtroEstrutura.isNotEmpty) {
    estrIds = estrIds.where((id) => ctx.filtroEstrutura.contains(id)).toList();
  }
  if (ctx.filtroConjuntoEstrutural.isNotEmpty && estrIds.isNotEmpty) {
    final estruturasResp = await _s.from('estruturas').select('id, conjunto_estrutural_id').inFilter('id', estrIds);
    final permitidas = (estruturasResp as List).where((e) => ctx.filtroConjuntoEstrutural.contains(e['conjunto_estrutural_id']?.toString())).map((e) => e['id'].toString()).toSet();
    estrIds = estrIds.where(permitidas.contains).toList();
  }
  return estrIds;
}

/// Elementos estruturais dentro do contexto do dashboard (nível
/// elemento/estrutura/projeto), já aplicando os filtros gerais (Local/Tipo
/// de elemento/Sistema, e — só no nível projeto — Conjunto/Estrutura). Base
/// compartilhada por "Dados gerais" e por qualquer fetcher que precise
/// apenas da lista de elementos (sem ensaio).
Future<List<Map<String, dynamic>>> _elementosNoContexto(BiContexto ctx) async {
  try {
    if (ctx.elementoId != null) {
      final r = await _s.from('elementos_estruturais').select('id, nome, tipo, local, revestimento, caa, estrutura_id, estruturas(nome)').eq('id', ctx.elementoId!).maybeSingle();
      return r == null ? [] : [r];
    }
    List<dynamic> resp;
    if (ctx.estruturaId != null) {
      resp = await _s.from('elementos_estruturais').select('id, nome, tipo, local, revestimento, caa, estrutura_id, estruturas(nome)').eq('estrutura_id', ctx.estruturaId!);
    } else if (ctx.projetoId != null) {
      final estrIds = await _estruturaIdsDoProjeto(ctx);
      if (estrIds.isEmpty) return [];
      resp = await _s.from('elementos_estruturais').select('id, nome, tipo, local, revestimento, caa, estrutura_id, estruturas(nome)').inFilter('estrutura_id', estrIds);
    } else {
      return [];
    }
    final lista = (resp).cast<Map<String, dynamic>>();
    final tiposDoSistema = ctx.filtroSistema.isEmpty ? null : await _resolverTiposPorSistema(ctx.filtroSistema);
    return lista.where((e) {
      if (ctx.filtroLocal.isNotEmpty && !ctx.filtroLocal.contains(e['local']?.toString())) return false;
      if (ctx.filtroTipoElemento.isNotEmpty && !ctx.filtroTipoElemento.contains(e['tipo']?.toString())) return false;
      if (tiposDoSistema != null && !tiposDoSistema.contains(e['tipo']?.toString())) return false;
      return true;
    }).toList();
  } catch (_) {
    return [];
  }
}

/// `pontos_ensaios_geral` do tipo de ensaio pedido, dentro do contexto do
/// dashboard, já com o elemento embutido (nome/tipo/local) — base
/// compartilhada pelos ensaios "1 ponto = 1 elemento" (a maioria).
Future<List<Map<String, dynamic>>> _pontosNoContexto(BiContexto ctx, String tipoEnsaio, String selectExtra) async {
  final tipoEnsaioId = await resolverTipoEnsaioIdBi(tipoEnsaio);
  if (tipoEnsaioId == null) return [];
  try {
    var q = _s.from('pontos_ensaios_geral').select('id, elemento_estrutural_id, $selectExtra, elementos_estruturais!inner(nome, tipo, local, estruturas(nome))').eq('tipo_ensaio_id', tipoEnsaioId);
    if (ctx.elementoId != null) {
      q = q.eq('elemento_estrutural_id', ctx.elementoId!);
    } else if (ctx.estruturaId != null) {
      q = q.eq('estrutura_id', ctx.estruturaId!);
      // Estrutura monitorada (n projetos) — restringe a quais projetos.
      if (ctx.filtroProjeto.isNotEmpty) q = q.inFilter('projeto_id', ctx.filtroProjeto);
    } else if (ctx.projetoId != null) {
      final estrIds = await _estruturaIdsDoProjeto(ctx);
      if (estrIds.isEmpty) return [];
      q = q.eq('projeto_id', ctx.projetoId!).inFilter('estrutura_id', estrIds);
    } else {
      return [];
    }
    if (ctx.filtroLocal.isNotEmpty) q = q.inFilter('elementos_estruturais.local', ctx.filtroLocal);
    if (ctx.filtroTipoElemento.isNotEmpty) q = q.inFilter('elementos_estruturais.tipo', ctx.filtroTipoElemento);
    final lista = (await q).cast<Map<String, dynamic>>();
    if (ctx.filtroSistema.isEmpty) return lista;
    final tiposDoSistema = await _resolverTiposPorSistema(ctx.filtroSistema);
    return lista.where((p) => tiposDoSistema.contains((p['elementos_estruturais'] as Map?)?['tipo']?.toString())).toList();
  } catch (_) {
    return [];
  }
}

/// Nome da estrutura a partir do embed `elementos_estruturais(..., estruturas(nome))`.
String _nomeEstrutura(Map? el) => ((el?['estruturas'] as Map?)?['nome'])?.toString() ?? '';

BiDataPoint _pontoParaDataPoint(Map<String, dynamic> p, {double? valor, String? categoria, DateTime? data}) {
  final el = p['elementos_estruturais'] as Map<String, dynamic>?;
  return BiDataPoint(
    estrutura: _nomeEstrutura(el),
    elementoId: p['elemento_estrutural_id']?.toString() ?? '',
    elementoNome: el?['nome']?.toString() ?? '',
    tipoElemento: el?['tipo']?.toString() ?? 'Desconhecido',
    local: el?['local']?.toString() ?? 'Desconhecido',
    valor: valor,
    categoria: categoria,
    data: data,
  );
}

// ==========================================================================
// Dados gerais — sempre disponível, independente do ensaio escolhido.
// ==========================================================================

Future<List<BiDataPoint>> _buscarIdadeCaaRevestimentoTipo(BiContexto ctx, String campo, {EstatisticaBi? estatistica}) async {
  final elementos = await _elementosNoContexto(ctx);
  if (elementos.isEmpty) return [];

  // Idade depende da estrutura (ano_concepcao) — resolve em lote.
  Map<String, int> anosConcepcao = {};
  if (campo == 'idade') {
    final estrIds = elementos.map((e) => e['estrutura_id']?.toString()).whereType<String>().toSet();
    if (estrIds.isNotEmpty) {
      final resp = await _s.from('estruturas').select('id, ano_concepcao').inFilter('id', estrIds.toList());
      for (final r in (resp as List)) {
        final ano = r['ano_concepcao'];
        if (ano != null) anosConcepcao[r['id'].toString()] = (ano as num).toInt();
      }
    }
  }

  final anoAtual = DateTime.now().year;
  return elementos.map((e) {
    switch (campo) {
      case 'idade':
        final ano = anosConcepcao[e['estrutura_id']?.toString()];
        final idade = ano == null ? null : max(1, anoAtual - ano).toDouble();
        return BiDataPoint(estrutura: _nomeEstrutura(e), elementoId: e['id'].toString(), elementoNome: e['nome']?.toString() ?? '', tipoElemento: e['tipo']?.toString() ?? 'Desconhecido', local: e['local']?.toString() ?? 'Desconhecido', valor: idade);
      case 'caa':
        return BiDataPoint(estrutura: _nomeEstrutura(e), elementoId: e['id'].toString(), elementoNome: e['nome']?.toString() ?? '', tipoElemento: e['tipo']?.toString() ?? 'Desconhecido', local: e['local']?.toString() ?? 'Desconhecido', categoria: e['caa']?.toString());
      case 'revestimento':
        return BiDataPoint(estrutura: _nomeEstrutura(e), elementoId: e['id'].toString(), elementoNome: e['nome']?.toString() ?? '', tipoElemento: e['tipo']?.toString() ?? 'Desconhecido', local: e['local']?.toString() ?? 'Desconhecido', categoria: e['revestimento']?.toString());
      case 'tipo':
        return BiDataPoint(estrutura: _nomeEstrutura(e), elementoId: e['id'].toString(), elementoNome: e['nome']?.toString() ?? '', tipoElemento: e['tipo']?.toString() ?? 'Desconhecido', local: e['local']?.toString() ?? 'Desconhecido', categoria: e['tipo']?.toString());
      default:
        return BiDataPoint(elementoId: e['id'].toString(), elementoNome: '', tipoElemento: '', local: '');
    }
  }).toList();
}

// ==========================================================================
// RDO — por projeto, sem dimensão Local/Tipo de elemento (não é por ponto
// de ensaio) — só serve pra gráficos ao longo do tempo/categóricos.
// ==========================================================================

Future<List<Map<String, dynamic>>> _rdoNoContexto(BiContexto ctx) async {
  if (ctx.projetoId == null) return [];
  try {
    final resp = await _s.from('rdo_realizado').select('*').eq('projeto_id', ctx.projetoId!).order('data');
    return (resp as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
}

DateTime? _parseDataBr(String? data) {
  if (data == null || data.isEmpty) return null;
  final partes = data.split('/');
  if (partes.length != 3) return DateTime.tryParse(data);
  final d = int.tryParse(partes[0]), m = int.tryParse(partes[1]), a = int.tryParse(partes[2]);
  if (d == null || m == null || a == null) return null;
  return DateTime(a, m, d);
}

double? _horaParaMinutos(String? hora) {
  if (hora == null || hora.isEmpty) return null;
  final partes = hora.split(':');
  if (partes.isEmpty) return null;
  final h = int.tryParse(partes[0]) ?? 0;
  final m = partes.length > 1 ? (int.tryParse(partes[1]) ?? 0) : 0;
  return (h * 60 + m).toDouble();
}

Future<List<BiDataPoint>> _buscarRdoCondicao(BiContexto ctx, String campo, {EstatisticaBi? estatistica}) async {
  final linhas = await _rdoNoContexto(ctx);
  return linhas.map((r) {
    final data = _parseDataBr(r['data']?.toString());
    String? categoria;
    if (campo == 'clima') categoria = r['manha_cond_clima']?.toString() ?? r['tarde_cond_clima']?.toString();
    if (campo == 'trabalho') categoria = r['manha_cond_trabalho']?.toString() ?? r['tarde_cond_trabalho']?.toString();
    return BiDataPoint(elementoId: r['id'].toString(), elementoNome: '', tipoElemento: '', local: '', categoria: categoria, data: data);
  }).toList();
}

Future<List<BiDataPoint>> _buscarRdoHorasTrabalhadas(BiContexto ctx, {EstatisticaBi? estatistica}) async {
  final linhas = await _rdoNoContexto(ctx);
  return linhas.map((r) {
    final data = _parseDataBr(r['data']?.toString());
    double totalMin = 0;
    for (final turno in ['manha', 'tarde', 'noite']) {
      final inicio = _horaParaMinutos(r['${turno}_inicio']?.toString());
      final saida = _horaParaMinutos(r['${turno}_saida']?.toString());
      if (inicio != null && saida != null && saida > inicio) totalMin += (saida - inicio);
    }
    return BiDataPoint(elementoId: r['id'].toString(), elementoNome: '', tipoElemento: '', local: '', valor: totalMin / 60, data: data);
  }).toList();
}

// ==========================================================================
// Tração em elemento chumbado — carga_max/desloc_max/cond_avaliar já são
// colunas diretas em `ponto_ensaio_tracao` (bruto, sem sub-agregação).
// ==========================================================================

Future<List<BiDataPoint>> _buscarChumbador(BiContexto ctx, String campo, {EstatisticaBi? estatistica}) async {
  final pontos = await _pontosNoContexto(ctx, 'chumbad', 'ponto_ensaio_tracao(carga_max, desloc_max, cond_avaliar)');
  final resultado = <BiDataPoint>[];
  for (final p in pontos) {
    final ensaioList = p['ponto_ensaio_tracao'] as List? ?? const [];
    if (ensaioList.isEmpty) continue;
    final ensaio = (ensaioList.first as Map).cast<String, dynamic>();
    switch (campo) {
      case 'carga_maxima':
        final v = double.tryParse(ensaio['carga_max']?.toString() ?? '');
        if (v != null) resultado.add(_pontoParaDataPoint(p, valor: v));
        break;
      case 'deslocamento_maximo':
        final v = double.tryParse(ensaio['desloc_max']?.toString() ?? '');
        if (v != null) resultado.add(_pontoParaDataPoint(p, valor: v));
        break;
      case 'status':
        resultado.add(_pontoParaDataPoint(p, categoria: ensaio['cond_avaliar']?.toString() ?? 'Pendente'));
        break;
    }
  }
  return resultado;
}

// ==========================================================================
// Monitoramento de fissuras — medida_x/medida_y/status são colunas diretas
// na leitura mais recente de cada ponto (bruto).
// ==========================================================================

Future<List<BiDataPoint>> _buscarMonitoramentoFissura(BiContexto ctx, String campo, {EstatisticaBi? estatistica}) async {
  final pontos = await _pontosNoContexto(
    ctx,
    'monitoramento%fissura',
    'ponto_ensaio_monitoramento_fissura(id, ponto_ensaio_monitoramento_fissura_leitura(data, hora, medida_x, medida_y, status))',
  );
  final resultado = <BiDataPoint>[];
  for (final p in pontos) {
    final instList = p['ponto_ensaio_monitoramento_fissura'] as List? ?? const [];
    if (instList.isEmpty) continue;
    final leituras = (instList.first as Map)['ponto_ensaio_monitoramento_fissura_leitura'] as List? ?? const [];
    if (leituras.isEmpty) continue;
    // Leitura mais recente (mesma regra da tela de análise geral do ensaio).
    final ordenadas = [...leituras]..sort((a, b) => ('${a['data']} ${a['hora']}').compareTo('${b['data']} ${b['hora']}'));
    final ultima = (ordenadas.last as Map).cast<String, dynamic>();
    switch (campo) {
      case 'deslocamento_x':
        final v = double.tryParse(ultima['medida_x']?.toString() ?? '');
        if (v != null) resultado.add(_pontoParaDataPoint(p, valor: v));
        break;
      case 'deslocamento_y':
        final v = double.tryParse(ultima['medida_y']?.toString() ?? '');
        if (v != null) resultado.add(_pontoParaDataPoint(p, valor: v));
        break;
      case 'status':
        resultado.add(_pontoParaDataPoint(p, categoria: ultima['status']?.toString() ?? 'Estável'));
        break;
    }
  }
  return resultado;
}

// ==========================================================================
// Extração e rompimento de testemunhos — cada TESTEMUNHO tem seu próprio
// elemento (diferente dos demais ensaios) — busca direto das leituras, sem
// passar pelo ponto_ensaio_geral (que aqui é 1 por Local, não por elemento).
// ==========================================================================

Future<List<BiDataPoint>> _buscarExtracao(BiContexto ctx, {EstatisticaBi? estatistica}) async {
  final tipoEnsaioId = await resolverTipoEnsaioIdBi('testemunho');
  if (tipoEnsaioId == null) return [];
  try {
    var q = _s.from('pontos_ensaios_geral').select('''
          id,
          ponto_ensaio_extracao_local(
            ponto_ensaio_extracao_leituras(resistencia_corrigida, elementos_estruturais(id, nome, tipo, local, estruturas(nome)))
          )
        ''').eq('tipo_ensaio_id', tipoEnsaioId);
    if (ctx.elementoId != null) return []; // testemunhos não são por elemento único — não aplica no nível elemento
    if (ctx.estruturaId != null) {
      q = q.eq('estrutura_id', ctx.estruturaId!);
    } else if (ctx.projetoId != null) {
      q = q.eq('projeto_id', ctx.projetoId!);
    } else {
      return [];
    }
    final resp = await q;
    final resultado = <BiDataPoint>[];
    for (final p in (resp as List)) {
      final locaisList = p['ponto_ensaio_extracao_local'] as List? ?? const [];
      if (locaisList.isEmpty) continue;
      final leituras = (locaisList.first as Map)['ponto_ensaio_extracao_leituras'] as List? ?? const [];
      for (final l in leituras) {
        final leitura = (l as Map).cast<String, dynamic>();
        final el = leitura['elementos_estruturais'] as Map<String, dynamic>?;
        // Fetcher com formato de query próprio (não passa pelos helpers
        // compartilhados) — só filtra Local/Tipo por ora; Sistema e os
        // filtros de escopo (projeto/conjunto/estrutura) ainda não se
        // aplicam aqui.
        if (ctx.filtroLocal.isNotEmpty && !ctx.filtroLocal.contains(el?['local']?.toString())) continue;
        if (ctx.filtroTipoElemento.isNotEmpty && !ctx.filtroTipoElemento.contains(el?['tipo']?.toString())) continue;
        final v = double.tryParse(leitura['resistencia_corrigida']?.toString() ?? '');
        if (v == null) continue;
        resultado.add(BiDataPoint(
          estrutura: _nomeEstrutura(el),
          elementoId: el?['id']?.toString() ?? '',
          elementoNome: el?['nome']?.toString() ?? '',
          tipoElemento: el?['tipo']?.toString() ?? 'Desconhecido',
          local: el?['local']?.toString() ?? 'Desconhecido',
          valor: v,
        ));
      }
    }
    return resultado;
  } catch (_) {
    return [];
  }
}

// ==========================================================================
// Carbonatação — cob_arm_p/cob_arm_s são colunas diretas (bruto); frente de
// carbonatação tem múltiplas leituras por ponto (estatística: agrega antes).
// ==========================================================================

Future<List<BiDataPoint>> _buscarCarbonatacao(BiContexto ctx, String campo, {EstatisticaBi? estatistica}) async {
  final pontos = await _pontosNoContexto(ctx, 'carbonat', 'ponto_ensaio_carb(cob_arm_p, cob_arm_s, ponto_ensaio_carb_frentes(profundidade))');
  final resultado = <BiDataPoint>[];
  for (final p in pontos) {
    final ensaioList = p['ponto_ensaio_carb'] as List? ?? const [];
    if (ensaioList.isEmpty) continue;
    final ensaio = (ensaioList.first as Map).cast<String, dynamic>();
    switch (campo) {
      case 'cob_arm_p':
        final v = _numDouble(ensaio['cob_arm_p']);
        if (v != null) resultado.add(_pontoParaDataPoint(p, valor: v));
        break;
      case 'cob_arm_s':
        final v = _numDouble(ensaio['cob_arm_s']);
        if (v != null) resultado.add(_pontoParaDataPoint(p, valor: v));
        break;
      case 'frente':
        final frentes = (ensaio['ponto_ensaio_carb_frentes'] as List? ?? const [])
            .map((f) => _numDouble((f as Map)['profundidade']))
            .whereType<double>()
            .toList();
        if (frentes.isNotEmpty) resultado.add(_pontoParaDataPoint(p, valor: _resolverEstatistica(frentes, estatistica)));
        break;
      // Uma leitura por BiDataPoint, sem agregar no ponto: é a população que
      // a probabilidade de despassivação usa (igual ao relatório), e que o
      // Monte Carlo precisa para não subestimar a dispersão — a média por
      // ponto já elimina parte da variação entre leituras.
      case 'frente_leituras':
        for (final f in ensaio['ponto_ensaio_carb_frentes'] as List? ?? const []) {
          final v = _numDouble((f as Map)['profundidade']);
          if (v != null) resultado.add(_pontoParaDataPoint(p, valor: v));
        }
        break;
    }
  }
  return resultado;
}

// ==========================================================================
// Resistividade — leituras ligam direto em pontos_ensaios_geral (sem tabela
// de ensaio intermediária); resistividade é estatística (agrega leituras).
// ==========================================================================

Future<List<BiDataPoint>> _buscarResistividade(BiContexto ctx, {EstatisticaBi? estatistica}) async {
  final pontos = await _pontosNoContexto(ctx, 'resistividade', 'ponto_ensaio_resistividade_leitura(resistividade)');
  final resultado = <BiDataPoint>[];
  for (final p in pontos) {
    final valores = (p['ponto_ensaio_resistividade_leitura'] as List? ?? const [])
        .map((l) => _numDouble((l as Map)['resistividade']))
        .whereType<double>()
        .toList();
    if (valores.isNotEmpty) resultado.add(_pontoParaDataPoint(p, valor: _resolverEstatistica(valores, estatistica)));
  }
  return resultado;
}

// ==========================================================================
// Esclerometria — valor_Q tem múltiplas leituras por ponto (estatística).
// ==========================================================================

Future<List<BiDataPoint>> _buscarEsclerometria(BiContexto ctx, {EstatisticaBi? estatistica}) async {
  final pontos = await _pontosNoContexto(ctx, 'esclerometria', 'ponto_ensaio_esclerometria(id, ponto_ensaio_esclerometria_leituras(valor_Q))');
  final resultado = <BiDataPoint>[];
  for (final p in pontos) {
    final ensaioList = p['ponto_ensaio_esclerometria'] as List? ?? const [];
    if (ensaioList.isEmpty) continue;
    final valores = ((ensaioList.first as Map)['ponto_ensaio_esclerometria_leituras'] as List? ?? const [])
        .map((l) => _numDouble((l as Map)['valor_Q']))
        .whereType<double>()
        .toList();
    if (valores.isNotEmpty) resultado.add(_pontoParaDataPoint(p, valor: _resolverEstatistica(valores, estatistica)));
  }
  return resultado;
}

// ==========================================================================
// Arrancamento (argamassa E placa cerâmica — mesmas tabelas, só o
// tipo_ensaio_id muda). Resistência não é uma coluna: é `carga / área`
// (área calculada a partir de d1/d2 quando não informada direto), igual à
// fórmula já usada em `arrancamento_modelo_report_data.dart`. Forma de
// ruptura = maior `porcentagem` entre as rupturas daquela leitura.
// ==========================================================================

Future<List<BiDataPoint>> _buscarArrancamento(BiContexto ctx, String tipoEnsaio, String campo, {EstatisticaBi? estatistica}) async {
  final pontos = await _pontosNoContexto(
    ctx,
    tipoEnsaio,
    'ponto_ensaio_arrancamento(id, ponto_ensaio_arrancamento_leitura(carga, area, d1, d2, ponto_ensaio_arrancamento_ruptura(tipo_ruptura, porcentagem)))',
  );
  final resultado = <BiDataPoint>[];
  for (final p in pontos) {
    final ensaioList = p['ponto_ensaio_arrancamento'] as List? ?? const [];
    if (ensaioList.isEmpty) continue;
    final leituras = (ensaioList.first as Map)['ponto_ensaio_arrancamento_leitura'] as List? ?? const [];
    switch (campo) {
      case 'resistencia':
        final tensoes = <double>[];
        for (final l in leituras) {
          final leitura = (l as Map).cast<String, dynamic>();
          final carga = _numDouble(leitura['carga']);
          var area = _numDouble(leitura['area']);
          if ((area == null || area <= 0)) {
            final d1 = _numDouble(leitura['d1']);
            final d2 = _numDouble(leitura['d2']);
            final diametroMedio = (d1 != null && d2 != null && d1 > 0 && d2 > 0) ? (d1 + d2) / 2 : (d1 != null && d1 > 0 ? d1 : 0);
            if (diametroMedio > 0) area = pi * pow(diametroMedio / 2, 2).toDouble();
          }
          if (carga != null && carga > 0 && area != null && area > 0) tensoes.add(carga / area);
        }
        if (tensoes.isNotEmpty) resultado.add(_pontoParaDataPoint(p, valor: _resolverEstatistica(tensoes, estatistica)));
        break;
      case 'forma_ruptura':
        String? predominante;
        double maiorPorcentagem = 0;
        for (final l in leituras) {
          final rupturas = (l as Map)['ponto_ensaio_arrancamento_ruptura'] as List? ?? const [];
          for (final r in rupturas) {
            final ruptura = (r as Map).cast<String, dynamic>();
            final pct = _numDouble(ruptura['porcentagem']) ?? 0;
            if (pct > maiorPorcentagem) {
              maiorPorcentagem = pct;
              predominante = ruptura['tipo_ruptura']?.toString();
            }
          }
        }
        if (predominante != null) resultado.add(_pontoParaDataPoint(p, categoria: predominante));
        break;
    }
  }
  return resultado;
}

// ==========================================================================
// Potencial de corrosão — leituras formam uma grade (linha/coluna);
// `potencial_mv` é guardado em módulo no banco e negado no app (convenção
// ASTM C876), igual a `potencial_modelo_report_data.dart`.
// ==========================================================================

Future<List<BiDataPoint>> _buscarPotencial(BiContexto ctx, {EstatisticaBi? estatistica}) async {
  final pontos = await _pontosNoContexto(ctx, 'potencial', 'ponto_ensaio_potencial(id, ponto_ensaio_potencial_leitura(potencial_mv))');
  final resultado = <BiDataPoint>[];
  for (final p in pontos) {
    final ensaioList = p['ponto_ensaio_potencial'] as List? ?? const [];
    if (ensaioList.isEmpty) continue;
    final valores = ((ensaioList.first as Map)['ponto_ensaio_potencial_leitura'] as List? ?? const [])
        .map((l) => _numDouble((l as Map)['potencial_mv']))
        .whereType<double>()
        .map((v) => -v.abs())
        .toList();
    if (valores.isNotEmpty) resultado.add(_pontoParaDataPoint(p, valor: _resolverEstatistica(valores, estatistica)));
  }
  return resultado;
}

// ==========================================================================
// Prova de carga estática — carga máxima/deslocamento máximo/residual são
// valores brutos por ponto (não têm Média/Desvio/CV: já são o próprio
// máximo, igual ao "carga_maxima_pc"/"desloc_max_pc"/"residual_maximo_pc" do
// catálogo de relatório); status é calculado (não é coluna): "Excedido"
// quando o maior deslocamento de alguma medição passa do limite configurado
// (`desloc_max`) DESSA medição — igual a `prova_carga_modelo_report_data.dart`.
// Residual = maior deslocamento em Carregamento menos o deslocamento da
// última leitura de Descarregamento (a mais próxima de carga zero) — igual a
// `calcularEstatisticasPonto` em `analise_prova_carga_utils.dart`.
// ==========================================================================

Future<List<BiDataPoint>> _buscarProvaCarga(BiContexto ctx, String campo, {EstatisticaBi? estatistica}) async {
  final pontos = await _pontosNoContexto(
    ctx,
    'prova de carga',
    'ponto_ensaio_prova_carga(id, ponto_ensaio_prova_carga_ponto_medicao(desloc_max, ponto_ensaio_prova_carga_ponto_leitura(deslocamento, carregamento, etapa)))',
  );
  final resultado = <BiDataPoint>[];
  for (final p in pontos) {
    final ensaioList = p['ponto_ensaio_prova_carga'] as List? ?? const [];
    if (ensaioList.isEmpty) continue;
    final medicoes = (ensaioList.first as Map)['ponto_ensaio_prova_carga_ponto_medicao'] as List? ?? const [];
    final leituras = medicoes
        .expand((m) => (m as Map)['ponto_ensaio_prova_carga_ponto_leitura'] as List? ?? const [])
        .map((l) => (l as Map).cast<String, dynamic>())
        .toList();
    switch (campo) {
      case 'deslocamento_maximo':
        final valores = leituras.map((l) => _numDouble(l['deslocamento'])).whereType<double>().toList();
        if (valores.isNotEmpty) resultado.add(_pontoParaDataPoint(p, valor: valores.reduce(max)));
        break;
      case 'carga_maxima':
        final valores = leituras.map((l) => _numDouble(l['carregamento'])).whereType<double>().toList();
        if (valores.isNotEmpty) resultado.add(_pontoParaDataPoint(p, valor: valores.reduce(max)));
        break;
      case 'deslocamento_residual':
        final carregamento = leituras.where((l) => l['etapa'] == 'Carregamento').toList();
        final descarregamento = leituras.where((l) => l['etapa'] == 'Descarregamento').toList()
          ..sort((a, b) => (_numDouble(b['carregamento']) ?? 0).compareTo(_numDouble(a['carregamento']) ?? 0));
        if (carregamento.isNotEmpty && descarregamento.isNotEmpty) {
          final maxCarregamento = carregamento.map((l) => _numDouble(l['deslocamento']) ?? 0).reduce(max);
          final deslocFinalDescarregamento = _numDouble(descarregamento.last['deslocamento']) ?? 0;
          resultado.add(_pontoParaDataPoint(p, valor: maxCarregamento - deslocFinalDescarregamento));
        }
        break;
      case 'status':
        var excedido = false;
        for (final m in medicoes) {
          final medicao = (m as Map).cast<String, dynamic>();
          final limite = _numDouble(medicao['desloc_max']);
          if (limite == null) continue;
          final leiturasMedicao = medicao['ponto_ensaio_prova_carga_ponto_leitura'] as List? ?? const [];
          final maiorDeslocamento = leiturasMedicao.map((l) => _numDouble((l as Map)['deslocamento']) ?? 0).fold<double>(0, max);
          if (maiorDeslocamento > limite) excedido = true;
        }
        if (medicoes.isNotEmpty) resultado.add(_pontoParaDataPoint(p, categoria: excedido ? 'Excedido' : 'Dentro do limite'));
        break;
    }
  }
  return resultado;
}

// ==========================================================================
// Inspeção visual — estrutura bem diferente dos demais: não é "1 ponto = 1
// elemento" com leituras filhas, é um registro (`ponto_inspecao_visual`)
// por local/elemento dentro de uma INSPEÇÃO. São TRÊS níveis, não dois:
//
//   pontos_ensaios_geral        (o "ponto" do ensaio, como nos outros)
//     └ ponto_inspecao_visual_geral   (a inspeção: nome, tipo, descrição)
//         └ ponto_inspecao_visual     (cada registro)
//
// `ponto_inspecao_visual.id_ponto_geral` aponta para a INSPEÇÃO do meio, e
// não para `pontos_ensaios_geral` — este código supunha o contrário e
// filtrava com os ids do nível errado, então nenhum registro casava e todo
// cartão de inspeção visual dizia "sem dados suficientes".
//
// Local e tipo de elemento também vêm do próprio registro
// (`estruturas_locais` e `tipos_elemento`): o elemento estrutural é
// opcional na inspeção visual e quase sempre fica vazio — tirar local e
// tipo só de `elementos_estruturais` deixava tudo em "Desconhecido".
//
// GUT não é uma coluna — é a mesma fórmula de `risco_gut_calculo.dart`,
// reaproveitada direto (fonte única do cálculo, usada também no registro e
// nas telas do ensaio).
// ==========================================================================

Future<List<BiDataPoint>> _buscarInspecaoVisual(BiContexto ctx, String campo, {EstatisticaBi? estatistica}) async {
  final tipoEnsaioId = await resolverTipoEnsaioIdBi(TipoEnsaioId.inspecaoVisual);
  if (tipoEnsaioId == null) return [];
  try {
    var geralQ = _s.from('pontos_ensaios_geral').select('id').eq('tipo_ensaio_id', tipoEnsaioId);
    if (ctx.elementoId != null) {
      geralQ = geralQ.eq('elemento_estrutural_id', ctx.elementoId!);
    } else if (ctx.estruturaId != null) {
      geralQ = geralQ.eq('estrutura_id', ctx.estruturaId!);
    } else if (ctx.projetoId != null) {
      geralQ = geralQ.eq('projeto_id', ctx.projetoId!);
    } else {
      return [];
    }
    final geralResp = await geralQ;
    final geralIds = (geralResp as List).map((g) => g['id'].toString()).toList();
    if (geralIds.isEmpty) return [];

    // Nível do meio: as inspeções desses pontos. É o id delas que os
    // registros guardam em `id_ponto_geral`.
    final inspecoesResp = await _s.from('ponto_inspecao_visual_geral').select('id').inFilter('id_ponto_geral', geralIds);
    final inspecaoIds = (inspecoesResp as List).map((i) => i['id'].toString()).toList();
    if (inspecaoIds.isEmpty) return [];

    final registros = await _s.from('ponto_inspecao_visual').select('''
          id, registro, id_elemento,
          estruturas_locais(nome), tipos_elemento(nome), estruturas(nome),
          elementos_estruturais(id, nome, tipo, local, estruturas(nome)),
          ponto_inspecao_visual_anomalia(area_afetada, risco_maj, risco_tipo, risco_valor,
            anomalias(nome, categoria, gravidade_valor, urgencia_valor, tendencia_valor))
        ''').inFilter('id_ponto_geral', inspecaoIds);

    final tiposDoSistema = ctx.filtroSistema.isEmpty ? null : await _resolverTiposPorSistema(ctx.filtroSistema);
    final resultado = <BiDataPoint>[];
    for (final r in (registros as List)) {
      final registro = (r as Map).cast<String, dynamic>();
      final el = registro['elementos_estruturais'] as Map<String, dynamic>?;
      // O registro traz o próprio local e o próprio tipo de elemento; o
      // elemento estrutural (opcional) só entra como reserva.
      final local = _textoOuNulo((registro['estruturas_locais'] as Map?)?['nome']) ?? _textoOuNulo(el?['local']);
      final tipo = _textoOuNulo((registro['tipos_elemento'] as Map?)?['nome']) ?? _textoOuNulo(el?['tipo']);
      if (ctx.filtroLocal.isNotEmpty && !ctx.filtroLocal.contains(local)) continue;
      if (ctx.filtroTipoElemento.isNotEmpty && !ctx.filtroTipoElemento.contains(tipo)) continue;
      if (tiposDoSistema != null && !tiposDoSistema.contains(tipo)) continue;

      final anomalias = (registro['ponto_inspecao_visual_anomalia'] as List? ?? const []).map((a) => (a as Map).cast<String, dynamic>()).toList();
      BiDataPoint pontoBase({double? valor, String? categoria}) => BiDataPoint(
            // Sem elemento estrutural, quem nomeia a barra é o próprio
            // registro ("Região externa - Pilares") — antes ficava sem
            // rótulo nenhum.
            estrutura: _textoOuNulo((registro['estruturas'] as Map?)?['nome']) ?? _nomeEstrutura(el),
            elementoId: el?['id']?.toString() ?? registro['id_elemento']?.toString() ?? registro['id'].toString(),
            elementoNome: _textoOuNulo(el?['nome']) ?? _textoOuNulo(registro['registro']) ?? 'Sem nome',
            tipoElemento: tipo ?? 'Desconhecido',
            local: local ?? 'Desconhecido',
            valor: valor,
            categoria: categoria,
          );

      switch (campo) {
        // G, U, T e GUT: UM ponto por ANOMALIA, somados no agrupamento (ver
        // AgregacaoBi.soma). Antes era o MAIOR GUT de cada registro, depois
        // tirada a média do grupo — o que escondia quantas anomalias o local
        // tinha. A categoria do ponto é a categoria da anomalia: é o que
        // permite empilhar o GUT de um local por tipo de anomalia.
        case 'pontuacao_gut':
        case 'gravidade':
        case 'urgencia':
        case 'tendencia':
          for (final a in anomalias) {
            final anomalia = a['anomalias'] as Map<String, dynamic>?;
            final double? valor = switch (campo) {
              'gravidade' => double.tryParse(anomalia?['gravidade_valor']?.toString() ?? ''),
              'urgencia' => double.tryParse(anomalia?['urgencia_valor']?.toString() ?? ''),
              'tendencia' => double.tryParse(anomalia?['tendencia_valor']?.toString() ?? ''),
              // Mesma fórmula (fonte única) do registro, das telas e do
              // somatório do relatório.
              _ => calcularPontuacaoRiscoGut(
                  gravidadeValor: anomalia?['gravidade_valor'],
                  urgenciaValor: anomalia?['urgencia_valor'],
                  tendenciaValor: anomalia?['tendencia_valor'],
                  majoracao: a['risco_maj'],
                  areaAfetada: a['area_afetada'],
                ),
            };
            if (valor == null) continue;
            resultado.add(pontoBase(valor: valor, categoria: anomalia?['categoria']?.toString() ?? 'Sem categoria'));
          }
          break;
        // Tipo de risco + intensidade de cada anomalia ("Humano · Alto").
        case 'risco':
          for (final a in anomalias) {
            final tipo = a['risco_tipo']?.toString();
            final classe = a['risco_valor']?.toString();
            if (tipo == null || tipo.isEmpty || classe == null || classe.isEmpty) continue;
            resultado.add(pontoBase(categoria: '$tipo · $classe'));
          }
          break;
        case 'anomalias':
          for (final a in anomalias) {
            final nome = (a['anomalias'] as Map?)?['nome']?.toString();
            if (nome != null) resultado.add(pontoBase(categoria: nome));
          }
          break;
        case 'categoria_anomalia':
          for (final a in anomalias) {
            final categoria = (a['anomalias'] as Map?)?['categoria']?.toString();
            if (categoria != null) resultado.add(pontoBase(categoria: categoria));
          }
          break;
      }
    }
    return resultado;
  } catch (_) {
    return [];
  }
}

// ==========================================================================
// Ultrassonografia — não reimplementa a física do zero: usa `UltrassomMath`
// (já existente, testado no ensaio) direto sobre a média das leituras de
// cada elemento, igual à agregação feita em
// `analise_todos_ultrassom_screen.dart`/`ultrassom_modelo_report_data.dart`.
// ==========================================================================

Future<List<BiDataPoint>> _buscarUltrassom(BiContexto ctx, String campo, {EstatisticaBi? estatistica}) async {
  final pontos = await _pontosNoContexto(
    ctx,
    'ultrass',
    '''ponto_ensaio_ultrassom(id, modo, tipo_onda, alfa_e, densidade,
          ponto_ensaio_ultrassom_direto_medicao(ponto_ensaio_ultrassom_direto_leitura(velocidade)),
          ponto_ensaio_ultrassom_indireto_medicao(ponto_ensaio_ultrassom_indireto_leitura(velocidade)))''',
  );

  // Agrupa por elemento (um elemento pode ter mais de um ponto/pulso).
  final porElemento = <String, List<Map<String, dynamic>>>{};
  for (final p in pontos) {
    final elementoId = p['elemento_estrutural_id']?.toString() ?? '';
    porElemento.putIfAbsent(elementoId, () => []).add(p);
  }

  final resultado = <BiDataPoint>[];
  for (final entry in porElemento.entries) {
    final pontosDoElemento = entry.value;
    final velocidadesLong = <double>[];
    final velocidadesTrans = <double>[];
    double? alfaE;
    double? densidade;
    String? modo;
    for (final p in pontosDoElemento) {
      final ensaioList = p['ponto_ensaio_ultrassom'] as List? ?? const [];
      if (ensaioList.isEmpty) continue;
      final ensaio = (ensaioList.first as Map).cast<String, dynamic>();
      modo ??= ensaio['modo']?.toString();
      alfaE ??= _numDouble(ensaio['alfa_e']);
      densidade ??= _numDouble(ensaio['densidade']);
      // `tipo_onda` fica no ensaio (um ponto de ultrassom inteiro é
      // Longitudinal OU Transversal) — um elemento com as duas ondas tem
      // dois pontos de ensaio separados, cada um com seu próprio modo
      // (direto/indireto/mapeamento) e suas próprias leituras.
      final velocidades = [
        ...(ensaio['ponto_ensaio_ultrassom_direto_medicao'] as List? ?? const [])
            .expand((m) => (m as Map)['ponto_ensaio_ultrassom_direto_leitura'] as List? ?? const [])
            .map((l) => _numDouble((l as Map)['velocidade']))
            .whereType<double>(),
        ...(ensaio['ponto_ensaio_ultrassom_indireto_medicao'] as List? ?? const [])
            .expand((m) => (m as Map)['ponto_ensaio_ultrassom_indireto_leitura'] as List? ?? const [])
            .map((l) => _numDouble((l as Map)['velocidade']))
            .whereType<double>(),
      ];
      if (ensaio['tipo_onda']?.toString() == 'Transversal') {
        velocidadesTrans.addAll(velocidades);
      } else {
        velocidadesLong.addAll(velocidades);
      }
    }
    if (velocidadesLong.isEmpty && velocidadesTrans.isEmpty) continue;
    final el = (pontosDoElemento.first['elementos_estruturais'] as Map?)?.cast<String, dynamic>();
    final vLongMedia = velocidadesLong.isEmpty ? null : _media(velocidadesLong);
    final vTransMedia = velocidadesTrans.isEmpty ? null : _media(velocidadesTrans);

    BiDataPoint pontoBase({double? valor, String? categoria}) => BiDataPoint(
          estrutura: _nomeEstrutura(el),
          elementoId: entry.key,
          elementoNome: el?['nome']?.toString() ?? '',
          tipoElemento: el?['tipo']?.toString() ?? 'Desconhecido',
          local: el?['local']?.toString() ?? 'Desconhecido',
          valor: valor,
          categoria: categoria,
        );

    switch (campo) {
      case 'velocidade_longitudinal':
        if (vLongMedia != null) resultado.add(pontoBase(valor: vLongMedia));
        break;
      case 'velocidade_transversal':
        if (vTransMedia != null) resultado.add(pontoBase(valor: vTransMedia));
        break;
      case 'densidade':
        if (densidade != null) resultado.add(pontoBase(valor: densidade));
        break;
      case 'alfa_e':
        if (alfaE != null) resultado.add(pontoBase(valor: alfaE));
        break;
      case 'modo':
        if (modo != null) resultado.add(pontoBase(categoria: modo));
        break;
      case 'poisson':
      case 'ecd':
      case 'fck':
        if (vLongMedia == null || vTransMedia == null || alfaE == null || densidade == null) continue;
        final poisson = UltrassomMath.poisson(vp: vLongMedia, vs: vTransMedia);
        if (campo == 'poisson') {
          resultado.add(pontoBase(valor: poisson));
          break;
        }
        final ed = UltrassomMath.moduloElasticidadeDinamico(densidade: densidade, vs: vTransMedia, poisson: poisson);
        if (campo == 'ecd') {
          resultado.add(pontoBase(valor: ed / 1000)); // MPa -> GPa
          break;
        }
        resultado.add(pontoBase(valor: UltrassomMath.resistenciaCompressaoEstimada(ed: ed, alfaE: alfaE)));
        break;
    }
  }
  return resultado;
}

// ==========================================================================
// Fonte "não implementada" — sobra só pra campos que dependem de dado ainda
// não exposto neste catálogo (ex: Transversal/fck/Ecd/Poisson do Ultrassom
// sem `tipo_onda` por leitura — ver nota no fetcher acima).
Future<List<BiDataPoint>> _naoImplementado(BiContexto ctx, {EstatisticaBi? estatistica}) async => [];

// ==========================================================================
// Catálogo
// ==========================================================================

final List<FonteBiCatalogo> catalogoFontesBi = [
  FonteBiCatalogo(
    chave: 'dados_gerais',
    rotulo: 'Dados gerais',
    campos: [
      CampoBiCatalogo(chave: 'idade', rotulo: 'Idade da estrutura', categoria: CategoriaDadoBi.bruto, unidade: 'anos', opcoesAgrupamento: const [], buscar: (ctx, {estatistica}) => _buscarIdadeCaaRevestimentoTipo(ctx, 'idade')),
      CampoBiCatalogo(chave: 'caa', rotulo: 'CAA (Classe de Agressividade Ambiental)', categoria: CategoriaDadoBi.categorico, opcoesAgrupamento: const [], buscar: (ctx, {estatistica}) => _buscarIdadeCaaRevestimentoTipo(ctx, 'caa')),
      CampoBiCatalogo(chave: 'tipo_elemento', rotulo: 'Tipo do elemento', categoria: CategoriaDadoBi.categorico, buscar: (ctx, {estatistica}) => _buscarIdadeCaaRevestimentoTipo(ctx, 'tipo')),
      CampoBiCatalogo(chave: 'revestimento', rotulo: 'Revestimento', categoria: CategoriaDadoBi.categorico, buscar: (ctx, {estatistica}) => _buscarIdadeCaaRevestimentoTipo(ctx, 'revestimento')),
      CampoBiCatalogo(chave: 'posicao_planta', rotulo: 'Posição em planta', categoria: CategoriaDadoBi.planta, buscar: (ctx, {estatistica}) async => []),
      CampoBiCatalogo(chave: 'galeria_geral', rotulo: 'Galeria de fotos geral', categoria: CategoriaDadoBi.galeria, buscar: (ctx, {estatistica}) async => []),
    ],
  ),
  FonteBiCatalogo(
    chave: 'rdo',
    rotulo: 'RDO (Relatório Diário de Obra)',
    campos: [
      CampoBiCatalogo(chave: 'rdo_clima', rotulo: 'Condição de clima ao longo das datas', categoria: CategoriaDadoBi.categorico, opcoesAgrupamento: const [], buscar: (ctx, {estatistica}) => _buscarRdoCondicao(ctx, 'clima')),
      CampoBiCatalogo(chave: 'rdo_trabalho', rotulo: 'Condição de trabalho ao longo das datas', categoria: CategoriaDadoBi.categorico, opcoesAgrupamento: const [], buscar: (ctx, {estatistica}) => _buscarRdoCondicao(ctx, 'trabalho')),
      // Sem local/tipo/elemento (o ponto é por dia de obra, não por ponto de
      // ensaio) — só "por dia" faz sentido pra segmentar; sem agrupamento
      // nenhum, o padrão já calcula a média geral (ver `_chaveAgrupamento`).
      CampoBiCatalogo(chave: 'rdo_horas', rotulo: 'Horas trabalhadas no dia', categoria: CategoriaDadoBi.bruto, unidade: 'h', opcoesAgrupamento: const ['data'], buscar: _buscarRdoHorasTrabalhadas),
    ],
  ),
  FonteBiCatalogo(
    chave: 'tracao_chumbado',
    rotulo: 'Tração em elemento chumbado',
    tipoEnsaio: 'chumbad',
    campos: [
      CampoBiCatalogo(chave: 'carga_maxima', rotulo: 'Força máxima', categoria: CategoriaDadoBi.bruto, unidade: 'kN', buscar: (ctx, {estatistica}) => _buscarChumbador(ctx, 'carga_maxima')),
      CampoBiCatalogo(chave: 'deslocamento_maximo', rotulo: 'Deslocamento máximo', categoria: CategoriaDadoBi.bruto, unidade: 'mm', buscar: (ctx, {estatistica}) => _buscarChumbador(ctx, 'deslocamento_maximo')),
      CampoBiCatalogo(chave: 'status', rotulo: 'Status', categoria: CategoriaDadoBi.categorico, buscar: (ctx, {estatistica}) => _buscarChumbador(ctx, 'status')),
    ],
  ),
  FonteBiCatalogo(
    chave: 'monitoramento_fissuras',
    rotulo: 'Monitoramento de fissuras',
    tipoEnsaio: 'monitoramento de fissura',
    campos: [
      CampoBiCatalogo(chave: 'status', rotulo: 'Status', categoria: CategoriaDadoBi.categorico, buscar: (ctx, {estatistica}) => _buscarMonitoramentoFissura(ctx, 'status')),
      CampoBiCatalogo(chave: 'deslocamento_x', rotulo: 'Deslocamento eixo X', categoria: CategoriaDadoBi.bruto, unidade: 'mm', buscar: (ctx, {estatistica}) => _buscarMonitoramentoFissura(ctx, 'deslocamento_x')),
      CampoBiCatalogo(chave: 'deslocamento_y', rotulo: 'Deslocamento eixo Y', categoria: CategoriaDadoBi.bruto, unidade: 'mm', buscar: (ctx, {estatistica}) => _buscarMonitoramentoFissura(ctx, 'deslocamento_y')),
      CampoBiCatalogo(chave: 'galeria', rotulo: 'Galeria', categoria: CategoriaDadoBi.galeria, buscar: (ctx, {estatistica}) async => []),
    ],
  ),
  FonteBiCatalogo(
    chave: 'extracao_testemunho',
    rotulo: 'Extração e rompimento de testemunhos',
    tipoEnsaio: 'testemunho',
    campos: [
      CampoBiCatalogo(chave: 'resistencia_corrigida', rotulo: 'Resistência à compressão corrigida', categoria: CategoriaDadoBi.estatistica, unidade: 'MPa', buscar: (ctx, {estatistica}) => _buscarExtracao(ctx, estatistica: estatistica)),
      CampoBiCatalogo(chave: 'galeria', rotulo: 'Galeria', categoria: CategoriaDadoBi.galeria, buscar: (ctx, {estatistica}) async => []),
      CampoBiCatalogo(chave: 'plantas_marcadas', rotulo: 'Plantas marcadas', categoria: CategoriaDadoBi.planta, buscar: (ctx, {estatistica}) async => []),
    ],
  ),
  FonteBiCatalogo(
    chave: 'carbonatacao',
    rotulo: 'Frente de carbonatação',
    tipoEnsaio: 'carbonat',
    campos: [
      CampoBiCatalogo(chave: 'frente', rotulo: 'Frente de carbonatação', categoria: CategoriaDadoBi.estatistica, unidade: 'mm', buscar: (ctx, {estatistica}) => _buscarCarbonatacao(ctx, 'frente', estatistica: estatistica)),
      CampoBiCatalogo(chave: 'frente_leituras', rotulo: 'Frente de carbonatação (leituras individuais)', categoria: CategoriaDadoBi.bruto, unidade: 'mm', buscar: (ctx, {estatistica}) => _buscarCarbonatacao(ctx, 'frente_leituras')),
      CampoBiCatalogo(chave: 'cob_arm_p', rotulo: 'Cobrimento armadura principal', categoria: CategoriaDadoBi.bruto, unidade: 'mm', buscar: (ctx, {estatistica}) => _buscarCarbonatacao(ctx, 'cob_arm_p')),
      CampoBiCatalogo(chave: 'cob_arm_s', rotulo: 'Cobrimento armadura secundária', categoria: CategoriaDadoBi.bruto, unidade: 'mm', buscar: (ctx, {estatistica}) => _buscarCarbonatacao(ctx, 'cob_arm_s')),
      CampoBiCatalogo(chave: 'galeria', rotulo: 'Galeria', categoria: CategoriaDadoBi.galeria, buscar: (ctx, {estatistica}) async => []),
    ],
  ),
  FonteBiCatalogo(
    chave: 'resistividade',
    rotulo: 'Resistividade elétrica superficial',
    tipoEnsaio: 'resistividade',
    campos: [
      CampoBiCatalogo(chave: 'resistividade', rotulo: 'Resistividade', categoria: CategoriaDadoBi.estatistica, unidade: 'KΩ.cm', buscar: (ctx, {estatistica}) => _buscarResistividade(ctx, estatistica: estatistica)),
    ],
  ),
  FonteBiCatalogo(
    chave: 'esclerometria',
    rotulo: 'Esclerometria',
    tipoEnsaio: 'esclerometria',
    campos: [
      CampoBiCatalogo(chave: 'valor_q', rotulo: 'Valor Q', categoria: CategoriaDadoBi.estatistica, buscar: (ctx, {estatistica}) => _buscarEsclerometria(ctx, estatistica: estatistica)),
    ],
  ),
  FonteBiCatalogo(
    chave: 'arrancamento_argamassa',
    rotulo: 'Arrancamento em argamassa',
    tipoEnsaio: TipoEnsaioId.arrancamentoArgamassa,
    campos: [
      CampoBiCatalogo(chave: 'resistencia', rotulo: 'Resistência', categoria: CategoriaDadoBi.estatistica, unidade: 'MPa', buscar: (ctx, {estatistica}) => _buscarArrancamento(ctx, TipoEnsaioId.arrancamentoArgamassa, 'resistencia', estatistica: estatistica)),
      CampoBiCatalogo(chave: 'forma_ruptura', rotulo: 'Forma de ruptura predominante', categoria: CategoriaDadoBi.categorico, buscar: (ctx, {estatistica}) => _buscarArrancamento(ctx, TipoEnsaioId.arrancamentoArgamassa, 'forma_ruptura')),
      CampoBiCatalogo(chave: 'galeria', rotulo: 'Galeria', categoria: CategoriaDadoBi.galeria, buscar: _naoImplementado),
    ],
  ),
  FonteBiCatalogo(
    chave: 'arrancamento_ceramica',
    rotulo: 'Arrancamento em placa cerâmica',
    tipoEnsaio: TipoEnsaioId.arrancamentoCeramica,
    campos: [
      CampoBiCatalogo(chave: 'resistencia', rotulo: 'Resistência', categoria: CategoriaDadoBi.estatistica, unidade: 'MPa', buscar: (ctx, {estatistica}) => _buscarArrancamento(ctx, TipoEnsaioId.arrancamentoCeramica, 'resistencia', estatistica: estatistica)),
      CampoBiCatalogo(chave: 'forma_ruptura', rotulo: 'Forma de ruptura predominante', categoria: CategoriaDadoBi.categorico, buscar: (ctx, {estatistica}) => _buscarArrancamento(ctx, TipoEnsaioId.arrancamentoCeramica, 'forma_ruptura')),
      CampoBiCatalogo(chave: 'galeria', rotulo: 'Galeria', categoria: CategoriaDadoBi.galeria, buscar: _naoImplementado),
    ],
  ),
  FonteBiCatalogo(
    chave: 'inspecao_visual',
    rotulo: 'Inspeção visual',
    tipoEnsaio: TipoEnsaioId.inspecaoVisual,
    campos: [
      CampoBiCatalogo(chave: 'pontuacao_gut', rotulo: 'GUT (somatório)', categoria: CategoriaDadoBi.bruto, agregacao: AgregacaoBi.soma, buscar: (ctx, {estatistica}) => _buscarInspecaoVisual(ctx, 'pontuacao_gut')),
      CampoBiCatalogo(chave: 'gravidade', rotulo: 'G — Gravidade (somatório)', categoria: CategoriaDadoBi.bruto, agregacao: AgregacaoBi.soma, buscar: (ctx, {estatistica}) => _buscarInspecaoVisual(ctx, 'gravidade')),
      CampoBiCatalogo(chave: 'urgencia', rotulo: 'U — Urgência (somatório)', categoria: CategoriaDadoBi.bruto, agregacao: AgregacaoBi.soma, buscar: (ctx, {estatistica}) => _buscarInspecaoVisual(ctx, 'urgencia')),
      CampoBiCatalogo(chave: 'tendencia', rotulo: 'T — Tendência (somatório)', categoria: CategoriaDadoBi.bruto, agregacao: AgregacaoBi.soma, buscar: (ctx, {estatistica}) => _buscarInspecaoVisual(ctx, 'tendencia')),
      CampoBiCatalogo(chave: 'risco', rotulo: 'Risco (tipo · intensidade)', categoria: CategoriaDadoBi.categorico, buscar: (ctx, {estatistica}) => _buscarInspecaoVisual(ctx, 'risco')),
      CampoBiCatalogo(chave: 'anomalias', rotulo: 'Anomalias', categoria: CategoriaDadoBi.categorico, buscar: (ctx, {estatistica}) => _buscarInspecaoVisual(ctx, 'anomalias')),
      CampoBiCatalogo(chave: 'categoria_anomalia', rotulo: 'Categoria de anomalia', categoria: CategoriaDadoBi.categorico, buscar: (ctx, {estatistica}) => _buscarInspecaoVisual(ctx, 'categoria_anomalia')),
      CampoBiCatalogo(chave: 'galeria', rotulo: 'Galeria', categoria: CategoriaDadoBi.galeria, buscar: _naoImplementado),
    ],
  ),
  FonteBiCatalogo(
    chave: 'potencial_corrosao',
    rotulo: 'Potencial de corrosão',
    tipoEnsaio: 'potencial',
    campos: [
      CampoBiCatalogo(chave: 'potencial', rotulo: 'Potencial de corrosão', categoria: CategoriaDadoBi.estatistica, unidade: 'mV', buscar: (ctx, {estatistica}) => _buscarPotencial(ctx, estatistica: estatistica)),
    ],
  ),
  FonteBiCatalogo(
    chave: 'prova_carga',
    rotulo: 'Prova de carga estática',
    tipoEnsaio: 'prova de carga',
    campos: [
      CampoBiCatalogo(chave: 'status', rotulo: 'Status/condição', categoria: CategoriaDadoBi.categorico, buscar: (ctx, {estatistica}) => _buscarProvaCarga(ctx, 'status')),
      CampoBiCatalogo(chave: 'carga_maxima', rotulo: 'Carga máxima', categoria: CategoriaDadoBi.bruto, unidade: 'kg', buscar: (ctx, {estatistica}) => _buscarProvaCarga(ctx, 'carga_maxima')),
      CampoBiCatalogo(chave: 'deslocamento_maximo', rotulo: 'Deslocamento máximo', categoria: CategoriaDadoBi.bruto, unidade: 'mm', buscar: (ctx, {estatistica}) => _buscarProvaCarga(ctx, 'deslocamento_maximo')),
      CampoBiCatalogo(chave: 'deslocamento_residual', rotulo: 'Deslocamento residual', categoria: CategoriaDadoBi.bruto, unidade: 'mm', buscar: (ctx, {estatistica}) => _buscarProvaCarga(ctx, 'deslocamento_residual')),
      CampoBiCatalogo(chave: 'marcacao_planta', rotulo: 'Marcação em planta', categoria: CategoriaDadoBi.planta, buscar: _naoImplementado),
      CampoBiCatalogo(chave: 'galeria', rotulo: 'Galeria', categoria: CategoriaDadoBi.galeria, buscar: _naoImplementado),
    ],
  ),
  FonteBiCatalogo(
    chave: 'ultrassom',
    rotulo: 'Ultrassonografia',
    tipoEnsaio: 'ultrass',
    campos: [
      CampoBiCatalogo(chave: 'velocidade_longitudinal', rotulo: 'Velocidade longitudinal', categoria: CategoriaDadoBi.estatistica, unidade: 'm/s', buscar: (ctx, {estatistica}) => _buscarUltrassom(ctx, 'velocidade_longitudinal', estatistica: estatistica)),
      CampoBiCatalogo(chave: 'velocidade_transversal', rotulo: 'Velocidade transversal', categoria: CategoriaDadoBi.estatistica, unidade: 'm/s', buscar: (ctx, {estatistica}) => _buscarUltrassom(ctx, 'velocidade_transversal', estatistica: estatistica)),
      CampoBiCatalogo(chave: 'poisson', rotulo: 'Módulo de Poisson estimado', categoria: CategoriaDadoBi.bruto, buscar: (ctx, {estatistica}) => _buscarUltrassom(ctx, 'poisson')),
      CampoBiCatalogo(chave: 'ecd', rotulo: 'Ecd estimado', categoria: CategoriaDadoBi.bruto, unidade: 'GPa', buscar: (ctx, {estatistica}) => _buscarUltrassom(ctx, 'ecd')),
      CampoBiCatalogo(chave: 'fck', rotulo: 'fck estimado', categoria: CategoriaDadoBi.bruto, unidade: 'MPa', buscar: (ctx, {estatistica}) => _buscarUltrassom(ctx, 'fck')),
      CampoBiCatalogo(chave: 'densidade', rotulo: 'Densidade', categoria: CategoriaDadoBi.bruto, buscar: (ctx, {estatistica}) => _buscarUltrassom(ctx, 'densidade')),
      CampoBiCatalogo(chave: 'alfa_e', rotulo: 'Alfa E', categoria: CategoriaDadoBi.bruto, buscar: (ctx, {estatistica}) => _buscarUltrassom(ctx, 'alfa_e')),
      CampoBiCatalogo(chave: 'modo', rotulo: 'Modo', categoria: CategoriaDadoBi.categorico, buscar: (ctx, {estatistica}) => _buscarUltrassom(ctx, 'modo')),
      // "Classificação" depende de faixas de referência que não têm fetcher
      // simples reaproveitável aqui — fica pra depois.
      CampoBiCatalogo(chave: 'classificacao', rotulo: 'Classificação', categoria: CategoriaDadoBi.categorico, buscar: _naoImplementado),
    ],
  ),
];

FonteBiCatalogo? buscarFonteBi(String chave) {
  try {
    return catalogoFontesBi.firstWhere((f) => f.chave == chave);
  } catch (_) {
    return null;
  }
}

CampoBiCatalogo? buscarCampoBi(String fonteChave, String campoChave) {
  final fonte = buscarFonteBi(fonteChave);
  if (fonte == null) return null;
  try {
    return fonte.campos.firstWhere((c) => c.chave == campoChave);
  } catch (_) {
    return null;
  }
}
