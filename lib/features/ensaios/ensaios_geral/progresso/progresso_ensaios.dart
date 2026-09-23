import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/providers/auth_provider.dart';
import '../models/tipos_ensaio_ids.dart';

// Progresso dos ensaios — regra única usada em todas as barras do app
// (card e tela do projeto, card e tela da estrutura, tela de cada ensaio).
//
//  * Por TIPO de ensaio numa estrutura: ensaios realizados ÷ pontos
//    contratados (marcados) para a empresa do usuário. Realizado = ponto
//    com resultado (não "Pendente"). Passar da quantidade contratada conta
//    no máximo 100% — um tipo adiantado não compensa outro atrasado.
//  * ESTRUTURA: soma dos tipos, cada um pesando pela quantidade contratada.
//  * PROJETO: média ponderada das estruturas, com peso = pontos contratados
//    de cada estrutura (uma estrutura com 40 pontos pesa 4× uma com 10).
//
// Sem nenhum ponto contratado não há o que medir: a fração fica `null` e a
// tela mostra "Sem ensaios contratados" em vez de um 0% enganoso.

class ProgressoTipoEnsaio {
  final String tipoEnsaioId;
  final int contratados;
  final int realizados;
  const ProgressoTipoEnsaio({required this.tipoEnsaioId, required this.contratados, required this.realizados});

  /// Realizados que contam para a meta (no máximo o contratado).
  int get realizadosNaMeta => realizados < contratados ? realizados : contratados;

  double? get fracao => contratados == 0 ? null : realizadosNaMeta / contratados;
}

class ProgressoEstrutura {
  final String estruturaId;
  final Map<String, ProgressoTipoEnsaio> porTipo;
  const ProgressoEstrutura({required this.estruturaId, required this.porTipo});

  static const vazio = ProgressoEstrutura(estruturaId: '', porTipo: {});

  int get contratados => porTipo.values.fold(0, (s, t) => s + t.contratados);
  int get realizadosNaMeta => porTipo.values.fold(0, (s, t) => s + t.realizadosNaMeta);
  int get realizados => porTipo.values.fold(0, (s, t) => s + t.realizados);

  /// Tipos ponderados pela quantidade contratada.
  double? get fracao => contratados == 0 ? null : realizadosNaMeta / contratados;

  ProgressoTipoEnsaio tipo(String tipoEnsaioId) =>
      porTipo[tipoEnsaioId] ?? ProgressoTipoEnsaio(tipoEnsaioId: tipoEnsaioId, contratados: 0, realizados: 0);
}

class ProgressoProjeto {
  final Map<String, ProgressoEstrutura> porEstrutura;
  const ProgressoProjeto(this.porEstrutura);

  static const vazio = ProgressoProjeto({});

  ProgressoEstrutura estrutura(String estruturaId) => porEstrutura[estruturaId] ?? ProgressoEstrutura.vazio;

  int get contratados => porEstrutura.values.fold(0, (s, e) => s + e.contratados);

  /// Média ponderada das estruturas (peso = pontos contratados de cada uma).
  double? get fracao {
    var somaPesos = 0;
    var somaPonderada = 0.0;
    for (final e in porEstrutura.values) {
      final f = e.fracao;
      if (f == null) continue;
      somaPesos += e.contratados;
      somaPonderada += f * e.contratados;
    }
    return somaPesos == 0 ? null : somaPonderada / somaPesos;
  }

