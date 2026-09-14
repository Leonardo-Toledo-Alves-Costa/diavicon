import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../empresa/providers/campos_personalizaveis_provider.dart';
import '../utils/analise_charts_util.dart';
import '../utils/risco_gut_calculo.dart';

// =========================================================================
// 1. MODELS DE DADOS
// =========================================================================

class AnaliseResumoModel {
  final int totalRegistros;
  final int totalElementos;
  final int pontuacaoGutTotal;
  AnaliseResumoModel({required this.totalRegistros, required this.totalElementos, required this.pontuacaoGutTotal});
}

/// Dados agregados que alimentam a aba Estatística — montados em memória a
/// partir das ocorrências reais de anomalia do local (ver [estatisticasAnaliseProvider]).
class EstatisticasAnaliseData {
  final List<ChartDataBar> topAnomalias;
  final List<ChartDataPie> distribuicaoRiscos;
  final List<ChartDataPie> distribuicaoCategorias;
  final List<String> seriesAnomalias;
  final List<Color> coresSeries;
  final List<String> eixoXElementos;
  final Map<String, Map<String, double>> gutPorElementoESerie;
  final List<String> eixoXSistemas;
  final Map<String, Map<String, double>> gutPorSistemaESerie;

  EstatisticasAnaliseData({
    required this.topAnomalias,
    required this.distribuicaoRiscos,
    required this.distribuicaoCategorias,
    required this.seriesAnomalias,
    required this.coresSeries,
    required this.eixoXElementos,
    required this.gutPorElementoESerie,
    required this.eixoXSistemas,
    required this.gutPorSistemaESerie,
  });

  factory EstatisticasAnaliseData.vazio() => EstatisticasAnaliseData(
        topAnomalias: [],
        distribuicaoRiscos: [],
        distribuicaoCategorias: [],
        seriesAnomalias: [],
        coresSeries: [],
        eixoXElementos: [],
        gutPorElementoESerie: {},
        eixoXSistemas: [],
        gutPorSistemaESerie: {},
      );
}

class _OcorrenciaAnomalia {
  final String nomeAnomalia;
  final String riscoTipo;
  final String categoria;
  final String nomeTipoElemento;
  final String nomeSistema;
  final double gut;
  _OcorrenciaAnomalia({
    required this.nomeAnomalia,
    required this.riscoTipo,
    required this.categoria,
    required this.nomeTipoElemento,
    required this.nomeSistema,
    required this.gut,
  });
}

// =========================================================================
// 2. PROVIDERS DE ESTADO E FILTROS
// =========================================================================

final filtroSistemaAnaliseProvider = StateProvider<String?>((ref) => null);
final filtroElementoAnaliseProvider = StateProvider<String?>((ref) => null);

// Dropdown de Sistemas (Regra: Empresa do User + Diavicon Padrão)
final sistemasDropdownAnaliseProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];
    
    final userRes = await supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
    final empresaId = userRes?['empresa_id'];

    final res = await supabase.from('sistemas_habitacionais').select('id, nome')
        .or('empresa_id.eq.$empresaId, empresa_id.eq.$DIAVICON_EMPRESA_ID')
        .order('nome');
        
    return List<Map<String, dynamic>>.from(res);
  } on PostgrestException catch (e) {
    debugPrint('Erro DB Sistemas: ${e.message}');
    return [];
  } catch (e) {
    return [];
  }
});

// Dropdown de Elementos (Vinculados ao Local atual)
final elementosDropdownAnaliseProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, localId) async {
  try {
    final res = await Supabase.instance.client.from('elementos_estruturais')
        .select('id, nome')
        .eq('local_id', localId)
        .order('nome');
    return List<Map<String, dynamic>>.from(res);
  } on PostgrestException catch (e) {
    debugPrint('Erro DB Elementos: ${e.message}');
    return [];
  } catch (e) {
    return [];
  }
});

// =========================================================================
// 3. PROVIDERS DE DADOS DA TELA
// =========================================================================

