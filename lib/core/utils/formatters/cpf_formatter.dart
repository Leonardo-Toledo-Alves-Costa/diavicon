
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class CpfFormatter {
  CpfFormatter._();

  /// Máscara para ser usada no inputFormatters do TextFormField
  static final mask = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  /// Aplica a máscara em uma String 
  static String format(String value) {
    final numbers = unformat(value);
    if (numbers.length != 11) return value;
    return '${numbers.substring(0, 3)}.${numbers.substring(3, 6)}.${numbers.substring(6, 9)}-${numbers.substring(9, 11)}';
  }

  /// Remove a máscara, retornando apenas os números
  static String unformat(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }
}