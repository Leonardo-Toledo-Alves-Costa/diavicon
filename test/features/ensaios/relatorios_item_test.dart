import 'package:diavicon/features/ensaios/ensaios_geral/repositories/relatorios_item_repository.dart';
import 'package:flutter_test/flutter_test.dart';

RelatorioItem item(String titulo, String ensaio) =>
    RelatorioItem(id: titulo, titulo: titulo, ensaio: ensaio, status: 'Concluído', criadoEm: DateTime(2026, 9, 1));

void main() {
  final lista = [
    item('Relatório Torre A', 'Carbonatação'),
    item('Relatório Torre B', 'Inspeção Visual'),
    item('Galpão Norte — campanha 2', 'Ultrassonografia'),
    item('RDO semana 36', 'RDO'),
  ];

  group('busca', () {
    test('vazia mostra tudo', () {
      expect(filtrarRelatorios(lista, '   '), lista);
    });

    test('acha pelo título', () {
      expect(filtrarRelatorios(lista, 'galpão').single.titulo, 'Galpão Norte — campanha 2');
    });

    test('acha pelo nome do ensaio', () {
      expect(filtrarRelatorios(lista, 'inspeção').single.ensaio, 'Inspeção Visual');
    });

    test('ignora acento e maiúscula: "inspecao" acha "Inspeção"', () {
      expect(filtrarRelatorios(lista, 'INSPECAO').single.ensaio, 'Inspeção Visual');
      expect(filtrarRelatorios(lista, 'carbonatacao'), hasLength(1));
    });

    test('várias palavras: todas precisam aparecer, no título ou no ensaio', () {
      // "torre" está no título, "carbonatacao" no ensaio.
      expect(filtrarRelatorios(lista, 'carbonatacao torre').single.titulo, 'Relatório Torre A');
      expect(filtrarRelatorios(lista, 'torre ultrassom'), isEmpty);
    });
  });

  group('leitura da linha', () {
    test('conteudo como objeto (relatorio_ensaio)', () {
      final r = RelatorioItem.fromLinha({
        'id': '1',
        'criado_em': '2026-09-10T12:00:00Z',
        'status': 'Concluído',
        'conteudo': {'nome_relatorio': 'Carbonatação Torre A', 'url_arquivo': 'https://x/a.pdf', 'formato': 'pdf'},
      }, ensaio: 'Carbonatação');
      expect(r.titulo, 'Carbonatação Torre A');
      expect(r.formato, 'pdf');
      expect(r.concluido, isTrue);
    });

    test('conteudo como texto JSON (relatorio_rdo)', () {
      final r = RelatorioItem.fromLinha({
        'id': '2',
        'criado_em': '2026-09-11T12:00:00Z',
        'status': 'Concluído',
        'conteudo': '{"nome_relatorio":"RDO semana 36","url_arquivo":"https://x/r.html","formato":"html"}',
      }, ensaio: 'RDO');
      expect(r.titulo, 'RDO semana 36');
      expect(r.formato, 'html');
    });

    test('relatório ainda gerando não abre', () {
      final r = RelatorioItem.fromLinha({'id': '3', 'status': 'Gerando', 'conteudo': {'nome_relatorio': 'X'}}, ensaio: 'Ensaio');
      expect(r.concluido, isFalse);
    });

    test('conteudo quebrado não derruba a lista', () {
      final r = RelatorioItem.fromLinha({'id': '4', 'status': 'Erro', 'conteudo': '{nao é json'}, ensaio: 'Ensaio');
      expect(r.titulo, 'Relatório sem nome');
    });
  });
}
