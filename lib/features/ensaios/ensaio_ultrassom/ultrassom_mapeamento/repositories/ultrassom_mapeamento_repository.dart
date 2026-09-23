import 'package:diavicon/core/security/upload_seguro.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../ultrassom_direto/models/ultrassom_direto_model.dart' show ClassificacaoWhitehurst;
import '../models/ultrassom_mapeamento_model.dart';
import 'package:diavicon/features/ensaios/ensaios_geral/repositories/ponto_geral_identidade.dart';

final ultrassomMapeamentoRepositoryProvider = Provider<UltrassomMapeamentoRepository>((ref) {
  return UltrassomMapeamentoRepository(Supabase.instance.client);
});

// Mesmo padrão de `PotencialRepository` (pontos_ensaios_geral ->
// ponto_ensaio_ultrassom -> ponto_ensaio_ultrassom_mapeamento -> leituras),
// só que dividido em 2 tabelas em vez de 1 pra reaproveitar o mesmo
// `ponto_ensaio_ultrassom` (fotos/tipo_onda) que Direto e Indireto usam,
// diferenciado por `modo`.
class UltrassomMapeamentoRepository {
  final SupabaseClient _supabase;
  UltrassomMapeamentoRepository(this._supabase);

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

  Future<PontoUltrassomMapeamentoModel?> buscarPontoMapeamento(String pontoGeralId) async {
    try {
      final resUltrassom = await _supabase
          .from('ponto_ensaio_ultrassom')
          .select('*')
          .eq('ponto_ensaio_id', pontoGeralId)
          .eq('modo', 'mapeamento')
          .maybeSingle();
      if (resUltrassom == null) return null;
      final idUltrassom = resUltrassom['id'] as String;

      final resMapeamento =
          await _supabase.from('ponto_ensaio_ultrassom_mapeamento').select('*').eq('ponto_id', idUltrassom).maybeSingle();

      List<LeituraUltrassomMapeamentoModel> leituras = [];
      String? mapeamentoId;
      if (resMapeamento != null) {
        mapeamentoId = resMapeamento['id'] as String;
        final leiturasResp =
            await _supabase.from('ponto_ensaio_ultrassom_mapeamento_leitura').select('*').eq('ponto_id', mapeamentoId);
        leituras = (leiturasResp as List).map((l) => LeituraUltrassomMapeamentoModel.fromJson(l)).toList();
      }

      return PontoUltrassomMapeamentoModel(
        id: idUltrassom,
        mapeamentoId: mapeamentoId,
        pontoGeralId: pontoGeralId,
        pulsoUltrassonico: resUltrassom['tipo_onda']?.toString() ?? 'Longitudinal',
        foto1: resUltrassom['foto_1']?.toString(),
        foto2: resUltrassom['foto_2']?.toString(),
        espacamentoX: resMapeamento?['espacamento_x']?.toString(),
        espacamentoY: resMapeamento?['espacamento_y']?.toString(),
        opacidade: resMapeamento?['opacidade']?.toString(),
        p1X: (resMapeamento?['p1_x'] as num?)?.toDouble(),
        p1Y: (resMapeamento?['p1_y'] as num?)?.toDouble(),
        p2X: (resMapeamento?['p2_x'] as num?)?.toDouble(),
        p2Y: (resMapeamento?['p2_y'] as num?)?.toDouble(),
        p3X: (resMapeamento?['p3_x'] as num?)?.toDouble(),
        p3Y: (resMapeamento?['p3_y'] as num?)?.toDouble(),
        p4X: (resMapeamento?['p4_x'] as num?)?.toDouble(),
        p4Y: (resMapeamento?['p4_y'] as num?)?.toDouble(),
        leituras: leituras,
      );
    } on PostgrestException catch (e) {
      throw Exception('Erro no banco de dados: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> salvarMapeamentoCompleto({
    required PontoUltrassomMapeamentoModel dados,
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

      final mediaGeral = dadosComFotos.mediaVelocidade;
      final classificacao = ClassificacaoWhitehurst.classificar(mediaGeral);
      final tagTexto = mediaGeral > 0 ? '${mediaGeral.toStringAsFixed(0)} m/s' : 'Pendente';

      // 1. Tabela geral
      String pontoGeralId = dadosComFotos.pontoGeralId ?? '';
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

      // 2. Tabela pai (ponto_ensaio_ultrassom, modo='mapeamento')
      String idUltrassom = dadosComFotos.id ?? '';
      final payloadUltrassom = dadosComFotos.toJsonUltrassom(pontoEnsaioId: pontoGeralId);
      if (idUltrassom.isEmpty) {
        final resUltrassom = await _supabase.from('ponto_ensaio_ultrassom').insert(payloadUltrassom).select('id').single();
        idUltrassom = resUltrassom['id'] as String;
      } else {
        await _supabase.from('ponto_ensaio_ultrassom').update(payloadUltrassom).eq('id', idUltrassom);
      }

      // 3. Tabela filha (ponto_ensaio_ultrassom_mapeamento — calibração + malha)
      String idMapeamento = dadosComFotos.mapeamentoId ?? '';
      final payloadMapeamento = dadosComFotos.toJsonMapeamento(idUltrassom);
      if (idMapeamento.isEmpty) {
        final resMapeamento = await _supabase.from('ponto_ensaio_ultrassom_mapeamento').insert(payloadMapeamento).select('id').single();
        idMapeamento = resMapeamento['id'] as String;
      } else {
        await _supabase.from('ponto_ensaio_ultrassom_mapeamento').update(payloadMapeamento).eq('id', idMapeamento);
      }

      // 4. Leituras da malha — apaga e reinsere, igual ao padrão de Potencial.
      await _supabase.from('ponto_ensaio_ultrassom_mapeamento_leitura').delete().eq('ponto_id', idMapeamento);
      final leiturasValidas = dadosComFotos.leituras.where((l) => l.velocidade != null).map((l) => l.toJson(idMapeamento)).toList();
      if (leiturasValidas.isNotEmpty) {
        await _supabase.from('ponto_ensaio_ultrassom_mapeamento_leitura').insert(leiturasValidas);
      }

      return {
        'pontoGeralId': pontoGeralId,
        'idUltrassom': idUltrassom,
        'idMapeamento': idMapeamento,
        'urlFoto1': urlFoto1,
        'urlFoto2': urlFoto2,
      };
    } on PostgrestException catch (e) {
      throw Exception('Erro ao persistir no Supabase: ${e.message}');
    }
  }

  Future<void> deletarPontoCompleto(String pontoGeralId) async {
    try {
      final ultrassomResp =
          await _supabase.from('ponto_ensaio_ultrassom').select('id').eq('ponto_ensaio_id', pontoGeralId).eq('modo', 'mapeamento').maybeSingle();
      final idUltrassom = ultrassomResp?['id']?.toString();

      if (idUltrassom != null) {
        final mapeamentoResp =
            await _supabase.from('ponto_ensaio_ultrassom_mapeamento').select('id').eq('ponto_id', idUltrassom).maybeSingle();
        final idMapeamento = mapeamentoResp?['id']?.toString();

        if (idMapeamento != null) {
          await _supabase.from('ponto_ensaio_ultrassom_mapeamento_leitura').delete().eq('ponto_id', idMapeamento);
          await _supabase.from('ponto_ensaio_ultrassom_mapeamento').delete().eq('id', idMapeamento);
        }
        await _supabase.from('ponto_ensaio_ultrassom').delete().eq('id', idUltrassom);
      }

      await _supabase.from('galeria_pontos_ensaios_geral').delete().eq('ponto_ensaio_id', pontoGeralId);
      await _supabase.from('pontos_ensaios_geral').delete().eq('id', pontoGeralId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao excluir ponto: ${e.message}');
    }
  }
}
