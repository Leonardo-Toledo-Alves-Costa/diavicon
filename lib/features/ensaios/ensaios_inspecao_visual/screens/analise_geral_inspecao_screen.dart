import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../utils/analise_charts_util.dart';
import '../utils/risco_gut_calculo.dart';

// =========================================================================
// 1. MODELS DE DADOS
// =========================================================================

class ResumoGeralModel {
  final int totalRegistros;
  final int totalLocais;
  final int totalElementos;
  final int pontuacaoGutTotal;
  ResumoGeralModel({
    required this.totalRegistros, required this.totalLocais,
    required this.totalElementos, required this.pontuacaoGutTotal,
  });
}

/// Igual a [EstatisticasAnaliseData] só que com uma dimensão a mais: o Local.
/// [gutPorLocal] é o ranking simples (pra um gráfico de barras direto,
/// "quais locais concentram mais risco"); [gutPorLocalESerie] é a mesma
/// ideia dos gráficos por elemento/sistema, mas quebrando cada local pelas
/// anomalias que mais pesam nele.
class EstatisticasGeralData {
  final List<ChartDataBar> gutPorLocal;
  final List<ChartDataBar> topAnomalias;
  final List<ChartDataPie> distribuicaoRiscos;
  final List<ChartDataPie> distribuicaoCategorias;
  final List<String> seriesAnomalias;
  final List<Color> coresSeries;
  final List<String> eixoXElementos;
  final Map<String, Map<String, double>> gutPorElementoESerie;
  final List<String> eixoXSistemas;
  final Map<String, Map<String, double>> gutPorSistemaESerie;
  final List<String> eixoXLocais;
  final Map<String, Map<String, double>> gutPorLocalESerie;

  EstatisticasGeralData({
    required this.gutPorLocal,
    required this.topAnomalias,
    required this.distribuicaoRiscos,
    required this.distribuicaoCategorias,
    required this.seriesAnomalias,
    required this.coresSeries,
    required this.eixoXElementos,
    required this.gutPorElementoESerie,
    required this.eixoXSistemas,
    required this.gutPorSistemaESerie,
    required this.eixoXLocais,
    required this.gutPorLocalESerie,
  });

  factory EstatisticasGeralData.vazio() => EstatisticasGeralData(
        gutPorLocal: [],
        topAnomalias: [],
        distribuicaoRiscos: [],
        distribuicaoCategorias: [],
        seriesAnomalias: [],
        coresSeries: [],
        eixoXElementos: [],
        gutPorElementoESerie: {},
        eixoXSistemas: [],
        gutPorSistemaESerie: {},
        eixoXLocais: [],
        gutPorLocalESerie: {},
      );
}

class _OcorrenciaGeral {
  final String nomeAnomalia;
  final String riscoTipo;
  final String categoria;
  final String nomeTipoElemento;
  final String nomeSistema;
  final String nomeLocal;
  final double gut;
  _OcorrenciaGeral({
    required this.nomeAnomalia,
    required this.riscoTipo,
    required this.categoria,
    required this.nomeTipoElemento,
    required this.nomeSistema,
    required this.nomeLocal,
    required this.gut,
  });
}

// =========================================================================
// 2. PROVIDERS DE ESTADO E FILTROS
// =========================================================================

/// Conjunto de locais escolhidos pra restringir a análise — vazio significa
/// "Todos os locais" (é o estado inicial, e também o que o seletor volta a
/// ser quando o usuário marca manualmente todos os locais disponíveis).
final filtroLocaisGeralProvider = StateProvider.family.autoDispose<Set<String>, String>((ref, inspecaoGeralId) => <String>{});

/// Locais que de fato têm ao menos um registro nesta inspeção (evita listar
/// locais cadastrados na estrutura mas nunca inspecionados nesta campanha).
final locaisDaInspecaoProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, inspecaoGeralId) async {
  final supabase = Supabase.instance.client;
  final res = await supabase
      .from('ponto_inspecao_visual')
      .select('id_local, estruturas_locais(nome)')
      .eq('id_ponto_geral', inspecaoGeralId);

  final vistos = <String, String>{};
  for (final p in List<Map<String, dynamic>>.from(res)) {
    final localId = p['id_local']?.toString();
    if (localId == null) continue;
    final nome = extrairEmbedMap(p['estruturas_locais'])?['nome']?.toString() ?? 'Local sem nome';
    vistos[localId] = nome;
  }

  final lista = vistos.entries.map((e) => {'id': e.key, 'nome': e.value}).toList()
    ..sort((a, b) => (a['nome'] as String).compareTo(b['nome'] as String));
  return lista;
});

