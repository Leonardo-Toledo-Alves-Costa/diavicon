import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

enum NivelRelatorios { elemento, estrutura, projeto }

/// Um relatório gerado, de qualquer ensaio (ou RDO), como a tela única de
/// relatórios mostra.
class RelatorioItem {
  final String id;
  final String titulo;

  /// Nome do ensaio ("Inspeção Visual", "Carbonatação"...) ou "RDO".
  final String ensaio;
  final String status;
  final DateTime criadoEm;
  final String? url;
  final String? formato;

  /// Arquivo à parte da tabela resumo (inspeção visual).
  final String? urlResumo;

  const RelatorioItem({
    required this.id,
    required this.titulo,
    required this.ensaio,
    required this.status,
    required this.criadoEm,
    this.url,
    this.formato,
    this.urlResumo,
  });

  bool get concluido => status == 'Concluído' && url != null;

  factory RelatorioItem.fromLinha(Map<String, dynamic> m, {required String ensaio}) {
    final bruto = m['conteudo'];
    Map<String, dynamic> conteudo = const {};
    if (bruto is Map) {
      conteudo = bruto.cast<String, dynamic>();
    } else if (bruto is String && bruto.isNotEmpty) {
      try {
        final d = jsonDecode(bruto);
        if (d is Map) conteudo = d.cast<String, dynamic>();
      } catch (_) {}
    }
    return RelatorioItem(
      id: m['id'].toString(),
      titulo: conteudo['nome_relatorio']?.toString() ?? 'Relatório sem nome',
      ensaio: ensaio,
      status: m['status']?.toString() ?? '-',
      criadoEm: DateTime.tryParse(m['criado_em']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      url: conteudo['url_arquivo']?.toString(),
      formato: conteudo['formato']?.toString(),
      urlResumo: conteudo['url_resumo']?.toString(),
    );
  }
}

/// Minúsculas e sem acento: quem busca "inspecao" acha "Inspeção".
String _normalizar(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const para = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  final b = StringBuffer();
  for (final c in s.split('')) {
    final i = de.indexOf(c);
    b.write(i >= 0 ? para[i] : c);
  }
  return b.toString().toLowerCase();
}

/// Filtra por título OU nome do ensaio. Cada palavra digitada precisa
/// aparecer em algum dos dois ("carbonatacao torre" acha "Relatório Torre A"
/// de carbonatação).
List<RelatorioItem> filtrarRelatorios(List<RelatorioItem> itens, String busca) {
  final termos = _normalizar(busca).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (termos.isEmpty) return itens;
  return itens.where((r) {
    final alvo = _normalizar('${r.titulo} ${r.ensaio}');
    return termos.every(alvo.contains);
  }).toList();
}

/// Busca todos os relatórios de um elemento, estrutura ou projeto.
class RelatoriosItemRepository {
  final SupabaseClient _s;
  RelatoriosItemRepository(this._s);

  Future<List<RelatorioItem>> buscar({
    required NivelRelatorios nivel,
    String? projetoId,
    String? estruturaId,
    String? elementoId,
  }) async {
    final tiposResp = await _s.from('tipos_ensaio').select('id, nome');
    final nomeDoTipo = {
      for (final t in (tiposResp as List)) t['id'].toString(): t['nome']?.toString() ?? 'Ensaio',
    };

    var q = _s.from('relatorio_ensaio').select('id, criado_em, conteudo, status, tipo_ensaio_id');
    switch (nivel) {
      case NivelRelatorios.projeto:
        q = q.eq('projeto_id', projetoId!);
      case NivelRelatorios.estrutura:
        q = q.eq('estrutura_id', estruturaId!);
        if (projetoId != null) q = q.eq('projeto_id', projetoId);
      case NivelRelatorios.elemento:
        // Relatórios são gerados por estrutura + ensaio e não guardam o
        // elemento. Mostra os da estrutura dele, só dos TIPOS de ensaio que
        // têm ponto neste elemento — os que podem incluí-lo.
        var pontosQ = _s.from('pontos_ensaios_geral').select('tipo_ensaio_id').eq('elemento_estrutural_id', elementoId!);
        if (projetoId != null) pontosQ = pontosQ.eq('projeto_id', projetoId);
        final tipos = (await pontosQ as List).map((p) => p['tipo_ensaio_id']?.toString()).whereType<String>().toSet().toList();
        if (tipos.isEmpty) return const [];

        var estrutura = estruturaId;
        estrutura ??= (await _s.from('elementos_estruturais').select('estrutura_id').eq('id', elementoId).maybeSingle())?['estrutura_id']?.toString();
        if (estrutura == null) return const [];

        q = q.eq('estrutura_id', estrutura).inFilter('tipo_ensaio_id', tipos);
        if (projetoId != null) q = q.eq('projeto_id', projetoId);
    }

    final linhas = await q.order('criado_em', ascending: false);
    final itens = [
      for (final m in (linhas as List))
        RelatorioItem.fromLinha((m as Map).cast<String, dynamic>(), ensaio: nomeDoTipo[m['tipo_ensaio_id']?.toString()] ?? 'Ensaio'),
    ];

    // RDO é relatório de projeto — só entra no nível projeto.
    if (nivel == NivelRelatorios.projeto) {
      final rdos = await _s.from('relatorio_rdo').select('id, criado_em, conteudo, status').eq('projeto_id', projetoId!);
      itens.addAll([for (final m in (rdos as List)) RelatorioItem.fromLinha((m as Map).cast<String, dynamic>(), ensaio: 'RDO')]);
      itens.sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
    }
    return itens;
  }
}
