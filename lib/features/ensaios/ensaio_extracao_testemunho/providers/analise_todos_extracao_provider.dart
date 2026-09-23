import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef AnaliseExtracaoParams = ({String projetoId, String estruturaId});

class PontoExtracaoResumoModel {
  final String pontoGeralId;
  final String ensaioNome;
  final String local;
  final String tipoElemento;
  final String elementoNome;
  final String nomeTestemunho;
  final double? resistenciaSemCorrecao;
  final double? resistenciaComCorrecao;

  const PontoExtracaoResumoModel({
    required this.pontoGeralId,
    required this.ensaioNome,
    required this.local,
    required this.tipoElemento,
    required this.elementoNome,
    required this.nomeTestemunho,
    required this.resistenciaSemCorrecao,
    required this.resistenciaComCorrecao,
  });
}

// Mesmo padrão das outras análises gerais — busca todos os testemunhos de
// todos os ensaios (locais) de Extração da estrutura, já achatados numa
// linha por testemunho (independente de qual ensaio/local ele pertence).
// Usa o `local` do ELEMENTO vinculado ao testemunho (texto livre já usado em
// todo o resto do app), não `estruturas_locais.local_id` do ensaio.
final analiseTodosExtracaoProvider =
    FutureProvider.family.autoDispose<List<PontoExtracaoResumoModel>, AnaliseExtracaoParams>((ref, params) async {
  final supabase = Supabase.instance.client;

  final resp = await supabase
      .from('pontos_ensaios_geral')
      .select('''
        id, nome_ponto,
        ponto_ensaio_extracao_local(
          id,
          ponto_ensaio_extracao_leituras(nome_testemunho, resistencia, resistencia_corrigida, elementos_estruturais(nome, tipo, local))
        )
      ''')
      .eq('projeto_id', params.projetoId)
      .eq('estrutura_id', params.estruturaId)
      .ilike('tipo_ensaio', '%testemunho%');

  final resultado = <PontoExtracaoResumoModel>[];
  for (final p in (resp as List)) {
    final locaisList = p['ponto_ensaio_extracao_local'] as List? ?? const [];
    if (locaisList.isEmpty) continue;
    final local = (locaisList.first as Map).cast<String, dynamic>();
    final leituras = local['ponto_ensaio_extracao_leituras'] as List? ?? const [];

    for (final l in leituras) {
      final leitura = (l as Map).cast<String, dynamic>();
      final elemento = leitura['elementos_estruturais'] as Map<String, dynamic>?;
      resultado.add(PontoExtracaoResumoModel(
        pontoGeralId: p['id'].toString(),
        ensaioNome: p['nome_ponto']?.toString() ?? 'Ensaio',
        local: elemento?['local']?.toString() ?? 'Desconhecido',
        tipoElemento: elemento?['tipo']?.toString() ?? 'Desconhecido',
        elementoNome: elemento?['nome']?.toString() ?? '',
        nomeTestemunho: leitura['nome_testemunho']?.toString() ?? '',
        resistenciaSemCorrecao: double.tryParse(leitura['resistencia']?.toString() ?? ''),
        resistenciaComCorrecao: double.tryParse(leitura['resistencia_corrigida']?.toString() ?? ''),
      ));
    }
  }

  return resultado;
});