// =========================================================================
// 3. PROVIDERS DE DADOS DA TELA
// =========================================================================

/// Busca única, reaproveitada pelos 3 providers abaixo: todos os registros
/// de inspeção visual da campanha (`id_ponto_geral`), com local, tipo de
/// elemento, sistema, elemento, galeria e anomalias — mesmo formato usado na
/// análise por Local, só que sem o filtro de `id_local` (ou restrito aos
/// locais escolhidos no seletor).
Future<List<Map<String, dynamic>>> _buscarPontosGeral({
  required String inspecaoGeralId,
  required Set<String> locaisSelecionados,
}) async {
  final supabase = Supabase.instance.client;

  var query = supabase.from('ponto_inspecao_visual').select('''
    id, registro, descricao, id_local,
    estruturas_locais (nome),
    tipos_elemento (id, nome, sistemas_id, sistemas_habitacionais(nome)),
    elementos_estruturais (nome),
    ponto_inspecao_visual_galeria (foto_url),
    ponto_inspecao_regiao (foto_marcacao),
    ponto_inspecao_visual_anomalia (
      area_afetada, risco_maj, risco_tipo, risco_valor,
      anomalias(nome, categoria, gravidade_valor, urgencia_valor, tendencia_valor)
    )
  ''').eq('id_ponto_geral', inspecaoGeralId);

  if (locaisSelecionados.isNotEmpty) {
    query = query.inFilter('id_local', locaisSelecionados.toList());
  }

  final res = await query.order('criado_em', ascending: false);
  return List<Map<String, dynamic>>.from(res);
}

final resumoGeralProvider = FutureProvider.family.autoDispose<ResumoGeralModel, String>((ref, inspecaoGeralId) async {
  final locaisFiltro = ref.watch(filtroLocaisGeralProvider(inspecaoGeralId));

  try {
    final pontos = await _buscarPontosGeral(inspecaoGeralId: inspecaoGeralId, locaisSelecionados: locaisFiltro);

    final locaisUnicos = <String>{};
    final elementosUnicos = <String>{};
    double gutTotal = 0;

    for (final p in pontos) {
      if (p['id_local'] != null) locaisUnicos.add(p['id_local'].toString());
      final elemento = extrairEmbedMap(p['elementos_estruturais']);
      if (elemento != null && elemento['nome'] != null) {
        elementosUnicos.add(elemento['nome'].toString());
      }
      final anomalias = p['ponto_inspecao_visual_anomalia'] as List? ?? [];
      for (final a in anomalias) {
        final catalogo = a['anomalias'] as Map<String, dynamic>?;
        gutTotal += calcularPontuacaoRiscoGut(
          gravidadeValor: catalogo?['gravidade_valor'],
          urgenciaValor: catalogo?['urgencia_valor'],
          tendenciaValor: catalogo?['tendencia_valor'],
          majoracao: a['risco_maj'],
          areaAfetada: a['area_afetada'],
        );
      }
    }

    return ResumoGeralModel(
      totalRegistros: pontos.length,
      totalLocais: locaisUnicos.length,
      totalElementos: elementosUnicos.length,
      pontuacaoGutTotal: gutTotal.round(),
    );
  } on PostgrestException catch (e) {
    throw Exception('Erro ao buscar resumo: ${e.message}');
  }
});

