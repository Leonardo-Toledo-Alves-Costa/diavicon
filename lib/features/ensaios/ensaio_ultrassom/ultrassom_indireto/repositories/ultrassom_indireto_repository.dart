import 'package:diavicon/core/security/upload_seguro.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../ultrassom_direto/models/ultrassom_direto_model.dart' show ClassificacaoWhitehurst;
import '../models/ultrassom_indireto_model.dart';
import 'package:diavicon/features/ensaios/ensaios_geral/repositories/ponto_geral_identidade.dart';

final ultrassomIndiretoRepositoryProvider = Provider<UltrassomIndiretoRepository>((ref) {
  return UltrassomIndiretoRepository(Supabase.instance.client);
});

// Mesma estrutura de `UltrassomDiretoRepository` (pontos_ensaios_geral ->
// ponto_ensaio_ultrassom -> upsert por presença de id), com mais um nível
// pra medição -> leitura. Compartilha a tabela `ponto_ensaio_ultrassom` com
// o modo Direto (diferenciados por `modo`).
class UltrassomIndiretoRepository {
  final SupabaseClient _supabase;
  UltrassomIndiretoRepository(this._supabase);

  Future<String?> uploadImagem(File file, String campo) async {
    // Tipo, nome e Content-Type decididos pelo app (ver upload_seguro.dart).
    final fullPath = await _supabase.storage.from('projetos').enviarArquivoSeguro(
          'ensaios/ultrassom',
          file,
          prefixo: '${campo}_',
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    return _supabase.storage.from('projetos').getPublicUrl(fullPath);
  }

  Future<PontoUltrassomIndiretoModel?> buscarPontoUltrassom(String pontoGeralId) async {
    try {
      final res = await _supabase
          .from('ponto_ensaio_ultrassom')
          .select('*')
          .eq('ponto_ensaio_id', pontoGeralId)
          .eq('modo', 'indireto')
          .maybeSingle();

      if (res == null) return null;
      final idUltrassom = res['id'] as String;

      final medicoesResp = await _supabase
          .from('ponto_ensaio_ultrassom_indireto_medicao')
          .select('*')
          .eq('ponto_id', idUltrassom)
          .order('criado_em', ascending: true);

      final medicoes = <MedicaoUltrassomIndiretoModel>[];
      for (final mMap in (medicoesResp as List)) {
        final idMedicao = mMap['id'] as String;
        final leiturasResp = await _supabase
            .from('ponto_ensaio_ultrassom_indireto_leitura')
            .select('*')
            .eq('ponto_id', idMedicao)
            .order('criado_em', ascending: true);

        final leituras = (leiturasResp as List).map((l) => LeituraUltrassomIndiretoModel.fromJson(l)).toList();
        medicoes.add(MedicaoUltrassomIndiretoModel.fromJson(mMap, leituras: leituras));
      }

      return PontoUltrassomIndiretoModel.fromJson(res, medicoes: medicoes);
    } on PostgrestException catch (e) {
      throw Exception('Erro no banco de dados: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> salvarPontoCompleto({
    required PontoUltrassomIndiretoModel dados,
    required String projetoId,
    required String elementoId,
    required String tipoEnsaioId,
    required String pontoNome,
    File? foto1Nova,
    File? foto2Nova,
  }) async {
    try {
      String? urlFoto1 = dados.foto1;
      String? urlFoto2 = dados.foto2;
      if (foto1Nova != null) urlFoto1 = await uploadImagem(foto1Nova, 'foto1');
      if (foto2Nova != null) urlFoto2 = await uploadImagem(foto2Nova, 'foto2');

      final dadosComFotos = dados.copyWith(foto1: urlFoto1, foto2: urlFoto2);

      final mediaGeral = dadosComFotos.mediaGeral;
      final classificacao = ClassificacaoWhitehurst.classificar(mediaGeral);
      final tagTexto = mediaGeral > 0 ? '${mediaGeral.toStringAsFixed(0)} m/s' : 'Pendente';

      String pontoGeralId = dados.pontoGeralId ?? '';
      if (pontoGeralId.isEmpty) {
        final elementoResponse = await _supabase.from('elementos_estruturais').select('estrutura_id').eq('id', elementoId).single();
        final estruturaId = elementoResponse['estrutura_id'] as String?;
        if (estruturaId == null) {
          throw Exception('Nenhuma estrutura vinculada a este elemento foi encontrada.');
        }

        final resGeral = await _supabase.from('pontos_ensaios_geral').insert({
          'nome_ponto': pontoNome,
          'tipo_ensaio': 'Ultrassonografia',
          'tipo_ensaio_id': tipoEnsaioId,
          'elemento_estrutural_id': elementoId,
          'projeto_id': projetoId,
          'estrutura_id': estruturaId,
          'valor_resultado': tagTexto,
          'cor_resultado': classificacao.hex,
          'criado_por': _supabase.auth.currentUser?.id,
        }).select('id').single();
        pontoGeralId = resGeral['id'] as String;
      } else {
        await _supabase.from('pontos_ensaios_geral').update({
          'nome_ponto': pontoNome,
          'valor_resultado': tagTexto,
          'cor_resultado': classificacao.hex,
        }).eq('id', pontoGeralId);
        // Ponto antigo sem estrutura/tipo? Completa ao salvar (ver ponto_geral_identidade.dart).
        await completarIdentidadePontoGeral(_supabase, pontoGeralId: pontoGeralId, elementoId: elementoId, tipoEnsaioId: tipoEnsaioId);
      }

      String idUltrassom = dadosComFotos.id ?? '';
      final payloadUltrassom = dadosComFotos.toJson(pontoEnsaioId: pontoGeralId);
      if (idUltrassom.isEmpty) {
        final resUltrassom = await _supabase.from('ponto_ensaio_ultrassom').insert(payloadUltrassom).select('id').single();
        idUltrassom = resUltrassom['id'] as String;
      } else {
        await _supabase.from('ponto_ensaio_ultrassom').update(payloadUltrassom).eq('id', idUltrassom);
      }

      for (final medicao in dadosComFotos.medicoes) {
        String idMedicao = medicao.id ?? '';
        final payloadMedicao = medicao.toJson(idUltrassom);
        if (idMedicao.isEmpty) {
          final resMedicao = await _supabase.from('ponto_ensaio_ultrassom_indireto_medicao').insert(payloadMedicao).select('id').single();
          idMedicao = resMedicao['id'] as String;
        } else {
          await _supabase.from('ponto_ensaio_ultrassom_indireto_medicao').update(payloadMedicao).eq('id', idMedicao);
        }

        for (final leitura in medicao.leituras) {
          if (leitura.id != null) {
            await _supabase.from('ponto_ensaio_ultrassom_indireto_leitura').update(leitura.toJson(idMedicao)).eq('id', leitura.id!);
          } else {
            await _supabase.from('ponto_ensaio_ultrassom_indireto_leitura').insert(leitura.toJson(idMedicao));
          }
        }
      }

      return {'pontoGeralId': pontoGeralId, 'idUltrassom': idUltrassom};
    } on PostgrestException catch (e) {
      throw Exception('Erro ao persistir no Supabase: ${e.message}');
    }
  }

  Future<void> deletarLeitura(String idLeitura) async {
    try {
      await _supabase.from('ponto_ensaio_ultrassom_indireto_leitura').delete().eq('id', idLeitura);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao remover leitura: ${e.message}');
    }
  }

  Future<void> deletarPontoMedicao(String idMedicao) async {
    try {
      await _supabase.from('ponto_ensaio_ultrassom_indireto_leitura').delete().eq('ponto_id', idMedicao);
      await _supabase.from('ponto_ensaio_ultrassom_indireto_medicao').delete().eq('id', idMedicao);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao remover ponto de medição: ${e.message}');
    }
  }

  Future<void> deletarPontoCompleto(String pontoGeralId) async {
    try {
      final ultrassomResp =
          await _supabase.from('ponto_ensaio_ultrassom').select('id').eq('ponto_ensaio_id', pontoGeralId).eq('modo', 'indireto').maybeSingle();
      final idUltrassom = ultrassomResp?['id']?.toString();

      if (idUltrassom != null) {
        final medicoesResp = await _supabase.from('ponto_ensaio_ultrassom_indireto_medicao').select('id').eq('ponto_id', idUltrassom);
        final idsMedicoes = (medicoesResp as List).map((m) => m['id'].toString()).toList();

        if (idsMedicoes.isNotEmpty) {
          await _supabase.from('ponto_ensaio_ultrassom_indireto_leitura').delete().inFilter('ponto_id', idsMedicoes);
        }
        await _supabase.from('ponto_ensaio_ultrassom_indireto_medicao').delete().eq('ponto_id', idUltrassom);
        await _supabase.from('ponto_ensaio_ultrassom').delete().eq('id', idUltrassom);
      }

      await _supabase.from('galeria_pontos_ensaios_geral').delete().eq('ponto_ensaio_id', pontoGeralId);
      await _supabase.from('pontos_ensaios_geral').delete().eq('id', pontoGeralId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao excluir ponto: ${e.message}');
    }
  }
}
