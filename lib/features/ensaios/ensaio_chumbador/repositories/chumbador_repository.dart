import 'package:diavicon/core/security/upload_seguro.dart';
import 'dart:io';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chumbador_model.dart';
import 'package:diavicon/features/ensaios/ensaios_geral/repositories/ponto_geral_identidade.dart';

final chumbadorRepositoryProvider = Provider<ChumbadorRepository>((ref) {
  return ChumbadorRepository(Supabase.instance.client);
});

// Mesmo padrão dos demais ensaios (pontos_ensaios_geral -> ponto_ensaio_X ->
// leituras) — ver `MonitoramentoFissuraRepository`. Tabelas reais:
// `ponto_ensaio_tracao`/`ponto_ensaio_tracao_leitura` (não
// "ponto_ensaio_chumbador" — nome genérico de "tração" escolhido na
// criação das tabelas). Diferente do Monitoramento de Fissuras,
// `valor_resultado`/`cor_resultado` aqui refletem a Condição de avaliação
// (campo MANUAL do inspetor), não um cálculo automático — fica
// "Pendente"/cinza até o inspetor escolher.
class ChumbadorRepository {
  final SupabaseClient _supabase;
  ChumbadorRepository(this._supabase);

  Future<String?> uploadImagem(File file, String campo) async {
    // Tipo, nome e Content-Type decididos pelo app (ver upload_seguro.dart).
    final fullPath = await _supabase.storage.from('projetos').enviarArquivoSeguro(
          'ensaios/chumbador',
          file,
          prefixo: '${campo}_',
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    return _supabase.storage.from('projetos').getPublicUrl(fullPath);
  }

  Future<ChumbadorModel?> buscarPontoChumbador(String pontoGeralId) async {
    try {
      final res = await _supabase.from('ponto_ensaio_tracao').select('*').eq('ponto_id', pontoGeralId).maybeSingle();
      if (res == null) return null;
      final ensaioId = res['id'] as String;

      // Sem número de leitura manual na tabela real — ordena por `criado_em`
      // (ver comentário em `LeituraChumbadorModel`).
      final leiturasResp =
          await _supabase.from('ponto_ensaio_tracao_leitura').select('*').eq('ponto_id', ensaioId).order('criado_em');
      final leituras = (leiturasResp as List).map((l) => LeituraChumbadorModel.fromJson((l as Map).cast<String, dynamic>())).toList();

      return ChumbadorModel.fromJson(res, leituras: leituras);
    } on PostgrestException catch (e) {
      throw Exception('Erro no banco de dados: ${e.message}');
    }
  }

  String _corHex(Color cor) => '#${cor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  Future<void> _atualizarResumoGeral(String pontoGeralId, ChumbadorModel ensaio) async {
    final condicao = ensaio.condicaoAvaliacao;
    final texto = condicao?.label ?? 'Pendente';
    final cor = condicao == null ? '#E0E0E0' : _corHex(condicao.cor);
    await _supabase.from('pontos_ensaios_geral').update({'valor_resultado': texto, 'cor_resultado': cor}).eq('id', pontoGeralId);
  }

  Future<Map<String, dynamic>> salvarPonto({
    required ChumbadorModel dados,
    required String projetoId,
    required String elementoId,
    required String tipoEnsaioId,
    required String pontoNome,
    File? fotoChumbadorNova,
    File? fotoDuranteNova,
    File? fotoAposNova,
  }) async {
    try {
      String? urlFotoChumbador = dados.fotoChumbador;
      String? urlFotoDurante = dados.fotoDurante;
      String? urlFotoApos = dados.fotoApos;
      if (fotoChumbadorNova != null) urlFotoChumbador = await uploadImagem(fotoChumbadorNova, 'foto_antes');
      if (fotoDuranteNova != null) urlFotoDurante = await uploadImagem(fotoDuranteNova, 'foto_durante');
      if (fotoAposNova != null) urlFotoApos = await uploadImagem(fotoAposNova, 'foto_apos');

      final dadosComFotos = dados.copyWith(fotoChumbador: urlFotoChumbador, fotoDurante: urlFotoDurante, fotoApos: urlFotoApos);

      String pontoGeralId = dados.pontoGeralId ?? '';
      if (pontoGeralId.isEmpty) {
        final elementoResponse = await _supabase.from('elementos_estruturais').select('estrutura_id').eq('id', elementoId).single();
        final estruturaId = elementoResponse['estrutura_id'] as String?;
        if (estruturaId == null) {
          throw Exception('Nenhuma estrutura vinculada a este elemento foi encontrada.');
        }

        final resGeral = await _supabase.from('pontos_ensaios_geral').insert({
          'nome_ponto': pontoNome,
          'tipo_ensaio': 'Tração em elemento chumbado',
          'tipo_ensaio_id': tipoEnsaioId,
          'elemento_estrutural_id': elementoId,
          'projeto_id': projetoId,
          'estrutura_id': estruturaId,
          'valor_resultado': dadosComFotos.condicaoAvaliacao?.label ?? 'Pendente',
          'cor_resultado': dadosComFotos.condicaoAvaliacao == null ? '#E0E0E0' : _corHex(dadosComFotos.condicaoAvaliacao!.cor),
          'criado_por': _supabase.auth.currentUser?.id,
        }).select('id').single();
        pontoGeralId = resGeral['id'] as String;
      } else {
        await _supabase.from('pontos_ensaios_geral').update({'nome_ponto': pontoNome}).eq('id', pontoGeralId);
        // Ponto antigo sem estrutura/tipo? Completa ao salvar (ver ponto_geral_identidade.dart).
        await completarIdentidadePontoGeral(_supabase, pontoGeralId: pontoGeralId, elementoId: elementoId, tipoEnsaioId: tipoEnsaioId);
      }

      String ensaioId = dadosComFotos.id ?? '';
      final payload = dadosComFotos.toJson(pontoGeralId: pontoGeralId);
      if (ensaioId.isEmpty) {
        final res = await _supabase.from('ponto_ensaio_tracao').insert(payload).select('id').single();
        ensaioId = res['id'] as String;
      } else {
        await _supabase.from('ponto_ensaio_tracao').update(payload).eq('id', ensaioId);
      }

      await _atualizarResumoGeral(pontoGeralId, dadosComFotos);

      return {
        'pontoGeralId': pontoGeralId,
        'ensaioId': ensaioId,
        'urlFotoChumbador': urlFotoChumbador,
        'urlFotoDurante': urlFotoDurante,
        'urlFotoApos': urlFotoApos,
      };
    } on PostgrestException catch (e) {
      throw Exception('Erro ao persistir no Supabase: ${e.message}');
    }
  }

