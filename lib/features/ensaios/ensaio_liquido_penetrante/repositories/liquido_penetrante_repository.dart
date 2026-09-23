import 'package:diavicon/core/security/upload_seguro.dart';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/foto_otimizacao_service.dart';
import '../models/liquido_penetrante_model.dart';

final liquidoPenetranteRepositoryProvider = Provider<LiquidoPenetranteRepository>((ref) {
  return LiquidoPenetranteRepository(Supabase.instance.client);
});

// pontos_ensaios_geral (1 por elemento) → ponto_ensaio_liquido_penetrante (N
// pontos de LP). A cada ponto salvo/excluído, a contagem por status é
// regravada em valor_resultado/cor_resultado do registro geral (badge).
class LiquidoPenetranteRepository {
  final SupabaseClient _supabase;
  LiquidoPenetranteRepository(this._supabase);

  static const _tabela = 'ponto_ensaio_liquido_penetrante';
  static const nomeTipoEnsaio = 'Líquido penetrante';

  Future<String> uploadImagem(File file, String campo) async {
    // Mesmo tamanho das demais fotos de relatório (1280px no maior lado).
    final reduzida = await FotoOtimizacaoService.reduzirParaRelatorio(file);
    // Tipo, nome e Content-Type decididos pelo app (ver upload_seguro.dart).
    final caminho = await _supabase.storage.from('projetos').enviarArquivoSeguro(
          'ensaios/liquido_penetrante',
          reduzida,
          prefixo: '${campo}_',
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );
    return _supabase.storage.from('projetos').getPublicUrl(caminho);
  }

  Future<List<PontoLiquidoPenetranteModel>> listarPontos(String pontoGeralId) async {
    try {
      final res = await _supabase.from(_tabela).select('*').eq('ponto_id', pontoGeralId).order('criado_em');
      return (res as List).map((m) => PontoLiquidoPenetranteModel.fromJson((m as Map).cast<String, dynamic>())).toList();
    } on PostgrestException catch (e) {
      throw Exception('Erro ao carregar os pontos de LP: ${e.message}');
    }
  }

  /// Cria o registro geral do ensaio no elemento (na 1ª gravação) — SEMPRE
  /// com projeto, estrutura e tipo de ensaio (a estrutura vem do elemento).
  Future<String> garantirPontoGeral({
    required String? pontoGeralId,
    required String projetoId,
    required String elementoId,
    required String tipoEnsaioId,
    required String nomeEnsaio,
  }) async {
    if (pontoGeralId != null && pontoGeralId.isNotEmpty) return pontoGeralId;
    if (tipoEnsaioId.isEmpty) throw Exception('Tipo de ensaio não identificado. Abra o ensaio novamente pela lista.');
    if (elementoId.isEmpty) throw Exception('Elemento não identificado.');

    final elemento = await _supabase.from('elementos_estruturais').select('estrutura_id').eq('id', elementoId).single();
    final estruturaId = elemento['estrutura_id']?.toString();
    if (estruturaId == null || estruturaId.isEmpty) {
      throw Exception('Este elemento não está vinculado a uma estrutura.');
    }

    try {
      final res = await _supabase.from('pontos_ensaios_geral').insert({
        'nome_ponto': nomeEnsaio.trim().isEmpty ? nomeTipoEnsaio : nomeEnsaio.trim(),
        'tipo_ensaio': nomeTipoEnsaio,
        'tipo_ensaio_id': tipoEnsaioId,
        'elemento_estrutural_id': elementoId,
        'projeto_id': projetoId,
        'estrutura_id': estruturaId,
        'valor_resultado': 'Pendente',
        'cor_resultado': '#E0E0E0',
        'criado_por': _supabase.auth.currentUser?.id,
      }).select('id').single();
      return res['id'] as String;
    } on PostgrestException catch (e) {
      throw Exception('Erro ao criar o ensaio: ${e.message}');
    }
  }

  /// Salva (insere ou atualiza) um ponto de LP, sobe as fotos novas e
  /// atualiza a badge do registro geral. Devolve o id do registro geral.
  Future<String> salvarPonto({
    required PontoLiquidoPenetranteModel ponto,
    required String? pontoGeralId,
    required String projetoId,
    required String elementoId,
    required String tipoEnsaioId,
    required String nomeEnsaio,
    File? fotoSoldaNova,
    File? fotoPenetranteNova,
    File? fotoResultadoNova,
  }) async {
    // Fotos primeiro: se o upload falhar, nada é gravado no banco.
    final comFotos = ponto.copyWith(
      fotoSolda: fotoSoldaNova != null ? await uploadImagem(fotoSoldaNova, 'solda') : null,
      fotoPenetrante: fotoPenetranteNova != null ? await uploadImagem(fotoPenetranteNova, 'penetrante') : null,
      fotoResultado: fotoResultadoNova != null ? await uploadImagem(fotoResultadoNova, 'resultado') : null,
    );

    final geralId = await garantirPontoGeral(
      pontoGeralId: pontoGeralId,
      projetoId: projetoId,
      elementoId: elementoId,
      tipoEnsaioId: tipoEnsaioId,
      nomeEnsaio: nomeEnsaio,
    );

    try {
      final payload = comFotos.toJson(pontoGeralId: geralId);
      if (comFotos.id == null) {
        await _supabase.from(_tabela).insert(payload);
      } else {
        await _supabase.from(_tabela).update(payload).eq('id', comFotos.id!);
      }
    } on PostgrestException catch (e) {
      throw Exception('Erro ao salvar o ponto de LP: ${e.message}');
    }

    await atualizarResumo(geralId);
    return geralId;
  }

  Future<void> excluirPonto({required String pontoId, required String pontoGeralId}) async {
    try {
      await _supabase.from(_tabela).delete().eq('id', pontoId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao excluir o ponto de LP: ${e.message}');
    }
    await atualizarResumo(pontoGeralId);
  }

  /// Regrava a badge (contagem por status) no registro geral.
  Future<ContagemStatusLP> atualizarResumo(String pontoGeralId) async {
    final pontos = await listarPontos(pontoGeralId);
    final contagem = ContagemStatusLP.de(pontos.map((p) => p.status));
    await _supabase
        .from('pontos_ensaios_geral')
        .update({'valor_resultado': contagem.textoBadge, 'cor_resultado': contagem.corHex})
        .eq('id', pontoGeralId);
    return contagem;
  }

  Future<void> excluirEnsaioCompleto(String pontoGeralId) async {
    try {
      await _supabase.from(_tabela).delete().eq('ponto_id', pontoGeralId);
      await _supabase.from('galeria_pontos_ensaios_geral').delete().eq('ponto_ensaio_id', pontoGeralId);
      await _supabase.from('pontos_ensaios_geral').delete().eq('id', pontoGeralId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao excluir o ensaio: ${e.message}');
    }
  }
}