/// Busca única, reaproveitada pelos 3 providers abaixo: todos os registros
/// de inspeção visual do local, com tipo de elemento, sistema, elemento,
/// galeria e anomalias (com os dados de gravidade/urgência/tendência do
/// catálogo, necessários pra calcular o G.U.T.). O filtro de sistema é
/// aplicado em memória (não há coluna de sistema em `ponto_inspecao_visual`
/// — a informação vem via `tipos_elemento.sistemas_id`).
Future<List<Map<String, dynamic>>> _buscarPontosAnalise({
  required String localId,
  String? sistemaId,
  String? elementoId,
}) async {
  final supabase = Supabase.instance.client;

  var query = supabase.from('ponto_inspecao_visual').select('''
    id, registro, descricao,
    tipos_elemento (id, nome, sistemas_id, sistemas_habitacionais(nome)),
    elementos_estruturais (nome),
    ponto_inspecao_visual_galeria (foto_url),
    ponto_inspecao_regiao (foto_marcacao),
    ponto_inspecao_visual_anomalia (
      area_afetada, risco_maj, risco_tipo, risco_valor,
      anomalias(nome, categoria, gravidade_valor, urgencia_valor, tendencia_valor)
    )
  ''').eq('id_local', localId);

  if (elementoId != null) {
    query = query.eq('id_elemento', elementoId);
  }

  final res = await query.order('criado_em', ascending: false);
  var lista = List<Map<String, dynamic>>.from(res);

  if (sistemaId != null) {
    lista = lista.where((p) {
      final tipo = extrairEmbedMap(p['tipos_elemento']);
      return tipo != null && tipo['sistemas_id']?.toString() == sistemaId;
    }).toList();
  }

  return lista;
}

