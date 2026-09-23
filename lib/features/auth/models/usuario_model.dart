class UsuarioModel {
  final String id;
  final String? nome;
  final String? sobrenome;
  final String? email;
  final String? celular;
  final String? cargo;
  final String? empresaId;
  final String? setorId;
  final bool? ativo;
  final String? tituloPrincipal;
  final String? escolaridade;
  final String? fotoUrl;
  final String? linkedin;
  final String? instagram;
  final DateTime? criadoEm;
  final bool? isAdminEmpresa;
  final bool? isAdmin;
  final bool? convitePendente;
  final String? enderecoId; // Adicionei o campo enderecoId
  final bool? podeVisualizarEmpresa;

  UsuarioModel({
    required this.id,
    this.nome,
    this.sobrenome,
    this.email,
    this.celular,
    this.cargo,
    this.empresaId,
    this.setorId,
    this.ativo,
    this.tituloPrincipal,
    this.escolaridade,
    this.fotoUrl,
    this.linkedin,
    this.instagram,
    this.criadoEm,
    this.isAdminEmpresa,
    this.isAdmin,
    this.convitePendente,
    this.enderecoId, // Inicializei o campo enderecoId
    this.podeVisualizarEmpresa,
  });

  factory UsuarioModel.fromMap(Map<String, dynamic> map) {
    return UsuarioModel(
      id: map['id'],
      nome: map['nome'],
      sobrenome: map['sobrenome'],
      email: map['email'],
      celular: map['celular'],
      cargo: map['cargo'],
      empresaId: map['empresa_id'],
      setorId: map['setor_id'],
      ativo: map['ativo'],
      tituloPrincipal: map['titulo_principal'],
      escolaridade: map['escolaridade'],
      fotoUrl: map['foto_url'],
      linkedin: map['linkedin'],
      instagram: map['instagram'],
      criadoEm: map['criado_em'] != null ? DateTime.parse(map['criado_em']) : null,
      isAdminEmpresa: map['is_admin_empresa'],
      isAdmin: map['is_admin'],
      convitePendente: map['convite_pendente'],
      enderecoId: map['endereco_id'],
      podeVisualizarEmpresa: map['pode_visualizar_empresa'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'sobrenome': sobrenome,
      // 'email' fica de fora: o banco não aceita mais UPDATE direto nessa
      // coluna (migração 20260921130000). E-mail muda pelo Supabase Auth.
      'celular': celular,
      'cargo': cargo,
      'setor_id': setorId,
      'titulo_principal': tituloPrincipal,
      'escolaridade': escolaridade,
      'foto_url': fotoUrl,
      'linkedin': linkedin,
      'instagram': instagram,
      'endereco_id': enderecoId, // Adicionei o campo enderecoId
    };
  }
}
