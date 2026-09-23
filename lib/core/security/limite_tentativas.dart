import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Limite de tentativas no próprio app (login e envio de e-mail de
// recuperação), com espera progressiva.
//
// IMPORTANTE: isto protege o fluxo normal do app e dá retorno claro ao
// usuário, mas NÃO substitui a proteção do servidor — quem ataca por força
// bruta chama a API do Supabase direto, sem passar pelo app. A barreira real
// é o limite de requisições do Supabase Auth + CAPTCHA (ver
// supabase/SEGURANCA_LOGIN_E_ENTRADAS.md). O estado fica salvo no aparelho
// (sobrevive a fechar o app / recarregar a página), sem guardar o e-mail em
// texto puro.

/// Regras de espera: [livres] falhas sem espera; depois, cada falha aplica o
/// próximo degrau de [escada] (o último se repete).
class PoliticaTentativas {
  final int livres;
  final List<Duration> escada;

  /// Falhas mais antigas que isso são esquecidas.
  final Duration esquecerApos;

  /// Limite por aparelho (qualquer conta): mais de [maxNoAparelho] falhas
  /// dentro de [janelaAparelho] bloqueiam por [bloqueioAparelho].
  final int maxNoAparelho;
  final Duration janelaAparelho;
  final Duration bloqueioAparelho;

  const PoliticaTentativas({
    required this.livres,
    required this.escada,
    this.esquecerApos = const Duration(hours: 24),
    this.maxNoAparelho = 10,
    this.janelaAparelho = const Duration(minutes: 15),
    this.bloqueioAparelho = const Duration(minutes: 5),
  });

  /// Login: 3 erros livres, depois 30 s, 1 min, 2 min, 5 min e 15 min.
  static const login = PoliticaTentativas(
    livres: 3,
    escada: [
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 2),
      Duration(minutes: 5),
      Duration(minutes: 15),
    ],
  );

  /// E-mail de recuperação: 1 min entre envios; a partir do 3º, 15 min.
  static const recuperacao = PoliticaTentativas(
    livres: 0,
    escada: [Duration(minutes: 1), Duration(minutes: 1), Duration(minutes: 15)],
    esquecerApos: Duration(hours: 1),
    maxNoAparelho: 5,
    janelaAparelho: Duration(hours: 1),
    bloqueioAparelho: Duration(minutes: 30),
  );

  Duration esperaPara(int falhas) {
    if (falhas <= livres || escada.isEmpty) return Duration.zero;
    final i = (falhas - livres - 1).clamp(0, escada.length - 1);
    return escada[i];
  }
}

/// Onde o estado fica guardado (trocável nos testes).
abstract class ArmazenamentoTentativas {
  Future<String?> ler(String chave);
  Future<void> gravar(String chave, String valor);
  Future<void> apagar(String chave);
}

