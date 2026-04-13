class EmpresaModel {
  final String id;
  final String? cnpj;
  final String? nome;
  final String? tamanho;
  final String? foto;
  final String? endereco;
  final String? cidade;
  final String? estado;
  final String? pais;
  final String? linkedin;
  final String? instagram;
  final String? site;
  final String? descricao;
  final List<String>? setores;
  final String? tipo;
  final List<String>? areasAtuacao;
  final String? plano;
  final bool? ativo;
  final DateTime? dataExpira;
  final String? authCompartilharResultados;
  final String? storage;
  
  // Módulo de Permissões de Acesso
  final bool? acessoCatalogo;
  final bool? acessoPlanoDeEnsaios;
  final bool? acessoRelatorio;
  final bool? acessoRdo;
  final bool? acessoMultiEquipe;
  final bool? acessoMonitoramento;
  final bool? acessoFinanceiro;
  final bool? acessoProcRec;
  
  final DateTime? criadoEm;

  EmpresaModel({
    required this.id,
    this.cnpj,
    this.nome,
    this.tamanho,
    this.foto,
    this.endereco,
    this.cidade,
    this.estado,
    this.pais,
    this.linkedin,
    this.instagram,
    this.site,
    this.descricao,
    this.setores,
    this.tipo,
    this.areasAtuacao,
    this.plano,
    this.ativo,
    this.dataExpira,
    this.authCompartilharResultados,
    this.storage,
    this.acessoCatalogo,
    this.acessoPlanoDeEnsaios,
    this.acessoRelatorio,
    this.acessoRdo,
    this.acessoMultiEquipe,
    this.acessoMonitoramento,
    this.acessoFinanceiro,
    this.acessoProcRec,
    this.criadoEm,
  });

  factory EmpresaModel.fromMap(Map<String, dynamic> map) {
    return EmpresaModel(
      id: map['id'],
      cnpj: map['cnpj'],
      nome: map['nome'],
      tamanho: map['tamanho'],
      foto: map['foto'],
      endereco: map['endereco'],
      cidade: map['cidade'],
      estado: map['estado'],
      pais: map['pais'],
      linkedin: map['linkedin'],
      instagram: map['instagram'],
      site: map['site'],
      descricao: map['descricao'],
      // Tratamento para converter o array do postgres para List do Dart
      setores: map['setores'] != null ? List<String>.from(map['setores']) : null,
      tipo: map['tipo'],
      areasAtuacao: map['areas_atuacao'] != null ? List<String>.from(map['areas_atuacao']) : null,
      plano: map['plano'],
      ativo: map['ativo'],
      dataExpira: map['data_expira'] != null ? DateTime.parse(map['data_expira']) : null,
      authCompartilharResultados: map['auth_compartilhar_resultados'], // Confirme o nome exato da coluna no Supabase
      storage: map['storage'],
      acessoCatalogo: map['acesso_catalogo'],
      acessoPlanoDeEnsaios: map['acesso_plano_de_ensaios'],
      acessoRelatorio: map['acesso_relatorio'],
      acessoRdo: map['acesso_rdo'],
      acessoMultiEquipe: map['acesso_multi_equipe'],
      acessoMonitoramento: map['acesso_monitoramento'],
      acessoFinanceiro: map['acesso_financeiro'],
      acessoProcRec: map['acesso_proc_rec'],
      criadoEm: map['criado_em'] != null ? DateTime.parse(map['criado_em']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cnpj': cnpj,
      'nome': nome,
      'tamanho': tamanho,
      'foto': foto,
      'endereco': endereco,
      'cidade': cidade,
      'estado': estado,
      'pais': pais,
      'linkedin': linkedin,
      'instagram': instagram,
      'site': site,
      'descricao': descricao,
      'setores': setores,
      'tipo': tipo,
      'areas_atuacao': areasAtuacao,
      'plano': plano,
      'ativo': ativo,
      'data_expira': dataExpira?.toIso8601String(),
      'auth_compartilhar_resultados': authCompartilharResultados, // Confirme o nome exato
      'storage': storage,
      'acesso_catalogo': acessoCatalogo,
      'acesso_plano_de_ensaios': acessoPlanoDeEnsaios,
      'acesso_relatorio': acessoRelatorio,
      'acesso_rdo': acessoRdo,
      'acesso_multi_equipe': acessoMultiEquipe,
      'acesso_monitoramento': acessoMonitoramento,
      'acesso_financeiro': acessoFinanceiro,
      'acesso_proc_rec': acessoProcRec,
    };
  }
}