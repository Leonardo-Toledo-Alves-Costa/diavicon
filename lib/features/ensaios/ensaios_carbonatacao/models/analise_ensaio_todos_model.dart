class AnalisePontoEnsaioModel {
  final String id;
  final String nomePonto;
  final String tipoElemento;
  final String local;
  final List<double> cobrimentosPrin;
  final List<double> cobrimentosSec;
  final List<double> frentes;
  final double idade;

  AnalisePontoEnsaioModel({
    required this.id,
    required this.nomePonto,
    required this.tipoElemento,
    required this.local,
    required this.cobrimentosPrin,
    required this.cobrimentosSec,
    required this.frentes,
    required this.idade,
  });
}