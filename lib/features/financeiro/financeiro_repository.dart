import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Controle financeiro das empresas clientes (contrato + cobranças mensais).
///
/// Tabelas `empresa_contratos` e `empresa_cobrancas` e bucket privado
/// `financeiro` (migration 20260922100000_financeiro_empresas.sql). O
/// servidor decide quem vê o quê: o administrador principal da DIAVICON lê e
/// grava tudo; o Gestor da empresa cliente só lê o que é da própria empresa.

// ---------------------------------------------------------------------------
// Modelos
// ---------------------------------------------------------------------------

/// Status mostrado na tela. `atrasado` não é gravado: é uma cobrança
/// pendente com o vencimento já passado.
enum StatusCobranca { pendente, atrasado, pago, cancelado }

extension StatusCobrancaRotulo on StatusCobranca {
  String get rotulo => switch (this) {
        StatusCobranca.pendente => 'Pendente',
        StatusCobranca.atrasado => 'Atrasado',
        StatusCobranca.pago => 'Pago',
        StatusCobranca.cancelado => 'Cancelado',
      };

  /// Valor gravado no banco (atrasado é gravado como pendente).
  String get valorBanco => this == StatusCobranca.atrasado ? 'pendente' : name;
}

class ContratoEmpresa {
  final String id;
  final String? empresaId;
  final String clienteNome;
  final String planoId;
  final String? planoNome;
  final double valorMensal;
  final int diaVencimento;
  final DateTime inicio;
  final DateTime? fim;
  final String especificidades;
  final bool ativo;

  const ContratoEmpresa({
    required this.id,
    required this.empresaId,
    required this.clienteNome,
    required this.planoId,
    this.planoNome,
    required this.valorMensal,
    required this.diaVencimento,
    required this.inicio,
    this.fim,
    this.especificidades = '',
    this.ativo = true,
  });

  factory ContratoEmpresa.fromMap(Map<String, dynamic> m) {
    final plano = m['planos'];
    return ContratoEmpresa(
      id: '${m['id']}',
      empresaId: m['cliente_empresa_id'] as String?,
      clienteNome: '${m['cliente_nome'] ?? ''}',
      planoId: '${m['plano_id']}',
      planoNome: plano is Map ? plano['nome'] as String? : null,
      valorMensal: _numero(m['valor_mensal']),
      diaVencimento: (m['dia_vencimento'] as num?)?.toInt() ?? 10,
      inicio: DateTime.parse('${m['inicio']}'),
      fim: m['fim'] == null ? null : DateTime.tryParse('${m['fim']}'),
      especificidades: '${m['especificidades'] ?? ''}',
      ativo: m['ativo'] == true,
    );
  }
}

class CobrancaEmpresa {
  final String id;
  final String? empresaId;
  final String clienteNome;
  final String? contratoId;
  final DateTime competencia;
  final String descricao;
  final double valor;
  final DateTime vencimento;
  final String statusBanco;
  final DateTime? pagoEm;
  final String? boletoPath;
  final String? notaFiscalPath;
  final String observacao;

  const CobrancaEmpresa({
    required this.id,
    required this.empresaId,
    required this.clienteNome,
    this.contratoId,
    required this.competencia,
    this.descricao = '',
    required this.valor,
    required this.vencimento,
    required this.statusBanco,
    this.pagoEm,
    this.boletoPath,
    this.notaFiscalPath,
    this.observacao = '',
  });

  StatusCobranca get status {
    switch (statusBanco) {
      case 'pago':
        return StatusCobranca.pago;
      case 'cancelado':
        return StatusCobranca.cancelado;
      default:
        final hoje = DateTime.now();
        final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
        return vencimento.isBefore(hojeSemHora) ? StatusCobranca.atrasado : StatusCobranca.pendente;
    }
  }

  /// Ainda precisa ser paga (pendente ou atrasada).
  bool get emAberto => status == StatusCobranca.pendente || status == StatusCobranca.atrasado;

  factory CobrancaEmpresa.fromMap(Map<String, dynamic> m) => CobrancaEmpresa(
        id: '${m['id']}',
        empresaId: m['cliente_empresa_id'] as String?,
        clienteNome: '${m['cliente_nome'] ?? ''}',
        contratoId: m['contrato_id'] as String?,
        competencia: DateTime.parse('${m['competencia']}'),
        descricao: '${m['descricao'] ?? ''}',
        valor: _numero(m['valor']),
        vencimento: DateTime.parse('${m['vencimento']}'),
        statusBanco: '${m['status'] ?? 'pendente'}',
        pagoEm: m['pago_em'] == null ? null : DateTime.tryParse('${m['pago_em']}'),
        boletoPath: (m['boleto_path'] as String?)?.isNotEmpty == true ? m['boleto_path'] as String : null,
        notaFiscalPath: (m['nota_fiscal_path'] as String?)?.isNotEmpty == true ? m['nota_fiscal_path'] as String : null,
        observacao: '${m['observacao'] ?? ''}',
      );
}

