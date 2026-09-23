import 'package:flutter/material.dart' show Colors, Color, Offset;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../../../../modelos_relatorios/charts/relatorio_chart_renderer.dart';
import '../../../../modelos_relatorios/models/foto_relatorio.dart';
import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart';
import '../../ultrassom_direto/models/ultrassom_direto_model.dart';
import '../../ultrassom_indireto/models/ultrassom_indireto_model.dart';
import '../../ultrassom_mapeamento/models/ultrassom_mapeamento_model.dart';
import '../../utils/ultrassom_math.dart';
import 'ultrassom_mapa_calor_renderer.dart';

class RegistroUltrassomReal {
  final Map<String, String> dados;
  final List<Map<String, String>> subLista;
  final List<FotoRelatorio> fotos;
  const RegistroUltrassomReal({required this.dados, required this.subLista, required this.fotos});
}

double? _paraDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.'));
}

// Um ponto de Ultrassonografia (qualquer modo) com todos os dados brutos —
// reaproveita as mesmas classes de modelo de Direto/Indireto/Mapeamento
// (inclusive a regressão do Indireto e a calibração de perspectiva do
// Mapeamento) já usadas nas telas de coleta/análise.
class PontoUltrassomBruto {
  final String nomeElemento;
  final String tipoElemento;
  final String local;
  final String revestimento;
  final String? marcacaoImagemUrl;
  final String nomePonto;
  final String valorResultado;
  final String modo;
  final String pulso;
  final double alfaE;
  final double densidade;
  final String? foto1;
  final String? foto2;
  final String? foto3;
  final List<PontoMedicaoUltrassomDiretoModel> medicoesDireto;
  final List<MedicaoUltrassomIndiretoModel> medicoesIndireto;
  final PontoUltrassomMapeamentoModel? mapeamento;
  final List<FotoRelatorio> fotos;

  const PontoUltrassomBruto({
    required this.nomeElemento,
    required this.tipoElemento,
    required this.local,
    required this.revestimento,
    required this.marcacaoImagemUrl,
    required this.nomePonto,
    required this.valorResultado,
    required this.modo,
    required this.pulso,
    required this.alfaE,
    required this.densidade,
    required this.foto1,
    required this.foto2,
    required this.foto3,
    required this.medicoesDireto,
    required this.medicoesIndireto,
    required this.mapeamento,
    required this.fotos,
  });

  bool get ehLongitudinal => pulso.toLowerCase() == 'longitudinal';

  List<double> get valoresVelocidade {
    switch (modo) {
      case 'direto':
        return medicoesDireto.expand((m) => m.leituras.map((l) => l.velocidade)).toList();
      case 'indireto':
        return medicoesIndireto.map((m) => m.valorVelocidade).where((v) => v > 0).toList();
      case 'mapeamento':
        return (mapeamento?.leituras ?? const []).where((l) => l.velocidade != null).map((l) => l.velocidade!).toList();
      default:
        return const [];
    }
  }

  double get media => UltrassomMath.mean(valoresVelocidade);
  double get coefVariacao => UltrassomMath.coefVariacao(valoresVelocidade);
}

// Um elemento com resultado Longitudinal E Transversal — só esses têm Ed/fck
// calculáveis (equações 1, 2 e 3 do artigo ENSUS 2024, ver UltrassomMath).
class ElementoUltrassomBruto {
  final String elementoId;
  final String nomeElemento;
  final String tipoElemento;
  final String local;
  final double velocidadeLongitudinal;
  final double velocidadeTransversal;
  final double alfaE;
  final double densidade;

  const ElementoUltrassomBruto({
    required this.elementoId,
    required this.nomeElemento,
    required this.tipoElemento,
    required this.local,
    required this.velocidadeLongitudinal,
    required this.velocidadeTransversal,
    required this.alfaE,
    required this.densidade,
  });

  double get poisson => UltrassomMath.poisson(vp: velocidadeLongitudinal, vs: velocidadeTransversal);
  double get moduloElasticidade =>
      UltrassomMath.moduloElasticidadeDinamico(densidade: densidade, vs: velocidadeTransversal, poisson: poisson);
  double get resistenciaCompressao => UltrassomMath.resistenciaCompressaoEstimada(ed: moduloElasticidade, alfaE: alfaE);
}

class UltrassomModeloReportData {
  final SupabaseClient _supabase;
  UltrassomModeloReportData(this._supabase);

