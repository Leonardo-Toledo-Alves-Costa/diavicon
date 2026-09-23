import 'package:diavicon/core/security/upload_seguro.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ponto_resistividade_model.dart';
import 'package:diavicon/features/ensaios/ensaios_geral/repositories/ponto_geral_identidade.dart';

final resistividadeRepositoryProvider = Provider((ref) => ResistividadeRepository());

class ResistividadeRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> salvarPonto({
    required PontoResistividadeCompletoModel dados,
    required String projetoId,
    required String elementoId,
    required String tipoEnsaioId,
    //required String estruturaId,
    File? fotoElementoNova,
    File? fotoRealizandoNova,
    File? fotoGridNova,
    File? fotoGridComPontosNova, // Foto gerada no app

    // 1. Busca a estrutura_id a partir do elementoId fornecido na tabela elementos_estruturais
      
  }) async {
    try {
      String pontoGeralId = dados.idGeral ?? '';

      // 1. Inserir ou Atualizar em `pontos_ensaios_geral`
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
          'tipo_ensaio': 'Resistividade el. sup.',
          'criado_por': _supabase.auth.currentUser?.id,
          'criado_em': dados.criadoEm,              // 👈 Novo
          'valor_resultado': dados.resultado,       // 👈 Novo
          'cor_resultado': dados.resultadoCor,      // 👈 Novo
          'estrutura_id': estruturaId,
        }).select('id').single();
        pontoGeralId = geralResp['id'] as String;
      } else {
        await _supabase.from('pontos_ensaios_geral').update({
          'nome_ponto': dados.nomePonto,
          'valor_resultado': dados.resultado,       // 👈 Novo
          'cor_resultado': dados.resultadoCor,      // 👈 Novo
        }).eq('id', pontoGeralId);
        // Ponto antigo sem estrutura/tipo? Completa ao salvar (ver ponto_geral_identidade.dart).
        await completarIdentidadePontoGeral(_supabase, pontoGeralId: pontoGeralId, elementoId: elementoId, tipoEnsaioId: tipoEnsaioId);
      }

      // 2. Upload de Imagens (Tabela: galeria_ponto_ensaio_resistividade)
      // Referências: 1-Elemento, 2-Realizando, 3-Grid, 4-Grid c/ Pontos
      Future<String?> uploadFoto(File? foto, String ref, String pasta) async {
        if (foto == null) return null;
        final path = await _supabase.storage.from('projetos').enviarArquivoSeguro(
          'ensaios/resistividade',
          foto,
          prefixo: '${pontoGeralId}_ref${ref}_',
          fileOptions: const FileOptions(upsert: true),
        );
        final url = _supabase.storage.from('projetos').getPublicUrl(path);

        // Remove a antiga se existir, e insere a nova
        await _supabase.from('galeria_ponto_ensaio_resistividade')
            .delete().eq('ponto_ensaio_id', pontoGeralId).eq('referencia', ref);

        await _supabase.from('galeria_ponto_ensaio_resistividade').insert({
          'ponto_ensaio_id': pontoGeralId,
          'imagem_url': url,
          'referencia': ref,
          'criado_por': _supabase.auth.currentUser?.id,
        });
        return url;
      }

      final urlElem = await uploadFoto(fotoElementoNova, '1','resistividade');
      final urlReal = await uploadFoto(fotoRealizandoNova, '2','resistividade');
      final urlGrid = await uploadFoto(fotoGridNova, '3','resistividade');
      final urlGridPts = await uploadFoto(fotoGridComPontosNova, '4','resistividade');

      // 3. Salvar as Leituras
      for (var leitura in dados.leituras) {
        if (leitura.id != null) {
          await _supabase.from('ponto_ensaio_resistividade_leitura')
              .update(leitura.toJson(pontoGeralId)).eq('id', leitura.id!);
        } else {
          await _supabase.from('ponto_ensaio_resistividade_leitura')
              .insert(leitura.toJson(pontoGeralId));
        }
      }

      return {
        'pontoGeralId': pontoGeralId,
        'urlFotoElemento': urlElem ?? dados.urlFotoElemento,
        'urlFotoRealizando': urlReal ?? dados.urlFotoRealizando,
        'urlFotoGrid': urlGrid ?? dados.urlFotoGrid,
        'urlFotoGridComPontos': urlGridPts ?? dados.urlFotoGridComPontos,
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
      await _supabase.from('ponto_ensaio_resistividade_leitura').delete().eq('id', idLeitura);
    } catch (e) {
      throw Exception('Erro ao deletar medição: $e');
    }
  }

  Future<void> deletarPontoCompleto(String pontoGeralId) async {
    try {
      await _supabase.from('galeria_ponto_ensaio_resistividade').delete().eq('ponto_ensaio_id', pontoGeralId);
      await _supabase.from('ponto_ensaio_resistividade_leitura').delete().eq('id_ponto_geral', pontoGeralId);
      await _supabase.from('pontos_ensaios_geral').delete().eq('id', pontoGeralId);
    } catch (e) {
      throw Exception('Erro ao excluir ponto: $e');
    }
  }
}