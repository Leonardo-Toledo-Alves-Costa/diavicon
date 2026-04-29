class EmpresaModel {
  final String id;
  final String nome;
  final String? cnpj;
  final String? descricao;
  final String? tipo;
  final bool ativo;
  final String? enderecoId;
  final String? planoId;
  final String? tamanho; 
  final String? fotoUrl;
  final String? site;
  final DateTime? criadoEm;

  EmpresaModel({
    required this.id,
    required this.nome,
    this.cnpj,
    this.descricao,
    this.tipo,
    this.ativo = true,
    this.enderecoId,
    this.planoId,
    this.tamanho,
    this.fotoUrl,
    this.site,
    this.criadoEm,
  });

  // Converte o JSON do Supabase para o Objeto Dart
  factory EmpresaModel.fromMap(Map<String, dynamic> map) {
    return EmpresaModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      cnpj: map['cnpj'],
      descricao: map['descricao'],
      tipo: map['tipo'],
      ativo: map['ativo'] ?? true,
      enderecoId: map['endereco_id'],
      planoId: map['plano_id'],
      tamanho: map['tamanho'],
      fotoUrl: map['foto_url'],
      site: map['site'],
      criadoEm: map['criado_em'] != null 
          ? DateTime.parse(map['criado_em']) 
          : null,
    );
  }

  // Converte o Objeto Dart para JSON
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'cnpj': cnpj,
      'descricao': descricao,
      'tipo': tipo,
      'ativo': ativo,
      'endereco_id': enderecoId,
      'plano_id': planoId,
      'tamanho': tamanho,
      'foto_url': fotoUrl,
      'site': site,
    };
  }

  // Permite criar uma cópia alterando apenas alguns campos (Imutabilidade)
  EmpresaModel copyWith({
    String? id,
    String? nome,
    String? cnpj,
    String? descricao,
    String? tipo,
    bool? ativo,
    String? enderecoId,
    String? planoId,
    String? tamanho,
    String? fotoUrl,
    String? site,
    DateTime? criadoEm,
  }) {
    return EmpresaModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      cnpj: cnpj ?? this.cnpj,
      descricao: descricao ?? this.descricao,
      tipo: tipo ?? this.tipo,
      ativo: ativo ?? this.ativo,
      enderecoId: enderecoId ?? this.enderecoId,
      planoId: planoId ?? this.planoId,
      tamanho: tamanho ?? this.tamanho,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      site: site ?? this.site,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }
}