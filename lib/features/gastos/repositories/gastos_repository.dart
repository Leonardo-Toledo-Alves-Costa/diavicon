import 'package:diavicon/core/security/upload_seguro.dart';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../models/gasto_model.dart';

// Acesso ao banco do módulo de Gastos.
//
// IMPORTANTE — `gastos` e `categoria_gastos` estão SEM RLS no Supabase (a
// proposta de RLS está em supabase/migrations/20260918150000_gastos_rls.sql,
// ainda não aplicada). Enquanto isso, o sigilo por empresa depende destas
// consultas: TODA leitura filtra por `empresa_id` da empresa do usuário, e
// quem não é admin só recebe os próprios gastos. Não crie consulta nova sem
// esses filtros.
class GastosRepository {
  GastosRepository(this._db);

  final SupabaseClient _db;

  static const _tabela = 'gastos';
  static const _tabelaCategorias = 'categoria_gastos';
  static const _bucket = 'projetos';
  static const _pastaAnexos = 'gastos';

  String? get usuarioLogadoId => _db.auth.currentUser?.id;

  // --- Gastos --------------------------------------------------------------

  Future<List<GastoModel>> listarMeusGastos({required String empresaId}) async {
    final uid = usuarioLogadoId;
    if (uid == null) return [];
    final res = await _db
        .from(_tabela)
        .select(GastoModel.selectPadrao)
        .eq('empresa_id', empresaId)
        .eq('criado_por', uid)
        .order('criado_em', ascending: false);
    return _mapear(res);
  }

  /// Admin: gastos de todos os colaboradores da empresa no projeto.
  /// Demais: só os próprios.
  Future<List<GastoModel>> listarDoProjeto({
    required String projetoId,
    required String empresaId,
    required bool admin,
  }) async {
    final uid = usuarioLogadoId;
    if (uid == null) return [];
    var query = _db.from(_tabela).select(GastoModel.selectPadrao).eq('projeto_id', projetoId).eq('empresa_id', empresaId);
    if (!admin) query = query.eq('criado_por', uid);
    final res = await query.order('criado_em', ascending: false);
    return _mapear(res);
  }

  /// Análise gerencial (só admin chama): toda a empresa, no período.
  Future<List<GastoModel>> listarDaEmpresa({
    required String empresaId,
    required DateTime inicio,
    required DateTime fim,
  }) async {
    // Limites do dia no horário local, convertidos para UTC (criado_em é timestamptz).
    final de = DateTime(inicio.year, inicio.month, inicio.day).toUtc().toIso8601String();
    final ate = DateTime(fim.year, fim.month, fim.day + 1).toUtc().toIso8601String();
    final res = await _db
        .from(_tabela)
        .select(GastoModel.selectPadrao)
        .eq('empresa_id', empresaId)
        .gte('criado_em', de)
        .lt('criado_em', ate)
        .order('criado_em', ascending: false);
    return _mapear(res);
  }

  Future<void> salvar({String? gastoId, required String empresaId, required Map<String, dynamic> dados}) async {
    final uid = usuarioLogadoId;
    if (uid == null) throw StateError('Sessão expirada. Entre novamente.');
    if (gastoId == null) {
      // Dono e empresa sempre explícitos: as colunas têm default
      // gen_random_uuid(), e omitir gravaria um id aleatório.
      await _db.from(_tabela).insert({...dados, 'criado_por': uid, 'empresa_id': empresaId});
    } else {
      // Só o autor altera (o filtro garante mesmo sem RLS).
      await _db.from(_tabela).update(dados).eq('id', gastoId).eq('criado_por', uid);
    }
  }

  Future<void> excluir(GastoModel gasto) async {
    final uid = usuarioLogadoId;
    if (uid == null) throw StateError('Sessão expirada. Entre novamente.');
    await _db.from(_tabela).delete().eq('id', gasto.id).eq('criado_por', uid);
    if (gasto.anexoUrl != null) await removerAnexo(gasto.anexoUrl!);
  }

  // --- Comprovantes --------------------------------------------------------

