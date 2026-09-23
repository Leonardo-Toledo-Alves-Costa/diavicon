import 'dart:math';
import '../utils/classificacao_resistividade.dart';

class AnaliseResistividadePonto {
  final String id;
  final String local;
  final String tipoElemento;
  final String nomeElemento;
  final List<double> leituras; // Guardará apenas as leituras da maior hora

  AnaliseResistividadePonto({
    required this.id,
    required this.local,
    required this.tipoElemento,
    required this.nomeElemento,
    required this.leituras,
  });

  factory AnaliseResistividadePonto.fromMap(Map<String, dynamic> map) {
    List<double> ultimasLeituras = [];
    
    final leiturasBrutas = map['leituras'];
    
    if (leiturasBrutas != null && leiturasBrutas is List && leiturasBrutas.isNotEmpty) {
      List<Map<String, dynamic>> leiturasProcessadas = [];
      String maiorHora = '00:00:00'; // Inicializamos com a menor hora possível
      
      // 1. Extrai todas as leituras válidas e descobre qual é a maior hora
      for (var item in leiturasBrutas) {
        if (item['resistividade'] != null) {
          double valor = double.tryParse(item['resistividade'].toString()) ?? 0.0;
          if (valor > 0) {
            String horaLeitura = item['hora']?.toString() ?? '00:00:00'; //[cite: 4]
            
            leiturasProcessadas.add({
              'valor': valor,
              'hora': horaLeitura,
            });

            // Compara as strings (ex: '14:30:00' > '10:15:00') para achar a mais recente
            if (horaLeitura.compareTo(maiorHora) > 0) {
              maiorHora = horaLeitura;
            }
          }
        }
      }

      // 2. Filtra a lista mantendo APENAS as leituras que possuem a maior hora encontrada
      if (leiturasProcessadas.isNotEmpty) {
        for (var l in leiturasProcessadas) {
          if (l['hora'] == maiorHora) {
            ultimasLeituras.add(l['valor']);
          }
        }
      }
    }

    // Se o ponto não tiver leituras ou falhar o parse, garante um fallback seguro
    if (ultimasLeituras.isEmpty) {
      ultimasLeituras = [0.0];
    }

    // 3. Identificação do Elemento e do Local
    final elemento = map['elementos_estruturais']; //[cite: 4]
    String nomeLocal = 'Sem Local';
    String tipoElem = 'Desconhecido';
    
    if (elemento != null) {
      tipoElem = elemento['tipo'] ?? 'Desconhecido';
      
      if (elemento['estruturas_locais'] != null && elemento['estruturas_locais']['nome'] != null) {
        nomeLocal = elemento['estruturas_locais']['nome'];
      } else if (elemento['local'] != null && elemento['local'].toString().trim().isNotEmpty) {
        nomeLocal = elemento['local'];
      }
    }

    return AnaliseResistividadePonto(
      id: map['id'] ?? '',
      local: nomeLocal,
      tipoElemento: tipoElem,
      nomeElemento: map['nome_ponto'] ?? 'Ponto Sem Nome', //[cite: 4]
      leituras: ultimasLeituras, // Passamos a lista já filtrada
    );
  }

  // Cálculos Estatísticos baseados apenas na última sessão
  double get media {
    if (leituras.isEmpty) return 0;
    return leituras.reduce((a, b) => a + b) / leituras.length;
  }

  double get desvioPadrao {
    if (leituras.length <= 1) return 0;
    double m = media;
    double variance = leituras.map((x) => pow(x - m, 2)).reduce((a, b) => a + b) / leituras.length;
    return sqrt(variance);
  }

  double get coeficienteVariacao {
    double m = media;
    if (m == 0) return 0;
    return (desvioPadrao / m) * 100;
  }

  // Delegam para a fonte unica (ver ClassificacaoResistividade).
  String get riscoCorrosao => ClassificacaoResistividade.risco.classificar(media)?.texto ?? '-';

  String get taxaCorrosao => ClassificacaoResistividade.taxa.classificar(media)?.texto ?? '-';

  String get permissividade => ClassificacaoResistividade.permissividade.classificar(media)?.texto ?? '-';
}