final tabelaGeralProvider = FutureProvider.family.autoDispose<List<RegistroAnaliseModel>, String>((ref, inspecaoGeralId) async {
  final locaisFiltro = ref.watch(filtroLocaisGeralProvider(inspecaoGeralId));

  try {
    final pontos = await _buscarPontosGeral(inspecaoGeralId: inspecaoGeralId, locaisSelecionados: locaisFiltro);

    return pontos.map((p) {
      final localEmbed = extrairEmbedMap(p['estruturas_locais']);
      final tipoElemento = extrairEmbedMap(p['tipos_elemento']);
      final sistemaEmbed = tipoElemento != null ? extrairEmbedMap(tipoElemento['sistemas_habitacionais']) : null;
      final elemento = extrairEmbedMap(p['elementos_estruturais']);
      final galeria = p['ponto_inspecao_visual_galeria'] as List? ?? [];
      final regiao = extrairEmbedMap(p['ponto_inspecao_regiao']);
      final anomaliasRaw = p['ponto_inspecao_visual_anomalia'] as List? ?? [];

      double gutRegistro = 0;
      final anomalias = anomaliasRaw.map((a) {
        final catalogo = a['anomalias'] as Map<String, dynamic>?;
        final gut = calcularPontuacaoRiscoGut(
          gravidadeValor: catalogo?['gravidade_valor'],
          urgenciaValor: catalogo?['urgencia_valor'],
          tendenciaValor: catalogo?['tendencia_valor'],
          majoracao: a['risco_maj'],
          areaAfetada: a['area_afetada'],
        );
        gutRegistro += gut;
        return AnomaliaDetalheModel(
          nome: catalogo?['nome']?.toString() ?? 'Anomalia',
          areaAfetada: double.tryParse(a['area_afetada']?.toString() ?? '') ?? 0,
          gut: gut.round(),
          riscoTipo: a['risco_tipo']?.toString() ?? '-',
          riscoClasse: a['risco_valor']?.toString() ?? '-',
          majoracao: double.tryParse(a['risco_maj']?.toString() ?? '') ?? 0,
        );
      }).toList();

      return RegistroAnaliseModel(
        id: p['id'].toString(),
        nomeRegistro: (p['registro']?.toString().isNotEmpty ?? false) ? p['registro'].toString() : 'Registro sem nome',
        descricao: p['descricao']?.toString() ?? '',
        plantaUrl: regiao?['foto_marcacao']?.toString() ?? '',
        localNome: localEmbed?['nome']?.toString() ?? '-',
        sistemaNome: sistemaEmbed?['nome']?.toString() ?? '-',
        tipoElementoNome: tipoElemento?['nome']?.toString() ?? '-',
        elementoNome: elemento?['nome']?.toString() ?? '-',
        fotosGaleria: galeria.map((g) => g['foto_url']?.toString() ?? '').where((u) => u.isNotEmpty).toList(),
        gutTotal: gutRegistro.round(),
        anomalias: anomalias,
      );
    }).toList();
  } on PostgrestException catch (e) {
    throw Exception('Erro nas tabelas: ${e.message}');
  }
});

