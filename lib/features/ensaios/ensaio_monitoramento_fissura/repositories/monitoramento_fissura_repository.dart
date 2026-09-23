import 'package:diavicon/core/security/upload_seguro.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/monitoramento_fissura_model.dart';
import 'package:diavicon/features/ensaios/ensaios_geral/repositories/ponto_geral_identidade.dart';

final monitoramentoFissuraRepositoryProvider = Provider<MonitoramentoFissuraRepository>((ref) {
  return MonitoramentoFissuraRepository(Supabase.instance.client);
});

// Mesmo padrão dos demais ensaios (pontos_ensaios_geral -> ponto_ensaio_X ->
// leituras) — `valor_resultado`/`cor_resultado` de `pontos_ensaios_geral`
// sempre refletem o status da medição mais recente, pra aparecer certo na
// lista de pontos de ensaio sem precisar abrir o ponto.
class MonitoramentoFissuraRepository {
  final SupabaseClient _supabase;
  MonitoramentoFissuraRepository(this._supabase);

  Future<String?> uploadImagem(File file, String campo) async {
    // Tipo, nome e Content-Type decididos pelo app (ver upload_seguro.dart).
    final fullPath = await _supabase.storage.from('projetos').enviarArquivoSeguro(
          'ensaios/monitoramento_fissura',
          file,
          prefixo: '${campo}_',
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    return _supabase.storage.from('projetos').getPublicUrl(fullPath);
  }

  Future<InstalacaoFissuraModel?> buscarInstalacao(String pontoGeralId) async {
    try {
      final res =
          await _supabase.from('ponto_ensaio_monitoramento_fissura').select('*').eq('ponto_ensaio_id', pontoGeralId).maybeSingle();
      if (res == null) return null;
      final instalacaoId = res['id'] as String;

      final leiturasResp =
          await _supabase.from('ponto_ensaio_monitoramento_fissura_leitura').select('*').eq('ponto_id', instalacaoId);
      final medicoes = (leiturasResp as List).map((l) => MedicaoFissuraModel.fromJson((l as Map).cast<String, dynamic>())).toList();

      return InstalacaoFissuraModel.fromJson(res, medicoes: medicoes);
    } on PostgrestException catch (e) {
      throw Exception('Erro no banco de dados: ${e.message}');
    }
  }

  String _corHex(Color cor) => '#${cor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  Future<void> _atualizarResumoGeral(String pontoGeralId, InstalacaoFissuraModel instalacao) async {
    final ultima = instalacao.ultimaMedicao;
    final texto = ultima == null ? 'Pendente' : ultima.status.label;
    final cor = ultima == null ? '#E0E0E0' : _corHex(ultima.status.cor);
    await _supabase.from('pontos_ensaios_geral').update({'valor_resultado': texto, 'cor_resultado': cor}).eq('id', pontoGeralId);
  }

  Future<Map<String, dynamic>> salvarInstalacao({
    required InstalacaoFissuraModel dados,
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

      String pontoGeralId = dados.pontoGeralId ?? '';
      if (pontoGeralId.isEmpty) {
        final elementoResponse = await _supabase.from('elementos_estruturais').select('estrutura_id').eq('id', elementoId).single();
        final estruturaId = elementoResponse['estrutura_id'] as String?;
        if (estruturaId == null) {
          throw Exception('Nenhuma estrutura vinculada a este elemento foi encontrada.');
        }

        final resGeral = await _supabase.from('pontos_ensaios_geral').insert({
          'nome_ponto': pontoNome,
          'tipo_ensaio': 'Monitoramento de Fissuras',
          'tipo_ensaio_id': tipoEnsaioId,
          'elemento_estrutural_id': elementoId,
          'projeto_id': projetoId,
          'estrutura_id': estruturaId,
          'valor_resultado': 'Pendente',
          'cor_resultado': '#E0E0E0',
          'criado_por': _supabase.auth.currentUser?.id,
        }).select('id').single();
        pontoGeralId = resGeral['id'] as String;
      } else {
        await _supabase.from('pontos_ensaios_geral').update({'nome_ponto': pontoNome}).eq('id', pontoGeralId);
        // Ponto antigo sem estrutura/tipo? Completa ao salvar (ver ponto_geral_identidade.dart).
        await completarIdentidadePontoGeral(_supabase, pontoGeralId: pontoGeralId, elementoId: elementoId, tipoEnsaioId: tipoEnsaioId);
      }

      String instalacaoId = dadosComFotos.id ?? '';
      final payload = dadosComFotos.toJson(pontoGeralId: pontoGeralId);
      if (instalacaoId.isEmpty) {
        final res = await _supabase.from('ponto_ensaio_monitoramento_fissura').insert(payload).select('id').single();
        instalacaoId = res['id'] as String;
      } else {
        await _supabase.from('ponto_ensaio_monitoramento_fissura').update(payload).eq('id', instalacaoId);
      }

      return {'pontoGeralId': pontoGeralId, 'instalacaoId': instalacaoId, 'urlFoto1': urlFoto1, 'urlFoto2': urlFoto2};
    } on PostgrestException catch (e) {
      throw Exception('Erro ao persistir no Supabase: ${e.message}');
    }
  }

