import 'package:diavicon/features/elementos/models/elemento_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ElementoModel marcacaoImagemUrl', () {
    test('lê e serializa a URL da imagem de marcação', () {
      final elemento = ElementoModel.fromMap({
        'id': 'elemento-1',
        'marcacao_imagem_url': 'https://example.com/marcacao.png?v=1',
      });

      expect(
        elemento.marcacaoImagemUrl,
        'https://example.com/marcacao.png?v=1',
      );
      expect(
        elemento.toMap()['marcacao_imagem_url'],
        'https://example.com/marcacao.png?v=1',
      );
    });

    test('copyWith atualiza a URL sem alterar os demais dados', () {
      final elemento = ElementoModel(id: 'elemento-1', nome: 'Pilar P1');

      final atualizado = elemento.copyWith(
        marcacaoImagemUrl: 'https://example.com/marcacao.png?v=2',
      );

      expect(atualizado.id, 'elemento-1');
      expect(atualizado.nome, 'Pilar P1');
      expect(
        atualizado.marcacaoImagemUrl,
        'https://example.com/marcacao.png?v=2',
      );
    });
  });
}
