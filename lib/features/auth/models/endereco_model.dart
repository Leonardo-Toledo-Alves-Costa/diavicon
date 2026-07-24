class EnderecoModel {

  final String id;
  final String endereco;
  final String cidade;
  final String estado;
  final String pais;
  final String cep;
  final String bairro;
  final String numero;
  final String? complemento;

  EnderecoModel({
    required this.id,
    required this.endereco,
    required this.cidade,
    required this.estado,
    required this.pais,
    required this.cep,
    required this.bairro,
    required this.numero,
    this.complemento,
  });

  factory EnderecoModel.fromMap(Map<String, dynamic> map) {
    return EnderecoModel(
      id: map['id'],
      endereco: map['endereco'],
      cidade: map['cidade'],
      estado: map['estado'],
      pais: map['pais'],
      cep: map['cep'],
      bairro: map['bairro'],
      numero: map['numero'],
      complemento: map['complemento'], 
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'endereco': endereco,
      'cidade': cidade,
      'estado': estado,
      'pais': pais,
      'cep': cep,
      'bairro': bairro,
      'numero': numero,
      'complemento': complemento, 
    };
  }

  EnderecoModel copyWith({
    String? id,
    String? endereco,
    String? cidade,
    String? estado,
    String? pais,
    String? cep,
    String? bairro,
    String? numero,
    String? complemento,
  }) {
    return EnderecoModel(
      id: id ?? this.id,
      endereco: endereco ?? this.endereco,
      cidade: cidade ?? this.cidade,
      estado: estado ?? this.estado,
      pais: pais ?? this.pais,
      cep: cep ?? this.cep,
      bairro: bairro ?? this.bairro,
      numero: numero ?? this.numero,
      complemento: complemento ?? this.complemento, 
    );
  }

}