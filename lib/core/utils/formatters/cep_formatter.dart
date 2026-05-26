import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class CepFormatter {
  CepFormatter._();

  /// Máscara para ser usada no inputFormatters do TextFormField
  static final mask = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  /// Aplica a máscara em uma String (ex: 12345678 -> 12345-678)
  static String format(String value) {
    final numbers = unformat(value);
    if (numbers.length != 8) return value;
    return '${numbers.substring(0, 5)}-${numbers.substring(5, 8)}';
  }

  /// Remove a máscara, retornando apenas os números
  static String unformat(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }
}