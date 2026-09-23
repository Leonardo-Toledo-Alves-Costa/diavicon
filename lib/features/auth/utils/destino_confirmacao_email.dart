import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Endereço público da página "E-mail confirmado", publicada junto do web app.
///
/// Fica na pasta do app (`/app/`), ao lado do WordPress que ocupa a raiz do
/// domínio. É o padrão do celular e a reserva do navegador.
const String kPaginaEmailConfirmado = 'https://diavicon.com.br/app/email-confirmado.html';

/// Para onde o link de confirmação de e-mail leva depois que o Supabase
/// confirma a conta.
///
/// Sempre a página `email-confirmado.html`: ela mostra "E-mail confirmado!",
/// tem o botão "Abrir o app Diavicon" (link `diavicon://login-callback`) e
/// "Continuar no navegador" — e funciona mesmo quando a pessoa abre o e-mail
/// no computador.
///
/// Ordem:
///  1. `URL_CONFIRMACAO_EMAIL` no `.env`, se alguém quiser outro endereço;
///  2. no navegador, a página na PASTA do app que está aberto
///     (`.../app/email-confirmado.html`);
///  3. senão (celular), [kPaginaEmailConfirmado].
///
/// Antes o navegador mandava para a RAIZ do domínio
/// (`diavicon.com.br/email-confirmado.html`), onde a página não existe — o
/// app mora em `/app/`. E o celular mandava para `diavicon://login-callback`,
/// que não abre nada quando o e-mail é lido no computador. Nos dois casos a
/// pessoa caía numa página genérica, sem saber se tinha dado certo.
///
/// O endereço usado precisa estar em Authentication › URL Configuration ›
/// Redirect URLs no Supabase; se não estiver, o Supabase manda para o Site URL.
String destinoConfirmacaoEmail() {
  final configurado = dotenv.isInitialized ? dotenv.env['URL_CONFIRMACAO_EMAIL']?.trim() : null;
  if (configurado != null && configurado.isNotEmpty) return configurado;
  if (kIsWeb) return '${_pastaDoApp()}email-confirmado.html';
  return kPaginaEmailConfirmado;
}

/// Pasta onde o web app está publicado, com a barra no fim
/// (ex.: `https://diavicon.com.br/app/`).
String _pastaDoApp() {
  final atual = Uri.base;
  var caminho = atual.path;
  final barra = caminho.lastIndexOf('/');
  // Tira o nome do arquivo do fim, quando o endereço aponta direto para ele.
  if (barra >= 0 && caminho.substring(barra + 1).contains('.')) {
    caminho = caminho.substring(0, barra + 1);
  }
  if (!caminho.endsWith('/')) caminho = '$caminho/';
  return Uri(
    scheme: atual.scheme,
    host: atual.host,
    port: atual.hasPort ? atual.port : null,
    path: caminho,
  ).toString();
}
