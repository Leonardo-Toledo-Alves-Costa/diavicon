import 'package:diavicon/core/models/autor_exibicao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutorExibicao.fromMap', () {
    test('colega de empresa traz nome e foto do autor', () {
      final autor = AutorExibicao.fromMap({
        'autor_id': 'u1',
        'autor_empresa_id': 'e1',
        'empresa_nome': 'ISQ',
        'empresa_logo_url': 'https://x/logo.png',
        'autor_nome': 'Ana Souza',
        'autor_foto_url': 'https://x/ana.png',
      });

      expect(autor.temLogoEmpresa, isTrue);
      expect(autor.temAutorVisivel, isTrue);
      expect(autor.nome, 'Ana Souza');
    });

    test('observador de fora recebe o logo mas nao a identidade do autor', () {
      // É assim que a RPC responde pra quem não é da mesma empresa: as duas
      // colunas do autor vêm nulas do banco.
      final autor = AutorExibicao.fromMap({
        'autor_id': 'u1',
        'autor_empresa_id': 'e1',
        'empresa_nome': 'ISQ',
        'empresa_logo_url': 'https://x/logo.png',
        'autor_nome': null,
        'autor_foto_url': null,
      });

      expect(autor.temLogoEmpresa, isTrue);
      expect(autor.temAutorVisivel, isFalse);
    });

    test('string vazia conta como ausente, nao como valor', () {
      // Sem isso o selo tentaria carregar NetworkImage('') e desenharia um
      // circulo quebrado em vez de cair no icone de fallback.
      final autor = AutorExibicao.fromMap({
        'autor_id': 'u1',
        'empresa_logo_url': '',
        'autor_foto_url': '',
        'autor_nome': '',
      });

      expect(autor.empresaLogoUrl, isNull);
      expect(autor.temLogoEmpresa, isFalse);
      expect(autor.temAutorVisivel, isFalse);
    });
  });
}
