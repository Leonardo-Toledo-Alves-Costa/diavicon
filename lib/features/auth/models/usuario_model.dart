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
      );
    }

    Map<String, dynamic> toMap() {
      return {
        'id': id,
        'nome': nome,
        'sobrenome': sobrenome,
        'email': email,
        'celular': celular,
        'cargo': cargo,
        'empresa_id': empresaId,
        'setor_id': setorId,
        'ativo': ativo ?? true,
        'titulo_principal': tituloPrincipal,
        'escolaridade': escolaridade,
        'foto_url': fotoUrl,
        'linkedin': linkedin,
        'instagram': instagram,
      };
    }
  }