/// Um turno (Manhã/Tarde/Noite) dentro de um RDO. Na tabela `rdo_realizado`
/// cada turno é achatado em 5 colunas de texto próprias (ex.: `manha_chegada`,
/// `manha_cond_trabalho`...), sem uma coluna json separada — por isso o
/// achatamento acontece em [RdoRealizadoModel.toJson]/`fromJson`, não aqui.
class TurnoRealizado {
  final String chegada;
  final String inicio;
  final String saida;
  final String condTrabalho;
  final String condClima;

  const TurnoRealizado({
    this.chegada = '',
    this.inicio = '',
    this.saida = '',
    this.condTrabalho = '',
    this.condClima = '',
  });

  bool get preenchido =>
      chegada.isNotEmpty || inicio.isNotEmpty || saida.isNotEmpty;

  TurnoRealizado copyWith({
    String? chegada,
    String? inicio,
    String? saida,
    String? condTrabalho,
    String? condClima,
  }) {
    return TurnoRealizado(
      chegada: chegada ?? this.chegada,
      inicio: inicio ?? this.inicio,
      saida: saida ?? this.saida,
      condTrabalho: condTrabalho ?? this.condTrabalho,
      condClima: condClima ?? this.condClima,
    );
  }
}

/// Status do RDO. Regra de negócio: nasce sempre `postado` ao ser salvo pela
/// empresa executante; só o cliente do projeto pode movê-lo entre os três
/// valores (ver [RdoRepository.atualizarStatus]).
enum RdoStatus {
  postado,
  visto,
  rejeitado;

  String get valor => name;

  String get rotulo => switch (this) {
    RdoStatus.postado => 'Postado',
    RdoStatus.visto => 'Visto',
    RdoStatus.rejeitado => 'Rejeitado',
  };

  static RdoStatus fromValor(String? valor) {
    return RdoStatus.values.firstWhere(
      (status) => status.valor == valor,
      orElse: () => RdoStatus.postado,
    );
  }
}

class RdoRealizadoModel {
  final String? id;
  final DateTime? criadoEm;
  final String projetoId;
  final String empresaId;
  final String? criadoUserId;
  final List<String> equipe;
  final String data;
  final TurnoRealizado manha;
  final TurnoRealizado tarde;
  final TurnoRealizado noite;
  final String atividadesRealizadas;
  final String equipamentosUtilizados;
  final String observacoes;
  final RdoStatus status;

  const RdoRealizadoModel({
    this.id,
    this.criadoEm,
    required this.projetoId,
    required this.empresaId,
    this.criadoUserId,
    this.equipe = const [],
    this.data = '',
    this.manha = const TurnoRealizado(),
    this.tarde = const TurnoRealizado(),
    this.noite = const TurnoRealizado(),
    this.atividadesRealizadas = '',
    this.equipamentosUtilizados = '',
    this.observacoes = '',
    this.status = RdoStatus.postado,
  });

