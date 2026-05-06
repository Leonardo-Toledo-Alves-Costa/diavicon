import '../../../core/widgets/status_badge.dart';

class ProjetoModel {
  final String id;
  final String nome;
  final String? descricao;
  final String? empresaGestoraId;
  final String? statusId;
  final String? prioridadeId;
  
  // Atributos para facilitar a UI (Vindos de Joins ou Cálculos)
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
  });

  /// Converte o JSON do Supabase para o Model
  /// Suporta Joins: prioridade(nome), status_projeto(nome) e empresas(nome)
  factory ProjetoModel.fromMap(Map<String, dynamic> map) {
    // Tratamento de dados de tabelas relacionadas (Joins)
    final prioridadeData = map['prioridade'] as Map<String, dynamic>?;
    final statusData = map['status_projeto'] as Map<String, dynamic>?;
    final empresaData = map['empresas'] as Map<String, dynamic>?;

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
      
      progresso: (map['progresso'] ?? 0.0).toDouble(),
      
      imageUrl: map['image_url'] ?? 'assets/images/project_placeholder1.png',
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
    };
  }

  /// Helper para transformar String do banco no Enum da UI
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
        return BadgeStatus.cancelado;
      default:
        return BadgeStatus.emAndamento;
    }
  }

  ProjetoModel copyWith({
    String? id,
    String? nome,
    String? descricao,
    double? progresso,
    String? prioridadeNome,
    BadgeStatus? statusBadge,
  }) {
    return ProjetoModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      progresso: progresso ?? this.progresso,
      prioridadeNome: prioridadeNome ?? this.prioridadeNome,
      statusBadge: statusBadge ?? this.statusBadge,
      empresaGestoraId: empresaGestoraId,
      statusId: statusId,
      prioridadeId: prioridadeId,
      imageUrl: imageUrl,
      empresaNome: empresaNome,
    );
  }
}