import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../modelos_relatorios/charts/relatorio_chart_renderer.dart';
import '../../../../modelos_relatorios/models/foto_relatorio.dart';
import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart';
import '../../models/liquido_penetrante_model.dart';

/// Um elemento ensaiado, pronto pro relatório: dados do bloco "Registros",
/// a sub-lista "Pontos de LP" e as fotos (galeria).
class RegistroLPReal {
  final Map<String, String> dados;
  final List<Map<String, String>> pontos;
  final List<FotoRelatorio> fotos;
  const RegistroLPReal({required this.dados, required this.pontos, required this.fotos});
}

class ElementoLPBruto {
  final String nomeElemento;
  final String tipoElemento;
  final String local;
  final String? marcacaoImagemUrl;
  final String nomeEnsaio;
  final List<PontoLiquidoPenetranteModel> pontos;
  final List<Map<String, String>> galeriaGeral; // {url, legenda}

  const ElementoLPBruto({
    required this.nomeElemento,
    required this.tipoElemento,
    required this.local,
    required this.marcacaoImagemUrl,
    required this.nomeEnsaio,
    required this.pontos,
    required this.galeriaGeral,
  });

  ContagemStatusLP get contagem => ContagemStatusLP.de(pontos.map((p) => p.status));
}

class LPModeloReportData {
  final SupabaseClient _supabase;
  LPModeloReportData(this._supabase);

