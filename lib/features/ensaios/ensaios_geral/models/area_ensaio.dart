/// Área de aplicação do ensaio — coluna `tipos_ensaio.area`
/// ('concreto' | 'metálica' | 'laboratório'). Separa, por exemplo, o
/// Líquido penetrante (estruturas metálicas) dos ensaios de concreto.
enum AreaEnsaio {
  concreto('Concreto'),
  metalica('Metálicas'),
  laboratorio('Laboratório');

  /// Rótulo da aba.
  final String rotulo;
  const AreaEnsaio(this.rotulo);

  /// Lê o valor do banco sem depender de maiúsculas, acentos ou plural
  /// ("Metálica", "metalica", "metálicas"...). Tipo sem área (nulo ou
  /// desconhecido) cai em Concreto — é onde estavam todos os ensaios antes
  /// da coluna existir, então nada some da lista.
  static AreaEnsaio deBanco(Object? valor) {
    final t = _semAcento(valor?.toString().trim().toLowerCase() ?? '');
    if (t.startsWith('metal')) return AreaEnsaio.metalica;
    if (t.startsWith('laborat')) return AreaEnsaio.laboratorio;
    return AreaEnsaio.concreto;
  }

  static String _semAcento(String s) => s
      .replaceAll(RegExp('[áàâã]'), 'a')
      .replaceAll(RegExp('[éê]'), 'e')
      .replaceAll(RegExp('[í]'), 'i')
      .replaceAll(RegExp('[óôõ]'), 'o')
      .replaceAll(RegExp('[ú]'), 'u')
      .replaceAll('ç', 'c');
}