  Future<List<PontoUltrassomBruto>> buscarPontosBrutos({
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioId,
  }) async {
    final resp = await _supabase.from('pontos_ensaios_geral').select('''
          id, nome_ponto, valor_resultado,
          elementos_estruturais!inner(id, nome, tipo, local, revestimento, marcacao_imagem_url, estrutura_id),
          galeria_pontos_ensaios_geral(imagem_url, legenda),
          ponto_ensaio_ultrassom(
            modo, tipo_onda, foto_1, foto_2, foto_3, alfa_e, densidade,
            ponto_ensaio_ultrassom_direto_medicao(nome_ponto, distancia,
              ponto_ensaio_ultrassom_direto_leitura(velocidade)),
            ponto_ensaio_ultrassom_indireto_medicao(nome_ponto,
              ponto_ensaio_ultrassom_indireto_leitura(distancia, velocidade)),
            ponto_ensaio_ultrassom_mapeamento(
              espacamento_x, espacamento_y, opacidade, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y,
              ponto_ensaio_ultrassom_mapeamento_leitura(linha, coluna, velocidade))
          )
        ''').eq('projeto_id', projetoId).eq('elementos_estruturais.estrutura_id', estruturaId).eq('tipo_ensaio_id', tipoEnsaioId);

    final pontos = <PontoUltrassomBruto>[];
    for (final p in (resp as List)) {
      final elemento = p['elementos_estruturais'] as Map<String, dynamic>?;
      final ultrassomList = p['ponto_ensaio_ultrassom'] as List? ?? const [];
      if (ultrassomList.isEmpty) continue;
      final u = (ultrassomList.first as Map).cast<String, dynamic>();

      final fotos = <FotoRelatorio>[];
      final galeriaGeral = p['galeria_pontos_ensaios_geral'] as List? ?? const [];
      for (final g in galeriaGeral) {
        final url = g['imagem_url']?.toString();
        if (url != null && url.isNotEmpty) fotos.add(FotoRelatorio(url: url, descricao: g['legenda']?.toString() ?? ''));
      }

      final medicoesDireto = (u['ponto_ensaio_ultrassom_direto_medicao'] as List? ?? const [])
          .map((m) => PontoMedicaoUltrassomDiretoModel.fromJson(
                (m as Map).cast<String, dynamic>(),
                leituras: ((m['ponto_ensaio_ultrassom_direto_leitura'] as List?) ?? const [])
                    .map((l) => LeituraUltrassomDiretoModel.fromJson((l as Map).cast<String, dynamic>()))
                    .toList(),
              ))
          .toList();

      final medicoesIndireto = (u['ponto_ensaio_ultrassom_indireto_medicao'] as List? ?? const [])
          .map((m) => MedicaoUltrassomIndiretoModel(
                nomePonto: m['nome_ponto']?.toString() ?? 'Ponto',
                leituras: ((m['ponto_ensaio_ultrassom_indireto_leitura'] as List?) ?? const [])
                    .map((l) => LeituraUltrassomIndiretoModel.fromJson((l as Map).cast<String, dynamic>()))
                    .toList(),
              ))
          .toList();

      final mapeamentoList = u['ponto_ensaio_ultrassom_mapeamento'] as List? ?? const [];
      PontoUltrassomMapeamentoModel? mapeamento;
      if (mapeamentoList.isNotEmpty) {
        final mp = (mapeamentoList.first as Map).cast<String, dynamic>();
        final leituras = ((mp['ponto_ensaio_ultrassom_mapeamento_leitura'] as List?) ?? const [])
            .map((l) => LeituraUltrassomMapeamentoModel.fromJson((l as Map).cast<String, dynamic>()))
            .toList();
        mapeamento = PontoUltrassomMapeamentoModel(
          espacamentoX: mp['espacamento_x']?.toString(),
          espacamentoY: mp['espacamento_y']?.toString(),
          opacidade: mp['opacidade']?.toString(),
          p1X: _paraDouble(mp['p1_x']),
          p1Y: _paraDouble(mp['p1_y']),
          p2X: _paraDouble(mp['p2_x']),
          p2Y: _paraDouble(mp['p2_y']),
          p3X: _paraDouble(mp['p3_x']),
          p3Y: _paraDouble(mp['p3_y']),
          p4X: _paraDouble(mp['p4_x']),
          p4Y: _paraDouble(mp['p4_y']),
          leituras: leituras,
        );
      }

      pontos.add(PontoUltrassomBruto(
        nomeElemento: elemento?['nome']?.toString() ?? '',
        tipoElemento: elemento?['tipo']?.toString() ?? 'Desconhecido',
        local: elemento?['local']?.toString() ?? 'Desconhecido',
        revestimento: elemento?['revestimento']?.toString() ?? '',
        marcacaoImagemUrl: elemento?['marcacao_imagem_url']?.toString(),
        nomePonto: p['nome_ponto']?.toString() ?? '',
        valorResultado: p['valor_resultado']?.toString() ?? '',
        modo: u['modo']?.toString() ?? '',
        pulso: u['tipo_onda']?.toString() ?? 'Longitudinal',
        alfaE: _paraDouble(u['alfa_e']) ?? 1.0,
        densidade: _paraDouble(u['densidade']) ?? 2400.0,
        foto1: u['foto_1']?.toString(),
        foto2: u['foto_2']?.toString(),
        foto3: u['foto_3']?.toString(),
        medicoesDireto: medicoesDireto,
        medicoesIndireto: medicoesIndireto,
        mapeamento: mapeamento,
        fotos: fotos,
      ));
    }
    return pontos;
  }

