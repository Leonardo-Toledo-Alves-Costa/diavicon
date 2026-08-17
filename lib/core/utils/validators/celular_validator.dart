class CelularValidator {
  static String? validar(String? value) {
    if (value == null || value.isEmpty) {
      return 'Obrigatório';
    }
    // A máscara (XX) XXXXX-XXXX tem exatos 15 caracteres
    if (value.length < 15) {
      return 'Celular inválido';
    }
    return null;
  }
}