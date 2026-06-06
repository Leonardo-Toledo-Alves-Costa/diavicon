import 'package:flutter/services.dart';

/// Formatadores centralizados para campos de cadastro.
/// Uso: inputFormatters: [FormattersCadastro.cnpj]
class FormattersCadastro {
  FormattersCadastro._();

  /// CNPJ: XX.XXX.XXX/XXXX-XX
  static final TextInputFormatter cnpj = _CnpjFormatter();

  /// CEP: XXXXX-XXX
  static final TextInputFormatter cep = _CepFormatter();

  /// Telefone: (XX) 9 XXXX-XXXX ou (XX) XXXX-XXXX
  static final TextInputFormatter telefone = _TelefoneFormatter();
}

// ── CNPJ ──────────────────────────────────────────────────────────────────────
class _CnpjFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length && i < 14; i++) {
      if (i == 2 || i == 5) buffer.write('.');
      if (i == 8) buffer.write('/');
      if (i == 12) buffer.write('-');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ── CEP ───────────────────────────────────────────────────────────────────────
class _CepFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length && i < 8; i++) {
      if (i == 5) buffer.write('-');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ── Telefone ──────────────────────────────────────────────────────────────────
class _TelefoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    // Identifica dinamicamente se é celular (11 dígitos) ou fixo (10 dígitos)
    final isCelular = digits.length == 11;

    for (int i = 0; i < digits.length && i < 11; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');
      
      
      if (isCelular && i == 3) buffer.write(' '); 
      
      if (!isCelular && i == 6) buffer.write('-');
      if (isCelular && i == 7) buffer.write('-');
      
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}