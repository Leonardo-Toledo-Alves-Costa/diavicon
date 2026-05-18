class ValidatorsCadastro {
  static String? campoObrigatorio(String? value, {String campo = 'Campo'}) {
    if (value == null || value.trim().isEmpty) {
      return '$campo obrigatório';
    }
    return null;
  }

  static String? validarCNPJ(String? value) {
    if (value == null || value.isEmpty) {
      return 'CNPJ obrigatório';
    }

    final numeros = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeros.length != 14) {
      return 'CNPJ inválido';
    }

    return null;
  }

  static String? validarCEP(String? value) {
    if (value == null || value.isEmpty) {
      return 'CEP obrigatório';
    }

    final numeros = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeros.length != 8) {
      return 'CEP inválido';
    }

    return null;
  }

  static String? validarUrl(String? value) {
    if (value == null || value.isEmpty) return null;

    final uri = Uri.tryParse(value);

    if (uri == null) {
      return 'URL inválida';
    }

    return null;
  }
}