  String _rotuloModo(String modo) {
    switch (modo) {
      case 'direto':
        return 'Direto';
      case 'indireto':
        return 'Indireto';
      case 'mapeamento':
        return 'Mapeamento';
      default:
        return modo;
    }
  }

  // "Box repetição" — um item por ponto de medição, comum a Direto e
  // Indireto (Mapeamento não usa, ver comentário no catálogo).
  List<Map<String, String>> _subListaMedicoes(PontoUltrassomBruto p) {
    switch (p.modo) {
      case 'direto':
        return p.medicoesDireto.map((m) {
          final classificacao = p.ehLongitudinal && m.media > 0 ? ClassificacaoWhitehurst.classificar(m.media).texto : '-';
          return {
            'nome_ponto_medicao_us': m.nomePonto,
            'distancia_medicao_us': m.distancia != null ? '${m.distancia!.toStringAsFixed(0)} cm' : '-',
            'velocidade_medicao_us': '${m.media.toStringAsFixed(0)} m/s',
            'classificacao_medicao_us': classificacao,
          };
        }).toList();
      case 'indireto':
        return p.medicoesIndireto.map((m) {
          final classificacao = p.ehLongitudinal && m.valorVelocidade > 0 ? ClassificacaoWhitehurst.classificar(m.valorVelocidade).texto : '-';
          return {
            'nome_ponto_medicao_us': m.nomePonto,
            'distancia_medicao_us': '-',
            'velocidade_medicao_us': '${m.valorVelocidade.toStringAsFixed(0)} m/s',
            'classificacao_medicao_us': classificacao,
          };
        }).toList();
      default:
        return const [];
    }
  }

  String _gridLeiturasMapeamentoHtml(PontoUltrassomMapeamentoModel mapeamento) {
    if (mapeamento.leituras.isEmpty) return '';
    final linhas = mapeamento.leituras.map((l) => l.linha).toSet().toList()..sort();
    final colunas = mapeamento.leituras.map((l) => l.coluna).toSet().toList()..sort();
    final espX = double.tryParse(mapeamento.espacamentoX ?? '10') ?? 10;
    final espY = double.tryParse(mapeamento.espacamentoY ?? '10') ?? 10;
    final mapa = {for (final l in mapeamento.leituras) '${l.linha}_${l.coluna}': l.velocidade};

    final buffer = StringBuffer('<table class="resumo"><thead><tr><th></th>');
    for (final c in colunas) {
      buffer.write('<th>${((c + 1) * espX).toStringAsFixed(0)}</th>');
    }
    buffer.write('</tr></thead><tbody>');
    for (final l in linhas) {
      buffer.write('<tr><td><b>${(l * espY).toStringAsFixed(0)}</b></td>');
      for (final c in colunas) {
        final v = mapa['${l}_$c'];
        buffer.write('<td>${v != null ? v.toStringAsFixed(0) : '-'}</td>');
      }
      buffer.write('</tr>');
    }
    buffer.write('</tbody></table>');
    return buffer.toString();
  }

  // Gráfico "tempo x distância" do método Indireto — uma série por ponto de
  // medição, mesma fórmula/eixos de `_buildGrafico` na tela de coleta.
  Future<String> _graficoTempoPropagacao(PontoUltrassomBruto p) async {
    if (p.medicoesIndireto.isEmpty) return '';
    final cores = [Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.brown, Colors.teal];
    final series = <SerieLinha>[];
    for (var i = 0; i < p.medicoesIndireto.length; i++) {
      final m = p.medicoesIndireto[i];
      if (m.leituras.isEmpty) continue;
      final ordenadas = [...m.leituras]..sort((a, b) => a.distancia.compareTo(b.distancia));
      series.add(SerieLinha(
        nome: m.nomePonto,
        pontos: ordenadas.map((l) => PontoGrafico(l.distancia, l.tempoMicrossegundos)).toList(),
        cor: cores[i % cores.length],
      ));
    }
    if (series.isEmpty) return '';
    return RelatorioChartRenderer.linhaComFaixa(
      series: series,
      tituloEixoX: 'Distância (cm)',
      tituloEixoY: 'Tempo de propagação do pulso (µs)',
    );
  }

