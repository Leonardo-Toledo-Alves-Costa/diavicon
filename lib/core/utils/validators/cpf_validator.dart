
class CpfValidator {
  CpfValidator._(); 

  static bool isValid(String? cpf) {
    if (cpf == null || cpf.isEmpty) return false;

    // Remove qualquer caractere que não seja número
    final String numbers = cpf.replaceAll(RegExp(r'[^0-9]'), '');

    // Verifica se tem 11 dígitos
    if (numbers.length != 11) return false;

    // Bloqueia CPFs com todos os números iguais (ex: 111.111.111-11)
    if (RegExp(r'^(\d)\1*$').hasMatch(numbers)) return false;

    // Converte a string em uma lista de inteiros
    final List<int> digits = numbers.split('').map(int.parse).toList();

    // Cálculo do primeiro dígito verificador
    int calc1 = 0;
    for (int i = 0; i < 9; i++) {
      calc1 += digits[i] * (10 - i);
    }
    calc1 = (calc1 * 10) % 11;
    if (calc1 == 10) calc1 = 0;

    if (digits[9] != calc1) return false;

    // Cálculo do segundo dígito verificador
    int calc2 = 0;
    for (int i = 0; i < 10; i++) {
      calc2 += digits[i] * (11 - i);
    }
    calc2 = (calc2 * 10) % 11;
    if (calc2 == 10) calc2 = 0;

    if (digits[10] != calc2) return false;

    return true;
  }
}