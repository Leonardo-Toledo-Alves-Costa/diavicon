import '../models/leitura_prova_carga_model.dart';
import '../models/ponto_medicao_model.dart';

/// Estatísticas de um único ponto de medição, usadas na aba "Gráficos" da
/// análise (cards) e na aba "Estatística" (ranking entre pontos).
class EstatisticasPontoMedicao {
  final PontoMedicaoModel ponto;
  final int cargaMaxima;
  final Duration? duracaoEnsaio;
  final int deslocamentoMaximo;
  final int? deslocamentoResidual;
  final bool excedeuDeformacaoMaxima;

  EstatisticasPontoMedicao({
    required this.ponto,
    required this.cargaMaxima,
    required this.duracaoEnsaio,
    required this.deslocamentoMaximo,
    required this.deslocamentoResidual,
    required this.excedeuDeformacaoMaxima,
  });
}

DateTime _parseHorario(String horario) {
  final partes = horario.split(':');
  if (partes.length < 2) return DateTime(2000, 1, 1);
  return DateTime(2000, 1, 1, int.tryParse(partes[0]) ?? 0, int.tryParse(partes[1]) ?? 0);
}

/// Calcula as estatísticas de um ponto de medição a partir das suas
/// leituras. O "residual" segue a definição pedida: deslocamento máximo do
/// carregamento menos o deslocamento da última leitura do descarregamento
/// (o que sobra depois de a carga ser totalmente retirada).
EstatisticasPontoMedicao calcularEstatisticasPonto(PontoMedicaoModel ponto, List<LeituraProvaCargaModel> leituras) {
  final leiturasDoPonto = leituras.where((l) => l.pontoMedicaoNome == ponto.nome).toList();

  final leiturasCarregamento = leiturasDoPonto.where((l) => l.etapa == 'Carregamento').toList()
    ..sort((a, b) => a.carregamento.compareTo(b.carregamento));
  final leiturasDescarregamento = leiturasDoPonto.where((l) => l.etapa == 'Descarregamento').toList()
    ..sort((a, b) => b.carregamento.compareTo(a.carregamento));

  final cargaMaxima = leiturasDoPonto.isEmpty ? 0 : leiturasDoPonto.map((l) => l.carregamento).reduce((a, b) => a > b ? a : b);
  final deslocamentoMaximo = leiturasDoPonto.isEmpty ? 0 : leiturasDoPonto.map((l) => l.deslocamento).reduce((a, b) => a > b ? a : b);

  int? residual;
  if (leiturasCarregamento.isNotEmpty && leiturasDescarregamento.isNotEmpty) {
    final maxCarregamento = leiturasCarregamento.map((l) => l.deslocamento).reduce((a, b) => a > b ? a : b);
    final deslocFinalDescarregamento = leiturasDescarregamento.last.deslocamento; // menor carga = fim do descarregamento
    residual = maxCarregamento - deslocFinalDescarregamento;
  }

  Duration? duracao;
  if (leiturasDoPonto.length >= 2) {
    final horarios = leiturasDoPonto.map((l) => _parseHorario(l.horario)).toList()..sort();
    duracao = horarios.last.difference(horarios.first);
  }

  return EstatisticasPontoMedicao(
    ponto: ponto,
    cargaMaxima: cargaMaxima,
    duracaoEnsaio: duracao,
    deslocamentoMaximo: deslocamentoMaximo,
    deslocamentoResidual: residual,
    excedeuDeformacaoMaxima: ponto.deslocMax != null && deslocamentoMaximo > ponto.deslocMax!,
  );
}

String formatarDuracao(Duration? d) {
  if (d == null) return '-';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${m}min';
  return '${h}h${m.toString().padLeft(2, '0')}min';
}
