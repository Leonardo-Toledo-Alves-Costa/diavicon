import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Trava a proposta de RLS dos Gastos (ainda não aplicada no Supabase):
// gasto é da empresa, o admin vê mas não edita os de terceiros, e o SQL não
// mexe nas colunas das tabelas criadas no painel.
const _path = 'supabase/migrations/20260918150000_gastos_rls.sql';

String _policy(String sql, String nome) {
  final m = RegExp('create policy $nome\\s').firstMatch(sql);
  expect(m, isNotNull, reason: 'policy $nome sumiu');
  final fim = sql.indexOf(');', m!.start);
  return sql.substring(m.start, fim);
}

void main() {
  late String sql;

  setUpAll(() {
    final arquivo = File(_path);
    expect(arquivo.existsSync(), isTrue, reason: 'proposta de RLS de gastos sumiu');
    sql = arquivo.readAsStringSync();
  });

  test('leitura sempre presa à empresa ativa; terceiros só para admin', () {
    final select = _policy(sql, 'gastos_select');
    expect(select, contains('empresa_id = private.active_actor_company_id()'));
    expect(select, contains('criado_por = (select auth.uid())'));
    expect(select, contains('private.is_active_company_admin(empresa_id)'));
  });

  test('editar e excluir: só o dono, nunca o admin por ser admin', () {
    for (final nome in ['gastos_update', 'gastos_delete']) {
      final p = _policy(sql, nome);
      expect(p, contains('criado_por = (select auth.uid())'), reason: nome);
      expect(p, isNot(contains('is_active_company_admin')), reason: nome);
    }
  });

  test('lançar: para si, na própria empresa, em projeto acessível', () {
    final insert = _policy(sql, 'gastos_insert');
    expect(insert, contains('criado_por = (select auth.uid())'));
    expect(insert, contains('empresa_id = private.active_actor_company_id()'));
    expect(insert, contains('private.can_access_project(projeto_id)'));
  });

  test('categoria: só o admin da empresa cria, renomeia e exclui', () {
    for (final nome in ['categoria_gastos_insert', 'categoria_gastos_update', 'categoria_gastos_delete']) {
      expect(_policy(sql, nome), contains('private.is_active_company_admin(empresa_id)'), reason: nome);
    }
  });

  test('não altera o schema criado no painel', () {
    expect(sql, isNot(contains('add column')));
    expect(sql, isNot(contains('alter column')));
    expect(sql, isNot(contains('drop constraint')));
  });

  test('anônimo não acessa', () {
    expect(sql, contains('revoke all on public.gastos from anon'));
    expect(sql, contains('revoke all on public.categoria_gastos from anon'));
  });
}