  // Foto "Marcação da área" com a sobreposição do mapa de calor (perspectiva
  // + IDW) — só existe quando o ponto tem calibração salva (p1-p4).
  Future<String?> _mapaCalor(PontoUltrassomBruto p) async {
    final mapeamento = p.mapeamento;
    if (mapeamento == null || p.foto1 == null || p.foto1!.isEmpty) return null;
    if (mapeamento.p1X == null || mapeamento.p1Y == null || mapeamento.p2X == null || mapeamento.p2Y == null) return null;
    if (mapeamento.p3X == null || mapeamento.p3Y == null || mapeamento.p4X == null || mapeamento.p4Y == null) return null;

    final leituras = mapeamento.leituras
        .where((l) => l.velocidade != null)
        .map((l) => (linha: l.linha, coluna: l.coluna, velocidade: l.velocidade!))
        .toList();
    if (leituras.isEmpty) return null;

    return UltrassomMapaCalorRenderer.compor(
      urlFotoBase: p.foto1!,
      leituras: leituras,
      espacamentoX: double.tryParse(mapeamento.espacamentoX ?? '10') ?? 10,
      espacamentoY: double.tryParse(mapeamento.espacamentoY ?? '10') ?? 10,
      opacidade: double.tryParse(mapeamento.opacidade ?? '0.6') ?? 0.6,
      p1: Offset(mapeamento.p1X!, mapeamento.p1Y!),
      p2: Offset(mapeamento.p2X!, mapeamento.p2Y!),
      p3: Offset(mapeamento.p3X!, mapeamento.p3Y!),
      p4: Offset(mapeamento.p4X!, mapeamento.p4Y!),
    );
  }

  Future<RegistroUltrassomReal> _montarRegistroIndividual(PontoUltrassomBruto p) async {
    final valores = p.valoresVelocidade;
    final media = p.media;
    final cv = p.coefVariacao;
    final classificacao = p.ehLongitudinal && media > 0 ? ClassificacaoWhitehurst.classificar(media).texto : '-';

    String? graficoIndireto;
    String? mapaCalor;
    String gridMapeamento = '';
    if (p.modo == 'indireto') {
      graficoIndireto = await _graficoTempoPropagacao(p);
    } else if (p.modo == 'mapeamento') {
      mapaCalor = await _mapaCalor(p);
      if (p.mapeamento != null) gridMapeamento = _gridLeiturasMapeamentoHtml(p.mapeamento!);
    }

    return RegistroUltrassomReal(
      dados: {
        'nome_elemento_us': p.nomeElemento,
        'tipo_elemento_us': p.tipoElemento,
        'local_elemento_us': p.local,
        'revestimento_elemento_us': p.revestimento,
        if (p.marcacaoImagemUrl != null && p.marcacaoImagemUrl!.isNotEmpty) 'marcacao_elemento_us': p.marcacaoImagemUrl!,
        'alfa_e_us': p.alfaE.toStringAsFixed(2),
        'densidade_us': p.densidade.toStringAsFixed(0),
        'nome_ponto_us': p.nomePonto,
        'modo_us': _rotuloModo(p.modo),
        'pulso_us': p.pulso,
        'valor_resultado_us': p.valorResultado,
        if (p.foto1 != null && p.foto1!.isNotEmpty) 'imagem_marcacao_area_us': p.foto1!,
        if (p.foto2 != null && p.foto2!.isNotEmpty) 'imagem_realizacao_ensaio_us': p.foto2!,
        'media_velocidade_us': valores.isEmpty ? '-' : '${media.toStringAsFixed(0)} m/s',
        'cv_us': valores.isEmpty ? '-' : '${cv.toStringAsFixed(1)}%',
        'classificacao_us': classificacao,
        if (p.modo == 'direto' && p.foto3 != null && p.foto3!.isNotEmpty) 'imagem_pontos_marcados_us': p.foto3!,
        if (graficoIndireto != null && graficoIndireto.isNotEmpty) 'grafico_tempo_propagacao_us': graficoIndireto,
        if (mapaCalor != null) 'mapa_calor_us': mapaCalor,
        if (gridMapeamento.isNotEmpty) 'grid_leituras_mapeamento_us': gridMapeamento,
      },
      subLista: _subListaMedicoes(p),
      fotos: p.fotos,
    );
  }

