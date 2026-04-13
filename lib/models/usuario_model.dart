class UsuarioModel {
  final String id;
  final String? nome;
  final String? sobrenome;
  final String? email;
  final String? celular;
  final String? endereco;
  final String? cidade;
  final String? estado;
  final String? pais;
  final String? tituloPrincipal;
  final String? escolaridade;
  final String? foto;
  final String? linkedin;
  final String? instagram;
  final String? tipoConta;
  final String? cargo;
  final bool? criador;
  final bool? ativo;
  final bool? permissoes; 
  final String? empresaId;
  final DateTime? criadoEm;

  UsuarioModel({
    required this.id,
    this.nome,
    this.sobrenome,
    this.email,
    this.celular,
    this.endereco,
    this.cidade,
    this.estado,
    this.pais,
    this.tituloPrincipal,
    this.escolaridade,
    this.foto,
    this.linkedin,
    this.instagram,
    this.tipoConta,
    this.cargo,
    this.criador,
    this.ativo,
    this.permissoes,
    this.empresaId,
    this.criadoEm,
  });

  factory UsuarioModel.fromMap(Map<String, dynamic> map) {
    return UsuarioModel(
      id: map['id'],
      nome: map['nome'],
      sobrenome: map['sobrenome'],
      email: map['email'],
      celular: map['celular'],
      endereco: map['endereco'],
      cidade: map['cidade'],
      estado: map['estado'],
      pais: map['pais'],
      tituloPrincipal: map['titulo_principal'],
      escolaridade: map['escolaridade'],
      foto: map['foto'],
      linkedin: map['linkedin'],
      instagram: map['instagram'],
      tipoConta: map['tipo_conta'],
      cargo: map['cargo'],
      criador: map['criador'],
      ativo: map['ativo'],
      permissoes: map['permissoes'],
      empresaId: map['empresa_id'],
      criadoEm: map['criado_em'] != null ? DateTime.parse(map['criado_em']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'sobrenome': sobrenome,
      'email': email,
      'celular': celular,
      'endereco': endereco,
      'cidade': cidade,
      'estado': estado,
      'pais': pais,
      'titulo_principal': tituloPrincipal,
      'escolaridade': escolaridade,
      'foto': foto,
      'linkedin': linkedin,
      'instagram': instagram,
      'tipo_conta': tipoConta,
      'cargo': cargo,
      'criador': criador,
      'ativo': ativo,
      'permissoes': permissoes,
      'empresa_id': empresaId,
      // O criado_em geralmente é gerado automaticamente pelo banco
    };
  }
}