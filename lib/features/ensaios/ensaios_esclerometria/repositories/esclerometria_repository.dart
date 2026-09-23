import 'package:diavicon/core/security/upload_seguro.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/esclerometria_model.dart';
import 'package:diavicon/features/ensaios/ensaios_geral/repositories/ponto_geral_identidade.dart';

final esclerometriaRepositoryProvider = Provider((ref) => EsclerometriaRepository());

class EsclerometriaRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> salvarPonto({
    required EsclerometriaCompletoModel dados,
    required String projetoId,
    required String elementoId,
    required String tipoEnsaioId,
    File? fotoJanelaNova,
    File? fotoEnsaioNova,
  }) async {
    try {
      String pontoGeralId = dados.idGeral ?? '';

      // 1. `pontos_ensaios_geral`
      if (pontoGeralId.isEmpty) {
        final elementoResponse = await _supabase
            .from('elementos_estruturais')
            .select('estrutura_id')
            .eq('id', elementoId)
            .single();

        final String? estruturaId = elementoResponse['estrutura_id'] as String?;
        if (estruturaId == null) {
          throw Exception('Nenhuma estrutura vinculada a este elemento foi encontrada.');
        }

        final geralResp = await _supabase.from('pontos_ensaios_geral').insert({
          'projeto_id': projetoId,
          'elemento_estrutural_id': elementoId,
          'tipo_ensaio_id': tipoEnsaioId,
          'nome_ponto': dados.nomePonto,
          'tipo_ensaio': 'Esclerometria',
          'criado_por': _supabase.auth.currentUser?.id,
          'criado_em': dados.criadoEm,
          'valor_resultado': dados.resultado,
          'cor_resultado': dados.resultadoCor,
          'estrutura_id': estruturaId,
        }).select('id').single();
        pontoGeralId = geralResp['id'] as String;
      } else {
        await _supabase.from('pontos_ensaios_geral').update({
          'nome_ponto': dados.nomePonto,
          'valor_resultado': dados.resultado,
          'cor_resultado': dados.resultadoCor,
        }).eq('id', pontoGeralId);
        // Ponto antigo sem estrutura/tipo? Completa ao salvar (ver ponto_geral_identidade.dart).
        await completarIdentidadePontoGeral(_supabase, pontoGeralId: pontoGeralId, elementoId: elementoId, tipoEnsaioId: tipoEnsaioId);
      }

      // 2. `ponto_ensaio_esclerometria` (upsert — leituras dependem do seu id)
      String? esclerometriaId = dados.idEsclerometria;
      final dadosEsclerometria = {
        'inclinacao': dados.inclinacao,
        'indice_k': dados.indiceK,
      };

      if (esclerometriaId != null) {
        await _supabase.from('ponto_ensaio_esclerometria').update(dadosEsclerometria).eq('id', esclerometriaId);
      } else {
        final resp = await _supabase.from('ponto_ensaio_esclerometria').insert({
          ...dadosEsclerometria,
          'ponto_geral_id': pontoGeralId,
        }).select('id').single();
        esclerometriaId = resp['id'] as String;
      }

      // 3. Fotos (foto_janela = marcação da área, foto_ensaio = realização do ensaio)
      Future<String?> uploadFoto(File? foto, String campo) async {
        if (foto == null) return null;
        final path = await _supabase.storage.from('projetos').enviarArquivoSeguro(
          'ensaios/esclerometria',
          foto,
          prefixo: '${esclerometriaId}_${campo}_',
          fileOptions: const FileOptions(upsert: true),
        );
        final url = _supabase.storage.from('projetos').getPublicUrl(path);

        await _supabase.from('ponto_ensaio_esclerometria').update({campo: url}).eq('id', esclerometriaId!);
        return url;
      }

      final urlJanela = await uploadFoto(fotoJanelaNova, 'foto_janela');
      final urlEnsaio = await uploadFoto(fotoEnsaioNova, 'foto_ensaio');

      // 4. Leituras
      for (final leitura in dados.leituras) {
        if (leitura.id != null) {
          await _supabase
              .from('ponto_ensaio_esclerometria_leituras')
              .update(leitura.toJson(esclerometriaId))
              .eq('id', leitura.id!);
        } else {
          await _supabase.from('ponto_ensaio_esclerometria_leituras').insert(leitura.toJson(esclerometriaId));
        }
      }

      return {
        'pontoGeralId': pontoGeralId,
        'esclerometriaId': esclerometriaId,
        'urlFotoJanela': urlJanela ?? dados.urlFotoJanela,
        'urlFotoEnsaio': urlEnsaio ?? dados.urlFotoEnsaio,
      };
    } on PostgrestException catch (e) {
      throw Exception('Erro de banco de dados: ${e.message}');
    } on AuthException catch (e) {
      throw Exception('Erro de autenticação: ${e.message}');
    } catch (e) {
      throw Exception('Erro inesperado ao salvar: $e');
    }
  }

  Future<void> deletarLeitura(String idLeitura) async {
    try {
      await _supabase.from('ponto_ensaio_esclerometria_leituras').delete().eq('id', idLeitura);
    } catch (e) {
      throw Exception('Erro ao deletar leitura: $e');
    }
  }

  Future<void> deletarPontoCompleto(String pontoGeralId) async {
    try {
      final esclerometriaResp = await _supabase
          .from('ponto_ensaio_esclerometria')
          .select('id')
          .eq('ponto_geral_id', pontoGeralId)
          .maybeSingle();

      final esclerometriaId = esclerometriaResp?['id']?.toString();
      if (esclerometriaId != null) {
        await _supabase.from('ponto_ensaio_esclerometria_leituras').delete().eq('ponto_id', esclerometriaId);
        await _supabase.from('ponto_ensaio_esclerometria').delete().eq('id', esclerometriaId);
      }

      await _supabase.from('galeria_pontos_ensaios_geral').delete().eq('ponto_ensaio_id', pontoGeralId);
      await _supabase.from('pontos_ensaios_geral').delete().eq('id', pontoGeralId);
    } catch (e) {
      throw Exception('Erro ao excluir ponto: $e');
    }
  }
}
