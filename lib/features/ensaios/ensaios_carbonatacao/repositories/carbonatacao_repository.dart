import 'package:diavicon/core/security/upload_seguro.dart';
import 'dart:io';
import 'dart:math'; // Necessário para os cálculos de raiz (sqrt) e potência (pow)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ponto_carbonatacao_completo_model.dart';
import 'package:diavicon/features/ensaios/ensaios_geral/repositories/ponto_geral_identidade.dart';

final carbonatacaoRepositoryProvider = Provider<CarbonatacaoRepository>((ref) {
  return CarbonatacaoRepository(Supabase.instance.client);
});

class CarbonatacaoRepository {
  final SupabaseClient _supabase;
  CarbonatacaoRepository(this._supabase);

  // Upload no Storage
  Future<String> _uploadFoto(File arquivo, String pasta) async {
    try {
      // Tipo, nome e Content-Type decididos pelo app (ver upload_seguro.dart).
      final path = await _supabase.storage.from('projetos').enviarArquivoSeguro(
        'ensaios/$pasta',
        arquivo,
        fileOptions: const FileOptions(upsert: true),
      );
      return _supabase.storage.from('projetos').getPublicUrl(path);
    } on ArquivoInvalidoException {
      rethrow;
    } on StorageException catch (e) {
      throw Exception('Erro de Storage (Verifique o Bucket "projetos"): ${e.message}');
    } catch (e) {
      throw Exception('Erro inesperado no upload da imagem: $e');
    }
  }

