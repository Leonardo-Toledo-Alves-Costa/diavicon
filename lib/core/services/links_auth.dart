import 'package:flutter/foundation.dart' show kIsWeb;

/// Para onde o link de redefinição de senha volta.
///
/// No celular é o endereço do próprio aplicativo (`diavicon://`), registrado
/// no Android e no iOS. No navegador isso não abre nada: precisa ser o
/// endereço do site.
///
/// Na web, volta para a **pasta do app**, e não para a raiz do domínio: o app
/// pode estar numa subpasta ao lado de outro site, como
/// `seudominio.com.br/app`. Quem leva até a tela de nova senha é o ouvinte de
/// `passwordRecovery` no main.dart, então basta cair na página inicial.
///
/// O endereço precisa estar liberado no painel do Supabase, em
/// Authentication › URL Configuration › Redirect URLs.
String get destinoNovaSenha => kIsWeb ? _pastaDoApp() : 'diavicon://nova-senha';

String _pastaDoApp() {
  final atual = Uri.base;
  var caminho = atual.path;
  // Tira o nome do arquivo do fim, quando o endereço aponta direto para ele.
  final barra = caminho.lastIndexOf('/');
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
