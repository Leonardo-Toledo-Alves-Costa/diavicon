import 'dart:math'; 
import 'dart:convert'; 
import 'package:http/http.dart' as http; 
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:ui' as ui; // Para manipular pixels e imagens nativamente
import 'dart:typed_data'; // Para manipular os bytes da imagem

import '../../models/carbonatacao_math.dart'; 

final carbonatacaoReportServiceProvider = Provider((ref) {
  return CarbonatacaoReportService(Supabase.instance.client);
});

class ReportAssets {
  static Future<String> imageBase64(String asset) async {
    final bytes = await rootBundle.load(asset);
    return 'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List())}';
  }
}
SerieEstatistica calcularSerie(List<double> valores) {
  if (valores.isEmpty) {
    return SerieEstatistica(
      media: 0,
      dp: 0,
      minimo: 0,
      maximo: 0,
    );
  }
  final media = CarbonatacaoMath.mean(valores);
  final dp = CarbonatacaoMath.stdDev(valores);
  return SerieEstatistica(
    media: media,
    dp: dp,
    minimo: valores.reduce(min),
    maximo: valores.reduce(max),
  );
}

class SerieEstatistica {
      final double media;
      final double dp;
      final double minimo;
      final double maximo;

      SerieEstatistica({
        required this.media,
        required this.dp,
        required this.minimo,
        required this.maximo,
      });
    }

class CarbonatacaoReportService {
  final SupabaseClient _supabase;
  CarbonatacaoReportService(this._supabase);

  String _processarRepeat(String html, String tag, List<Map<String, String>> itens, {bool addPageBreak = false}) {
    // O .*? garante que ele ignore textos extras como "(um bloco por ponto)" na tag do HTML
    final regex = RegExp('<!-- REPEAT:$tag.*?-->(.*?)<!-- /REPEAT -->', dotAll: true);
    final match = regex.firstMatch(html);
    if (match == null) return html;
    
    final templateBloco = match.group(1)!;
    final buffer = StringBuffer();
    
    for (int i = 0; i < itens.length; i++) {
      String blocoPreenchido = templateBloco;
      itens[i].forEach((key, value) {
        blocoPreenchido = blocoPreenchido.replaceAll('{{$key}}', value);
      });
      
      // 👇 INJEÇÃO DA QUEBRA DE PÁGINA: Garante que cada ponto fique numa folha isolada!
      if (addPageBreak && i < itens.length - 1) {
        blocoPreenchido += '\n<div style="page-break-after: always;"></div>\n';
      }
      buffer.write(blocoPreenchido);
    }
    return html.replaceAll(regex, buffer.toString());
  }

