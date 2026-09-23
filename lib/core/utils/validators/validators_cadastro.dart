import '../../widgets/requisitos_senha.dart';

/// Validadores centralizados para as telas de cadastro.
/// Uso: validator: ValidatorsCadastro.email
class ValidatorsCadastro {
  ValidatorsCadastro._();

  // ── Genérico ───────────────────────────────────────────────────────────────
  // ele aceita uma mensagem opcional personalizada!
  static String? obrigatorio(String? val, [String mensagem = 'Campo obrigatório']) {
    if (val == null || val.trim().isEmpty) return mensagem;
    return null;
  }

  //  Útil para não deixar o cara colocar só "A" no nome e sobrenome
  static String? nome(String? val, [String campo = 'Nome']) {
    if (val == null || val.trim().isEmpty) return 'Informe o $campo';
    if (val.trim().length < 2) return '$campo muito curto';
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
  // Vale para senhas NOVAS (cadastro e troca). O login não usa esta regra,
  // para quem já tem senha antiga de 6 caracteres continuar entrando.
  // Mantenha igual à política do Supabase Auth (ver
  // supabase/SEGURANCA_LOGIN_E_ENTRADAS.md): mínimo 8, letras e números.
  static String? senha(String? val) {
    if (val == null || val.isEmpty) return 'Campo obrigatório';
    if (val.length > 72) return 'Máximo 72 caracteres';
    // Os requisitos ficam em requisitos_senha.dart, junto da lista que a tela
    // mostra: a regra cobrada e o aviso exibido são sempre os mesmos.
    final faltando = [
      for (final r in requisitosSenha)
        if (!r.cumprido(val)) r.texto.toLowerCase(),
    ];
    if (faltando.isEmpty) return null;
    if (faltando.length == 1) return 'Falta ${faltando.first}';
    return 'Falta ${faltando.sublist(0, faltando.length - 1).join(', ')} e ${faltando.last}';
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