/// Resumo financeiro de uma empresa para o cartão em Empresas cadastradas.
class ResumoFinanceiroEmpresa {
  final int emAberto;
  final int atrasadas;
  final double valorEmAberto;

  const ResumoFinanceiroEmpresa({this.emAberto = 0, this.atrasadas = 0, this.valorEmAberto = 0});
}

enum TipoAnexo { boleto, notaFiscal }

extension TipoAnexoInfo on TipoAnexo {
  String get rotulo => this == TipoAnexo.boleto ? 'Boleto' : 'Nota fiscal';
  String get coluna => this == TipoAnexo.boleto ? 'boleto_path' : 'nota_fiscal_path';
  String get prefixoArquivo => this == TipoAnexo.boleto ? 'boleto' : 'nota-fiscal';
}

double _numero(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

String _data(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// Repositório
// ---------------------------------------------------------------------------
class FinanceiroRepository {
  static const bucket = 'financeiro';

  final SupabaseClient _db;
  FinanceiroRepository([SupabaseClient? db]) : _db = db ?? Supabase.instance.client;

  Future<ContratoEmpresa?> contratoAtivo(String empresaId) async {
    final linha = await _db
        .from('empresa_contratos')
        .select('*, planos(nome)')
        .eq('cliente_empresa_id', empresaId)
        .eq('ativo', true)
        .maybeSingle();
    return linha == null ? null : ContratoEmpresa.fromMap(linha);
  }

  /// Cria (id nulo) ou altera o contrato. Um contrato ativo novo substitui o
  /// anterior e troca o plano da empresa (feito no servidor).
  Future<ContratoEmpresa> salvarContrato({
    String? id,
    required String empresaId,
    required String planoId,
    required double valorMensal,
    required int diaVencimento,
    required DateTime inicio,
    DateTime? fim,
    required String especificidades,
  }) async {
    final dados = {
      // Nome e CNPJ da empresa são copiados pelo servidor.
      'cliente_empresa_id': empresaId,
      'plano_id': planoId,
      'valor_mensal': valorMensal,
      'dia_vencimento': diaVencimento,
      'inicio': _data(inicio),
      'fim': fim == null ? null : _data(fim),
      'especificidades': especificidades.trim().isEmpty ? null : especificidades.trim(),
      'ativo': true,
    };
    final linha = id == null
        ? await _db.from('empresa_contratos').insert(dados).select('*, planos(nome)').single()
        : await _db.from('empresa_contratos').update(dados).eq('id', id).select('*, planos(nome)').single();
    return ContratoEmpresa.fromMap(linha);
  }

  /// Encerra o contrato (fica no histórico; o plano da empresa não muda).
  Future<void> encerrarContrato(String id) => _db.from('empresa_contratos').update({'ativo': false}).eq('id', id);

  Future<List<CobrancaEmpresa>> cobrancas(String empresaId) async {
    final linhas = await _db
        .from('empresa_cobrancas')
        .select()
        .eq('cliente_empresa_id', empresaId)
        .order('competencia', ascending: false)
        .order('vencimento', ascending: false);
    return linhas.map(CobrancaEmpresa.fromMap).toList();
  }

  /// Painel da DIAVICON: cobranças em aberto de todas as empresas, para os
  /// avisos nos cartões de Empresas cadastradas.
  Future<Map<String, ResumoFinanceiroEmpresa>> resumoEmAberto() async {
    final linhas = await _db
        .from('empresa_cobrancas')
        .select('id, cliente_empresa_id, cliente_nome, competencia, valor, vencimento, status')
        .eq('status', 'pendente')
        .not('cliente_empresa_id', 'is', null);
    final porEmpresa = <String, List<CobrancaEmpresa>>{};
    for (final l in linhas) {
      final c = CobrancaEmpresa.fromMap(l);
      porEmpresa.putIfAbsent(c.empresaId!, () => []).add(c);
    }
    return porEmpresa.map((empresa, lista) => MapEntry(
          empresa,
          ResumoFinanceiroEmpresa(
            emAberto: lista.length,
            atrasadas: lista.where((c) => c.status == StatusCobranca.atrasado).length,
            valorEmAberto: lista.fold(0, (s, c) => s + c.valor),
          ),
        ));
  }

  /// Cria as mensalidades que faltam na vigência do contrato. Devolve
  /// quantas foram criadas.
  Future<int> gerarMensalidades(String contratoId) async {
    final r = await _db.rpc('plataforma_gerar_cobrancas', params: {'p_contrato_id': contratoId});
    return r is num ? r.toInt() : 0;
  }

  Future<void> salvarCobranca({
    String? id,
    required String empresaId,
    required DateTime competencia,
    required String descricao,
    required double valor,
    required DateTime vencimento,
    required String observacao,
  }) async {
    final dados = {
      'cliente_empresa_id': empresaId,
      'competencia': _data(DateTime(competencia.year, competencia.month)),
      'descricao': descricao.trim().isEmpty ? null : descricao.trim(),
      'valor': valor,
      'vencimento': _data(vencimento),
      'observacao': observacao.trim().isEmpty ? null : observacao.trim(),
    };
    if (id == null) {
      await _db.from('empresa_cobrancas').insert(dados);
    } else {
      await _db.from('empresa_cobrancas').update(dados).eq('id', id);
    }
  }

  Future<void> alterarStatus(String cobrancaId, StatusCobranca status, {DateTime? pagoEm}) {
    return _db.from('empresa_cobrancas').update({
      'status': status.valorBanco,
      'pago_em': status == StatusCobranca.pago ? _data(pagoEm ?? DateTime.now()) : null,
    }).eq('id', cobrancaId);
  }

  /// Apaga a cobrança e os arquivos dela.
  Future<void> excluirCobranca(CobrancaEmpresa c) async {
    final arquivos = [c.boletoPath, c.notaFiscalPath].whereType<String>().toList();
    await _db.from('empresa_cobrancas').delete().eq('id', c.id);
    if (arquivos.isNotEmpty) {
      try {
        await _db.storage.from(bucket).remove(arquivos);
      } catch (_) {
        // A cobrança já saiu; um arquivo que sobrar não atrapalha ninguém.
      }
    }
  }

  /// Envia o boleto ou a nota fiscal e liga à cobrança. Substitui o anterior.
  Future<void> anexar({
    required CobrancaEmpresa cobranca,
    required TipoAnexo tipo,
    required Uint8List bytes,
    required String nomeOriginal,
  }) async {
    final empresa = cobranca.empresaId;
    if (empresa == null) throw Exception('A empresa desta cobrança foi excluída.');
    final ext = nomeOriginal.contains('.') ? nomeOriginal.split('.').last.toLowerCase() : 'pdf';
    final carimbo = DateTime.now().millisecondsSinceEpoch;
    final caminho = '$empresa/${cobranca.id}/${tipo.prefixoArquivo}-$carimbo.$ext';
    await _db.storage.from(bucket).uploadBinary(
          caminho,
          bytes,
          fileOptions: FileOptions(contentType: _mime(ext), upsert: true),
        );
    final anterior = tipo == TipoAnexo.boleto ? cobranca.boletoPath : cobranca.notaFiscalPath;
    await _db.from('empresa_cobrancas').update({tipo.coluna: caminho}).eq('id', cobranca.id);
    if (anterior != null && anterior != caminho) {
      try {
        await _db.storage.from(bucket).remove([anterior]);
      } catch (_) {}
    }
  }

  Future<void> removerAnexo(CobrancaEmpresa cobranca, TipoAnexo tipo) async {
    final caminho = tipo == TipoAnexo.boleto ? cobranca.boletoPath : cobranca.notaFiscalPath;
    await _db.from('empresa_cobrancas').update({tipo.coluna: null}).eq('id', cobranca.id);
    if (caminho != null) {
      try {
        await _db.storage.from(bucket).remove([caminho]);
      } catch (_) {}
    }
  }

  /// Link temporário (10 min) para abrir o boleto ou a nota fiscal.
  Future<String> linkTemporario(String caminho) => _db.storage.from(bucket).createSignedUrl(caminho, 600);

  static String _mime(String ext) => switch (ext) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'xml' => 'application/xml',
        _ => 'application/octet-stream',
      };
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------
final financeiroRepositoryProvider = Provider((ref) => FinanceiroRepository());

final contratoAtivoProvider = FutureProvider.autoDispose.family<ContratoEmpresa?, String>(
  (ref, empresaId) => ref.watch(financeiroRepositoryProvider).contratoAtivo(empresaId),
  retry: (_, _) => null,
);

final cobrancasEmpresaProvider = FutureProvider.autoDispose.family<List<CobrancaEmpresa>, String>(
  (ref, empresaId) => ref.watch(financeiroRepositoryProvider).cobrancas(empresaId),
  retry: (_, _) => null,
);

final resumoFinanceiroProvider = FutureProvider.autoDispose<Map<String, ResumoFinanceiroEmpresa>>(
  (ref) => ref.watch(financeiroRepositoryProvider).resumoEmAberto(),
  retry: (_, _) => null,
);

// ---------------------------------------------------------------------------
// Formatação
// ---------------------------------------------------------------------------
const _meses = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

String formatarReais(double v) {
  final negativo = v < 0;
  final centavos = (v.abs() * 100).round();
  final inteiro = (centavos ~/ 100).toString();
  final grupos = <String>[];
  for (var i = inteiro.length; i > 0; i -= 3) {
    grupos.insert(0, inteiro.substring(i - 3 < 0 ? 0 : i - 3, i));
  }
  return '${negativo ? '-' : ''}R\$ ${grupos.join('.')},${(centavos % 100).toString().padLeft(2, '0')}';
}

String formatarDataBr(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String formatarCompetencia(DateTime d) => '${_meses[d.month - 1]}/${d.year}';

/// Lê "1.234,56", "1234.56" ou "1234" como número.
double? lerValorReais(String texto) {
  var t = texto.replaceAll('R\$', '').replaceAll(' ', '').trim();
  if (t.isEmpty) return null;
  if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t);
}
