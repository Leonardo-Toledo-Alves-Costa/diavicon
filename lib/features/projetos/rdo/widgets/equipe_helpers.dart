/// Helpers para cruzar os nomes salvos em `RdoRealizadoModel.equipe` (uma
/// lista de texto — ver o schema de `rdo_realizado`) com os dados reais da
/// equipe do projeto (foto, cargo), vindos de `colaboradoresProjetoVisiveisProvider`.
/// O cruzamento é por nome porque é essa a identidade que o RDO guarda; um
/// nome duplicado na equipe do projeto é uma limitação conhecida desse
/// desenho, não deste helper.
Map<String, Map<String, dynamic>> mapaEquipePorNome(List<Map<String, dynamic>> membros) {
  final mapa = <String, Map<String, dynamic>>{};
  for (final membro in membros) {
    final usuario = membro['usuario'] as Map<String, dynamic>?;
    final nome = '${usuario?['nome'] ?? ''} ${usuario?['sobrenome'] ?? ''}'.trim();
    if (nome.isNotEmpty) mapa[nome] = membro;
  }
  return mapa;
}

String? fotoDoMembro(Map<String, dynamic>? membro) {
  final usuario = membro?['usuario'] as Map<String, dynamic>?;
  final foto = usuario?['foto_url']?.toString();
  return (foto == null || foto.isEmpty) ? null : foto;
}

String cargoDoMembro(Map<String, dynamic>? membro) {
  final usuario = membro?['usuario'] as Map<String, dynamic>?;
  return usuario?['cargo']?.toString() ?? '';
}