  /// Sobe em `projetos/gastos/<empresa_id>/<usuario_id>/<uuid>.<ext>`
  /// e devolve a URL pública (gravada em `anexo_url`).
  Future<String> enviarAnexo(File arquivo, {required String empresaId}) async {
    final uid = usuarioLogadoId;
    if (uid == null) throw StateError('Sessão expirada. Entre novamente.');
    // Foto ou PDF; tipo, nome e Content-Type decididos pelo app pelo
    // conteúdo do arquivo (ver upload_seguro.dart).
    final path = await _db.storage.from(_bucket).enviarArquivoSeguro(
          '$_pastaAnexos/$empresaId/$uid',
          arquivo,
          permitidas: UploadSeguro.extensoesImagemOuPdf,
        );
    return _db.storage.from(_bucket).getPublicUrl(path);
  }

  /// Best-effort: o gasto já foi alterado; um arquivo órfão não é erro para
  /// o usuário.
  Future<void> removerAnexo(String url) async {
    final path = caminhoDoAnexo(url);
    if (path == null) return;
    try {
      await _db.storage.from(_bucket).remove([path]);
    } catch (_) {}
  }

  /// URL pública → caminho dentro do bucket (`gastos/...`).
  static String? caminhoDoAnexo(String url) {
    const marcador = '/object/public/$_bucket/';
    final i = url.indexOf(marcador);
    if (i < 0) return null;
    return Uri.decodeComponent(url.substring(i + marcador.length).split('?').first);
  }

  // --- Categorias ----------------------------------------------------------

  /// Categorias da empresa + padrão DIAVICON, por nome.
  Future<List<CategoriaGastoModel>> listarCategorias({required String empresaId}) async {
    final res = await _db
        .from(_tabelaCategorias)
        .select('id, empresa_id, nome')
        .inFilter('empresa_id', [empresaId, DIAVICON_EMPRESA_ID])
        .order('nome');
    return (res as List)
        .map((m) => CategoriaGastoModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .where((c) => c.nome.trim().isNotEmpty)
        .toList();
  }

  /// Só o admin cria (Padrões da empresa › Categorias de gasto). Devolve o id.
  Future<String> criarCategoria({required String empresaId, required String nome}) async {
    final res = await _db
        .from(_tabelaCategorias)
        .insert({'empresa_id': empresaId, 'nome': nome.trim()})
        .select('id')
        .single();
    return res['id'].toString();
  }

  Future<void> renomearCategoria(String id, {required String empresaId, required String nome}) async {
    await _db.from(_tabelaCategorias).update({'nome': nome.trim()}).eq('id', id).eq('empresa_id', empresaId);
  }

  /// Categoria com gastos não pode ser excluída (FK `gastos_categoria_fkey`).
  Future<void> excluirCategoria(String id, {required String empresaId}) async {
    try {
      await _db.from(_tabelaCategorias).delete().eq('id', id).eq('empresa_id', empresaId);
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        throw const CategoriaEmUsoException();
      }
      rethrow;
    }
  }

  List<GastoModel> _mapear(dynamic res) =>
      (res as List).map((m) => GastoModel.fromMap(Map<String, dynamic>.from(m as Map))).toList();
}

class CategoriaEmUsoException implements Exception {
  const CategoriaEmUsoException();
  @override
  String toString() => 'Há gastos lançados nesta categoria, por isso ela não pode ser excluída.';
}

final gastosRepositoryProvider = Provider<GastosRepository>((ref) => GastosRepository(Supabase.instance.client));

/// Nome já existente (sem diferenciar maiúsculas/espaços)? A tabela não tem
/// unique, então o app evita duplicar.
CategoriaGastoModel? categoriaComNome(Iterable<CategoriaGastoModel> categorias, String nome) {
  final alvo = nome.trim().toLowerCase();
  for (final c in categorias) {
    if (c.nome.trim().toLowerCase() == alvo) return c;
  }
  return null;
}

/// Texto de erro para o usuário, em vez do erro cru do Postgres.
String mensagemErroGastos(Object erro) {
  if (erro is CategoriaEmUsoException) return erro.toString();
  if (erro is PostgrestException) {
    const esquemaDiferente = {'42703', '42P01', 'PGRST200', 'PGRST204', 'PGRST205'};
    if (esquemaDiferente.contains(erro.code)) {
      return 'As tabelas de gastos no Supabase não estão como o app espera.\n(${erro.message})';
    }
    if (erro.code == '42501') {
      return 'Sem permissão para acessar os gastos. Confira se o seu usuário está ativo e vinculado a uma empresa.';
    }
    return erro.message;
  }
  if (erro is StorageException) return 'Erro ao enviar o comprovante: ${erro.message}';
  if (erro is SocketException) return 'Sem conexão com a internet.';
  return '$erro';
}