  Future<void> salvarLeitura({
    required String pontoGeralId,
    required ChumbadorModel ensaioAtual,
    required LeituraChumbadorModel leitura,
    File? fotoNova,
  }) async {
    try {
      String? urlFoto = leitura.foto;
      if (fotoNova != null) urlFoto = await uploadImagem(fotoNova, 'leitura');
      final leituraComFoto = LeituraChumbadorModel(
        id: leitura.id,
        ensaioId: ensaioAtual.id,
        criadoEm: leitura.criadoEm,
        etapa: leitura.etapa,
        forcaKn: leitura.forcaKn,
        deslocamentoMm: leitura.deslocamentoMm,
        foto: urlFoto,
        ocorrencia: leitura.ocorrencia,
      );

      final payload = leituraComFoto.toJson(ensaioAtual.id!);
      List<LeituraChumbadorModel> leiturasAtualizadas;
      if (leitura.id == null) {
        final res = await _supabase.from('ponto_ensaio_tracao_leitura').insert(payload).select('id, criado_em').single();
        leiturasAtualizadas = [
          ...ensaioAtual.leituras,
          LeituraChumbadorModel(
            id: res['id'] as String,
            ensaioId: ensaioAtual.id,
            criadoEm: DateTime.tryParse(res['criado_em']?.toString() ?? ''),
            etapa: leituraComFoto.etapa,
            forcaKn: leituraComFoto.forcaKn,
            deslocamentoMm: leituraComFoto.deslocamentoMm,
            foto: leituraComFoto.foto,
            ocorrencia: leituraComFoto.ocorrencia,
          ),
        ];
      } else {
        await _supabase.from('ponto_ensaio_tracao_leitura').update(payload).eq('id', leitura.id!);
        leiturasAtualizadas = ensaioAtual.leituras.map((l) => l.id == leitura.id ? leituraComFoto : l).toList();
      }

      // Carga máxima/deslocamento máximo são derivados das leituras — a cada
      // leitura nova ou editada, recalcula e regrava no registro do ensaio
      // (ver regra de negócio do prompt original). Colunas reais são texto.
      final ensaioAtualizado = ensaioAtual.copyWith(leituras: leiturasAtualizadas);
      await _supabase.from('ponto_ensaio_tracao').update({
        'carga_max': ensaioAtualizado.cargaMaxima?.toString(),
        'desloc_max': ensaioAtualizado.deslocamentoMaximo?.toString(),
      }).eq('id', ensaioAtual.id!);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao salvar leitura: ${e.message}');
    }
  }

  Future<void> deletarLeitura({
    required String pontoGeralId,
    required ChumbadorModel ensaioAtual,
    required String leituraId,
  }) async {
    try {
      await _supabase.from('ponto_ensaio_tracao_leitura').delete().eq('id', leituraId);
      final leiturasAtualizadas = ensaioAtual.leituras.where((l) => l.id != leituraId).toList();
      final ensaioAtualizado = ensaioAtual.copyWith(leituras: leiturasAtualizadas);
      await _supabase.from('ponto_ensaio_tracao').update({
        'carga_max': ensaioAtualizado.cargaMaxima?.toString(),
        'desloc_max': ensaioAtualizado.deslocamentoMaximo?.toString(),
      }).eq('id', ensaioAtual.id!);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao excluir leitura: ${e.message}');
    }
  }

  Future<void> deletarPontoCompleto(String pontoGeralId) async {
    try {
      final ensaioResp = await _supabase.from('ponto_ensaio_tracao').select('id').eq('ponto_id', pontoGeralId).maybeSingle();
      final ensaioId = ensaioResp?['id']?.toString();

      if (ensaioId != null) {
        await _supabase.from('ponto_ensaio_tracao_leitura').delete().eq('ponto_id', ensaioId);
        await _supabase.from('ponto_ensaio_tracao').delete().eq('id', ensaioId);
      }

      await _supabase.from('galeria_pontos_ensaios_geral').delete().eq('ponto_ensaio_id', pontoGeralId);
      await _supabase.from('pontos_ensaios_geral').delete().eq('id', pontoGeralId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao excluir ponto: ${e.message}');
    }
  }
}