  Future<List<RegistroUltrassomReal>> montarRegistros(List<PontoUltrassomBruto> pontos) async {
    final registros = <RegistroUltrassomReal>[];
    for (final p in pontos) {
      registros.add(await _montarRegistroIndividual(p));
    }
    return registros;
  }

  // Elementos com resultado Longitudinal E Transversal — "a média das
  // velocidades" pedida pelo usuário: pool de TODAS as leituras dos pontos
  // daquele pulso naquele elemento (não a média das médias de cada ponto).
  List<ElementoUltrassomBruto> elementosComAmbasOndas(List<PontoUltrassomBruto> pontos) {
    // `PontoUltrassomBruto` não guarda o id do elemento — usa a combinação
    // nome+tipo+local como chave estável o bastante pra esse agrupamento
    // (dois elementos idênticos nos 3 campos seriam agregados juntos,
    // aceitável já que o app não permite nomes duplicados no mesmo local).
    final porElemento = <String, List<PontoUltrassomBruto>>{};
    for (final p in pontos) {
      porElemento.putIfAbsent('${p.nomeElemento}|${p.tipoElemento}|${p.local}', () => []).add(p);
    }

    final resultado = <ElementoUltrassomBruto>[];
    for (final entry in porElemento.entries) {
      final pontosElemento = entry.value;
      final longitudinais = pontosElemento.where((p) => p.ehLongitudinal).expand((p) => p.valoresVelocidade).toList();
      final transversais = pontosElemento.where((p) => !p.ehLongitudinal).expand((p) => p.valoresVelocidade).toList();
      if (longitudinais.isEmpty || transversais.isEmpty) continue;

      final primeiro = pontosElemento.first;
      resultado.add(ElementoUltrassomBruto(
        elementoId: entry.key,
        nomeElemento: primeiro.nomeElemento,
        tipoElemento: primeiro.tipoElemento,
        local: primeiro.local,
        velocidadeLongitudinal: UltrassomMath.mean(longitudinais),
        velocidadeTransversal: UltrassomMath.mean(transversais),
        alfaE: primeiro.alfaE,
        densidade: primeiro.densidade,
      ));
    }
    resultado.sort((a, b) => a.nomeElemento.compareTo(b.nomeElemento));
    return resultado;
  }

  // Linhas da seção "Análise de Elementos" (antes de "Registros agrupados")
  // — uma por elemento com ambas as ondas, expondo Ed e fck estimados.
  List<Map<String, String>> montarLinhasAnaliseElementos(List<PontoUltrassomBruto> pontos) {
    return elementosComAmbasOndas(pontos)
        .map((e) => {
              'nome_elemento_analise_us': e.nomeElemento,
              'tipo_elemento_analise_us': e.tipoElemento,
              'local_elemento_analise_us': e.local,
              'alfa_e_analise_us': e.alfaE.toStringAsFixed(2),
              'densidade_analise_us': e.densidade.toStringAsFixed(0),
              'velocidade_longitudinal_analise_us': '${e.velocidadeLongitudinal.toStringAsFixed(0)} m/s',
              'velocidade_transversal_analise_us': '${e.velocidadeTransversal.toStringAsFixed(0)} m/s',
              'poisson_analise_us': e.poisson.toStringAsFixed(2),
              'modulo_elasticidade_analise_us': '${(e.moduloElasticidade / 1000).toStringAsFixed(1)} GPa',
              'fck_analise_us': '${e.resistenciaCompressao.toStringAsFixed(1)} MPa',
            })
        .toList();
  }