/// Agrega todas as ocorrências de anomalia da campanha (respeitando os
/// locais escolhidos) nas séries de dados que a aba Estatística exibe —
/// mesma lógica da análise por Local, com a dimensão "Local" adicionada:
/// um ranking simples de G.U.T. por local e uma quebra por anomalia dentro
/// de cada local (mesmo estilo dos gráficos por elemento/sistema).
final estatisticasGeralProvider = FutureProvider.family.autoDispose<EstatisticasGeralData, String>((ref, inspecaoGeralId) async {
  final locaisFiltro = ref.watch(filtroLocaisGeralProvider(inspecaoGeralId));

  final pontos = await _buscarPontosGeral(inspecaoGeralId: inspecaoGeralId, locaisSelecionados: locaisFiltro);

  final ocorrencias = <_OcorrenciaGeral>[];
  for (final p in pontos) {
    final localEmbed = extrairEmbedMap(p['estruturas_locais']);
    final nomeLocal = localEmbed?['nome']?.toString() ?? 'Local sem nome';
    final tipoElemento = extrairEmbedMap(p['tipos_elemento']);
    final nomeTipoElemento = tipoElemento?['nome']?.toString() ?? 'Sem tipo';
    final sistemaEmbed = tipoElemento != null ? extrairEmbedMap(tipoElemento['sistemas_habitacionais']) : null;
    final nomeSistema = sistemaEmbed?['nome']?.toString() ?? 'Sem sistema';

    final anomaliasRaw = p['ponto_inspecao_visual_anomalia'] as List? ?? [];
    for (final a in anomaliasRaw) {
      final catalogo = a['anomalias'] as Map<String, dynamic>?;
      final gut = calcularPontuacaoRiscoGut(
        gravidadeValor: catalogo?['gravidade_valor'],
        urgenciaValor: catalogo?['urgencia_valor'],
        tendenciaValor: catalogo?['tendencia_valor'],
        majoracao: a['risco_maj'],
        areaAfetada: a['area_afetada'],
      );
      if (gut <= 0) continue;

      final riscoTipo = a['risco_tipo']?.toString();
      final categoria = catalogo?['categoria']?.toString();

      ocorrencias.add(_OcorrenciaGeral(
        nomeAnomalia: catalogo?['nome']?.toString() ?? 'Anomalia',
        riscoTipo: (riscoTipo != null && riscoTipo.isNotEmpty) ? riscoTipo : 'Não informado',
        categoria: (categoria != null && categoria.isNotEmpty) ? categoria : 'Não informado',
        nomeTipoElemento: nomeTipoElemento,
        nomeSistema: nomeSistema,
        nomeLocal: nomeLocal,
        gut: gut,
      ));
    }
  }

  if (ocorrencias.isEmpty) return EstatisticasGeralData.vazio();

  final gutTotal = ocorrencias.fold(0.0, (s, o) => s + o.gut);

  final gutPorAnomalia = <String, double>{};
  for (final o in ocorrencias) {
    gutPorAnomalia[o.nomeAnomalia] = (gutPorAnomalia[o.nomeAnomalia] ?? 0) + o.gut;
  }
  final rankingAnomalias = gutPorAnomalia.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  final topAnomalias = List.generate(
    rankingAnomalias.length > 8 ? 8 : rankingAnomalias.length,
    (i) => ChartDataBar(rankingAnomalias[i].key, rankingAnomalias[i].value, corDaPaleta(i)),
  );

  final gutPorRisco = <String, double>{};
  final gutPorCategoria = <String, double>{};
  final gutPorLocalSimples = <String, double>{};
  for (final o in ocorrencias) {
    gutPorRisco[o.riscoTipo] = (gutPorRisco[o.riscoTipo] ?? 0) + o.gut;
    gutPorCategoria[o.categoria] = (gutPorCategoria[o.categoria] ?? 0) + o.gut;
    gutPorLocalSimples[o.nomeLocal] = (gutPorLocalSimples[o.nomeLocal] ?? 0) + o.gut;
  }
  final distribuicaoRiscos = paraPizza(gutPorRisco, gutTotal);
  final distribuicaoCategorias = paraPizza(gutPorCategoria, gutTotal);

  final rankingLocais = gutPorLocalSimples.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final gutPorLocal = List.generate(
    rankingLocais.length > 10 ? 10 : rankingLocais.length,
    (i) => ChartDataBar(rankingLocais[i].key, rankingLocais[i].value, corDaPaleta(i)),
  );

  final seriesPrincipais = rankingAnomalias.take(6).map((e) => e.key).toList();
  final temOutras = rankingAnomalias.length > 6;
  final seriesAnomalias = temOutras ? [...seriesPrincipais, bucketOutrasAnomalias] : seriesPrincipais;
  final coresSeries = List.generate(
    seriesAnomalias.length,
    (i) => seriesAnomalias[i] == bucketOutrasAnomalias ? corOutrasAnalise : corDaPaleta(i),
  );

  String serieDe(String nomeAnomalia) => seriesPrincipais.contains(nomeAnomalia) ? nomeAnomalia : bucketOutrasAnomalias;

  final gutPorElemento = <String, double>{};
  final gutPorElementoESerie = <String, Map<String, double>>{};
  final gutPorSistema = <String, double>{};
  final gutPorSistemaESerie = <String, Map<String, double>>{};
  final gutPorLocalESerie = <String, Map<String, double>>{};
  for (final o in ocorrencias) {
    final serie = serieDe(o.nomeAnomalia);

    gutPorElemento[o.nomeTipoElemento] = (gutPorElemento[o.nomeTipoElemento] ?? 0) + o.gut;
    final mapaElemento = gutPorElementoESerie.putIfAbsent(o.nomeTipoElemento, () => {});
    mapaElemento[serie] = (mapaElemento[serie] ?? 0) + o.gut;

    gutPorSistema[o.nomeSistema] = (gutPorSistema[o.nomeSistema] ?? 0) + o.gut;
    final mapaSistema = gutPorSistemaESerie.putIfAbsent(o.nomeSistema, () => {});
    mapaSistema[serie] = (mapaSistema[serie] ?? 0) + o.gut;

    final mapaLocal = gutPorLocalESerie.putIfAbsent(o.nomeLocal, () => {});
    mapaLocal[serie] = (mapaLocal[serie] ?? 0) + o.gut;
  }

  return EstatisticasGeralData(
    gutPorLocal: gutPorLocal,
    topAnomalias: topAnomalias,
    distribuicaoRiscos: distribuicaoRiscos,
    distribuicaoCategorias: distribuicaoCategorias,
    seriesAnomalias: seriesAnomalias,
    coresSeries: coresSeries,
    eixoXElementos: topNCategorias(gutPorElemento, 6),
    gutPorElementoESerie: gutPorElementoESerie,
    eixoXSistemas: topNCategorias(gutPorSistema, 6),
    gutPorSistemaESerie: gutPorSistemaESerie,
    eixoXLocais: topNCategorias(gutPorLocalSimples, 8),
    gutPorLocalESerie: gutPorLocalESerie,
  );
});