  Future<void> salvarMedicao({
    required String pontoGeralId,
    required InstalacaoFissuraModel instalacaoAtual,
    required MedicaoFissuraModel medicao,
    File? fotoNova,
  }) async {
    try {
      String? urlFoto = medicao.foto;
      if (fotoNova != null) urlFoto = await uploadImagem(fotoNova, 'medicao');
      final medicaoComFoto = MedicaoFissuraModel(
        id: medicao.id,
        instalacaoId: instalacaoAtual.id,
        dataHora: medicao.dataHora,
        foto: urlFoto,
        descricao: medicao.descricao,
        temperatura: medicao.temperatura,
        medidaX: medicao.medidaX,
        medidaY: medicao.medidaY,
        status: medicao.status,
      );

      final payload = medicaoComFoto.toJson(instalacaoAtual.id!);
      List<MedicaoFissuraModel> medicoesAtualizadas;
      if (medicao.id == null) {
        final res = await _supabase.from('ponto_ensaio_monitoramento_fissura_leitura').insert(payload).select('id').single();
        medicoesAtualizadas = [
          ...instalacaoAtual.medicoes,
          MedicaoFissuraModel(
            id: res['id'] as String,
            instalacaoId: instalacaoAtual.id,
            dataHora: medicaoComFoto.dataHora,
            foto: medicaoComFoto.foto,
            descricao: medicaoComFoto.descricao,
            temperatura: medicaoComFoto.temperatura,
            medidaX: medicaoComFoto.medidaX,
            medidaY: medicaoComFoto.medidaY,
            status: medicaoComFoto.status,
          ),
        ];
      } else {
        await _supabase.from('ponto_ensaio_monitoramento_fissura_leitura').update(payload).eq('id', medicao.id!);
        medicoesAtualizadas = instalacaoAtual.medicoes.map((m) => m.id == medicao.id ? medicaoComFoto : m).toList();
      }

      await _atualizarResumoGeral(pontoGeralId, instalacaoAtual.copyWith(medicoes: medicoesAtualizadas));
    } on PostgrestException catch (e) {
      throw Exception('Erro ao salvar medição: ${e.message}');
    }
  }

  Future<void> deletarMedicao({
    required String pontoGeralId,
    required InstalacaoFissuraModel instalacaoAtual,
    required String medicaoId,
  }) async {
    try {
      await _supabase.from('ponto_ensaio_monitoramento_fissura_leitura').delete().eq('id', medicaoId);
      final medicoesAtualizadas = instalacaoAtual.medicoes.where((m) => m.id != medicaoId).toList();
      await _atualizarResumoGeral(pontoGeralId, instalacaoAtual.copyWith(medicoes: medicoesAtualizadas));
    } on PostgrestException catch (e) {
      throw Exception('Erro ao excluir medição: ${e.message}');
    }
  }

  Future<void> deletarPontoCompleto(String pontoGeralId) async {
    try {
      final instalacaoResp =
          await _supabase.from('ponto_ensaio_monitoramento_fissura').select('id').eq('ponto_ensaio_id', pontoGeralId).maybeSingle();
      final instalacaoId = instalacaoResp?['id']?.toString();

      if (instalacaoId != null) {
        await _supabase.from('ponto_ensaio_monitoramento_fissura_leitura').delete().eq('ponto_id', instalacaoId);
        await _supabase.from('ponto_ensaio_monitoramento_fissura').delete().eq('id', instalacaoId);
      }

      await _supabase.from('galeria_pontos_ensaios_geral').delete().eq('ponto_ensaio_id', pontoGeralId);
      await _supabase.from('pontos_ensaios_geral').delete().eq('id', pontoGeralId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao excluir ponto: ${e.message}');
    }
  }
}