  Future<List<Map<String, String>>> buscarLinhasAgrupadas({
    required List<PontoUltrassomBruto> pontos,
    required HierarquiaAgrupamento hierarquia,
  }) async {
    final grupos = <String, List<PontoUltrassomBruto>>{};
    final rotulos = <String, ({String local, String tipo})>{};
    for (final p in pontos) {
      final String chave;
      switch (hierarquia) {
        case HierarquiaAgrupamento.local:
          chave = p.local;
          break;
        case HierarquiaAgrupamento.tipoElemento:
          chave = p.tipoElemento;
          break;
        case HierarquiaAgrupamento.localTipoElemento:
          chave = '${p.local}|${p.tipoElemento}';
          break;
      }
      grupos.putIfAbsent(chave, () => []).add(p);
      rotulos[chave] = (local: p.local, tipo: p.tipoElemento);
    }

    final linhas = <Map<String, String>>[];
    for (final entrada in grupos.entries) {
      final longitudinais = entrada.value.where((p) => p.ehLongitudinal).expand((p) => p.valoresVelocidade).toList();
      final transversais = entrada.value.where((p) => !p.ehLongitudinal).expand((p) => p.valoresVelocidade).toList();
      final mediaLong = UltrassomMath.mean(longitudinais);

      linhas.add({
        'local_grupo_us': rotulos[entrada.key]!.local,
        'tipo_elemento_grupo_us': rotulos[entrada.key]!.tipo,
        'media_longitudinal_grupo_us': longitudinais.isEmpty ? '-' : '${mediaLong.toStringAsFixed(0)} m/s',
        'cv_longitudinal_grupo_us': longitudinais.isEmpty ? '-' : '${UltrassomMath.coefVariacao(longitudinais).toStringAsFixed(1)}%',
        'classificacao_longitudinal_grupo_us': longitudinais.isEmpty ? '-' : ClassificacaoWhitehurst.classificar(mediaLong).texto,
        'media_transversal_grupo_us': transversais.isEmpty ? '-' : '${UltrassomMath.mean(transversais).toStringAsFixed(0)} m/s',
        'cv_transversal_grupo_us': transversais.isEmpty ? '-' : '${UltrassomMath.coefVariacao(transversais).toStringAsFixed(1)}%',
      });
    }
    return linhas;
  }

  // Barra por elemento (Longitudinal/Transversal) — mesma agregação de
  // `AnaliseTodosUltrassomScreen._mediasPorElemento`: média das médias de
  // cada ponto daquele elemento no pulso escolhido.
  Future<String> _graficoBarraPulso(List<PontoUltrassomBruto> pontos, bool longitudinal) async {
    final pontosPulso = pontos.where((p) => p.ehLongitudinal == longitudinal).toList();
    final porElemento = <String, List<PontoUltrassomBruto>>{};
    for (final p in pontosPulso) {
      porElemento.putIfAbsent('${p.nomeElemento}|${p.tipoElemento}|${p.local}', () => []).add(p);
    }
    final grupos = <BarraGrupo>[];
    for (final entry in porElemento.entries) {
      final medias = entry.value.map((p) => p.media).where((m) => m > 0).toList();
      if (medias.isEmpty) continue;
      grupos.add(BarraGrupo(rotulo: entry.value.first.nomeElemento, valor: UltrassomMath.mean(medias)));
    }
    if (grupos.isEmpty) return '';
    grupos.sort((a, b) => a.rotulo.compareTo(b.rotulo));

    return RelatorioChartRenderer.barrasComFaixas(
      grupos: grupos,
      tituloEixoY: 'Velocidade (m/s)',
      corBarra: const Color(0xFFFFC107),
      faixas: longitudinal
          ? const [
              FaixaFundo(de: 0, ate: 2000, cor: Colors.red, rotulo: 'Ruim'),
              FaixaFundo(de: 2000, ate: 3000, cor: Colors.orange, rotulo: 'Regular'),
              FaixaFundo(de: 3000, ate: 3500, cor: Colors.yellow, rotulo: 'Bom'),
              FaixaFundo(de: 3500, ate: 4500, cor: Colors.lightGreen, rotulo: 'Ótimo'),
              FaixaFundo(de: 4500, ate: 5500, cor: Colors.green, rotulo: 'Excelente'),
            ]
          : const [],
    );
  }

  Future<String> _graficoBarraElementos(List<ElementoUltrassomBruto> elementos, bool resistencia) async {
    if (elementos.isEmpty) return '';
    final grupos = elementos
        .map((e) => BarraGrupo(rotulo: e.nomeElemento, valor: resistencia ? e.resistenciaCompressao : e.moduloElasticidade / 1000))
        .toList();
    return RelatorioChartRenderer.barrasComFaixas(
      grupos: grupos,
      tituloEixoY: resistencia ? 'Resistência (MPa)' : 'Ed (GPa)',
      corBarra: const Color(0xFFFFC107),
    );
  }