  /// Monta o progresso a partir das linhas do banco:
  /// [contratos] de `ensaios_contratados` (estrutura_id, tipo_ensaio_id,
  /// quantidade) e [pontos] de `pontos_ensaios_geral` (estrutura_id,
  /// tipo_ensaio_id, valor_resultado) — ambos já filtrados por projeto e
  /// pela empresa.
  factory ProgressoProjeto.calcular({
    required List<Map<String, dynamic>> contratos,
    required List<Map<String, dynamic>> pontos,
  }) {
    final contratados = <String, Map<String, int>>{};
    for (final c in contratos) {
      final e = c['estrutura_id']?.toString();
      final t = c['tipo_ensaio_id']?.toString();
      final q = (c['quantidade'] as num?)?.toInt() ?? 0;
      if (e == null || e.isEmpty || t == null || t.isEmpty || q <= 0) continue;
      final porTipo = contratados.putIfAbsent(e, () => {});
      porTipo[t] = (porTipo[t] ?? 0) + q;
    }

    final realizados = <String, Map<String, int>>{};
    for (final p in pontos) {
      final e = p['estrutura_id']?.toString();
      final t = p['tipo_ensaio_id']?.toString();
      if (e == null || e.isEmpty || t == null || t.isEmpty || !pontoRealizado(p['valor_resultado'], tipoEnsaioId: t, tipoEnsaio: p['tipo_ensaio'])) continue;
      final porTipo = realizados.putIfAbsent(e, () => {});
      porTipo[t] = (porTipo[t] ?? 0) + 1;
    }

    final estruturas = {...contratados.keys, ...realizados.keys};
    return ProgressoProjeto({
      for (final e in estruturas)
        e: ProgressoEstrutura(
          estruturaId: e,
          porTipo: {
            for (final t in {...?contratados[e]?.keys, ...?realizados[e]?.keys})
              t: ProgressoTipoEnsaio(
                tipoEnsaioId: t,
                contratados: contratados[e]?[t] ?? 0,
                realizados: realizados[e]?[t] ?? 0,
              ),
          },
        ),
    });
  }
}

/// Tipo "Inspeção Visual" (tipos_ensaio.id).
const kTipoEnsaioInspecaoVisualId = TipoEnsaioId.inspecaoVisual;

/// Ponto com resultado registrado (o app grava "Pendente" enquanto não há
/// leitura).
///
/// Inspeção visual não tem leitura única: cada inspeção criada é uma
/// unidade realizada (os registros ficam em ponto_inspecao_visual) e
/// valor_resultado fica sempre vazio. Sem esta exceção, a tag "Und.
/// realizadas" e as barras de progresso nunca contavam inspeções.
bool pontoRealizado(Object? valorResultado, {String? tipoEnsaioId, Object? tipoEnsaio}) {
  if (tipoEnsaioId == kTipoEnsaioInspecaoVisualId) return true;
  final nomeTipo = tipoEnsaio?.toString().toLowerCase() ?? '';
  if (nomeTipo.contains('inspeção visual') || nomeTipo.contains('inspecao visual')) return true;
  final v = valorResultado?.toString().trim() ?? '';
  return v.isNotEmpty && v.toLowerCase() != 'pendente';
}

/// Progresso de um projeto para a empresa do usuário logado.
///
/// Invalide (`ref.invalidate(progressoProjetoProvider(id))`) ao salvar ou
/// excluir pontos para as barras abertas se atualizarem.
final progressoProjetoProvider = FutureProvider.autoDispose.family<ProgressoProjeto, String>((ref, projetoId) async {
  final empresaId = ref.watch(currentUserProvider.select((u) => u?.empresaId));
  if (empresaId == null || empresaId.isEmpty || projetoId.isEmpty) return ProgressoProjeto.vazio;
  final supabase = Supabase.instance.client;

  final respostas = await Future.wait([
    supabase
        .from('ensaios_contratados')
        .select('estrutura_id, tipo_ensaio_id, quantidade')
        .eq('projeto_id', projetoId)
        .eq('empresa_id', empresaId),
    supabase
        .from('pontos_ensaios_geral')
        .select('estrutura_id, tipo_ensaio_id, tipo_ensaio, valor_resultado')
        .eq('projeto_id', projetoId)
        .eq('empresa_autora_id', empresaId),
  ]);

  return ProgressoProjeto.calcular(
    contratos: List<Map<String, dynamic>>.from(respostas[0] as List),
    pontos: List<Map<String, dynamic>>.from(respostas[1] as List),
  );
});

/// Texto padrão de uma fração: "45%" ou "—" sem contrato.
String textoProgresso(double? fracao) => fracao == null ? '—' : '${(fracao * 100).floor()}%';
