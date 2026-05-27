class CepValidator {
  CepValidator._(); 

  static bool isValid(String? cep) {
    if (cep == null || cep.isEmpty) return false;

    // Remove qualquer caractere que não seja número (ex: o traço)
    final String numbers = cep.replaceAll(RegExp(r'[^0-9]'), '');

    // Um CEP brasileiro possui exatamente 8 dígitos numéricos
    if (numbers.length != 8) return false;

    // Bloqueia CEPs preenchidos com o mesmo número (ex: 00000-000)
    // Embora os correios tenham alguns CEPs genéricos, a maioria dos sistemas bloqueia
    if (RegExp(r'^(\d)\1*$').hasMatch(numbers)) return false;

    return true;
  }
}