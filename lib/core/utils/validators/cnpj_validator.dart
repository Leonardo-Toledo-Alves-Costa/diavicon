class CnpjValidator {
  CnpjValidator._(); 

  static bool isValid(String? cnpj) {
    if (cnpj == null || cnpj.isEmpty) return false;

    // Remove qualquer caractere que não seja número
    final String numbers = cnpj.replaceAll(RegExp(r'[^0-9]'), '');

    // Verifica se tem 14 dígitos
    if (numbers.length != 14) return false;

    // Bloqueia CNPJs com todos os números iguais
    if (RegExp(r'^(\d)\1*$').hasMatch(numbers)) return false;

    final List<int> digits = numbers.split('').map(int.parse).toList();

    // Cálculo do primeiro dígito verificador
    int calc1 = 0;
    final List<int> weights1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    for (int i = 0; i < 12; i++) {
      calc1 += digits[i] * weights1[i];
    }
    calc1 = calc1 % 11;
    calc1 = calc1 < 2 ? 0 : 11 - calc1;

    if (digits[12] != calc1) return false;

    // Cálculo do segundo dígito verificador
    int calc2 = 0;
    final List<int> weights2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    for (int i = 0; i < 13; i++) {
      calc2 += digits[i] * weights2[i];
    }
    calc2 = calc2 % 11;
    calc2 = calc2 < 2 ? 0 : 11 - calc2;

    if (digits[13] != calc2) return false;

    return true;
  }
}