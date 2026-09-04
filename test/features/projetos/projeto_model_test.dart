import 'package:diavicon/core/models/badge_status.dart';
import 'package:diavicon/features/projetos/models/projeto_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mapeia joins do Supabase e mantém apenas fotos da empresa atual', () {
    final project = ProjetoModel.fromMap({
      'id': 'project-1',
      'nome': 'Ponte',
      'descricao': 'Inspeção',
      'empresa_gestora_id': 'company-1',
      'empresa_cliente_id': 'client-1',
      'status_vinculo_cliente': 'ativo',
      'progresso': 0.75,
      'criado_em': '2026-09-03T12:00:00Z',
      'prioridade': {'nome': 'Alta'},
      'status_projeto': {'nome': 'Concluído'},
      'empresas': {'nome': 'Gestora', 'foto_url': 'manager.png'},
      'empresa_cliente': {'nome': 'Cliente'},
      'projeto_equipe_interna': [
        {
          'empresa_id': 'company-1',
          'usuarios': {'foto_url': 'first.png'},
        },
        {
          'empresa_id': 'company-2',
          'usuarios': {'foto_url': 'other.png'},
        },
        {
          'empresa_id': 'company-1',
          'usuarios': {'foto_url': null},
        },
      ],
    }, minhaEmpresaId: 'company-1');

    expect(project.statusBadge, BadgeStatus.concluido);
    expect(project.statusNome, 'Concluído');
    expect(project.prioridadeNome, 'Alta');
    expect(project.empresaNome, 'Gestora');
    expect(project.clienteNome, 'Cliente');
    expect(project.progresso, 0.75);
    expect(project.equipeFotos, ['first.png']);
    expect(project.criadoEm, DateTime.parse('2026-09-03T12:00:00Z'));
  });

  test('usa fallbacks seguros para dados ausentes ou inválidos', () {
    final project = ProjetoModel.fromMap({
      'id': 10,
      'nome': null,
      'progresso': 'inválido',
      'criado_em': 'inválido',
      'status_projeto': {'nome': 'atrasado'},
    });

    expect(project.id, '10');
    expect(project.nome, 'Projeto sem nome');
    expect(project.progresso, 0);
    expect(project.statusBadge, BadgeStatus.cancelado);
    expect(project.criadoEm, DateTime.fromMillisecondsSinceEpoch(0));
  });

  test('copyWith não perde vínculos nem metadados não alterados', () {
    final original = ProjetoModel(
      id: 'project-1',
      nome: 'Original',
      criadoEm: DateTime.utc(2026),
      empresaGestoraId: 'manager',
      empresaClienteId: 'client',
      statusVinculoCliente: 'ativo',
      clienteNome: 'Cliente',
      empresaFotoUrl: 'manager.png',
      equipeFotos: const ['member.png'],
      statusNome: 'Atrasado',
    );

    final updated = original.copyWith(nome: 'Atualizado');

    expect(updated.nome, 'Atualizado');
    expect(updated.empresaGestoraId, 'manager');
    expect(updated.empresaClienteId, 'client');
    expect(updated.statusVinculoCliente, 'ativo');
    expect(updated.clienteNome, 'Cliente');
    expect(updated.empresaFotoUrl, 'manager.png');
    expect(updated.equipeFotos, ['member.png']);
    expect(updated.statusNome, 'Atrasado');
  });

  test('preserva o status original sem condensar atrasado em cancelado', () {
    final project = ProjetoModel.fromMap({
      'id': 'project-1',
      'nome': 'Ponte',
      'status_projeto': {'nome': 'Atrasado'},
    });

    expect(project.statusNome, 'Atrasado');
    expect(project.statusBadge, BadgeStatus.cancelado);
  });

  test('aceita progresso numérico recebido como texto', () {
    final project = ProjetoModel.fromMap({
      'id': 'project-1',
      'nome': 'Ponte',
      'progresso': '0.45',
    });

    expect(project.progresso, 0.45);
  });
}
