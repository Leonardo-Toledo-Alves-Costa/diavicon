import '../../../core/widgets/status_badge.dart';

class ProjetoModel {
  final String id;
  final String nome;
  final String? descricao;
  final String? empresaGestoraId;
  final String? statusId;
  final String? prioridadeId;
  final String? empresaClienteId;
  final String? statusVinculoCliente;
  final String? clienteNome;
  
  // Atributos para facilitar a UI (Preenchidos via Joins na query)
  final double progresso;
  final String imageUrl;
  final String prioridadeNome;
  final String empresaNome;
  final BadgeStatus statusBadge;
  final DateTime criadoEm;
  final List<String> equipeFotos;
  final String? empresaFotoUrl;

  ProjetoModel({
    required this.id,
    required this.nome,
    this.descricao,
    this.empresaGestoraId,
    this.statusId,
    this.prioridadeId,
    this.progresso = 0.0,
    this.imageUrl = 'assets/images/project_placeholder1.png',
    this.prioridadeNome = 'Média',
    this.empresaNome = 'Gestora não identificada',
    this.statusBadge = BadgeStatus.emAndamento,
    this.empresaClienteId,
    this.statusVinculoCliente,
    this.clienteNome, 
    required this.criadoEm,
    this.equipeFotos = const [],
    this.empresaFotoUrl, 
  });

  // 🔥 OLHA A "PORTA" ABERTA AQUI: {String? minhaEmpresaId}
  factory ProjetoModel.fromMap(Map<String, dynamic> map, {String? minhaEmpresaId}) {
    final prioridadeData = map['prioridade'] as Map<String, dynamic>?;
    final statusData = map['status_projeto'] as Map<String, dynamic>?;
    final empresaData = map['empresas'] as Map<String, dynamic>?;
    final clienteData = map['empresa_cliente'] as Map<String, dynamic>?;

    final List<String> fotos = [];
    if (map['projeto_equipe_interna'] != null) {
      final equipeLista = map['projeto_equipe_interna'] as List;
      for (var item in equipeLista) {
        // 🔥 A MÁGICA DO B2B AQUI!
        if (minhaEmpresaId != null && item['empresa_id'] != minhaEmpresaId) {
          continue; 
        }
        
        final usuarioData = item['usuarios'];
        if (usuarioData != null) {
          fotos.add(usuarioData['foto_url']?.toString() ?? '');
        }
      }
    }

    return ProjetoModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? 'Projeto Sem Nome',
      descricao: map['descricao'],
      empresaGestoraId: map['empresa_gestora_id'],
      statusId: map['status_id'],
      prioridadeId: map['prioridade_id'],
      prioridadeNome: prioridadeData?['nome'] ?? 'Média',
      empresaNome: empresaData?['nome'] ?? 'Empresa não identificada',
      statusBadge: _parseStatus(statusData?['nome']),
      equipeFotos: fotos, 
      progresso: (map['progresso'] ?? 0.0).toDouble(),
      imageUrl: map['image_url'] ?? 'assets/images/project_placeholder1.png',
      empresaClienteId: map['empresa_cliente_id'],
      empresaFotoUrl: empresaData?['foto_url'],
      statusVinculoCliente: map['status_vinculo_cliente'],
      clienteNome: clienteData?['nome'] ?? 'Cliente não definido',
      criadoEm: map['criado_em'] != null ? DateTime.parse(map['criado_em']) : DateTime.now(),
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
      'image_url': imageUrl,
      'progresso': progresso,
    };
  }

  static BadgeStatus _parseStatus(String? status) {
    if (status == null) return BadgeStatus.emAndamento;
    switch (status.toLowerCase()) {
      case 'em andamento': return BadgeStatus.emAndamento;
      case 'concluido':
      case 'concluído': return BadgeStatus.concluido;
      case 'parado':
      case 'atrasado':
      case 'cancelado': return BadgeStatus.cancelado;
      default: return BadgeStatus.emAndamento;
    }
  }

  ProjetoModel copyWith({
    String? id,
    String? nome,
    String? descricao,
    double? progresso,
    String? imageUrl,
    String? prioridadeNome,
    String? empresaNome,
    BadgeStatus? statusBadge,
    List<String>? equipeFotos, 
  }) {
    return ProjetoModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      progresso: progresso ?? this.progresso,
      imageUrl: imageUrl ?? this.imageUrl,
      prioridadeNome: prioridadeNome ?? this.prioridadeNome,
      empresaNome: empresaNome ?? this.empresaNome,
      statusBadge: statusBadge ?? this.statusBadge,
      empresaGestoraId: empresaGestoraId,
      statusId: statusId,
      prioridadeId: prioridadeId, 
      criadoEm: criadoEm,
      equipeFotos: equipeFotos ?? this.equipeFotos,
    );
  }
}