final analiseResumoProvider = FutureProvider.family.autoDispose<AnaliseResumoModel, String>((ref, localId) async {
  final sistemaFiltro = ref.watch(filtroSistemaAnaliseProvider);
  final elementoFiltro = ref.watch(filtroElementoAnaliseProvider);

  try {
    final pontos = await _buscarPontosAnalise(localId: localId, sistemaId: sistemaFiltro, elementoId: elementoFiltro);

    final elementosUnicos = <String>{};
    double gutTotal = 0;

    for (final p in pontos) {
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

    return AnaliseResumoModel(
      totalRegistros: pontos.length,
      totalElementos: elementosUnicos.length,
      pontuacaoGutTotal: gutTotal.round(),
    );
  } on PostgrestException catch (e) {
    throw Exception('Erro ao buscar resumo: ${e.message}');
  }
});

final tabelasAnaliseProvider = FutureProvider.family.autoDispose<List<RegistroAnaliseModel>, String>((ref, localId) async {
  final sistemaFiltro = ref.watch(filtroSistemaAnaliseProvider);
  final elementoFiltro = ref.watch(filtroElementoAnaliseProvider);

  try {
    final pontos = await _buscarPontosAnalise(localId: localId, sistemaId: sistemaFiltro, elementoId: elementoFiltro);

    return pontos.map((p) {
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

/// Agrega todas as ocorrências de anomalia do local nas 5 séries de dados
/// que a aba Estatística exibe. Os gráficos de pizza (riscos/categorias) são
/// ponderados pela soma do G.U.T. (não por contagem de ocorrências), e os
/// empilhados usam as anomalias de maior peso como séries dinâmicas
/// (limitadas a 6 + "Outras anomalias"), com o eixo X limitado às 6
/// categorias (tipo de elemento / sistema) de maior pontuação.
final estatisticasAnaliseProvider = FutureProvider.family.autoDispose<EstatisticasAnaliseData, String>((ref, localId) async {
  final sistemaFiltro = ref.watch(filtroSistemaAnaliseProvider);
  final elementoFiltro = ref.watch(filtroElementoAnaliseProvider);

  final pontos = await _buscarPontosAnalise(localId: localId, sistemaId: sistemaFiltro, elementoId: elementoFiltro);

  final ocorrencias = <_OcorrenciaAnomalia>[];
  for (final p in pontos) {
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

      ocorrencias.add(_OcorrenciaAnomalia(
        nomeAnomalia: catalogo?['nome']?.toString() ?? 'Anomalia',
        riscoTipo: (riscoTipo != null && riscoTipo.isNotEmpty) ? riscoTipo : 'Não informado',
        categoria: (categoria != null && categoria.isNotEmpty) ? categoria : 'Não informado',
        nomeTipoElemento: nomeTipoElemento,
        nomeSistema: nomeSistema,
        gut: gut,
      ));
    }
  }

  if (ocorrencias.isEmpty) return EstatisticasAnaliseData.vazio();

  final gutTotal = ocorrencias.fold(0.0, (s, o) => s + o.gut);

  final gutPorAnomalia = <String, double>{};
  for (final o in ocorrencias) {
    gutPorAnomalia[o.nomeAnomalia] = (gutPorAnomalia[o.nomeAnomalia] ?? 0) + o.gut;
  }
  final rankingAnomalias = gutPorAnomalia.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  final topAnomalias = List.generate(
    rankingAnomalias.length > 8 ? 8 : rankingAnomalias.length,
    (i) => ChartDataBar(rankingAnomalias[i].key, rankingAnomalias[i].value, paletaAnalise[i % paletaAnalise.length]),
  );

  final gutPorRisco = <String, double>{};
  final gutPorCategoria = <String, double>{};
  for (final o in ocorrencias) {
    gutPorRisco[o.riscoTipo] = (gutPorRisco[o.riscoTipo] ?? 0) + o.gut;
    gutPorCategoria[o.categoria] = (gutPorCategoria[o.categoria] ?? 0) + o.gut;
  }
  final distribuicaoRiscos = paraPizza(gutPorRisco, gutTotal);
  final distribuicaoCategorias = paraPizza(gutPorCategoria, gutTotal);

  final seriesPrincipais = rankingAnomalias.take(6).map((e) => e.key).toList();
  final temOutras = rankingAnomalias.length > 6;
  final seriesAnomalias = temOutras ? [...seriesPrincipais, bucketOutrasAnomalias] : seriesPrincipais;
  final coresSeries = List.generate(
    seriesAnomalias.length,
    (i) => seriesAnomalias[i] == bucketOutrasAnomalias ? corOutrasAnalise : paletaAnalise[i % paletaAnalise.length],
  );

  String serieDe(String nomeAnomalia) => seriesPrincipais.contains(nomeAnomalia) ? nomeAnomalia : bucketOutrasAnomalias;

  final gutPorElemento = <String, double>{};
  final gutPorElementoESerie = <String, Map<String, double>>{};
  final gutPorSistema = <String, double>{};
  final gutPorSistemaESerie = <String, Map<String, double>>{};
  for (final o in ocorrencias) {
    final serie = serieDe(o.nomeAnomalia);

    gutPorElemento[o.nomeTipoElemento] = (gutPorElemento[o.nomeTipoElemento] ?? 0) + o.gut;
    final mapaElemento = gutPorElementoESerie.putIfAbsent(o.nomeTipoElemento, () => {});
    mapaElemento[serie] = (mapaElemento[serie] ?? 0) + o.gut;

    gutPorSistema[o.nomeSistema] = (gutPorSistema[o.nomeSistema] ?? 0) + o.gut;
    final mapaSistema = gutPorSistemaESerie.putIfAbsent(o.nomeSistema, () => {});
    mapaSistema[serie] = (mapaSistema[serie] ?? 0) + o.gut;
  }

  return EstatisticasAnaliseData(
    topAnomalias: topAnomalias,
    distribuicaoRiscos: distribuicaoRiscos,
    distribuicaoCategorias: distribuicaoCategorias,
    seriesAnomalias: seriesAnomalias,
    coresSeries: coresSeries,
    eixoXElementos: topNCategorias(gutPorElemento, 6),
    gutPorElementoESerie: gutPorElementoESerie,
    eixoXSistemas: topNCategorias(gutPorSistema, 6),
    gutPorSistemaESerie: gutPorSistemaESerie,
  );
});

// =========================================================================
// 4. TELA PRINCIPAL
// =========================================================================

class InspecaoVisualAnaliseScreen extends ConsumerStatefulWidget {
  final String localId;
  final String localNome;
  final String projetoId;

  const InspecaoVisualAnaliseScreen({
    super.key,
    required this.localId,
    required this.localNome,
    required this.projetoId,
  });

  @override
  ConsumerState<InspecaoVisualAnaliseScreen> createState() => _InspecaoVisualAnaliseScreenState();
}

class _InspecaoVisualAnaliseScreenState extends ConsumerState<InspecaoVisualAnaliseScreen> {
  int _abaSelecionada = 0; // 0 = Tabelas, 1 = Estatística

  @override
  Widget build(BuildContext context) {
    final resumoAsync = ref.watch(analiseResumoProvider(widget.localId));
    final sistemasAsync = ref.watch(sistemasDropdownAnaliseProvider);
    final elementosAsync = ref.watch(elementosDropdownAnaliseProvider(widget.localId));

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
            Text('Análise por Local', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9))),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // CABEÇALHO BRANCO (Filtros e Resumo)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.localNome, style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF3E3E3D))),
                const SizedBox(height: 8),
                
                // DROPDOWNS DE FILTRO
                Row(
                  children: [
                    Expanded(
                      child: _DropdownFiltro(
                        label: 'Sistema',
                        value: ref.watch(filtroSistemaAnaliseProvider),
                        items: sistemasAsync.value ?? [],
                        onChanged: (val) => ref.read(filtroSistemaAnaliseProvider.notifier).state = val,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DropdownFiltro(
                        label: 'Elemento',
                        value: ref.watch(filtroElementoAnaliseProvider),
                        items: elementosAsync.value ?? [],
                        onChanged: (val) => ref.read(filtroElementoAnaliseProvider.notifier).state = val,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                
                // CARDS DE RESUMO
                resumoAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (e, _) => const Text('Erro ao carregar dados', style: TextStyle(color: Colors.red)),
                  data: (resumo) => Row(
                    children: [
                      _ResumoCardBase(titulo: 'Registros', valor: resumo.totalRegistros.toString()),
                      const SizedBox(width: 8),
                      _ResumoCardBase(titulo: 'Elementos', valor: resumo.totalElementos.toString()),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]),
                          child: Column(
                            children: [
                              Text('Pontuação G.U.T', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade500)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                                  const SizedBox(width: 4),
                                  Text(resumo.pontuacaoGutTotal.toString(), style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),

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

          // CONTEÚDO DAS ABAS
          Expanded(
            child: _abaSelecionada == 0 ? _TabelasView(localId: widget.localId) : _EstatisticasView(localId: widget.localId),
          ),
        ],
      ),
    );
  }
}

class _DropdownFiltro extends StatelessWidget {
  final String label;
  final String? value;
  final List<Map<String, dynamic>> items;
  final ValueChanged<String?> onChanged;

  const _DropdownFiltro({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: items.any((i) => i['id'].toString() == value) ? value : null,
              hint: Text('Selecione', style: GoogleFonts.lato(fontSize: 14, color: Colors.grey)),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              items: items.map((e) => DropdownMenuItem<String>(value: e['id'].toString(), child: Text(e['nome'] ?? '', overflow: TextOverflow.ellipsis))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResumoCardBase extends StatelessWidget {
  final String titulo;
  final String valor;
  const _ResumoCardBase({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text(titulo, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Text(valor, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
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
// ABA 1: TABELAS (Listagem de Registros)
// =========================================================================

class _TabelasView extends ConsumerWidget {
  final String localId;
  const _TabelasView({required this.localId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registrosAsync = ref.watch(tabelasAnaliseProvider(localId));

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

class _EstatisticasView extends ConsumerWidget {
  final String localId;
  const _EstatisticasView({required this.localId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(estatisticasAnaliseProvider(localId));

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
              // GRÁFICO 1: Barras GUT (top anomalias)
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

              // GRÁFICO 2: Pizza Riscos (ponderada por G.U.T.)
              _ChartContainer(
                title: 'Distribuição dos riscos',
                child: pizzaChart(dados.distribuicaoRiscos),
              ),
              const SizedBox(height: 24),

              // GRÁFICO 3: Barras Empilhadas (Tipo de Elemento)
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

              // GRÁFICO 4: Barras Empilhadas (Sistema Habitacional)
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

              // GRÁFICO 5: Pizza Categorias (ponderada por G.U.T.)
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