  Future<List<ElementoLPBruto>> buscarElementos({
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioId,
  }) async {
    final resp = await _supabase
        .from('pontos_ensaios_geral')
        .select('''
          id, nome_ponto,
          elementos_estruturais!inner(nome, tipo, local, marcacao_imagem_url, estrutura_id),
          ponto_ensaio_liquido_penetrante(*),
          galeria_pontos_ensaios_geral(imagem_url, legenda)
        ''')
        .eq('projeto_id', projetoId)
        .eq('elementos_estruturais.estrutura_id', estruturaId)
        .eq('tipo_ensaio_id', tipoEnsaioId);

    final elementos = <ElementoLPBruto>[];
    for (final p in (resp as List)) {
      final el = p['elementos_estruturais'] as Map<String, dynamic>?;
      final pontos = (p['ponto_ensaio_liquido_penetrante'] as List? ?? const [])
          .map((m) => PontoLiquidoPenetranteModel.fromJson((m as Map).cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => (a.criadoEm ?? DateTime(0)).compareTo(b.criadoEm ?? DateTime(0)));
      final galeria = (p['galeria_pontos_ensaios_geral'] as List? ?? const [])
          .map((g) => {'url': g['imagem_url']?.toString() ?? '', 'legenda': g['legenda']?.toString() ?? ''})
          .where((g) => g['url']!.isNotEmpty)
          .toList();
      elementos.add(ElementoLPBruto(
        nomeElemento: el?['nome']?.toString() ?? '',
        tipoElemento: el?['tipo']?.toString() ?? 'Desconhecido',
        local: el?['local']?.toString() ?? 'Desconhecido',
        marcacaoImagemUrl: el?['marcacao_imagem_url']?.toString(),
        nomeEnsaio: p['nome_ponto']?.toString() ?? '',
        pontos: pontos,
        galeriaGeral: galeria,
      ));
    }
    elementos.sort((a, b) => a.nomeElemento.compareTo(b.nomeElemento));
    return elementos;
  }

  static String _comUnidade(String valor, String unidade) => valor.trim().isEmpty ? '-' : '${valor.trim()} $unidade';

  List<RegistroLPReal> montarRegistros(List<ElementoLPBruto> elementos) {
    return [
      for (final e in elementos)
        () {
          final c = e.contagem;
          final fotos = <FotoRelatorio>[];
          for (final p in e.pontos) {
            if (p.fotoSolda != null) fotos.add(FotoRelatorio(url: p.fotoSolda!, descricao: '${e.nomeElemento} · ${p.nomePonto} — Solda'));
            if (p.fotoPenetrante != null) fotos.add(FotoRelatorio(url: p.fotoPenetrante!, descricao: '${e.nomeElemento} · ${p.nomePonto} — Com penetrante'));
            if (p.fotoResultado != null) fotos.add(FotoRelatorio(url: p.fotoResultado!, descricao: '${e.nomeElemento} · ${p.nomePonto} — Resultado'));
          }
          for (final g in e.galeriaGeral) {
            fotos.add(FotoRelatorio(url: g['url']!, descricao: g['legenda'] ?? ''));
          }
          return RegistroLPReal(
            dados: {
              'nome_elemento_lp': e.nomeElemento,
              'tipo_elemento_lp': e.tipoElemento,
              'local_elemento_lp': e.local,
              if (e.marcacaoImagemUrl != null && e.marcacaoImagemUrl!.isNotEmpty) 'marcacao_elemento_lp': e.marcacaoImagemUrl!,
              'nome_ensaio_lp': e.nomeEnsaio,
              'total_pontos_lp': '${c.total}',
              'aprovados_lp': '${c.aprovados}',
              'reprovados_lp': '${c.reprovados}',
              'cabe_analise_lp': '${c.cabeAnalise}',
              'resultado_lp': c.textoBadge,
            },
            pontos: [
              for (final p in e.pontos)
                {
                  'nome_ponto_lp': p.nomePonto,
                  'status_ponto_lp': p.status?.label ?? 'Sem status',
                  'tamanho_ponto_lp': _comUnidade(p.tamanhoAnalise, 'cm'),
                  'tempo_ponto_lp': _comUnidade(p.tempoPenetracao, 'min'),
                  'descricao_ponto_lp': p.descricao,
                  'foto_solda_lp': ?p.fotoSolda,
                  'foto_penetrante_lp': ?p.fotoPenetrante,
                  'foto_resultado_lp': ?p.fotoResultado,
                },
            ],
            fotos: fotos,
          );
        }(),
    ];
  }

  String _chaveGrupo(ElementoLPBruto e, HierarquiaAgrupamento h) => switch (h) {
        HierarquiaAgrupamento.local => e.local,
        HierarquiaAgrupamento.tipoElemento => e.tipoElemento,
        HierarquiaAgrupamento.localTipoElemento => '${e.local}|${e.tipoElemento}',
      };

  List<Map<String, String>> linhasAgrupadas({required List<ElementoLPBruto> elementos, required HierarquiaAgrupamento hierarquia}) {
    final grupos = <String, List<ElementoLPBruto>>{};
    for (final e in elementos) {
      grupos.putIfAbsent(_chaveGrupo(e, hierarquia), () => []).add(e);
    }
    return [
      for (final g in grupos.values)
        () {
          final c = g.fold(const ContagemStatusLP(), (acc, e) => acc + e.contagem);
          return {
            'local_grupo_lp': g.first.local,
            'tipo_elemento_grupo_lp': g.first.tipoElemento,
            'total_elementos_grupo_lp': '${g.length}',
            'total_pontos_grupo_lp': '${c.total}',
            'aprovados_grupo_lp': '${c.aprovados}',
            'reprovados_grupo_lp': '${c.reprovados}',
            'cabe_analise_grupo_lp': '${c.cabeAnalise}',
          };
        }(),
    ];
  }

  Future<Map<String, String>> graficosAgrupados({required Set<String> selecionados, required List<ElementoLPBruto> elementos}) async {
    if (!selecionados.contains(chaveGraficoStatusLocalTipoLP) || elementos.isEmpty) return const {};
    final grupos = <String, ContagemStatusLP>{};
    for (final e in elementos) {
      final chave = '${e.local} / ${e.tipoElemento}';
      grupos[chave] = (grupos[chave] ?? const ContagemStatusLP()) + e.contagem;
    }
    final imagem = await RelatorioChartRenderer.barrasSegmentadas(
      tituloEixoY: 'Pontos',
      grupos: [
        for (final g in grupos.entries)
          BarraSegmentadaGrupo(rotulo: g.key, segmentos: [
            for (final s in StatusLP.values) SegmentoBarra(rotulo: s.label, valor: g.value.de(s).toDouble(), cor: s.cor),
          ]),
      ],
    );
    return {chaveGraficoStatusLocalTipoLP: imagem};
  }

  /// Referencial: só os catálogos da estrutura (tipo/tipologia/utilização).
  Future<Map<String, List<Map<String, String>>>> buscarReferencial({
    required List<String> catalogosNecessarios,
    required String estruturaId,
  }) async {
    final necessarios = {'tipos_estrutura', 'tipologias_estrutura', 'utilizacoes_estrutura'}.intersection(catalogosNecessarios.toSet());
    if (necessarios.isEmpty) return const {};
    try {
      final e = await _supabase
          .from('estruturas')
          .select('tipos_estrutura(nome, descricao), tipologias_estrutura(nome, descricao), utilizacoes_estrutura(nome, descricao)')
          .eq('id', estruturaId)
          .maybeSingle();
      if (e == null) return const {};
      return {
        for (final chave in necessarios)
          if (e[chave] is Map)
            chave: [
              {'nome': (e[chave] as Map)['nome']?.toString() ?? '', 'descricao': (e[chave] as Map)['descricao']?.toString() ?? ''}
            ],
      };
    } catch (_) {
      return const {};
    }
  }
}
