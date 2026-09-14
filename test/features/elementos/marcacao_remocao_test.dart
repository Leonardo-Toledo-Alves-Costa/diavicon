import 'package:diavicon/features/elementos/repositories/elemento_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remoção limpa somente os campos da marcação em planta', () {
    const patch = ElementoRepository.marcacaoRemovidaPatch;

    expect(
      patch.keys,
      containsAll(<String>[
        'planta_id',
        'posicao_x',
        'posicao_y',
        'tipo_marcacao',
        'marcacao_largura',
        'marcacao_altura',
        'marcacao_rotacao',
        'marcacao_cor',
        'marcacao_nome_x',
        'marcacao_nome_y',
        'marcacao_imagem_url',
      ]),
    );
    expect(patch.values, everyElement(isNull));
    expect(patch, isNot(contains('posicao_z')));
    expect(patch, isNot(contains('fotos')));
    expect(patch, isNot(contains('ativo')));
  });
}
