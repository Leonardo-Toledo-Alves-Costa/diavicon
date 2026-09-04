import 'package:diavicon/features/projetos/models/projeto_form_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('alternar para cliente existente limpa os dados do convite', () {
    final draft = const ProjetoFormState().withNewClient(
      name: 'Cliente novo',
      email: 'cliente@exemplo.com',
    );

    final updated = draft.withExistingClient(
      id: 'company-1',
      name: 'Cliente cadastrado',
    );

    expect(updated.clienteId, 'company-1');
    expect(updated.clienteNome, 'Cliente cadastrado');
    expect(updated.isNovoCliente, isFalse);
    expect(updated.emailNovoCliente, isNull);
  });

  test('alternar para cliente novo limpa o id do cliente anterior', () {
    final draft = const ProjetoFormState().withExistingClient(
      id: 'company-1',
      name: 'Cliente cadastrado',
    );

    final updated = draft.withNewClient(
      name: 'Cliente novo',
      email: 'cliente@exemplo.com',
    );

    expect(updated.clienteId, isNull);
    expect(updated.isNovoCliente, isTrue);
    expect(updated.emailNovoCliente, 'cliente@exemplo.com');
  });
}