// =========================================================================
// 4. TELA PRINCIPAL
// =========================================================================

class AnaliseGeralInspecaoScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String estruturaId;
  final String inspecaoGeralId;
  final String inspecaoGeralNome;
  final String projetoNome;
  final String estruturaNome;

  const AnaliseGeralInspecaoScreen({
    super.key,
    required this.projetoId,
    required this.estruturaId,
    required this.inspecaoGeralId,
    required this.inspecaoGeralNome,
    required this.projetoNome,
    required this.estruturaNome,
  });

  @override
  ConsumerState<AnaliseGeralInspecaoScreen> createState() => _AnaliseGeralInspecaoScreenState();
}

class _AnaliseGeralInspecaoScreenState extends ConsumerState<AnaliseGeralInspecaoScreen> {
  int _abaSelecionada = 0; // 0 = Tabelas, 1 = Estatística

  Future<void> _abrirSeletorLocais(List<Map<String, dynamic>> locais) async {
    var selecionado = Set<String>.from(ref.read(filtroLocaisGeralProvider(widget.inspecaoGeralId)));

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final todosSelecionados = selecionado.isEmpty;
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.35,
              maxChildSize: 0.9,
              expand: false,
              builder: (ctx, scrollController) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                    ),
                    const SizedBox(height: 16),
                    Text('Selecionar Locais', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                    const SizedBox(height: 8),
                    Text('Escolha quais locais entram na análise, ou deixe "Todos" marcado.', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: [
                          CheckboxListTile(
                            value: todosSelecionados,
                            onChanged: (_) => setModalState(() => selecionado.clear()),
                            title: Text('Todos os locais', style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                            activeColor: const Color(0xFFFFA726),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          const Divider(),
                          ...locais.map((l) {
                            final id = l['id'].toString();
                            final marcado = todosSelecionados || selecionado.contains(id);
                            return CheckboxListTile(
                              value: marcado,
                              onChanged: (v) => setModalState(() {
                                if (todosSelecionados) {
                                  selecionado = locais.map((x) => x['id'].toString()).toSet()..remove(id);
                                } else if (v == true) {
                                  selecionado.add(id);
                                  if (selecionado.length == locais.length) selecionado.clear();
                                } else {
                                  selecionado.remove(id);
                                }
                              }),
                              title: Text(l['nome']?.toString() ?? ''),
                              activeColor: const Color(0xFFFFA726),
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(filtroLocaisGeralProvider(widget.inspecaoGeralId).notifier).state = selecionado;
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFA726),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                      child: const Text('Aplicar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final resumoAsync = ref.watch(resumoGeralProvider(widget.inspecaoGeralId));
    final locaisAsync = ref.watch(locaisDaInspecaoProvider(widget.inspecaoGeralId));
    final locaisSelecionados = ref.watch(filtroLocaisGeralProvider(widget.inspecaoGeralId));

    final locais = locaisAsync.value ?? [];
    final rotuloLocais = locaisSelecionados.isEmpty
        ? 'Todos os locais (${locais.length})'
        : '${locaisSelecionados.length} de ${locais.length} locais';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: CustomAppBar(
        title: '',
        showBackButton: true,
        showMenuButton: true,
        showNotificationButton: true,
        titleWidget: Column(
          children: [
            Text('Projeto', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
            const Text('Inspeção Visual', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Análise Geral', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9))),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.inspecaoGeralNome, style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF3E3E3D))),
                const SizedBox(height: 2),
                Text('${widget.projetoNome} · ${widget.estruturaNome}', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 12),

                // SELETOR DE LOCAIS
                GestureDetector(
                  onTap: locais.isEmpty ? null : () => _abrirSeletorLocais(locais),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(child: Text(rotuloLocais, style: GoogleFonts.lato(fontSize: 14, color: const Color(0xFF3E3E3D)))),
                        const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // CARDS DE RESUMO
                resumoAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (e, _) => const Text('Erro ao carregar dados', style: TextStyle(color: Colors.red)),
                  data: (resumo) => Row(
                    children: [
                      _MiniCard(titulo: 'Registros', valor: resumo.totalRegistros.toString()),
                      const SizedBox(width: 8),
                      _MiniCard(titulo: 'Locais', valor: resumo.totalLocais.toString()),
                      const SizedBox(width: 8),
                      _MiniCard(titulo: 'Elementos', valor: resumo.totalElementos.toString()),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]),
                          child: Column(
                            children: [
                              Text('Pontuação G.U.T', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade500)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                                  const SizedBox(width: 4),
                                  Text(resumo.pontuacaoGutTotal.toString(), style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // TOGGLE TABS (Tabelas / Estatísticas)
                Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(24)),
                  child: Row(
                    children: [
                      Expanded(child: _TabButton(title: 'Tabelas', isSelected: _abaSelecionada == 0, onTap: () => setState(() => _abaSelecionada = 0))),
                      Expanded(child: _TabButton(title: 'Estatística', isSelected: _abaSelecionada == 1, onTap: () => setState(() => _abaSelecionada = 1))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _abaSelecionada == 0 ? _TabelasGeralView(inspecaoGeralId: widget.inspecaoGeralId) : _EstatisticasGeralView(inspecaoGeralId: widget.inspecaoGeralId),
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String titulo;
  final String valor;
  const _MiniCard({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text(titulo, style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Text(valor, style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  const _TabButton({required this.title, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFA726) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(title, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }
}

// =========================================================================
// ABA 1: TABELAS (Listagem de Registros, com o Local de cada um)
// =========================================================================

class _TabelasGeralView extends ConsumerWidget {
  final String inspecaoGeralId;
  const _TabelasGeralView({required this.inspecaoGeralId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registrosAsync = ref.watch(tabelaGeralProvider(inspecaoGeralId));

    return registrosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (registros) {
        if (registros.isEmpty) return const Center(child: Text('Nenhum registro encontrado.'));

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: registros.length,
          separatorBuilder: (_, __) => const SizedBox(height: 20),
          itemBuilder: (context, index) => RegistroAnaliseCard(registro: registros[index]),
        );
      },
    );
  }
}

// =========================================================================
// ABA 2: ESTATÍSTICA (Syncfusion Charts)
// =========================================================================

class _EstatisticasGeralView extends ConsumerWidget {
  final String inspecaoGeralId;
  const _EstatisticasGeralView({required this.inspecaoGeralId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(estatisticasGeralProvider(inspecaoGeralId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (dados) {
        if (dados.topAnomalias.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Nenhuma anomalia registrada para gerar estatísticas.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // GRÁFICO 1: G.U.T. por Local — o comparativo entre locais pedido
              _ChartContainer(
                title: 'Pontuação G.U.T. por Local',
                child: SfCartesianChart(
                  primaryXAxis: const CategoryAxis(
                    majorGridLines: MajorGridLines(width: 0),
                    labelStyle: TextStyle(fontSize: 10),
                    labelRotation: 45,
                  ),
                  primaryYAxis: const NumericAxis(
                    minimum: 0,
                    axisLine: AxisLine(width: 0),
                    title: AxisTitle(text: 'Pontuação GUT', textStyle: TextStyle(fontSize: 10)),
                  ),
                  series: <CartesianSeries>[
                    ColumnSeries<ChartDataBar, String>(
                      dataSource: dados.gutPorLocal,
                      xValueMapper: (ChartDataBar data, _) => data.categoria,
                      yValueMapper: (ChartDataBar data, _) => data.valor,
                      pointColorMapper: (ChartDataBar data, _) => data.cor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      width: 0.7,
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // GRÁFICO 2: Barras GUT (top anomalias, em toda a campanha)
              _ChartContainer(
                title: 'Pontuação das\nanomalias/manifestações patológicas',
                child: SfCartesianChart(
                  primaryXAxis: const CategoryAxis(
                    majorGridLines: MajorGridLines(width: 0),
                    labelStyle: TextStyle(fontSize: 10),
                    labelRotation: 45,
                  ),
                  primaryYAxis: const NumericAxis(
                    minimum: 0,
                    axisLine: AxisLine(width: 0),
                    title: AxisTitle(text: 'Pontuação GUT', textStyle: TextStyle(fontSize: 10)),
                  ),
                  series: <CartesianSeries>[
                    ColumnSeries<ChartDataBar, String>(
                      dataSource: dados.topAnomalias,
                      xValueMapper: (ChartDataBar data, _) => data.categoria,
                      yValueMapper: (ChartDataBar data, _) => data.valor,
                      pointColorMapper: (ChartDataBar data, _) => data.cor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      width: 0.7,
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // GRÁFICO 3: Pizza Riscos (ponderada por G.U.T.)
              _ChartContainer(
                title: 'Distribuição dos riscos',
                child: pizzaChart(dados.distribuicaoRiscos),
              ),
              const SizedBox(height: 24),

              // GRÁFICO 4: Anomalias por Local (composição)
              _ChartContainer(
                title: 'Anomalias e manifestações patológicas\npor local',
                child: empilhadoChart(
                  eixoX: dados.eixoXLocais,
                  dadosPorCategoria: dados.gutPorLocalESerie,
                  series: dados.seriesAnomalias,
                  cores: dados.coresSeries,
                  tituloEixoX: 'Local',
                  rotacionarRotulos: true,
                ),
              ),
              const SizedBox(height: 24),

              // GRÁFICO 5: Barras Empilhadas (Tipo de Elemento)
              _ChartContainer(
                title: 'Anomalias e manifestações patológicas\nnos elementos',
                child: empilhadoChart(
                  eixoX: dados.eixoXElementos,
                  dadosPorCategoria: dados.gutPorElementoESerie,
                  series: dados.seriesAnomalias,
                  cores: dados.coresSeries,
                  tituloEixoX: 'Tipo de Elemento',
                ),
              ),
              const SizedBox(height: 24),

              // GRÁFICO 6: Barras Empilhadas (Sistema Habitacional)
              _ChartContainer(
                title: 'Anomalias e manifestações patológicas\nnos sistemas',
                child: empilhadoChart(
                  eixoX: dados.eixoXSistemas,
                  dadosPorCategoria: dados.gutPorSistemaESerie,
                  series: dados.seriesAnomalias,
                  cores: dados.coresSeries,
                  tituloEixoX: 'Sistema Habitacional',
                  rotacionarRotulos: true,
                ),
              ),
              const SizedBox(height: 24),

              // GRÁFICO 7: Pizza Categorias (ponderada por G.U.T.)
              _ChartContainer(
                title: 'Distribuição das categorias das anomalias',
                child: pizzaChart(dados.distribuicaoCategorias),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}

class _ChartContainer extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartContainer({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(title, textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
          ),
          const SizedBox(height: 12),
          SizedBox(height: 300, child: child),
        ],
      ),
    );
  }
}