  // Uma curva de Gauss por grupo (Local / Tipo de elemento / os dois — a
  // mesma escolha de `HierarquiaAgrupamento` já usada em "Registros
  // agrupados") — cada elemento só entra na distribuição do SEU grupo, em
  // vez de uma única curva com todos os elementos juntos.
  String _chaveGrupoFck(ElementoUltrassomBruto e, HierarquiaAgrupamento hierarquia) {
    switch (hierarquia) {
      case HierarquiaAgrupamento.local:
        return e.local;
      case HierarquiaAgrupamento.tipoElemento:
        return e.tipoElemento;
      case HierarquiaAgrupamento.localTipoElemento:
        return '${e.local} — ${e.tipoElemento}';
    }
  }

  Future<String> _graficoDistribuicaoFck(List<ElementoUltrassomBruto> elementos, HierarquiaAgrupamento hierarquia) async {
    final grupos = <String, List<double>>{};
    for (final e in elementos) {
      if (e.resistenciaCompressao <= 0) continue;
      grupos.putIfAbsent(_chaveGrupoFck(e, hierarquia), () => []).add(e.resistenciaCompressao);
    }

    final paleta = [const Color(0xFF3F51B5), Colors.teal, Colors.deepOrange, Colors.purple, Colors.brown, Colors.blueGrey];
    final series = <SerieLinha>[];
    final marcadores = <MarcadorVertical>[];
    var i = 0;
    for (final entry in grupos.entries) {
      if (entry.value.length < 2) continue;
      final media = UltrassomMath.mean(entry.value);
      final desvio = UltrassomMath.stdDev(entry.value);
      final fck = UltrassomMath.valorCaracteristico95(entry.value);
      final minX = (media - 4 * desvio).clamp(0, double.infinity).toDouble();
      final maxX = media + 4 * desvio;
      final passo = (maxX - minX) / 100;

      final curva = <PontoGrafico>[];
      for (double x = minX; x <= maxX; x += (passo == 0 ? 1 : passo)) {
        curva.add(PontoGrafico(x, UltrassomMath.normalPdf(x, media, desvio)));
      }

      final cor = paleta[i % paleta.length];
      series.add(SerieLinha(nome: '${entry.key} (fck ${fck.toStringAsFixed(1)})', pontos: curva, cor: cor, preenchida: grupos.length == 1));
      marcadores.add(MarcadorVertical(x: fck, rotulo: entry.key, cor: cor));
      i++;
    }
    if (series.isEmpty) return '';

    return RelatorioChartRenderer.linhaComFaixa(
      series: series,
      marcadores: marcadores,
      tituloEixoX: 'Resistência à compressão (MPa)',
      tituloEixoY: 'Densidade de probabilidade',
    );
  }

  // Boxplot por elemento, colorido por Local — mesma lógica de
  // `AnaliseTodosUltrassomScreen._buildAbaEstatistica` (pool de TODAS as
  // leituras dos pontos daquele elemento, não só de um ponto por vez).
  // Locais diferentes quase sempre têm conjuntos de elementos diferentes, e
  // `boxplotPorGrupo` espera o MESMO conjunto de rótulos (na mesma ordem)
  // em toda série que lhe é passada — por isso usa 1 série SÓ com todas as
  // caixas, sobrepondo a cor por caixa via `GrupoBoxplot.cor` (mesmo
  // mecanismo do "boxplot por elementos específicos" da Arrancamento) em
  // vez de 1 série por Local.
  Future<String> _boxplotPulso(List<PontoUltrassomBruto> pontos, bool longitudinal) async {
    final pontosPulso = pontos.where((p) => p.ehLongitudinal == longitudinal).toList();
    if (pontosPulso.isEmpty) return '';

    final locaisUnicos = pontosPulso.map((p) => p.local).toSet().toList()..sort();
    final paleta = [Colors.indigo, Colors.red, Colors.green, Colors.orange, Colors.purple];
    final corPorLocal = {for (var i = 0; i < locaisUnicos.length; i++) locaisUnicos[i]: paleta[i % paleta.length]};

    final porElementoLocal = <String, List<PontoUltrassomBruto>>{};
    for (final p in pontosPulso) {
      porElementoLocal.putIfAbsent('${p.nomeElemento}|${p.tipoElemento}|${p.local}', () => []).add(p);
    }

    final gruposBox = <GrupoBoxplot>[];
    for (final entry in porElementoLocal.entries) {
      final valores = entry.value.expand((p) => p.valoresVelocidade).toList();
      if (valores.length < 2) continue;
      final primeiro = entry.value.first;
      gruposBox.add(GrupoBoxplot(
        rotulo: '${primeiro.nomeElemento}\n${primeiro.tipoElemento}',
        minimo: valores.reduce((a, b) => a < b ? a : b),
        media: UltrassomMath.mean(valores),
        maximo: valores.reduce((a, b) => a > b ? a : b),
        cor: corPorLocal[primeiro.local],
      ));
    }
    if (gruposBox.isEmpty) return '';

    return RelatorioChartRenderer.boxplotPorGrupo(
      series: [SerieBoxplot(nome: 'Velocidade', cor: Colors.blueGrey, grupos: gruposBox)],
      tituloEixoY: 'Velocidade (m/s)',
      legendaOverride: [for (final local in locaisUnicos) MapEntry(local, corPorLocal[local]!)],
    );
  }