  // CREATE / UPDATE
  Future<Map<String, dynamic>> salvarPonto({
    required PontoCarbonatacaoCompletoModel dados,
    required String projetoId,
    required String elementoId,
    required String tipoEnsaioId,
    
    File? fotoQuebraNova,
    File? fotoAspersaoNova,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const AuthException('Usuário não autenticado.');

      final String agora = DateTime.now().toIso8601String();

      // =========================================================
      // 1. UPLOAD DE FOTOS PRIMEIRO
      // =========================================================
      String? urlQuebraFinal = dados.urlFotoQuebra;
      if (fotoQuebraNova != null) {
        urlQuebraFinal = await _uploadFoto(fotoQuebraNova, 'carbonatacao');
      }

      String? urlAspersaoFinal = dados.urlFotoAspersao;
      if (fotoAspersaoNova != null) {
        urlAspersaoFinal = await _uploadFoto(fotoAspersaoNova, 'carbonatacao');
      }

      // =========================================================
      // 2. CÁLCULO DE RISCO PARA SALVAR NA TABELA GERAL
      // =========================================================
      
      // A. Busca a idade da estrutura[cite: 12]
      final elementoResp = await _supabase
          .from('elementos_estruturais')
          .select('estrutura_id')
          .eq('id', elementoId)
          .maybeSingle();

      int anoConcepcao = DateTime.now().year;
      if (elementoResp != null && elementoResp['estrutura_id'] != null) {
        final estruturaResp = await _supabase
            .from('estruturas')
            .select('ano_concepcao')
            .eq('id', elementoResp['estrutura_id'])
            .maybeSingle();
        if (estruturaResp != null && estruturaResp['ano_concepcao'] != null) {
          anoConcepcao = (estruturaResp['ano_concepcao'] as num).toInt();
        }
      }
      int idade = max(1, DateTime.now().year - anoConcepcao);

      // B. Calcula o cobrimento efetivo[cite: 12]
      double cobP = dados.cobArmP ?? 0.0;
      double cobS = dados.cobArmS ?? 0.0;
      double cobrimentoEfetivo = 0.0;
      if (cobS > 0 && cobP > 0) {
        cobrimentoEfetivo = min(cobS, cobP);
      } else if (cobS > 0) cobrimentoEfetivo = cobS;
      else cobrimentoEfetivo = cobP;

      // C. Calcula a média das frentes de carbonatação[cite: 12]
      double mediaFrentes = 0.0;
      if (dados.frentes.isNotEmpty) {
        mediaFrentes = dados.frentes.map((f) => f.profundidade).reduce((a, b) => a + b) / dados.frentes.length;
      }

      // D. Lógica Matemática do Risco[cite: 12]
      double coefCarb = mediaFrentes / sqrt(idade);
      double tempoCarbonatar = coefCarb > 0 ? pow(cobrimentoEfetivo / coefCarb, 2).toDouble() : 999.0;
      double deltaCarb = tempoCarbonatar - idade;

      String valorResultado;
      String corResultado;

      if (deltaCarb <= 0) {
        valorResultado = "Despassivado";
        corResultado = "#FF4C4C";
      } else if (deltaCarb < 5) {
        valorResultado = "Risco Alto";
        corResultado = "#FF8C00";
      } else if (deltaCarb < 15) {
        valorResultado = "Risco Moderado";
        corResultado = "#FFB74D";
      } else if (deltaCarb < 30) {
        valorResultado = "Risco Baixo";
        corResultado = "#AED581";
      } else {
        valorResultado = "Risco Irrelevante";
        corResultado = "#81C784";
      }

      // =========================================================
      // 3. SALVAR NO BANCO DE DADOS (INJETANDO OS RESULTADOS)
      // =========================================================
      String pontoGeralId;
      // 1. Busca a estrutura_id a partir do elementoId fornecido na tabela elementos_estruturais
     
      
      // Agrupa os dados que serão criados ou atualizados[cite: 15]
      final dadosGerais = {
        'nome_ponto': dados.nomePonto,
        'valor_resultado': valorResultado, // Preenche a nova coluna[cite: 15]
        'cor_resultado': corResultado,     // Preenche a nova coluna[cite: 15]
      };

      final String? userIdT = _supabase.auth.currentUser?.id;
      if (userIdT == null) {
        throw const AuthException('Usuário não está autenticado ou a sessão expirou.');
      }

final String userId2 = userIdT;
      final usuarioResponse = await _supabase
          .from('usuarios')
          .select('empresa_id')
          .eq('id', userIdT)
          .single();

      final String? empresaId = usuarioResponse['empresa_id'] as String?;

      if (empresaId == null) {
        throw Exception('Usuário não está vinculado a nenhuma empresa.');
      }

      if (dados.idGeral == null || dados.idGeral!.isEmpty) {

                  final elementoResponse = await _supabase
          .from('elementos_estruturais')
          .select('estrutura_id')
          .eq('id', elementoId)
          .single();

          final String? estruturaId = elementoResponse['estrutura_id'] as String?;

          if (estruturaId == null) {
            throw Exception('Nenhuma estrutura vinculada a este elemento foi encontrada.');
          }

        final resp = await _supabase.from('pontos_ensaios_geral').insert({
          ...dadosGerais,
          'criado_por': userId,
          'criado_em': agora,
          'tipo_ensaio_id': tipoEnsaioId,
          'tipo_ensaio': 'Frente de carbonatação',
          'elemento_estrutural_id': elementoId,
          'projeto_id': projetoId,
          'estrutura_id': estruturaId,
          
        }).select('id').single();
        pontoGeralId = resp['id'] as String;
      } else {
        pontoGeralId = dados.idGeral!;
        await _supabase.from('pontos_ensaios_geral').update(dadosGerais).eq('id', pontoGeralId);
        // Ponto antigo sem estrutura/tipo? Completa ao salvar (ver ponto_geral_identidade.dart).
        await completarIdentidadePontoGeral(_supabase, pontoGeralId: pontoGeralId, elementoId: elementoId, tipoEnsaioId: tipoEnsaioId);
      }

      final carbResp = await _supabase
          .from('ponto_ensaio_carb')
          .select('id')
          .eq('ponto_ensaio_id', pontoGeralId)
          .maybeSingle();

      String carbId;
      final dadosCarb = {
        'nome_ponto': dados.nomePonto,
        'cob_arm_p': dados.cobArmP,
        'bit_arm_p': dados.bitArmP,
        'cob_arm_s': dados.cobArmS,
        'bit_arm_s': dados.bitArmS,
      };

      if (carbResp == null) {
        final insertCarb = await _supabase.from('ponto_ensaio_carb').insert({
          ...dadosCarb,
          'criado_por': userId,
          'criado_em': agora,
          'elemento_estrutural_id': elementoId,
          'projeto_id': projetoId,
          'ponto_ensaio_id': pontoGeralId,
        }).select('id').single();
        carbId = insertCarb['id'] as String;
      } else {
        carbId = carbResp['id'] as String;
        await _supabase.from('ponto_ensaio_carb').update(dadosCarb).eq('id', carbId);
      }

      // Atualizar Frentes
      if (dados.frentes.isNotEmpty) {
        for (var frente in dados.frentes) {
          if (frente.id != null && frente.id!.isNotEmpty) {
            await _supabase.from('ponto_ensaio_carb_frentes').update({
              'profundidade': frente.profundidade,
            }).eq('id', frente.id!);
          } else {
            await _supabase.from('ponto_ensaio_carb_frentes').insert({
              'criado_por': userId,
              'criado_em': agora,
              'profundidade': frente.profundidade,
              'ponto_ensaio_id': carbId,
            });
          }
        }
      }

      // Vincular Fotos na Galeria
      Future<void> salvarReferenciaFoto(String? url, String referencia) async {
        if (url == null || url.isEmpty) return;

        final fotoExistente = await _supabase
            .from('galeria_ponto_ensaio_carb')
            .select('id')
            .eq('ponto_ensaio_id', carbId)
            .eq('referencia', referencia)
            .maybeSingle();

        if (fotoExistente != null) {
          await _supabase.from('galeria_ponto_ensaio_carb').update({
            'imagem_url': url,
          }).eq('id', fotoExistente['id']);
        } else {
          await _supabase.from('galeria_ponto_ensaio_carb').insert({
            'criado_por': userId,
            'criado_em': agora,
            'ponto_ensaio_id': carbId,
            'imagem_url': url,
            'referencia': referencia,
          });
        }
      }

      await salvarReferenciaFoto(urlQuebraFinal, '1');
      await salvarReferenciaFoto(urlAspersaoFinal, '2');

      return {
        'pontoGeralId': pontoGeralId,
        'carbId': carbId,
        'urlFotoQuebra': urlQuebraFinal,
        'urlFotoAspersao': urlAspersaoFinal,
      };

    } on PostgrestException catch (e) {
      throw Exception('Erro de Banco de Dados: ${e.message}');
    } on AuthException catch (e) {
      throw Exception('Erro de Autenticação: ${e.message}');
    }
  }

  Future<void> deletarFrente(String frenteId) async {
    try {
      await _supabase.from('ponto_ensaio_carb_frentes').delete().eq('id', frenteId);
    } on PostgrestException catch (e) {
      throw Exception('Erro de Banco de Dados ao deletar frente: ${e.message}');
    }
  }

  Future<void> deletarPontoCompleto(String pontoGeralId, String? carbId) async {
    try {
      if (carbId != null && carbId.isNotEmpty) {
        await _supabase.from('galeria_ponto_ensaio_carb').delete().eq('ponto_ensaio_id', carbId);
        await _supabase.from('ponto_ensaio_carb_frentes').delete().eq('ponto_ensaio_id', carbId);
        await _supabase.from('ponto_ensaio_carb').delete().eq('id', carbId);
      }
      await _supabase.from('pontos_ensaios_geral').delete().eq('id', pontoGeralId);
    } on PostgrestException catch (e) {
      throw Exception('Erro de Banco de Dados ao excluir ponto: ${e.message}');
    }
  }
}