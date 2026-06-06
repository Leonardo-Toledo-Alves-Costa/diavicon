/// Validadores centralizados para as telas de cadastro.
/// Uso: validator: ValidatorsCadastro.email
class ValidatorsCadastro {
  ValidatorsCadastro._();

  // ── Genérico ───────────────────────────────────────────────────────────────
  static String? obrigatorio(String? val) {
    if (val == null || val.trim().isEmpty) return 'Campo obrigatório';
    return null;
  }

  // ── E-mail ─────────────────────────────────────────────────────────────────
  static String? email(String? val) {
    if (val == null || val.trim().isEmpty) return 'Campo obrigatório';
    final regex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!regex.hasMatch(val.trim())) return 'E-mail inválido';
    return null;
  }

  // ── Senha ──────────────────────────────────────────────────────────────────
  static String? senha(String? val) {
    if (val == null || val.isEmpty) return 'Campo obrigatório';
    if (val.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  /// Valida confirmação de senha comparando com a senha original.
  /// Uso: validator: (val) => ValidatorsCadastro.confirmarSenha(val, _senhaController.text)
  static String? confirmarSenha(String? val, String senhaOriginal) {
    if (val == null || val.isEmpty) return 'Campo obrigatório';
    if (val != senhaOriginal) return 'As senhas não conferem';
    return null;
  }

  // ── Telefone ───────────────────────────────────────────────────────────────
  static String? telefone(String? val) {
    if (val == null || val.trim().isEmpty) return 'Campo obrigatório';
    final digits = val.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 11) return 'Telefone inválido';
    return null;
  }

  // ── CNPJ ───────────────────────────────────────────────────────────────────
  static String? cnpj(String? val) {
    if (val == null || val.trim().isEmpty) return 'Campo obrigatório';
    final digits = val.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 14) return 'CNPJ inválido';
    return null;
  }

  // ── CEP ────────────────────────────────────────────────────────────────────
  static String? cep(String? val) {
    if (val == null || val.trim().isEmpty) return 'Campo obrigatório';
    final digits = val.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return 'CEP inválido';
    return null;
  }

  // ── URL (opcional) ─────────────────────────────────────────────────────────
  /// Valida URL apenas se o campo foi preenchido (campo opcional).
  static String? urlOpcional(String? val) {
    if (val == null || val.trim().isEmpty) return null; // opcional
    final regex = RegExp(r'^(https?:\/\/)?([\w-]+\.)+[\w-]{2,}(\/\S*)?$');
    if (!regex.hasMatch(val.trim())) return 'URL inválida';
    return null;
  }

  // ── Dropdown ───────────────────────────────────────────────────────────────
  static String? dropdown(String? val, {String mensagem = 'Selecione uma opção'}) {
    if (val == null) return mensagem;
    return null;
  }
}