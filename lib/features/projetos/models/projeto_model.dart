import '../../../core/widgets/status_badge.dart';

class ProjetoModel {
  final String id;
  final String nome;
  final String? descricao;
  final String? empresaGestoraId;
  final String? statusId;
  final String? prioridadeId;
  
  final double progresso;
  final String imageUrl;
  final String prioridadeNome;
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
    this.statusBadge = BadgeStatus.emAndamento,
  });

  factory ProjetoModel.fromMap(Map<String, dynamic> map) {
    return ProjetoModel(
      id: map['id'],
      nome: map['nome'] ?? 'Projeto Sem Nome',
      descricao: map['descricao'],
      empresaGestoraId: map['empresa_gestora_id'],
      statusId: map['status_id'],
      prioridadeId: map['prioridade_id'],
    );
  }
}