import 'package:diavicon/core/models/badge_status.dart';

class ProjetoModel {
  const ProjetoModel({
    required this.id,
    required this.nome,
    required this.criadoEm,
    this.descricao,
    this.empresaGestoraId,
    this.statusId,
    this.prioridadeId,
    this.progresso = 0,
    this.imageUrl = 'assets/images/project_placeholder1.png',
    this.prioridadeNome = 'Média',
    this.statusNome = 'Em andamento',
    this.empresaNome = 'Gestora não identificada',
    this.statusBadge = BadgeStatus.emAndamento,
    this.empresaClienteId,
    this.statusVinculoCliente,
    this.clienteNome,
    this.clienteFotoUrl,
    this.equipeFotos = const [],
    this.empresaFotoUrl,
  });

  final String id;
  final String nome;
  final String? descricao;
  final String? empresaGestoraId;
  final String? statusId;
  final String? prioridadeId;
  final String? empresaClienteId;
  final String? statusVinculoCliente;
  final String? clienteNome;
  final String? clienteFotoUrl;
  final double progresso;
  final String imageUrl;
  final String prioridadeNome;
  final String statusNome;
  final String empresaNome;
  final BadgeStatus statusBadge;
  final DateTime criadoEm;
  final List<String> equipeFotos;
  final String? empresaFotoUrl;

  factory ProjetoModel.fromMap(
    Map<String, dynamic> map, {
    String? minhaEmpresaId,
  }) {
    final priority = _asMap(map['prioridade']);
    final status = _asMap(map['status_projeto']);
    final managerCompany = _asMap(map['empresas']);
    final clientCompany = _asMap(map['empresa_cliente']);

    final teamPhotos = <String>[];
    final team = map['projeto_equipe_interna'];
    if (team is List) {
      for (final rawMember in team) {
        final member = _asMap(rawMember);
        if (member == null) continue;
        if (minhaEmpresaId != null &&
            member['empresa_id']?.toString() != minhaEmpresaId) {
          continue;
        }

        final user = _asMap(member['usuarios']);
        final photoUrl = user?['foto_url']?.toString();
        if (photoUrl != null && photoUrl.isNotEmpty) teamPhotos.add(photoUrl);
      }
    }

    final progress = map['progresso'];
    final statusName = status?['nome']?.toString().trim();
    final createdAt = DateTime.tryParse(map['criado_em']?.toString() ?? '');

    return ProjetoModel(
      id: map['id']?.toString() ?? '',
      nome: map['nome']?.toString() ?? 'Projeto sem nome',
      descricao: map['descricao']?.toString(),
      empresaGestoraId: map['empresa_gestora_id']?.toString(),
      statusId: map['status_id']?.toString(),
      prioridadeId: map['prioridade_id']?.toString(),
      prioridadeNome: priority?['nome']?.toString() ?? 'Média',
      statusNome: statusName == null || statusName.isEmpty
          ? 'Em andamento'
          : statusName,
      empresaNome:
          managerCompany?['nome']?.toString() ?? 'Empresa não identificada',
      statusBadge: _parseStatus(status?['nome']?.toString()),
      equipeFotos: teamPhotos,
      progresso: progress is num
          ? progress.toDouble()
          : double.tryParse(progress?.toString() ?? '') ?? 0,
      imageUrl:
          map['image_url']?.toString() ??
          'assets/images/project_placeholder1.png',
      empresaClienteId: map['empresa_cliente_id']?.toString(),
      empresaFotoUrl: managerCompany?['foto_url']?.toString(),
      statusVinculoCliente: map['status_vinculo_cliente']?.toString(),
      clienteNome: clientCompany?['nome']?.toString() ?? 'Cliente não definido',
      clienteFotoUrl: clientCompany?['foto_url']?.toString(),
      criadoEm: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'empresa_gestora_id': empresaGestoraId,
      'status_id': statusId,
      'prioridade_id': prioridadeId,
      'empresa_cliente_id': empresaClienteId,
      'status_vinculo_cliente': statusVinculoCliente,
      'image_url': imageUrl,
      'progresso': progresso,
      'criado_em': criadoEm.toIso8601String(),
    };
  }

  ProjetoModel copyWith({
    String? id,
    String? nome,
    String? descricao,
    String? empresaGestoraId,
    String? statusId,
    String? prioridadeId,
    String? empresaClienteId,
    String? statusVinculoCliente,
    String? clienteNome,
    String? clienteFotoUrl,
    double? progresso,
    String? imageUrl,
    String? prioridadeNome,
    String? statusNome,
    String? empresaNome,
    BadgeStatus? statusBadge,
    DateTime? criadoEm,
    List<String>? equipeFotos,
    String? empresaFotoUrl,
  }) {
    return ProjetoModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      empresaGestoraId: empresaGestoraId ?? this.empresaGestoraId,
      statusId: statusId ?? this.statusId,
      prioridadeId: prioridadeId ?? this.prioridadeId,
      empresaClienteId: empresaClienteId ?? this.empresaClienteId,
      statusVinculoCliente: statusVinculoCliente ?? this.statusVinculoCliente,
      clienteNome: clienteNome ?? this.clienteNome,
      clienteFotoUrl: clienteFotoUrl ?? this.clienteFotoUrl,
      progresso: progresso ?? this.progresso,
      imageUrl: imageUrl ?? this.imageUrl,
      prioridadeNome: prioridadeNome ?? this.prioridadeNome,
      statusNome: statusNome ?? this.statusNome,
      empresaNome: empresaNome ?? this.empresaNome,
      statusBadge: statusBadge ?? this.statusBadge,
      criadoEm: criadoEm ?? this.criadoEm,
      equipeFotos: equipeFotos ?? this.equipeFotos,
      empresaFotoUrl: empresaFotoUrl ?? this.empresaFotoUrl,
    );
  }

  static BadgeStatus _parseStatus(String? status) {
    switch (status?.trim().toLowerCase()) {
      case 'concluido':
      case 'concluído':
        return BadgeStatus.concluido;
      case 'parado':
      case 'atrasado':
      case 'cancelado':
        return BadgeStatus.cancelado;
      default:
        return BadgeStatus.emAndamento;
    }
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
