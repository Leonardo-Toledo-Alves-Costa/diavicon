import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/limite_tentativas.dart';

/// O app bloqueou novas tentativas por um tempo (limite local de
/// tentativas — ver core/security/limite_tentativas.dart).
class TentativasExcedidasException implements Exception {
  final Duration espera;
  const TentativasExcedidasException(this.espera);

  @override
  String toString() =>
      'Muitas tentativas. Por segurança, aguarde ${formatarEspera(espera)} para tentar de novo.';
}

/// Texto único do acesso suspenso — a tela de entrada e o aviso de saída
/// dizem a mesma coisa.
const mensagemAcessoSuspenso =
    'Seu acesso foi suspenso pelo administrador da empresa. '
    'Fale com quem administra a conta da sua empresa.';

/// O perfil está suspenso (`ativo = false`). A sessão é encerrada na hora e a
/// pessoa não entra de novo enquanto o acesso não voltar.
class AcessoSuspensoException implements Exception {
  final String mensagem;
  const AcessoSuspensoException([this.mensagem = mensagemAcessoSuspenso]);

  @override
  String toString() => mensagem;
}

/// O Supabase Auth recusou a entrada porque a conta está banida — é o que a
/// suspensão faz no servidor, então a pessoa vê o mesmo texto.
bool ehContaBanida(Object error) {
  if (error is! AuthException) return false;
  final code = (error.code ?? '').toLowerCase();
  return code == 'user_banned' || error.message.toLowerCase().contains('banned');
}

/// E-mail/senha não conferem (a resposta do Auth é a mesma para conta
/// inexistente e senha errada — e a mensagem do app também, para não revelar
/// quais e-mails têm conta).
bool ehCredencialInvalida(Object error) {
  if (error is! AuthException) return false;
  final code = (error.code ?? '').toLowerCase();
  final msg = error.message.toLowerCase();
  return code == 'invalid_credentials' ||
      code == 'invalid_grant' ||
      msg.contains('invalid login credentials') ||
      (error.statusCode == '400' && msg.contains('invalid'));
}

/// O servidor recusou por excesso de requisições (limite do Supabase Auth).
bool ehLimiteDoServidor(Object error) {
  if (error is! AuthException) return false;
  final code = (error.code ?? '').toLowerCase();
  return error.statusCode == '429' ||
      code.startsWith('over_') ||
      error.message.toLowerCase().contains('rate limit');
}

/// Converts provider errors that are safe to expose into concise Portuguese UI
/// messages. In particular, Supabase may report leaked-password protection as
/// either a `weak_password` code or a provider-specific message.
String authErrorMessage(Object error, {String fallback = 'Não foi possível concluir a operação.'}) {
  if (error is AcessoSuspensoException) return error.mensagem;
  if (ehContaBanida(error)) return mensagemAcessoSuspenso;
  if (error is TentativasExcedidasException) return error.toString();
  if (ehLimiteDoServidor(error)) {
    return 'Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente de novo.';
  }
  if (ehCredencialInvalida(error)) return 'E-mail ou senha incorretos.';

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