  Future<Map<String, String>> gerarGraficosAgrupados({
    required Set<String> graficosSelecionados,
    required List<PontoUltrassomBruto> pontos,
    required HierarquiaAgrupamento hierarquia,
  }) async {
    final resultado = <String, String>{};
    if (graficosSelecionados.isEmpty || pontos.isEmpty) return resultado;

    final elementos = elementosComAmbasOndas(pontos);

    if (graficosSelecionados.contains(chaveGraficoBarraLongitudinal)) {
      final img = await _graficoBarraPulso(pontos, true);
      if (img.isNotEmpty) resultado[chaveGraficoBarraLongitudinal] = img;
    }
    if (graficosSelecionados.contains(chaveGraficoBarraTransversal)) {
      final img = await _graficoBarraPulso(pontos, false);
      if (img.isNotEmpty) resultado[chaveGraficoBarraTransversal] = img;
    }
    if (graficosSelecionados.contains(chaveGraficoBarraResistencia)) {
      final img = await _graficoBarraElementos(elementos, true);
      if (img.isNotEmpty) resultado[chaveGraficoBarraResistencia] = img;
    }
    if (graficosSelecionados.contains(chaveGraficoBarraModuloElasticidade)) {
      final img = await _graficoBarraElementos(elementos, false);
      if (img.isNotEmpty) resultado[chaveGraficoBarraModuloElasticidade] = img;
    }
    if (graficosSelecionados.contains(chaveGraficoDistribuicaoFck)) {
      final img = await _graficoDistribuicaoFck(elementos, hierarquia);
      if (img.isNotEmpty) resultado[chaveGraficoDistribuicaoFck] = img;
    }
    if (graficosSelecionados.contains(chaveGraficoBoxplotLongitudinal)) {
      final img = await _boxplotPulso(pontos, true);
      if (img.isNotEmpty) resultado[chaveGraficoBoxplotLongitudinal] = img;
    }
    if (graficosSelecionados.contains(chaveGraficoBoxplotTransversal)) {
      final img = await _boxplotPulso(pontos, false);
      if (img.isNotEmpty) resultado[chaveGraficoBoxplotTransversal] = img;
    }

    return resultado;
  }

  Future<List<Map<String, String>>> _buscarCatalogoPorNome(String tabela, Set<String> nomes, String? empresaId) async {
    if (nomes.isEmpty) return [];
    try {
      final query = _supabase.from(tabela).select('nome, descricao').inFilter('nome', nomes.toList());
      final resp = empresaId != null ? await query.or('empresa_id.eq.$empresaId,empresa_id.eq.$DIAVICON_EMPRESA_ID') : await query;
      return (resp as List).map((r) => {'nome': r['nome']?.toString() ?? '', 'descricao': r['descricao']?.toString() ?? ''}).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, List<Map<String, String>>>> buscarReferencial({
    required List<String> catalogosNecessarios,
    required String estruturaId,
    required List<PontoUltrassomBruto> pontos,
    String? empresaId,
  }) async {
    final necessarios = catalogosNecessarios.toSet();
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
            if (item != null) {
              resultado[chave] = [
                {'nome': item['nome']?.toString() ?? '', 'descricao': item['descricao']?.toString() ?? ''}
              ];
            }
          }
        }
      } catch (_) {
        // Segue sem esses catálogos se a busca falhar.
      }
    }

    if (necessarios.contains('tipologias_elemento')) {
      final valores = pontos.map((p) => p.revestimento).where((v) => v.isNotEmpty).toSet();
      resultado['tipologias_elemento'] = await _buscarCatalogoPorNome('tipologias_elemento', valores, empresaId);
    }
    if (necessarios.contains('revestimentos_elemento')) {
      final valores = pontos.map((p) => p.revestimento).where((v) => v.isNotEmpty).toSet();
      resultado['revestimentos_elemento'] = await _buscarCatalogoPorNome('revestimentos_elemento', valores, empresaId);
    }

    return resultado;
  }
}
