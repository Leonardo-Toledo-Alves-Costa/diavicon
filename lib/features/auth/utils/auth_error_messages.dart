import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts provider errors that are safe to expose into concise Portuguese UI
/// messages. In particular, Supabase may report leaked-password protection as
/// either a `weak_password` code or a provider-specific message.
String authErrorMessage(Object error, {String fallback = 'Não foi possível concluir a operação.'}) {
  final raw = error.toString();
  final value = raw.toLowerCase();
  if (value.contains('weak_password') ||
      value.contains('leaked') ||
      value.contains('compromised') ||
      value.contains('data breach') ||
      value.contains('vazamento') ||
      value.contains('haveibeenpwned')) {
    return 'Esta senha foi encontrada em vazamentos. Escolha outra senha ou use a recuperação de senha.';
  }
  if (value.contains('confirm') || value.contains('email_not_confirmed')) {
    return 'Confirme seu e-mail antes de continuar.';
  }
  // Avoid exposing provider status codes or raw response metadata for errors
  // that do not have a known safe translation.
  if (error is AuthException) return fallback;
  return raw.replaceFirst('Exception: ', '').trim().isEmpty
      ? fallback
      : raw.replaceFirst('Exception: ', '').trim();
}
