import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class CnpjFormatter {
  CnpjFormatter._();

  /// Máscara para ser usada no inputFormatters do TextFormField
  static final mask = MaskTextInputFormatter(
    mask: '##.###.###/####-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  /// Aplica a máscara em uma String 
  static String format(String value) {
    final numbers = unformat(value);
    if (numbers.length != 14) return value;
    return '${numbers.substring(0, 2)}.${numbers.substring(2, 5)}.${numbers.substring(5, 8)}/${numbers.substring(8, 12)}-${numbers.substring(12, 14)}';
  }

  /// Remove a máscara, retornando apenas os números
  static String unformat(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }
}