class ArmazenamentoSeguroTentativas implements ArmazenamentoTentativas {
  final FlutterSecureStorage _s;
  final Map<String, String> _reserva = {};
  ArmazenamentoSeguroTentativas([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();

  // Se o armazenamento seguro falhar (navegador sem WebCrypto, keystore
  // indisponível), segue com memória em vez de travar o login.
  @override
  Future<String?> ler(String chave) async {
    try {
      return await _s.read(key: chave) ?? _reserva[chave];
    } catch (e) {
      debugPrint('LimiteTentativas: leitura falhou ($e)');
      return _reserva[chave];
    }
  }

  @override
  Future<void> gravar(String chave, String valor) async {
    _reserva[chave] = valor;
    try {
      await _s.write(key: chave, value: valor);
    } catch (e) {
      debugPrint('LimiteTentativas: gravação falhou ($e)');
    }
  }

  @override
  Future<void> apagar(String chave) async {
    _reserva.remove(chave);
    try {
      await _s.delete(key: chave);
    } catch (_) {}
  }
}

class ArmazenamentoMemoriaTentativas implements ArmazenamentoTentativas {
  final Map<String, String> dados = {};
  @override
  Future<String?> ler(String chave) async => dados[chave];
  @override
  Future<void> gravar(String chave, String valor) async => dados[chave] = valor;
  @override
  Future<void> apagar(String chave) async => dados.remove(chave);
}

class LimiteTentativas {
  final String escopo;
  final PoliticaTentativas politica;
  final ArmazenamentoTentativas _armazenamento;
  final DateTime Function() _agora;

  LimiteTentativas({
    required this.escopo,
    required this.politica,
    ArmazenamentoTentativas? armazenamento,
    DateTime Function()? agora,
  })  : _armazenamento = armazenamento ?? ArmazenamentoSeguroTentativas(),
        _agora = agora ?? DateTime.now;

  /// Quanto falta para poder tentar de novo com esta conta (zero = liberado).
  Future<Duration> esperaRestante(String conta) async {
    final agora = _agora();
    final estadoConta = await _lerConta(conta);
    final aparelho = await _lerAparelho();
    var ate = estadoConta.bloqueadoAte;
    if (aparelho.bloqueadoAte != null && (ate == null || aparelho.bloqueadoAte!.isAfter(ate))) {
      ate = aparelho.bloqueadoAte;
    }
    if (ate == null || !ate.isAfter(agora)) return Duration.zero;
    return ate.difference(agora);
  }

  /// Registra uma falha (login) ou um envio (recuperação) e devolve a espera
  /// que passa a valer.
  Future<Duration> registrar(String conta) async {
    final agora = _agora();

    final c = await _lerConta(conta);
    final falhas = (c.ultima != null && agora.difference(c.ultima!) > politica.esquecerApos) ? 1 : c.falhas + 1;
    final espera = politica.esperaPara(falhas);
    await _armazenamento.gravar(
      _chaveConta(conta),
      jsonEncode({
        'f': falhas,
        'u': agora.millisecondsSinceEpoch,
        if (espera > Duration.zero) 'b': agora.add(espera).millisecondsSinceEpoch,
      }),
    );

    final a = await _lerAparelho();
    final recentes = [...a.falhas.where((t) => agora.difference(t) < politica.janelaAparelho), agora];
    final bloqueioAparelho = recentes.length > politica.maxNoAparelho ? agora.add(politica.bloqueioAparelho) : a.bloqueadoAte;
    final manter = recentes.length > 30 ? recentes.sublist(recentes.length - 30) : recentes;
    await _armazenamento.gravar(
      _chaveAparelho,
      jsonEncode({
        't': [for (final t in manter) t.millisecondsSinceEpoch],
        if (bloqueioAparelho != null) 'b': bloqueioAparelho.millisecondsSinceEpoch,
      }),
    );

    return esperaRestante(conta);
  }

  /// Login certo: zera o contador da conta (o do aparelho expira sozinho).
  Future<void> limpar(String conta) => _armazenamento.apagar(_chaveConta(conta));

  // ── internos ──────────────────────────────────────────────────────────

  String get _chaveAparelho => 'lim_${escopo}_aparelho';
  String _chaveConta(String conta) => 'lim_${escopo}_${_resumo(conta.trim().toLowerCase())}';

  /// Resumo (hash) do e-mail — dois hashes polinomiais de 32 bits, que dão o
  /// mesmo resultado no app e no navegador. Não é criptográfico: serve só
  /// para o e-mail não ficar gravado em texto puro no aparelho.
  static String _resumo(String texto) {
    var h1 = 7, h2 = 11;
    for (final c in texto.codeUnits) {
      h1 = (h1 * 31 + c) % 4294967291;
      h2 = (h2 * 131 + c) % 4294967279;
    }
    return '${h1.toRadixString(16)}${h2.toRadixString(16)}';
  }

  Future<({int falhas, DateTime? ultima, DateTime? bloqueadoAte})> _lerConta(String conta) async {
    try {
      final bruto = await _armazenamento.ler(_chaveConta(conta));
      if (bruto == null) return (falhas: 0, ultima: null, bloqueadoAte: null);
      final m = jsonDecode(bruto) as Map<String, dynamic>;
      DateTime? data(Object? v) => v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;
      return (falhas: (m['f'] as num?)?.toInt() ?? 0, ultima: data(m['u']), bloqueadoAte: data(m['b']));
    } catch (_) {
      return (falhas: 0, ultima: null, bloqueadoAte: null);
    }
  }

  Future<({List<DateTime> falhas, DateTime? bloqueadoAte})> _lerAparelho() async {
    try {
      final bruto = await _armazenamento.ler(_chaveAparelho);
      if (bruto == null) return (falhas: const <DateTime>[], bloqueadoAte: null);
      final m = jsonDecode(bruto) as Map<String, dynamic>;
      final t = (m['t'] as List? ?? const []).whereType<int>().map(DateTime.fromMillisecondsSinceEpoch).toList();
      final b = m['b'];
      return (falhas: t, bloqueadoAte: b is int ? DateTime.fromMillisecondsSinceEpoch(b) : null);
    } catch (_) {
      return (falhas: const <DateTime>[], bloqueadoAte: null);
    }
  }
}

/// "45 s", "2 min", "1 min 30 s" — para as mensagens de espera.
String formatarEspera(Duration d) {
  final s = d.inSeconds + (d.inMilliseconds % 1000 > 0 ? 1 : 0);
  if (s < 60) return '$s s';
  final m = s ~/ 60, r = s % 60;
  return r == 0 ? '$m min' : '$m min $r s';
}