  Future<String> _obterImagemBase64Redimensionada(String url) async {
      if (url.isEmpty || !url.startsWith('http')) return url;
      
      try {
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
          // 1. Decodifica os bytes nativamente
          final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(response.bodyBytes);
          final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(buffer);
          
          // 2. Define o tamanho limite mantendo a proporção (600px de largura é excelente para PDF)
          int targetWidth = descriptor.width;
          if (targetWidth > 600) {
            targetWidth = 600;
          }
          
          // O Flutter decodifica a imagem já no tamanho reduzido (muito otimizado para RAM)
          final ui.Codec codec = await descriptor.instantiateCodec(targetWidth: targetWidth);
          final ui.FrameInfo frame = await codec.getNextFrame();
          
          // 3. Converte para PNG base64
          final ByteData? resizedBytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
          if (resizedBytes != null) {
            final String base64Image = base64Encode(resizedBytes.buffer.asUint8List());
            return 'data:image/png;base64,$base64Image';
          }
        }
      } catch (e) {
        print('Erro ao redimensionar foto do ensaio: $e');
      }
      return url; // Retorna a URL original se algo falhar
    }


  Future<String> _gerarGraficoQuickChart(Map<String, dynamic> config, {String version = '4'}) async {
    try {
      final response = await http.post(
        Uri.parse('https://quickchart.io/chart'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chart': config,
          // 👇 CORREÇÃO: Forçando versão 3 para habilitar o plugin de BoxPlot no servidor
          'version': version, 
          'width': 600,
          'height': 300,
          'format': 'png',
          'backgroundColor': 'transparent',
          'devicePixelRatio': 1.0, 
        }),
      );
      
      if (response.statusCode == 200) {
        final base64Image = base64Encode(response.bodyBytes);
        return 'data:image/png;base64,$base64Image';
      }
    } catch (e) {
      print('Erro ao gerar gráfico: $e');
    }
    return ''; 
  }

  Future<String> gerarHtml({
    required String projetoId,
    required String estruturaId,
    required Map<String, dynamic> config,
  }) async {
    final estResp = await _supabase.from('estruturas').select('nome, caa, ano_concepcao, conjunto_estrutural_id, utilizacoes_estrutura(nome), tipos_estrutura(nome), tipologias_estrutura(nome)').eq('id', estruturaId).maybeSingle();
    final projResp = await _supabase.from('projetos').select('nome').eq('id', projetoId).maybeSingle();

    var query = _supabase.from('pontos_ensaios_geral').select('''
      id, nome_ponto, valor_resultado, cor_resultado,
      elementos_estruturais!inner ( id, nome, tipo, local, revestimento ),
      ponto_ensaio_carb ( 
        id, cob_arm_p, bit_arm_p, cob_arm_s, bit_arm_s,
        ponto_ensaio_carb_frentes ( profundidade ),
        galeria_ponto_ensaio_carb ( imagem_url, referencia )
      )
    ''').eq('projeto_id', projetoId).eq('elementos_estruturais.estrutura_id', estruturaId);

    final locais = config['locais'] as List<dynamic>? ?? [];
    if (locais.isNotEmpty) query = query.inFilter('elementos_estruturais.local', locais);
    
    final tipos = config['tipos_elemento'] as List<dynamic>? ?? [];
    if (tipos.isNotEmpty) query = query.inFilter('elementos_estruturais.tipo', tipos);

    final List pontosAtivos = await query;

    String styles = await rootBundle.loadString('assets/reports/carbonatacao/css/style.css');
    String header = await rootBundle.loadString('assets/reports/carbonatacao/components/header.html');
    String footer = await rootBundle.loadString('assets/reports/carbonatacao/components/footer.html');
    String htmlFinal = '<!DOCTYPE html><html><head><meta charset="UTF-8"><style>$styles</style></head><body>';

    // Variáveis úteis da Estrutura
    int anoConcepcao = (estResp?['ano_concepcao'] as num?)?.toInt() ?? DateTime.now().year;
    int idade = max(1, DateTime.now().year - anoConcepcao);
    String utilNome = estResp?['utilizacoes_estrutura']?['nome']?.toString() ?? '-';
    String tipoNome = estResp?['tipos_estrutura']?['nome']?.toString() ?? '-';
    String tipoLogia = estResp?['tipologias_estrutura']?['nome']?.toString() ?? '-';
    String placeholderB64 = await ReportAssets.imageBase64('assets/images/project_placeholder1.png');

    // =======================================================================
    // CONSTRUÇÃO PÁGINA GERAL (RESUMO + GRÁFICOS)
    // =======================================================================
    if (config['incluir_resumo'] == true) {
      String pageGeral = await rootBundle.loadString('assets/reports/carbonatacao/templates/ensaio_geral_template.html');
      
      String utilNome = estResp?['utilizacoes_estrutura']?['nome']?.toString() ?? '-';
      String tipoNome = estResp?['tipos_estrutura']?['nome']?.toString() ?? '-';
      String tipoLogia = estResp?['tipologiaEstrutura']?['nome']?.toString() ?? '-';

      pageGeral = pageGeral.replaceAll('{{projeto}}', projResp?['nome']?.toString() ?? '-');
      pageGeral = pageGeral.replaceAll('{{estrutura}}', estResp?['nome']?.toString() ?? '-');
      
      pageGeral = pageGeral.replaceAll('{{caa}}', estResp?['caa']?.toString() ?? '-');
      pageGeral = pageGeral.replaceAll('{{utilizacao}}', utilNome);
      pageGeral = pageGeral.replaceAll('{{tipo}}', tipoNome);
      pageGeral = pageGeral.replaceAll('{{tipologiaEstrutural}}', tipoLogia);
      pageGeral = pageGeral.replaceAll('{{local}}', locais.isEmpty ? 'Todos' : locais.join(', '));
      pageGeral = pageGeral.replaceAll('{{elementos}}', tipos.isEmpty ? 'Todos' : tipos.join(', '));
      
      List<double> cobP = [];
      List<double> cobS = [];
      List<double> frentes = [];
      
      for (var p in pontosAtivos) {
        final carbList = p['ponto_ensaio_carb'] as List<dynamic>? ?? [];
        if (carbList.isNotEmpty) {
          final carb = carbList.first as Map<String, dynamic>;
          if (carb['cob_arm_p'] != null) cobP.add((carb['cob_arm_p'] as num).toDouble());
          if (carb['cob_arm_s'] != null) cobS.add((carb['cob_arm_s'] as num).toDouble());
          
          final frList = carb['ponto_ensaio_carb_frentes'] as List<dynamic>? ?? [];
          for (var f in frList) {
            if (f['profundidade'] != null) frentes.add((f['profundidade'] as num).toDouble());
          }
        }
      }

  
      double mediaCobP = CarbonatacaoMath.mean(cobP);
      double dpCobP = CarbonatacaoMath.stdDev(cobP);
      double cvCobP = mediaCobP == 0 ? 0.0 : (dpCobP / mediaCobP) * 100;

      double mediaCobS = CarbonatacaoMath.mean(cobS);
      double dpCobS = CarbonatacaoMath.stdDev(cobS);
      double cvCobS = mediaCobS == 0 ? 0.0 : (dpCobS / mediaCobS) * 100;

      double mediaFrente = CarbonatacaoMath.mean(frentes);
      double dpFrente = CarbonatacaoMath.stdDev(frentes);
      double cvFrente = mediaFrente == 0 ? 0.0 : (dpFrente / mediaFrente) * 100;

      double mediaCob = min(mediaCobP, mediaCobS);
      double dpCob = (mediaCobS <= mediaCobP) ? dpCobS : dpCobP;

      int anoConcepcao = (estResp?['ano_concepcao'] as num?)?.toInt() ?? DateTime.now().year;
      int idade = max(1, DateTime.now().year - anoConcepcao);

      double kMedia = mediaFrente / sqrt(idade);
      double tempoTotal = kMedia > 0 ? pow(mediaCob / kMedia, 2).toDouble() : 999.0;
      double vidaUtilResidual = tempoTotal - idade;
      if (vidaUtilResidual < 0) vidaUtilResidual = 0;

      //double percentualVida = tempoTotal > 0 ? (vidaUtilResidual / tempoTotal) * 100 : 100.0;
      //if (percentualVida > 100) percentualVida = 100;
      
      String condicao = "Irrelevante";
      if (vidaUtilResidual == 0) condicao = "Despassivado";
      else if (vidaUtilResidual < 5) condicao = "Risco Alto";
      else if (vidaUtilResidual < 15) condicao = "Risco Moderado";
      else if (vidaUtilResidual < 30) condicao = "Risco Baixo";

      // =======================================================================
      // 📊 SIMULAÇÃO DE MONTE CARLO - Idêntico à Tela (1000 Simulações)
      // =======================================================================
      List<double> arrayK = frentes.map((f) => f / sqrt(idade)).toList();
      double kMd = CarbonatacaoMath.mean(arrayK);
      double kDp = CarbonatacaoMath.stdDev(arrayK);

      double tempoCalc = (vidaUtilResidual == 0) ? idade.toDouble() : tempoTotal;
      double tempoAnalisePb = tempoCalc * (tempoCalc < 10 ? 3 : 2);
      int nSim = 1000;

      List<double> kSim = CarbonatacaoMath.randomNormal(kMd, kDp, nSim);
      List<double> cobSim = CarbonatacaoMath.randomNormal(mediaCob, dpCob, nSim);

      List<double> tLabels = [];
      List<double> probValues = [];

      for (double t = 0; t <= tempoAnalisePb; t += (tempoAnalisePb / 100)) {
        tLabels.add(t);
        if (t == 0) {
          probValues.add(0.0);
          continue;
        }
        int falhas = 0;
        for (int i = 0; i < nSim; i++) {
          double x = kSim[i] * sqrt(t);
          if (x > cobSim[i]) falhas++;
        }
        probValues.add((falhas / nSim) * 100);
      }

      String buscarTempoProb(double probAlvo) {
        for (int i = 0; i < probValues.length; i++) {
          if (probValues[i] >= probAlvo) return tLabels[i].toStringAsFixed(1);
        }
        return '> ${tempoAnalisePb.toStringAsFixed(0)}';
      }

      pageGeral = pageGeral.replaceAll('{{idade}}', idade.toStringAsFixed(2));
      pageGeral = pageGeral.replaceAll('{{utilizacao}}', utilNome);
      pageGeral = pageGeral.replaceAll('{{cob_principal_media}}', mediaCobP.toStringAsFixed(2));
      pageGeral = pageGeral.replaceAll('{{cob_principal_desvpad}}', dpCobP.toStringAsFixed(2));
      pageGeral = pageGeral.replaceAll('{{cob_principal_coefvar}}', cvCobP.toStringAsFixed(2));
      pageGeral = pageGeral.replaceAll('{{cob_secundaria_media}}', mediaCobS.toStringAsFixed(2));
      pageGeral = pageGeral.replaceAll('{{cob_secundaria_desvpad}}', dpCobS.toStringAsFixed(2));
      pageGeral = pageGeral.replaceAll('{{cob_secundaria_coefvar}}', cvCobS.toStringAsFixed(2));
      pageGeral = pageGeral.replaceAll('{{carb_principal_media}}', mediaFrente.toStringAsFixed(2));
      pageGeral = pageGeral.replaceAll('{{carb_principal_desvpad}}', dpFrente.toStringAsFixed(2));
      pageGeral = pageGeral.replaceAll('{{carb_principal_coefvar}}', cvFrente.toStringAsFixed(2));
      pageGeral = pageGeral.replaceAll('{{vida_util_anos}}', vidaUtilResidual.toStringAsFixed(0));
      //pageGeral = pageGeral.replaceAll('{{vida_util_percentual}}', percentualVida.toStringAsFixed(0));
      pageGeral = pageGeral.replaceAll('{{vida_util_condicao}}', condicao);
      pageGeral = pageGeral.replaceAll('{{coef_carb_k}}', kMedia.toStringAsFixed(2));
      
     //pageGeral = pageGeral.replaceAll('{{prob_baixo_anos}}', buscarTempoProb(20));
      //pageGeral = pageGeral.replaceAll('{{prob_medio_anos}}', buscarTempoProb(40));
      //pageGeral = pageGeral.replaceAll('{{prob_alto_anos}}', buscarTempoProb(60));
      //pageGeral = pageGeral.replaceAll('{{prob_muitoalto_anos}}', buscarTempoProb(80));
      //pageGeral = pageGeral.replaceAll('{{condicao_geral_texto}}', 'Análise baseada na média estatística de $idade anos da estrutura, indicando uma condição geral de $condicao.');

      // =======================================================================
      // 📊 GERAÇÃO DE IMAGENS DOS GRÁFICOS (Eixo Linear X + Coordenadas Y)
      // =======================================================================

      // Gráfico 1: Avanço da frente de carbonatação
      double tempoAnaliseG1 = max(idade * 2, tempoTotal * 2);
      
      // 👇 CORREÇÃO: Gerando dados no formato {x: t, y: valor} para eixo Linear contínuo
      List<Map<String, double>> dadosCobGrafico1 = [];
      List<Map<String, double>> dadosFrenteGrafico1 = [];
      
      for (double t = 0; t <= tempoAnaliseG1; t += (tempoAnaliseG1 / 50)) {
        dadosCobGrafico1.add({'x': t, 'y': mediaCob});
        dadosFrenteGrafico1.add({'x': t, 'y': sqrt(t) * kMedia});
      }
      double maxYG1 = max(dadosFrenteGrafico1.last['y']!, mediaCob) * 1.2;

      String base64FrenteCob = await _gerarGraficoQuickChart({
        'type': 'line',
        'plugins': ['chartjs-plugin-annotation'],
        'data': {
          'datasets': [
            {
              'label': 'Cobrimento (mm)',
              'data': dadosCobGrafico1,
              'backgroundColor': 'rgba(200, 150, 255, 0.2)', 
              'borderColor': '#C896FF',
              'borderWidth': 2,
              'fill': true,
              'pointRadius': 0,
            },
            {
              'label': 'Frente de Carbonatação (mm)',
              'data': dadosFrenteGrafico1,
              'borderColor': '#616161',
              'backgroundColor': 'rgba(120,120,120,0.20)',
              'borderWidth': 3,
              'fill': true,
              'pointRadius': 0,
            }
          ]
        },
        'options': {
          'plugins': {
            'title': { 'display': false, 'text': 'Avanço da frente de carbonatação', 'font': { 'family': 'Lato', 'size': 14 } },
            'legend': { 'position': 'bottom', 'labels': { 'font': { 'family': 'Lato', 'size': 12 } } },
            'annotation': {
              'annotations': {
                'lineIdade': { 'type': 'line', 'xMin': idade, 'xMax': idade, 'borderColor': 'orange', 'borderDash': [8, 6], 'borderWidth': 2, 'label': { 'content': 'Idade', 'display': true, 'position': 'start' } },
                'lineFalha': { 'type': 'line', 'xMin': tempoTotal, 'xMax': tempoTotal, 'borderColor': 'red', 'borderDash': [8, 6], 'borderWidth': 2, 'label': { 'content': 'Falha', 'display': true, 'position': 'start' } }
              }
            }
          },
          'scales': {
            // 👇 Eixo X Linear permite que a anotação caia na posição exata!
            'x': { 'type': 'linear', 'title': { 'display': true, 'text': 'Exposição (anos)' }, 'min': 0, 'max':tempoAnalisePb },
            'y': { 'title': { 'display': true, 'text': 'Profundidade (mm)' }, 'min': 0, 'max': maxYG1 }
          }
        }
      });

      // Gráfico 2: Distribuição de Riscos (Doughnut)
      Map<String, int> contagemRisco = {'Despassivado': 0, 'Risco Alto': 0, 'Risco Moderado': 0, 'Risco Baixo': 0, 'Irrelevante': 0};
      for (var p in pontosAtivos) {
        String risco = p['valor_resultado']?.toString() ?? 'Irrelevante';
        if (contagemRisco.containsKey(risco)) contagemRisco[risco] = contagemRisco[risco]! + 1;
      }
      String base64Riscos = await _gerarGraficoQuickChart({
        'type': 'doughnut',
        'data': {
          'labels': contagemRisco.keys.toList(),
          'datasets': [{
            'data': contagemRisco.values.toList(),
            'backgroundColor': ['#FF4C4C', '#FF8C00', '#FFB74D', '#AED581', '#81C784']
          }]
        },
        'options': { 
          'plugins': { 
            'title': { 'display': false, 'text': 'Distribuição dos Riscos na Estrutura', 'font': { 'family': 'Lato', 'size': 14 } },
            'legend': { 'position': 'right', 'labels': { 'font': { 'family': 'Lato', 'size': 12 } } } 
          } 
        }
      });

      // Gráfico 3: Curva de Probabilidade de Falha
      List<Map<String, double>> dadosProbGrafico3 = [];
      for (int i = 0; i < tLabels.length; i++) {
        dadosProbGrafico3.add({'x': tLabels[i], 'y': probValues[i]});
      }

      String base64Prob = await _gerarGraficoQuickChart({
        'type': 'line',
        'plugins': ['chartjs-plugin-annotation'],
        'data': {
          'datasets': [
            {
              'label': 'Probabilidade de falha (%)',
              'data': dadosProbGrafico3,
              'backgroundColor': 'rgba(224, 224, 224, 1)', 
              'borderColor': '#757575', 
              'borderWidth': 3,
              'fill': true,
              'pointRadius': 0,
            }
          ]
        },
        'options': {
          'plugins': {
            'title': { 'display': false, 'text': 'Estimativa da Probabilidade de Despassivação', 'font': { 'family': 'Lato', 'size': 14 } },
            'legend': { 'position': 'bottom', 'labels': { 'font': { 'family': 'Lato', 'size': 12 } } },
            'annotation': {
              'annotations': {
                'lineIdade': { 'type': 'line', 'xMin': idade, 'xMax': idade, 'borderColor': 'orange', 'borderDash': [8, 6], 'borderWidth': 2, 'label': { 'content': 'Idade', 'display': true, 'position': 'start' } }
              }
            }
          },
          'scales': {
            'x': { 'type': 'linear', 'title': { 'display': true, 'text': 'Exposição (anos)', 'min': 0, 'max':tempoAnalisePb } },
            'y': { 'title': { 'display': true, 'text': 'Probabilidade de falha (%)' }, 'min': 0, 'max': 100 }
          }
        }
      });

      // Gráficos 4 e 5: Boxplots (A versão 3 os processa de forma excelente)
      Map<String, List<double>> mapCobElemento = {};
      Map<String, List<double>> mapFrenteElemento = {};
      Map<String, List<double>> mapCobLocal = {};
      Map<String, List<double>> mapFrenteLocal = {};

      for (var p in pontosAtivos) {
        final el = p['elementos_estruturais'] as Map<String, dynamic>? ?? {};
        String tipo = el['tipo']?.toString() ?? 'Desconhecido';
        String local = el['local']?.toString() ?? 'Desconhecido';

        mapCobElemento.putIfAbsent(tipo, () => []);
        mapFrenteElemento.putIfAbsent(tipo, () => []);
        mapCobLocal.putIfAbsent(local, () => []);
        mapFrenteLocal.putIfAbsent(local, () => []);

        final carbList = p['ponto_ensaio_carb'] as List<dynamic>? ?? [];
        if (carbList.isNotEmpty) {
          final carb = carbList.first as Map<String, dynamic>;
          
          List<double> cobs = [];
          if (carb['cob_arm_p'] != null) cobs.add((carb['cob_arm_p'] as num).toDouble());
          if (carb['cob_arm_s'] != null) cobs.add((carb['cob_arm_s'] as num).toDouble());
          
          List<double> frentesPonto = [];
          final frList = carb['ponto_ensaio_carb_frentes'] as List<dynamic>? ?? [];
          for (var f in frList) {
            if (f['profundidade'] != null) frentesPonto.add((f['profundidade'] as num).toDouble());
          }

          mapCobElemento[tipo]!.addAll(cobs);
          mapFrenteElemento[tipo]!.addAll(frentesPonto);
          mapCobLocal[local]!.addAll(cobs);
          mapFrenteLocal[local]!.addAll(frentesPonto);
        }
      }

      // Função auxiliar para gerar configuração do gráfico de Barras Flutuantes
      Map<String, dynamic> _buildEstatisticaConfig(
          List<String> labels,
          Map<String, List<double>> mapCob,
          Map<String, List<double>> mapFrente,
          ) {
            List<double> dataCob = [];
            List<double> dataFrente = [];

            Map<String, dynamic> errorBarsCob = {};
            Map<String, dynamic> errorBarsFrente = {};

            for (String label in labels) {
              // ================================================================
              // COBRIMENTO
              // ================================================================
              final cobList = mapCob[label] ?? [];
              if (cobList.isEmpty) {
                dataCob.add(0);
                errorBarsCob[label] = {
                  'plus': 0,
                  'minus': 0,
                };
              } else {
                final double media =
                    CarbonatacaoMath.mean(cobList);
                final double minimo =
                    cobList.reduce(min);
                final double maximo =
                    cobList.reduce(max);
                dataCob.add(media);
                errorBarsCob[label] = {
                  'plus': maximo - media,
                  'minus':-(media - minimo),
                };
              }
              // ================================================================
              // CARBONATAÇÃO
              // ================================================================
              final frenteList =
                  mapFrente[label] ?? [];
              if (frenteList.isEmpty) {
                dataFrente.add(0);
                errorBarsFrente[label] = {
                  'plus': 0,
                  'minus': 0,
                };
              } else {
                final double media =
                    CarbonatacaoMath.mean(frenteList);
                final double minimo =
                    frenteList.reduce(min);
                final double maximo =
                    frenteList.reduce(max);
                dataFrente.add(media);
                errorBarsFrente[label] = {
                  'plus': maximo - media,
                  'minus': -(media - minimo),
                };
              }
            }
            final double maxPlus = errorBarsFrente.values
                .map((e) => e['plus'] as double)
                .reduce(max);

            final double maxPlus2 = errorBarsCob.values
              .map((e) => e['plus'] as double)
              .reduce(max);
              

            final double maxP = max(maxPlus2,maxPlus);
            final double maxM = max(dataFrente.reduce(max),dataCob.reduce(max));

            final double maxY = (maxM + maxP)*1.1;
            
            // ================================================================
            // CONFIGURAÇÃO DO GRÁFICO
            // ================================================================
            return {
              // IMPORTANTE:
              // Mantemos bar porque queremos barras verticais
              'type': 'bar',
              'data': {
                'labels': labels,
                'datasets': [
                  // ============================================================
                  // CARBONATAÇÃO
                  // ============================================================
                  {
                    'label': 'Carbonatação (Média ± Extremos)',
                    'data': dataFrente,
                    'backgroundColor': 'rgba(117, 117, 117, 0.3)',
                    'borderColor': '#757575',
                    'borderWidth': 1,
                    'errorBars': errorBarsFrente,
                  },
                  // ============================================================
                  // COBRIMENTO
                  // ============================================================
                  {
                    'label': 'Cobrimento (Média ± Extremos)',
                    'data': dataCob,
                    'backgroundColor':'rgba(200, 150, 255, 0.20)',
                    'borderColor': '#C896FF',
                    'borderWidth': 1,
                    'errorBars': errorBarsCob,
                  },
                ],
              },
              // ================================================================
              // OPÇÕES
              // ================================================================
              'options': {
                'plugins': {
                  'legend': {
                    'position': 'bottom',
                    'labels': {
                      'font': {
                        'family': 'Lato',
                        'size': 12,
                      },
                      'usePointStyle': true,
                    },
                  },
                  'chartJsPluginErrorBars': {
                      'color': '#000000',
                      'width': 12,
                      'lineWidth': 2,
                      'absoluteValues': false,
                    },
                  },
                'scales': {
                  
                  "yAxes": [
                {
                  "stacked": false,
                  "scaleLabel": {
                    "display": true,
                    "labelString": "Profundidade (mm)",
                    "lineHeight": 1.2,
                    "fontColor": "#666666",
                    "fontFamily": "sans-serif",
                    "fontSize": 12,
                    "fontStyle": "normal",
                    "padding": 4
                  },
                  "ticks": {
                    "display": true,
                    "fontSize": 12,
                    "fontFamily": "sans-serif",
                    "fontColor": "#666666",
                    "fontStyle": "normal",
                    "padding": 0,
                    "min": 0,
                    "max": maxY,
                    "stepSize": null,
                    "minRotation": 0,
                    "maxRotation": 50,
                    "mirror": false,
                    "reverse": false
                  }
                  }]
                },
              },
            };
          }

      // =======================================================================
      // 📊 NOVO GRÁFICO 1: FRENTE MÁXIMA VS COBRIMENTO MÍNIMO POR ELEMENTO
      // =======================================================================
      Map<String, Map<String, dynamic>> mapElementoDados = {};

      for (var pDyn in pontosAtivos) {
        final p = pDyn as Map<String, dynamic>;
        final el = p['elementos_estruturais'] as Map<String, dynamic>? ?? {};

        String nomeEl = el['nome']?.toString() ?? 'Desconhecido';
        String tipoEl = el['tipo']?.toString() ?? '-';
        String localEl = el['local']?.toString() ?? '-';

        // Chave única para juntar os pontos do mesmo elemento
        String chave = '$nomeEl|$tipoEl|$localEl';

        if (!mapElementoDados.containsKey(chave)) {
          mapElementoDados[chave] = {
            'nome': nomeEl,
            'tipo': tipoEl,
            'local': localEl,
            'cobs': <double>[],
            'frentes': <double>[]
          };
        }

        final carbList = p['ponto_ensaio_carb'] as List<dynamic>? ?? [];
        if (carbList.isNotEmpty) {
          final carb = carbList.first as Map<String, dynamic>;
          
          if (carb['cob_arm_p'] != null) mapElementoDados[chave]!['cobs'].add((carb['cob_arm_p'] as num).toDouble());
          if (carb['cob_arm_s'] != null) mapElementoDados[chave]!['cobs'].add((carb['cob_arm_s'] as num).toDouble());

          final frList = carb['ponto_ensaio_carb_frentes'] as List<dynamic>? ?? [];
          for (var f in frList) {
            if (f['profundidade'] != null) mapElementoDados[chave]!['frentes'].add((f['profundidade'] as num).toDouble());
          }
        }
      }

      // 👇 NOVA LÓGICA DE AGRUPAMENTO VISUAL
      // 1. Agrupar os elementos por "local" para organizar o eixo X
      // =======================================================================
      Map<String, Map<String, dynamic>> mapElementoDadosGraf = {};

      for (var pDyn in pontosAtivos) {
        final p = pDyn as Map<String, dynamic>;
        final el = p['elementos_estruturais'] as Map<String, dynamic>? ?? {};

        // 1. CHAVE DE AGRUPAMENTO: Usando o ID real do elemento para não misturar dados
        String idEl = el['id']?.toString() ?? p['id'].toString();
        String nomeEl = el['nome']?.toString() ?? 'Desconhecido';
        String tipoEl = el['tipo']?.toString() ?? '-';
        String localEl = el['local']?.toString() ?? '-';

        if (!mapElementoDadosGraf.containsKey(idEl)) {
          mapElementoDadosGraf[idEl] = {
            'nome': nomeEl,
            'tipo': tipoEl,
            'local': localEl,
            'pontos_cob_critico': <double>[],
            'pontos_frente_media': <double>[]
          };
        }

        final carbList = p['ponto_ensaio_carb'] as List<dynamic>? ?? [];
        if (carbList.isNotEmpty) {
          final carb = carbList.first as Map<String, dynamic>;
          
          // A. Cálculo da Frente MÉDIA deste Ponto de Ensaio específico
          final frList = carb['ponto_ensaio_carb_frentes'] as List<dynamic>? ?? [];
          List<double> frentes = [];
          for (var f in frList) {
            if (f['profundidade'] != null) frentes.add((f['profundidade'] as num).toDouble());
          }
          double mediaFrentePonto = frentes.isEmpty ? 0.0 : CarbonatacaoMath.mean(frentes);
          mapElementoDadosGraf[idEl]!['pontos_frente_media'].add(mediaFrentePonto);

          // B. Cálculo do Cobrimento CRÍTICO deste Ponto de Ensaio específico
          double cobP = (carb['cob_arm_p'] as num?)?.toDouble() ?? 0.0;
          double cobS = (carb['cob_arm_s'] as num?)?.toDouble() ?? 0.0;
          double cobCriticoPonto = 0.0;
          if (cobP > 0 && cobS > 0) {
            cobCriticoPonto = min(cobP, cobS);
          } else {
            cobCriticoPonto = max(cobP, cobS);
          }
          if (cobCriticoPonto > 0) {
            mapElementoDadosGraf[idEl]!['pontos_cob_critico'].add(cobCriticoPonto);
          }
        }
      }

      // 2. AGRUPAMENTO VISUAL HIERÁRQUICO (Local -> Tipo)
      Map<String, List<Map<String, dynamic>>> agrupadoPorLocalETipo = {};
      for (var data in mapElementoDadosGraf.values) {
        String chaveGrupo = '${data['local']}|${data['tipo']}';
        agrupadoPorLocalETipo.putIfAbsent(chaveGrupo, () => []);
        agrupadoPorLocalETipo[chaveGrupo]!.add(data);
      }

      List<List<String>> labelsGraficoElementos = [];
      List<double> dadosMenorCobrimento = [];
      List<double> dadosMaiorFrente = [];

      for (var chaveGrupo in agrupadoPorLocalETipo.keys) {
        var elementos = agrupadoPorLocalETipo[chaveGrupo]!;
        
        // Ordena pelo nome do elemento para organizar alfabeticamente
        elementos.sort((a, b) => a['nome'].compareTo(b['nome']));

        // Pega o índice do meio para exibir o Tipo e o Local apenas 1 vez, bem centralizado!
        int middleIndex = elementos.length ~/ 2;

        for (int i = 0; i < elementos.length; i++) {
          var elData = elementos[i];

          List<double> cobs = elData['pontos_cob_critico'];
          List<double> frentes = elData['pontos_frente_media'];

          // Extração matemática (Maior Frente e Menor Cobrimento do Elemento)
          double menorCob = cobs.isEmpty ? 0.0 : cobs.reduce(min);
          double maiorFrente = frentes.isEmpty ? 0.0 : frentes.reduce(max);

          // Constroi a label do eixo X dinamicamente
          List<String> labelItem = [elData['nome']];
          if (i == middleIndex) {
            labelItem.add(elData['tipo']);
            labelItem.add(elData['local']);
          }

          labelsGraficoElementos.add(labelItem);
          
          // 👇 ALIMENTANDO COM DADOS POSITIVOS!
          dadosMenorCobrimento.add(menorCob); 
          dadosMaiorFrente.add(maiorFrente);
        }
      }

      // 3. GERAÇÃO DA IMAGEM NA API (QUICKCHART)
      String base64FrenteCobrimento = await _gerarGraficoQuickChart({
        'type': 'line',
        'data': {
          'labels': labelsGraficoElementos,
          'datasets': [
            {
              'label': 'Frente de Carbonatação',
              'data': dadosMaiorFrente, // Dados positivos
              'borderColor': '#757575',
              'backgroundColor': 'rgba(117, 117, 117, 0.3)',
              'borderWidth': 4,
              'pointRadius': 6,
              'fill': true,
            },
            {
              'label': 'Cobrimento',
              'data': dadosMenorCobrimento, // Dados positivos
              'borderColor': '#C896FF',
              'backgroundColor': 'rgba(200, 150, 255, 0.20)',
              'borderWidth': 4,
              'pointRadius': 6,
              'fill': true,
            }
          ]
        },
        'options': {
          'plugins': {
            'title': { 'display': false },
            'legend': { 'position': 'bottom', 'labels': { 'font': { 'family': 'Lato', 'size': 12 }, 'usePointStyle': true } },
          },
          'scales': {
            'x': {
              'offset': true,
              'ticks': { 'autoSkip': false, 'font': { 'family': 'Lato', 'size': 11 } },
              'grid': { 'display': false } // Grid invisível para visual clean
            },
            'y': {
              'title': { 'display': true, 'text': 'Profundidade (mm)' },
            }
          }
        }
      });
      
      

      
      // 5. Gráfico Locais
      List<String> labelsLocal = mapCobLocal.keys.where((k) => mapCobLocal[k]!.isNotEmpty || mapFrenteLocal[k]!.isNotEmpty).toList();
      String base64BoxplotLocal = await _gerarGraficoQuickChart(_buildEstatisticaConfig(labelsLocal, mapCobLocal, mapFrenteLocal),
        version: '2');

      pageGeral = pageGeral.replaceAll('<canvas id="chartFrenteCarbon" height="220"></canvas>', '<img src="$base64FrenteCob" style="width: 100%; max-height: 220px; object-fit: contain;">');
      pageGeral = pageGeral.replaceAll('<canvas id="chartRiscos" height="220"></canvas>', '<img src="$base64Riscos" style="width: 100%; max-height: 220px; object-fit: contain;">');
      //pageGeral = pageGeral.replaceAll('<canvas id="chartAvancoGeral" height="220"></canvas>', '<img src="$base64Avanco" style="width: 100%; max-height: 220px; object-fit: contain;">');
      pageGeral = pageGeral.replaceAll('<canvas id="chartProbGeral" height="220"></canvas>', '<img src="$base64Prob" style="width: 100%; max-height: 220px; object-fit: contain;">');
      pageGeral = pageGeral.replaceAll('<canvas id="chartBoxElementos" height="220"></canvas>', '<img src="$base64FrenteCobrimento" style="width: 100%; max-height: 220px; object-fit: contain;">');
      pageGeral = pageGeral.replaceAll('<canvas id="chartBoxLocal" height="220"></canvas>', '<img src="$base64BoxplotLocal" style="width: 100%; max-height: 220px; object-fit: contain;">');

      header = header.replaceAll('{{titulo_relatorio}}', 'Frente de Carbonatação'); 
      header = header.replaceAll('{{subtitulo_pagina}}', 'Análise Gráfica Geral');
      header = header.replaceAll('{{logo_url}}', await ReportAssets.imageBase64('assets/images/logo_diavicon.png'));
      
      htmlFinal += header + pageGeral + footer + ('\n<div style="page-break-after: always;"></div>\n');
    }

    // =======================================================================
    // 2. CONSTRUÇÃO PÁGINAS INDIVIDUAIS (POR PONTO DE ENSAIO)
    // =======================================================================
    if (config['incluir_resultados'] == true) {
      String pageIndTemplate = await rootBundle.loadString('assets/reports/carbonatacao/templates/ensaio_individual_template.html');
      String placeholderB64 = await ReportAssets.imageBase64('assets/images/project_placeholder1.png');
      String base64Logo = await ReportAssets.imageBase64('assets/images/logo_diavicon.png');
      
      // 1. Removemos a div inteira do gráfico de Probabilidade para limpar a tela
      pageIndTemplate = pageIndTemplate.replaceAll(RegExp(r'<div class="chart-box">\s*<div class="chart-title">Estimativa da Probabilidade.*?<\/div>\s*<canvas id="chartProb_.*?<\/canvas>\s*<\/div>', dotAll: true), '');

      // 2. O Loop Real (Itera CRIANDO UMA PÁGINA COMPLETA por ponto)
      for (var pDyn in pontosAtivos) {
        final p = pDyn as Map<String, dynamic>;
        final el = p['elementos_estruturais'] as Map<String, dynamic>? ?? {};
        final carbList = p['ponto_ensaio_carb'] as List<dynamic>? ?? [];
        final carb = carbList.isNotEmpty ? (carbList.first as Map<String, dynamic>) : {};
        final frentesList = carb['ponto_ensaio_carb_frentes'] as List<dynamic>? ?? [];
        final galeriaList = carb['galeria_ponto_ensaio_carb'] as List<dynamic>? ?? [];
        
        List<double> frentes = [];
        for (var f in frentesList) {
          if (f['profundidade'] != null) frentes.add((f['profundidade'] as num).toDouble());
        }

        // Cálculos individuais do Ponto
        double cobP = (carb['cob_arm_p'] as num?)?.toDouble() ?? 0.0;
        double cobS = (carb['cob_arm_s'] as num?)?.toDouble() ?? 0.0;
        double cobCritico = (cobP > 0 && cobS > 0) ? min(cobP, cobS) : max(cobP, cobS);
        if (cobCritico == 0) cobCritico = 1.0; 

        double media = CarbonatacaoMath.mean(frentes);
        double minFr = frentes.isEmpty ? 0.0 : frentes.reduce(min);
        double maxFr = frentes.isEmpty ? 0.0 : frentes.reduce(max);
        double dpFr = CarbonatacaoMath.stdDev(frentes);
        double cvFr = media == 0 ? 0.0 : (dpFr / media) * 100;

        double kMedia = media / sqrt(idade);
        double tempoTotal = kMedia > 0 ? pow(cobCritico / kMedia, 2).toDouble() : 999.0;
        
        // 📊 Geração do Gráfico (Avanço da Carbonatação)
        double tempoAnaliseG1 = max(idade * 2, tempoTotal * 2);
        List<Map<String, double>> dadosCobGrafico1 = [];
        List<Map<String, double>> dadosFrenteGrafico1 = [];
        
        for (double t = 0; t <= tempoAnaliseG1; t += (tempoAnaliseG1 / 30)) {
          dadosCobGrafico1.add({'x': t, 'y': cobCritico});
          dadosFrenteGrafico1.add({'x': t, 'y': sqrt(t) * kMedia});
        }
        double maxYG1 = max(dadosFrenteGrafico1.isNotEmpty ? dadosFrenteGrafico1.last['y']! : 0.0, cobCritico) * 1.2;

        String base64FrenteCobInd = await _gerarGraficoQuickChart({
          'type': 'line',
          'plugins': ['chartjs-plugin-annotation'],
          'data': {
            'datasets': [
              {'label': 'Cobrimento', 'data': dadosCobGrafico1, 'backgroundColor': 'rgba(200, 150, 255, 0.2)', 'borderColor': '#C896FF', 'borderWidth': 2, 'fill': true, 'pointRadius': 0},
              {'label': 'Carbonatação', 'data': dadosFrenteGrafico1, 'borderColor': '#616161', 'backgroundColor': 'rgba(120,120,120,0.20)', 'borderWidth': 3, 'fill': true, 'pointRadius': 0}
            ]
          },
          'options': {
            'plugins': {
              'title': { 'display': false },
              'legend': { 'position': 'bottom' },
              'annotation': { 'annotations': {
                  'lineIdade': { 'type': 'line', 'xMin': idade, 'xMax': idade, 'borderColor': 'orange', 'borderDash': [8, 6], 'borderWidth': 2, 'label': { 'content': 'Idade', 'display': true, 'position': 'start' } },
                  'lineFalha': { 'type': 'line', 'xMin': tempoTotal, 'xMax': tempoTotal, 'borderColor': 'red', 'borderDash': [8, 6], 'borderWidth': 2, 'label': { 'content': 'Falha', 'display': true, 'position': 'start' } }
              }}
            },
            'scales': { 'x': { 'type': 'linear', 'title': { 'display': true, 'text': 'Exposição (anos)' } }, 'y': { 'title': { 'display': true, 'text': 'Profundidade (mm)' }, 'min': 0, 'max': maxYG1 } }
          }
        });

        // Extraindo Fotos
        String fotoQuebra = '';
        String fotoFeno = '';
        for (var gal in galeriaList) {
          if (gal['referencia'] == '1') fotoQuebra = gal['imagem_url'] ?? '';
          if (gal['referencia'] == '2') fotoFeno = gal['imagem_url'] ?? '';
        }

        // Mapeamento dos Dados deste ponto específico
        Map<String, String> pontoMapeado = {
          'projeto': projResp?['nome']?.toString() ?? '-',
          'idade': idade.toString(),
          'caa': estResp?['caa']?.toString() ?? '-',
          'estrutura': estResp?['nome']?.toString() ?? '-',
          //'ambiente': 'Urbano', 
          'tipo':  el['local']?.toString() ?? '-',
          'ponto.id': p['id']?.toString() ?? '',
          'ponto.local': el['local']?.toString() ?? '-',
          'ponto.elemento': el['nome']?.toString() ?? '-',
          'revestimento': el['revestimento']?.toString() ?? '-',
          'ponto.planta_url': placeholderB64, 
          'ponto.cob_principal': carb['cob_arm_p']?.toString() ?? '-',
          'ponto.bitola_principal': carb['bit_arm_p']?.toString() ?? '-',
          'ponto.cob_secundaria': carb['cob_arm_s']?.toString() ?? '-', 
          'ponto.bitola_secundaria': carb['bit_arm_s']?.toString() ?? '-',
          'ponto.carb_max': maxFr.toStringAsFixed(1),
          'ponto.carb_media': media.toStringAsFixed(1),
          'ponto.carb_min': minFr.toStringAsFixed(1),
          'ponto.carb_cvar': cvFr.toStringAsFixed(1),
          'ponto.coef_carb': kMedia.toStringAsFixed(2),
          'ponto.risco': p['valor_resultado']?.toString() ?? '-',
          'ponto.img_avanco': base64FrenteCobInd.isNotEmpty ? '<img src="$base64FrenteCobInd" style="width: 100%; max-height: 200px; object-fit: contain;">' : '',
          'ponto.foto_quebra_url': fotoQuebra.isNotEmpty ? await _obterImagemBase64Redimensionada(fotoQuebra) : placeholderB64, 
          'ponto.foto_fenolftaleina_url': fotoFeno.isNotEmpty ? await _obterImagemBase64Redimensionada(fotoFeno) : placeholderB64,
        };

        // 3. Substitui os gráficos na cópia local do template do corpo
        String currentPageInd = pageIndTemplate.replaceAll(RegExp(r'<canvas id="chartAvanco_.*?<\/canvas>', dotAll: true), pontoMapeado['ponto.img_avanco']!);
        
        // Processa o template APENAS PARA ESTE PONTO (sem quebra de página interna)
        currentPageInd = _processarRepeat(currentPageInd, 'pontos_carbonatacao', [pontoMapeado]);

        // 4. Criação de uma cópia LOCAL do cabeçalho (Para não destruir as chaves {{}} globais)
        String currentHeader = header;
        currentHeader = currentHeader.replaceAll('{{titulo_relatorio}}', 'Frente de Carbonatação'); 
        currentHeader = currentHeader.replaceAll('{{subtitulo_pagina}}', 'Análise Individual - ${pontoMapeado['ponto.elemento']}');
        currentHeader = currentHeader.replaceAll('{{logo_url}}', base64Logo);
        
        // 5. Injeta TUDO no HTML Final, forçando a quebra de página APÓS O RODAPÉ deste ponto
        htmlFinal += currentHeader + currentPageInd + footer + '\n<div style="page-break-after: always;"></div>\n';
      }
    }


    if (config['incluir_graficos'] == true) {
      String pageTab = await rootBundle.loadString('assets/reports/carbonatacao/templates/tabela_geral_template.html');
      // =======================================================================
      // 📝 PREENCHIMENTO DA TABELA GERAL - MODO EXPLÍCITO (.replaceAll)
      // =======================================================================
      String linhasHtml = '';

      for (var pDyn in pontosAtivos) {
        final p = pDyn as Map<String, dynamic>;
        final el = p['elementos_estruturais'] as Map<String, dynamic>? ?? {};
        final carbList = p['ponto_ensaio_carb'] as List<dynamic>? ?? [];
        final carb = carbList.isNotEmpty ? (carbList.first as Map<String, dynamic>) : {};
        final frentesList = carb['ponto_ensaio_carb_frentes'] as List<dynamic>? ?? [];
        
        // 1. Cálculos
        List<double> frentes = [];
        for (var f in frentesList) {
          if (f['profundidade'] != null) frentes.add((f['profundidade'] as num).toDouble());
        }
        double mediaFr = frentes.isEmpty ? 0.0 : CarbonatacaoMath.mean(frentes);
        double kPonto = mediaFr / sqrt(idade);

        // 2. Extração de variáveis do banco
        String nome = el['nome']?.toString() ?? 'Desconhecido';
        String tipo = el['tipo']?.toString() ?? '-';
        String local = el['local']?.toString() ?? '-';
        String rev = el['revestimento']?.toString() ?? '-';
        
        String cobP = carb['cob_arm_p']?.toString() ?? '-';
        String bitP = carb['bit_arm_p']?.toString() ?? '-';
        String cobS = carb['cob_arm_s']?.toString() ?? '-';
        String bitS = carb['bit_arm_s']?.toString() ?? '-';
        String riscoCondicao = p['valor_resultado']?.toString() ?? 'Irrelevante';

        String bgColor = '#E0E0E0';
        String textColor = '#000000';

        switch (riscoCondicao) {
          case 'Despassivado':
            bgColor = '#FF4C4C';
            textColor = '#FFFFFF';
            break;
          case 'Risco Alto':
            bgColor = '#FF8C00';
            textColor = '#FFFFFF';
            break;
          case 'Risco Moderado':
            bgColor = '#FFB74D';
            textColor = '#000000';
            break;
          case 'Risco Baixo':
            bgColor = '#AED581';
            textColor = '#000000';
            break;
          case 'Irrelevante':
            bgColor = '#81C784';
            textColor = '#000000';
            break;
        }

        // Criando o elemento visual do Badge com HTML/CSS inline para o PDF
        String badgeHtml = '<span style="background-color: $bgColor; color: $textColor; padding: 4px 10px; border-radius: 12px; font-size: 10px; font-weight: bold; display: inline-block; text-align: center; white-space: nowrap;">$riscoCondicao</span>';

        // 3. Montando a linha HTML manualmente e acumulando
        linhasHtml += '''
        <tr>
          <td class="label-cell" style="text-align: left; line-height: 1.2;">
            $nome<br>
            <span style="font-size: 9px; color: #686868; font-weight: normal;">
              Tipo: $tipo | Local: $local<br>Rev: $rev
            </span>
          </td>
          <td>$cobP</td><td>$bitP</td>
          <td>$cobS</td><td>$bitS</td>
          <td>${mediaFr.toStringAsFixed(1)}</td><td>${kPonto.toStringAsFixed(2)}</td>
          <td class="condicao">$badgeHtml</td>
        </tr>
        ''';
      }

      // 4. Substituições literais no template HTML
      pageTab = pageTab.replaceAll('{{projeto}}', projResp?['nome']?.toString() ?? '-');
      pageTab = pageTab.replaceAll('{{exposicao}}', '$idade anos');
      pageTab = pageTab.replaceAll('{{caa}}', estResp?['caa']?.toString() ?? '-');
      pageTab = pageTab.replaceAll('{{estrutura}}', estResp?['nome']?.toString() ?? '-');
      pageTab = pageTab.replaceAll('{{ambiente}}', 'Urbano'); 
      pageTab = pageTab.replaceAll('{{tipo}}', tipoNome);
      pageTab = pageTab.replaceAll('{{idade}}', idade.toString());
      pageTab = pageTab.replaceAll('{{local}}', locais.isEmpty ? 'Todos' : locais.join(', '));
      
      // Injeta todas as linhas montadas de uma só vez!
      pageTab = pageTab.replaceAll('{{linhas_tabela}}', linhasHtml);

      // =======================================================================
      // FECHAMENTO E CABEÇALHO DA PÁGINA
      // =======================================================================
      String currentHeader = header;
      currentHeader = currentHeader.replaceAll('{{titulo_relatorio}}', 'Frente de Carbonatação'); 
      currentHeader = currentHeader.replaceAll('{{subtitulo_pagina}}', 'Análise Tabelada Geral');
      currentHeader = currentHeader.replaceAll('{{logo_url}}', await ReportAssets.imageBase64('assets/images/logo_diavicon.png'));

      htmlFinal += currentHeader + pageTab + footer + ('\n<div style="page-break-after: always;"></div>\n');
    } // <-- Fim do bloco if (config['incluir_resumo'] == true)

  // =======================================================================
    // 📷 CONSTRUÇÃO DA GALERIA DE FOTOS (POR PONTO DE ENSAIO)
    // =======================================================================
    if (config['incluir_galeria'] == true) { 
      String pageGaleriaTemplate = await rootBundle.loadString('assets/reports/carbonatacao/templates/galeria_ensaio_template.html');
      String base64Logo = await ReportAssets.imageBase64('assets/images/logo_diavicon.png');
      // 1. Busca as fotos separadamente
      List<String> idsPontos = pontosAtivos.map((p) => p['id'].toString()).toList();
      List<dynamic> fotosGaleria = [];

      if (idsPontos.isNotEmpty) {
        fotosGaleria = await _supabase
            .from('galeria_pontos_ensaios_geral')
            .select('imagem_url, legenda, ponto_ensaio_id')
            .inFilter('ponto_ensaio_id', idsPontos);
      }

      List<Map<String, String>> todasFotosMapeadas = [];

      for (var foto in fotosGaleria) {
        // 👇 SOLUÇÃO DO ERRO NULL SUBTYPE: Filtro seguro que não quebra se não encontrar o ponto
        final match = pontosAtivos.where((p) => p['id'] == foto['ponto_ensaio_id']);
        if (match.isEmpty) continue; // Se o ponto não existir, pula a foto silenciosamente
        
        final p = match.first as Map<String, dynamic>;
        final el = p['elementos_estruturais'] as Map<String, dynamic>? ?? {};

        String rawUrl = foto['imagem_url']?.toString() ?? '';
        if (rawUrl.isEmpty) continue;

        // Comprime a foto on-the-fly para o PDF não pesar
        String base64Img = await _obterImagemBase64Redimensionada(rawUrl);

        // Resgatando dados para montar a descrição rica
        String nomePonto = p['nome_ponto']?.toString() ?? 'S/N';
        String nomeEl = el['nome']?.toString() ?? '-';
        String tipoEl = el['tipo']?.toString() ?? '-';
        String localEl = el['local']?.toString() ?? '-';
        String legendaBase = foto['legenda']?.toString() ?? 'Registro fotográfico';

        // Mescla todas as informações na legenda permitindo quebra de linha (HTML)
        String legendaRica = '<b>Ponto $nomePonto</b> | $nomeEl ($tipoEl) - $localEl<br>$legendaBase';

        todasFotosMapeadas.add({
          'foto.url': base64Img,
          'foto.legenda': legendaRica,
        });
      }

      // 2. Divisão em páginas de 6 fotos (CHUNK) para respeitar o grid do template
      for (int i = 0; i < todasFotosMapeadas.length; i += 6) {
        int end = (i + 6 < todasFotosMapeadas.length) ? i + 6 : todasFotosMapeadas.length;
        List<Map<String, String>> chunkFotos = todasFotosMapeadas.sublist(i, end);

        String pageGaleria = pageGaleriaTemplate;

        // Cabeçalho da Página
        pageGaleria = pageGaleria.replaceAll('{{projeto}}', projResp?['nome']?.toString() ?? '-');
        pageGaleria = pageGaleria.replaceAll('{{exposicao}}', '$idade anos');
        pageGaleria = pageGaleria.replaceAll('{{caa}}', estResp?['caa']?.toString() ?? '-');
        pageGaleria = pageGaleria.replaceAll('{{estrutura}}', estResp?['nome']?.toString() ?? '-');
        pageGaleria = pageGaleria.replaceAll('{{idade}}', idade.toString());

        // Como as fotos estão misturadas, os campos do topo ficam genéricos
        pageGaleria = pageGaleria.replaceAll('{{utilizacao}}', utilNome);
        pageGaleria = pageGaleria.replaceAll('{{tipo}}', tipoNome);
        pageGaleria = pageGaleria.replaceAll('{{tipologiaEstrutural}}', tipoLogia);
        pageGaleria = pageGaleria.replaceAll('{{local}}', locais.isEmpty ? 'Todos' : locais.join(', '));
        pageGaleria = pageGaleria.replaceAll('{{elementos}}', tipos.isEmpty ? 'Todos' : tipos.join(', '));


        // Adiciona a logo
        pageGaleria = pageGaleria.replaceAll('{{logo_url}}', await ReportAssets.imageBase64('assets/images/logo_diavicon.png'));

        // Injeta o grupo de até 6 fotos no template
        pageGaleria = _processarRepeat(pageGaleria, 'fotos', chunkFotos);

        String currentHeader = header;
        currentHeader = currentHeader.replaceAll('{{titulo_relatorio}}', 'Frente de Carbonatação'); 
        currentHeader = currentHeader.replaceAll('{{subtitulo_pagina}}', 'Galeria');
        currentHeader = currentHeader.replaceAll('{{logo_url}}', base64Logo);

        htmlFinal += currentHeader + pageGaleria + '\n<div style="page-break-after: always;"></div>\n';
      }
    }
    

    htmlFinal += '</body></html>';
    return htmlFinal;
  }
}