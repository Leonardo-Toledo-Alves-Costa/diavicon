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
  });

  /// Converte o JSON do Supabase para o Model
  factory ProjetoModel.fromMap(Map<String, dynamic> map) {
    // Captura os dados das tabelas relacionadas (Joins)
    final prioridadeData = map['prioridade'] as Map<String, dynamic>?;
    final statusData = map['status_projeto'] as Map<String, dynamic>?;
    final empresaData = map['empresas'] as Map<String, dynamic>?;
    final clienteData = map['empresa_cliente'] as Map<String, dynamic>?;

    return ProjetoModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? 'Projeto Sem Nome',
      descricao: map['descricao'],

      // Mapeamento direto das colunas do banco (snake_case) para o Model (camelCase)
      empresaGestoraId: map['empresa_gestora_id'],
      statusId: map['status_id'],
      prioridadeId: map['prioridade_id'],

      // Dados processados dos Joins
      prioridadeNome: prioridadeData?['nome'] ?? 'Média',
      empresaNome: empresaData?['nome'] ?? 'Empresa não identificada',
      statusBadge: _parseStatus(statusData?['nome']),

      // Conversão segura de numéricos
      progresso: (map['progresso'] ?? 0.0).toDouble(),
      imageUrl: map['image_url'] ?? 'assets/images/project_placeholder1.png',

      empresaClienteId: map['empresa_cliente_id'],
      statusVinculoCliente: map['status_vinculo_cliente'],
      clienteNome: clienteData?['nome'] ?? 'Cliente não definido',
    );
  }

  /// Converte o Model de volta para Map (Útil para Inserts/Updates)
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

  /// Helper privado para converter a String do banco no Enum da sua UI
  static BadgeStatus _parseStatus(String? status) {
    if (status == null) return BadgeStatus.emAndamento;

    switch (status.toLowerCase()) {
      case 'em andamento':
        return BadgeStatus.emAndamento;
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

  /// Método para criar uma cópia com alterações (Padrão Clean Architecture)
  ProjetoModel copyWith({
    String? id,
    String? nome,
    String? descricao,
    double? progresso,
    String? imageUrl,
    String? prioridadeNome,
    String? empresaNome,
    BadgeStatus? statusBadge,
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
    );
  }
}