  factory RdoRealizadoModel.fromJson(Map<String, dynamic> json) {
    TurnoRealizado turno(String prefixo) => TurnoRealizado(
      chegada: json['${prefixo}_chegada']?.toString() ?? '',
      inicio: json['${prefixo}_inicio']?.toString() ?? '',
      saida: json['${prefixo}_saida']?.toString() ?? '',
      condTrabalho: json['${prefixo}_cond_trabalho']?.toString() ?? '',
      condClima: json['${prefixo}_cond_clima']?.toString() ?? '',
    );

    return RdoRealizadoModel(
      id: json['id']?.toString(),
      criadoEm: DateTime.tryParse(json['criado_em']?.toString() ?? ''),
      projetoId: json['projeto_id']?.toString() ?? '',
      empresaId: json['empresa_id']?.toString() ?? '',
      criadoUserId: json['criado_user_id']?.toString(),
      equipe: json['equipe'] is List
          ? List<String>.from(
              (json['equipe'] as List).map((e) => e.toString()),
            )
          : const [],
      data: json['data']?.toString() ?? '',
      manha: turno('manha'),
      tarde: turno('tarde'),
      noite: turno('noite'),
      atividadesRealizadas: json['atividades_realizadas']?.toString() ?? '',
      equipamentosUtilizados:
          json['equipamentos_utilizados']?.toString() ?? '',
      observacoes: json['observacoes']?.toString() ?? '',
      status: RdoStatus.fromValor(json['status']?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> turno(String prefixo, TurnoRealizado t) => {
      '${prefixo}_chegada': t.chegada,
      '${prefixo}_inicio': t.inicio,
      '${prefixo}_saida': t.saida,
      '${prefixo}_cond_trabalho': t.condTrabalho,
      '${prefixo}_cond_clima': t.condClima,
    };

    return {
      if (id != null) 'id': id,
      'projeto_id': projetoId,
      'empresa_id': empresaId,
      if (criadoUserId != null) 'criado_user_id': criadoUserId,
      'equipe': equipe,
      'data': data,
      ...turno('manha', manha),
      ...turno('tarde', tarde),
      ...turno('noite', noite),
      'atividades_realizadas': atividadesRealizadas,
      'equipamentos_utilizados': equipamentosUtilizados,
      'observacoes': observacoes,
      'status': status.valor,
    };
  }

  RdoRealizadoModel copyWith({RdoStatus? status}) {
    return RdoRealizadoModel(
      id: id,
      criadoEm: criadoEm,
      projetoId: projetoId,
      empresaId: empresaId,
      criadoUserId: criadoUserId,
      equipe: equipe,
      data: data,
      manha: manha,
      tarde: tarde,
      noite: noite,
      atividadesRealizadas: atividadesRealizadas,
      equipamentosUtilizados: equipamentosUtilizados,
      observacoes: observacoes,
      status: status ?? this.status,
    );
  }
}

/// Resumo de uma empresa do projeto para a tela [RdoEmpresasScreen]: dados
/// cadastrais (via `projeto_empresas_colaboradoras`/`projetos`, já existentes
/// no app) + contagem/data do último RDO (via `rdo_realizado`, calculado no
/// cliente a partir das linhas da empresa no projeto).
class EmpresaRdoResumo {
  final String id;
  final String nome;
  final String? fotoUrl;
  final String? cidade;
  final String? estado;
  final int totalRdos;
  final DateTime? ultimoRdoEm;

  const EmpresaRdoResumo({
    required this.id,
    required this.nome,
    this.fotoUrl,
    this.cidade,
    this.estado,
    this.totalRdos = 0,
    this.ultimoRdoEm,
  });

  String get local {
    if (cidade == null || cidade!.isEmpty) return '';
    if (estado == null || estado!.isEmpty) return cidade!;
    return '$cidade - $estado';
  }

  EmpresaRdoResumo copyWith({int? totalRdos, DateTime? ultimoRdoEm}) {
    return EmpresaRdoResumo(
      id: id,
      nome: nome,
      fotoUrl: fotoUrl,
      cidade: cidade,
      estado: estado,
      totalRdos: totalRdos ?? this.totalRdos,
      ultimoRdoEm: ultimoRdoEm ?? this.ultimoRdoEm,
    );
  }
}

/// Papel da empresa do usuário logado dentro de um projeto — determina o que
/// ele pode ver/fazer no RDO. Não existe coluna de "papel" no banco: é
/// derivado comparando `empresa_id` do usuário com
/// `projetos.empresa_gestora_id`/`empresa_cliente_id`.
enum PapelEmpresaProjeto {
  gestora,
  cliente,
  colaboradora;

  /// Gestora e cliente enxergam o RDO de todas as empresas do projeto;
  /// colaboradora comum só enxerga o próprio.
  bool get vePapeisDeTodasEmpresas =>
      this == PapelEmpresaProjeto.gestora || this == PapelEmpresaProjeto.cliente;

  /// Só o cliente revisa e muda o status de um RDO.
  bool get podeAlterarStatus => this == PapelEmpresaProjeto.cliente;

  /// Cliente só revisa — quem executa a obra (gestora/colaboradora) é quem
  /// registra o RDO.
  bool get podeCriarRdo => this != PapelEmpresaProjeto.cliente;
}
