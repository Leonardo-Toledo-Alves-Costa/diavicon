import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ponto_resistividade_model.dart';

// --- MODELO DE DADOS DA ANÁLISE ---
class AnaliseResistividadeData {
  final String pontoNome;
  final String elementoNome;
  final String tipoElemento;
  final String local;
  final double media;
  final double maior;
  final double menor;
  final double coefVar;
  final bool isHomogeneo;
  final Map<String, dynamic> riscoCorrosao;
  final Map<String, dynamic> taxaCorrosao;
  final Map<String, dynamic> permissividade;
  final Map<String, List<PontoResistividadeLeituraModel>> leiturasAgrupadas;

  AnaliseResistividadeData({
    required this.pontoNome,
    required this.elementoNome,
    required this.tipoElemento,
    required this.local,
    required this.media,
    required this.maior,
    required this.menor,
    required this.coefVar,
    required this.isHomogeneo,
    required this.riscoCorrosao,
    required this.taxaCorrosao,
    required this.permissividade,
    required this.leiturasAgrupadas,
  });
}

// --- PROVIDER DA ANÁLISE ---
final analiseResistividadeProvider = FutureProvider.family<AnaliseResistividadeData, String>((ref, pontoGeralId) async {
  final supabase = Supabase.instance.client;

  // 1. Busca os dados gerais do ponto
  final geralResp = await supabase.from('pontos_ensaios_geral').select('''
    nome_ponto,
    elementos_estruturais (nome, tipo, local)
  ''').eq('id', pontoGeralId).single();

  final elemento = geralResp['elementos_estruturais'] ?? {};

  // 2. Busca as leituras
  final leiturasResp = await supabase
      .from('ponto_ensaio_resistividade_leitura')
      .select('*')
      .eq('id_ponto_geral', pontoGeralId)
      .order('criado_em', ascending: true);

  List<PontoResistividadeLeituraModel> leituras = (leiturasResp as List).map((l) {
    final Map<String, dynamic> mutableL = Map.from(l);
    // Correção 1: Trata o '00:00:00' do banco para '00:00'
    if (mutableL['hora'] != null && mutableL['hora'].toString().length >= 5) {
      mutableL['hora'] = mutableL['hora'].toString().substring(0, 5);
    }
    return PontoResistividadeLeituraModel.fromJson(mutableL);
  }).toList();

  // 3. Agrupa por Ponto (Ex: Ponto 1, Ponto 2)
  Map<String, List<PontoResistividadeLeituraModel>> agrupadas = {};
  for (var l in leituras) {
    final nome = l.nomeLeitura ?? 'Ponto 1';
    agrupadas.putIfAbsent(nome, () => []).add(l);
  }

  // 4. Lógica: Coleta apenas a ÚLTIMA leitura estabilizada de cada ponto
  List<double> ultimasLeituras = [];
  
  DateTime parseTime(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return DateTime(2000, 1, 1);
    return DateTime(2000, 1, 1, int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
  }

  for (var entry in agrupadas.entries) {
    var lista = entry.value;
    lista.sort((a, b) => parseTime(a.hora).compareTo(parseTime(b.hora)));
    if (lista.isNotEmpty) {
      ultimasLeituras.add(lista.last.resistividade);
    }
  }

  // 5. Cálculos Estatísticos (Baseado nas últimas leituras)
  double media = 0;
  double maior = 0;
  double menor = 0;
  double coefVar = 0;
  bool isHomogeneo = true;

  if (ultimasLeituras.isNotEmpty) {
    maior = ultimasLeituras.reduce(max);
    menor = ultimasLeituras.reduce(min);
    media = ultimasLeituras.reduce((a, b) => a + b) / ultimasLeituras.length;

    if (ultimasLeituras.length > 1 && media > 0) {
      double variance = ultimasLeituras.map((e) => pow(e - media, 2)).reduce((a, b) => a + b) / ultimasLeituras.length;
      coefVar = (sqrt(variance) / media) * 100;
    }
    isHomogeneo = coefVar <= 15.0;
  }

  // 6. Condicionais de Risco Genéricas (Podem ser ajustadas conforme a norma)
  Map<String, dynamic> avaliarRiscoCorrosao(double m) {
    if (m <= 0) return {'texto': '-', 'corTxt': Colors.grey.shade500, 'corFundo': Colors.grey.shade200};
    if (m <= 15) return {'texto': 'Muito Alto', 'corTxt': const Color(0xFFD32F2F), 'corFundo': const Color(0xFFFFEBEE)};
    if (m <= 20) return {'texto': 'Alto', 'corTxt': const Color(0xFFF57C00), 'corFundo': const Color(0xFFFFF3E0)};
    if (m <= 55) return {'texto': 'Moderado', 'corTxt': const Color(0xFFFBC02D), 'corFundo': const Color(0xFFFFFDE7)};
    if (m <= 80) return {'texto': 'Baixo', 'corTxt': const Color(0xFF388E3C), 'corFundo': const Color(0xFFFFFDE7)};
    return {'texto': 'Desprezível', 'corTxt': const Color(0xFF388E3C), 'corFundo': const Color(0xFFE8F5E9)};
  }

  Map<String, dynamic> avaliarTaxa(double m) {
    if (m <= 0) return {'texto': '-', 'corTxt': Colors.grey.shade500, 'corFundo': Colors.grey.shade200};
    if (m <= 5) return {'texto': 'Muito Alto', 'corTxt': const Color(0xFFD32F2F), 'corFundo': const Color(0xFFFFEBEE)};
    if (m <= 10) return {'texto': 'Alto', 'corTxt': const Color(0xFFF57C00), 'corFundo': const Color(0xFFFFF3E0)};
    if (m <= 20) return {'texto': 'Moderado', 'corTxt': const Color(0xFFFBC02D), 'corFundo': const Color(0xFFFFFDE7)};
    return {'texto': 'Baixo', 'corTxt': const Color(0xFF388E3C), 'corFundo': const Color(0xFFE8F5E9)};
  }

  Map<String, dynamic> avaliarPremissividade(double m) {
    if (m <= 0) return {'texto': '-', 'corTxt': Colors.grey.shade500, 'corFundo': Colors.grey.shade200};
    if (m <= 12) return {'texto': 'Muito Alto', 'corTxt': const Color(0xFFD32F2F), 'corFundo': const Color(0xFFFFEBEE)};
    if (m <= 21) return {'texto': 'Alto', 'corTxt': const Color(0xFFF57C00), 'corFundo': const Color(0xFFFFF3E0)};
    if (m <= 37) return {'texto': 'Moderado', 'corTxt': const Color(0xFFFBC02D), 'corFundo': const Color(0xFFFFFDE7)};
    if (m <= 254) return {'texto': 'Baixo', 'corTxt': const Color(0xFF388E3C), 'corFundo': const Color(0xFFFFFDE7)};
    return {'texto': 'Desprezível', 'corTxt': const Color(0xFF388E3C), 'corFundo': const Color(0xFFE8F5E9)};
  }

  return AnaliseResistividadeData(
    pontoNome: geralResp['nome_ponto'] ?? 'Desconhecido',
    elementoNome: elemento['nome'] ?? '-',
    tipoElemento: elemento['tipo'] ?? '-',
    local: elemento['local'] ?? '-',
    media: media,
    maior: maior,
    menor: menor,
    coefVar: coefVar,
    isHomogeneo: isHomogeneo,
    riscoCorrosao: avaliarRiscoCorrosao(media),
    taxaCorrosao: avaliarTaxa(media), // Usa a mesma condicional inicial (Pode alterar futuramente)
    permissividade: avaliarPremissividade(media), // Usa a mesma condicional inicial
    leiturasAgrupadas: agrupadas,
  );
});