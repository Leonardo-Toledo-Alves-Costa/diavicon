import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Trava as duas garantias do rastreio de autoria que quebram em silêncio se
// alguém reescrever as migrations: o autor é preenchido pelo banco (não pelo
// app) e a identidade dele só sai pra quem é da mesma empresa.
const _elementosPath = 'supabase/migrations/20260917230000_elementos_criado_por.sql';
const _autoresPath = 'supabase/migrations/20260917230500_autores_para_exibicao.sql';

void main() {
  late String elementos;
  late String autores;

  setUpAll(() {
    final arquivoElementos = File(_elementosPath);
    expect(arquivoElementos.existsSync(), isTrue, reason: 'migration de criado_por sumiu');
    elementos = arquivoElementos.readAsStringSync();

    final arquivoAutores = File(_autoresPath);
    expect(arquivoAutores.existsSync(), isTrue, reason: 'migration da RPC de autoria sumiu');
    autores = arquivoAutores.readAsStringSync();
  });

  group('elementos_estruturais.criado_por', () {
    test('o autor é definido por trigger, não pelo cliente', () {
      expect(elementos, contains('create trigger set_elemento_author'));
      expect(elementos, contains('new.criado_por := (select auth.uid())'));
    });

    test('a autoria é imutável depois do insert', () {
      expect(elementos, contains('new.criado_por := old.criado_por'));
    });

    test('excluir um colaborador não pode travar na FK nem apagar o elemento', () {
      expect(elementos, contains('references public.usuarios(id) on delete set null'));
    });

    test('a coluna continua nullable, pros elementos anteriores à migration', () {
      expect(elementos, contains('add column if not exists criado_por uuid'));
      expect(elementos, isNot(contains('criado_por uuid not null')));
    });
  });

  group('autores_para_exibicao', () {
    test('nome e foto do autor dependem da empresa de quem consulta', () {
      expect(autores, contains('private.active_actor_company_id()'));
      expect(autores, contains('u.empresa_id = private.active_actor_company_id()'));
    });

    test('dois usuários sem empresa não são tratados como colegas', () {
      expect(autores, contains('private.active_actor_company_id() is not null'));
    });

    test('a função não fica aberta a anônimo', () {
      expect(autores, contains('revoke all on function public.autores_para_exibicao(uuid[]) from public, anon'));
      expect(autores, contains('grant execute on function public.autores_para_exibicao(uuid[]) to authenticated'));
    });

    test('só expõe as colunas do selo — nada de email ou celular', () {
      for (final coluna in ['email', 'celular', 'escolaridade', 'linkedin', 'instagram', 'cpf']) {
        expect(autores, isNot(contains('u.$coluna')), reason: 'coluna sensível $coluna exposta pela RPC');
      }
    });
  });
}
