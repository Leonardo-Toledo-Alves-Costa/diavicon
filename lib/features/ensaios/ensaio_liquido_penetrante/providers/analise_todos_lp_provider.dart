import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/liquido_penetrante_model.dart';

typedef AnaliseLPParams = ({String projetoId, String estruturaId});

/// Um elemento ensaiado com Líquido penetrante e a contagem dos seus pontos.
class ElementoLPResumo {
  final String pontoGeralId;
  final String nomeEnsaio;
  final String nomeElemento;
  final String tipoElemento;
  final String local;
  final ContagemStatusLP contagem;

  const ElementoLPResumo({
    required this.pontoGeralId,
    required this.nomeEnsaio,
    required this.nomeElemento,
    required this.tipoElemento,
    required this.local,
    required this.contagem,
  });
}

// Mesmo recorte das demais análises gerais (projeto + estrutura, via o
// elemento). O ensaio é identificado pelo texto de `tipo_ensaio` — que o
// repositório sempre grava — como nas outras análises.
final analiseTodosLPProvider =
    FutureProvider.family.autoDispose<List<ElementoLPResumo>, AnaliseLPParams>((ref, params) async {
  final resp = await Supabase.instance.client
      .from('pontos_ensaios_geral')
      .select('''
        id, nome_ponto,
        elementos_estruturais!inner(nome, tipo, local, estrutura_id),
        ponto_ensaio_liquido_penetrante(status)
      ''')
      .eq('projeto_id', params.projetoId)
      .eq('elementos_estruturais.estrutura_id', params.estruturaId)
      .ilike('tipo_ensaio', '%penetrante%');

  final lista = <ElementoLPResumo>[];
  for (final p in (resp as List)) {
    final el = p['elementos_estruturais'] as Map<String, dynamic>?;
    final pontos = p['ponto_ensaio_liquido_penetrante'] as List? ?? const [];
    lista.add(ElementoLPResumo(
      pontoGeralId: p['id'].toString(),
      nomeEnsaio: p['nome_ponto']?.toString() ?? '',
      nomeElemento: el?['nome']?.toString() ?? '',
      tipoElemento: el?['tipo']?.toString() ?? 'Desconhecido',
      local: el?['local']?.toString() ?? 'Desconhecido',
      contagem: ContagemStatusLP.de(pontos.map((x) => StatusLP.fromChave((x as Map)['status']?.toString()))),
    ));
  }
  lista.sort((a, b) => a.nomeElemento.compareTo(b.nomeElemento));
  return lista;
}, retry: (_, _) => null);
