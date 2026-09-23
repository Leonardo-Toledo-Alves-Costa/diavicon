import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/planos_model.dart';
import 'empresa_plano_atual_provider.dart';

/// Uso de armazenamento da empresa, em MB, por categoria.
///
/// Fonte principal: RPC `uso_armazenamento_empresa` (migration
/// 20260921100000_cota_armazenamento.sql). Ela soma o tamanho REAL de cada
/// arquivo no Storage enviado por usuários da empresa (PDF = relatório, resto
/// = foto) e estima os dados em 2 KB por projeto/estrutura/elemento/ponto. É a
/// mesma conta que o servidor usa para bloquear criações quando o plano enche.
///
/// Se a RPC ainda não existir no banco, cai na estimativa antiga (contagem de
/// linhas × tamanho médio), calculada aqui no app.
class ArmazenamentoUso {
  final double dadosMb;
  final double fotosMb;
  final double relatoriosMb;
  final int limiteMb;

  ArmazenamentoUso({
    required this.dadosMb,
    required this.fotosMb,
    required this.relatoriosMb,
    required this.limiteMb,
  });

  double get totalMb => dadosMb + fotosMb + relatoriosMb;
  double get percentualUsado => limiteMb <= 0 ? 0 : (totalMb / limiteMb).clamp(0, 1);
}

const double _kbPorLinhaDados = 2;
const double _kbPorFoto = 800;
const double _kbPorRelatorio = 500;

final armazenamentoUsoProvider = FutureProvider.autoDispose<ArmazenamentoUso>((ref) async {
  final supabase = Supabase.instance.client;
  // Assinado antes de qualquer await (regra do Riverpod para `ref.watch`).
  final planoFuture = ref.watch(empresaPlanoAtualProvider.future);

  try {
    final rows = await supabase.rpc('uso_armazenamento_empresa');
    if (rows is List && rows.isNotEmpty) {
      final r = Map<String, dynamic>.from(rows.first as Map);
      double mb(String k) => (r[k] as num?)?.toDouble() ?? 0;
      return ArmazenamentoUso(
        dadosMb: mb('dados_mb'),
        fotosMb: mb('fotos_mb'),
        relatoriosMb: mb('relatorios_mb'),
        limiteMb: (r['limite_mb'] as num?)?.toInt() ?? 0,
      );
    }
  } catch (_) {
    // RPC ainda não aplicada: segue para a estimativa abaixo.
  }

  return _estimativaLocal(planoFuture);
});

/// Estimativa antiga, usada só se a RPC não estiver disponível.
Future<ArmazenamentoUso> _estimativaLocal(Future<PlanosModel> planoFuture) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  final plano = await planoFuture;

  if (userId == null) {
    return ArmazenamentoUso(dadosMb: 0, fotosMb: 0, relatoriosMb: 0, limiteMb: plano.armazenamentoMb);
  }

  final usuarioResp = await supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
  final empresaId = usuarioResp?['empresa_id'] as String?;
  if (empresaId == null) {
    return ArmazenamentoUso(dadosMb: 0, fotosMb: 0, relatoriosMb: 0, limiteMb: plano.armazenamentoMb);
  }

  Future<int> contar(String tabela, String coluna, dynamic valor) async {
    final res = await supabase.from(tabela).select('id').eq(coluna, valor).count(CountOption.exact);
    return res.count;
  }

  // Estruturas que a empresa gerencia ou possui — base pra achar elementos e
  // pontos de ensaio que pertencem a ela.
  final estruturasResp = await supabase
      .from('estruturas')
      .select('id')
      .or('empresa_gestora_id.eq.$empresaId,proprietaria_id.eq.$empresaId');
  final estruturaIds = (estruturasResp as List).map((e) => e['id'] as String).toList();

  int elementosCount = 0;
  int elementosFotosCount = 0;
  int pontosEnsaioCount = 0;
  int galeriaGeralCount = 0;

  if (estruturaIds.isNotEmpty) {
    final elementosResp = await supabase.from('elementos_estruturais').select('id, fotos').inFilter('estrutura_id', estruturaIds);
    elementosCount = (elementosResp as List).length;
    for (final e in elementosResp) {
      final fotos = e['fotos'];
      if (fotos is List) elementosFotosCount += fotos.length;
    }

    final pontosResp = await supabase.from('pontos_ensaios_geral').select('id').inFilter('estrutura_id', estruturaIds).count(CountOption.exact);
    pontosEnsaioCount = pontosResp.count;

    final pontosIdsResp = await supabase.from('pontos_ensaios_geral').select('id').inFilter('estrutura_id', estruturaIds);
    final pontosIds = (pontosIdsResp as List).map((p) => p['id'] as String).toList();
    if (pontosIds.isNotEmpty) {
      final galeriaResp = await supabase.from('galeria_pontos_ensaios_geral').select('id').inFilter('ponto_ensaio_id', pontosIds).count(CountOption.exact);
      galeriaGeralCount = galeriaResp.count;
    }
  }

  final projetosResp = await supabase
      .from('projetos')
      .select('id')
      .or('empresa_gestora_id.eq.$empresaId,empresa_cliente_id.eq.$empresaId');
  final projetoIds = (projetosResp as List).map((p) => p['id'] as String).toList();

  int relatoriosCount = 0;
  if (projetoIds.isNotEmpty) {
    final relResp = await supabase.from('relatorio_ensaio').select('id').inFilter('projeto_id', projetoIds).count(CountOption.exact);
    relatoriosCount = relResp.count;
  }

  final feedFotosCount = await contar('feed_fotos', 'usuario_id', userId).catchError((_) => 0);
  final servicosGaleriaResp = await supabase.from('empresa_servicos_galeria').select('id, empresa_servicos!inner(empresa_id)').eq('empresa_servicos.empresa_id', empresaId);
  final servicosGaleriaCount = (servicosGaleriaResp as List).length;

  final linhasDados = estruturaIds.length + elementosCount + pontosEnsaioCount + projetoIds.length;
  final totalFotos = elementosFotosCount + galeriaGeralCount + feedFotosCount + servicosGaleriaCount;

  return ArmazenamentoUso(
    dadosMb: (linhasDados * _kbPorLinhaDados) / 1024,
    fotosMb: (totalFotos * _kbPorFoto) / 1024,
    relatoriosMb: (relatoriosCount * _kbPorRelatorio) / 1024,
    limiteMb: plano.armazenamentoMb,
  );
}

/// Checa se a empresa ainda tem espaço no plano antes de uma nova criação
/// (post do feed, serviço, etc.) que vá adicionar aproximadamente
/// [tamanhoEstimadoMb] de armazenamento.
Future<bool> podeAdicionarArquivo(WidgetRef ref, {double tamanhoEstimadoMb = 1}) async {
  final uso = await ref.read(armazenamentoUsoProvider.future);
  // Limite 0 = plano sem limite definido: não bloqueia (igual ao servidor).
  if (uso.limiteMb <= 0) return true;
  // O servidor recusa quando o uso já atingiu o limite; aqui, igual, e também
  // quando a nova criação passaria do limite.
  return (uso.totalMb + tamanhoEstimadoMb) < uso.limiteMb;
}
