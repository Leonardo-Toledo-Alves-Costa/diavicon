class EmpresaModel {
  final String? id;
  final String? nome;
  final String? cnpj;
  final String? descricao;
  final String? tipo;
  final bool? ativo;
  final String? enderecoId;
  final String? planoId;
  final String? tamanho;
  final String? fotoUrl;
  final String? site;
  final DateTime? criadoEm;

  EmpresaModel({
    this.id,
    this.nome,
    this.cnpj,
    this.descricao,
    this.tipo,
    this.ativo,
    this.enderecoId,
    this.planoId,
    this.tamanho,
    this.fotoUrl,
    this.site,
    this.criadoEm,
  });

  factory EmpresaModel.fromMap(Map<String, dynamic> map) {
    return EmpresaModel(
      id: map['id'],
      nome: map['nome'],
      cnpj: map['cnpj'],
      descricao: map['descricao'],
      tipo: map['tipo'],
      ativo: map['ativo'],
      enderecoId: map['endereco_id'],
      planoId: map['plano_id'],
      tamanho: map['tamanho'],
      fotoUrl: map['foto_url'],
      site: map['site'],
      criadoEm: map['criado_em'] != null ? DateTime.parse(map['criado_em']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'cnpj': cnpj,
      'descricao': descricao,
      'tipo': tipo,
      'ativo': ativo ?? true,
      'endereco_id': enderecoId,
      'plano_id': planoId,
      'tamanho': tamanho,
      'foto_url': fotoUrl,
      'site': site,
    };
  }
}