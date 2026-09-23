import 'package:diavicon/core/security/upload_seguro.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/extracao_model.dart';

final extracaoRepositoryProvider = Provider<ExtracaoRepository>((ref) {
  return ExtracaoRepository(Supabase.instance.client);
});

// Diferente dos demais ensaios (1 ponto_ensaio_geral por ELEMENTO), aqui é
// 1 ponto_ensaio_geral por LOCAL (`ponto_ensaio_extracao_local`), com
// múltiplos testemunhos (`ponto_ensaio_extracao_leituras`) cada um vinculado
// ao seu próprio elemento estrutural — ver comentário em `ExtracaoLocalModel`.
class ExtracaoRepository {
  final SupabaseClient _supabase;
  ExtracaoRepository(this._supabase);

  Future<String?> uploadImagem(File file, String campo) async {
    // Tipo, nome e Content-Type decididos pelo app (ver upload_seguro.dart).
    final fullPath = await _supabase.storage.from('projetos').enviarArquivoSeguro(
          'ensaios/extracao_testemunho',
          file,
          prefixo: '${campo}_',
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    return _supabase.storage.from('projetos').getPublicUrl(fullPath);
  }

  Future<String?> resolverNomeLocal(String? localId) async {
    if (localId == null || localId.isEmpty) return null;
    try {
      final res = await _supabase.from('estruturas_locais').select('nome').eq('id', localId).maybeSingle();
      return res?['nome']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<String?> resolverPlantaUrl(String? plantaId) async {
    if (plantaId == null || plantaId.isEmpty) return null;
    try {
      final res = await _supabase.from('estruturas_plantas').select('arquivo_url').eq('id', plantaId).maybeSingle();
      return res?['arquivo_url']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String?>> buscarDadosGerais(String pontoGeralId) async {
    final res = await _supabase.from('pontos_ensaios_geral').select('nome_ponto, estrutura_id, projeto_id, tipo_ensaio_id').eq('id', pontoGeralId).maybeSingle();
    return {
      'nomePonto': res?['nome_ponto']?.toString(),
      'estruturaId': res?['estrutura_id']?.toString(),
      'projetoId': res?['projeto_id']?.toString(),
      'tipoEnsaioId': res?['tipo_ensaio_id']?.toString(),
    };
  }

  Future<ExtracaoLocalModel?> buscarPontoExtracao(String pontoGeralId) async {
    try {
      final res = await _supabase.from('ponto_ensaio_extracao_local').select('*').eq('ponto_id', pontoGeralId).maybeSingle();
      if (res == null) return null;
      final localRegistroId = res['id'] as String;

      final leiturasResp = await _supabase
          .from('ponto_ensaio_extracao_leituras')
          .select('*, elementos_estruturais(nome, tipo)')
          .eq('ponto_local_id', localRegistroId)
          .order('criado_em');
      final leituras = (leiturasResp as List).map((l) => LeituraExtracaoModel.fromJson((l as Map).cast<String, dynamic>())).toList();

      return ExtracaoLocalModel.fromJson(res, leituras: leituras);
    } on PostgrestException catch (e) {
      throw Exception('Erro no banco de dados: ${e.message}');
    }
  }

  /// Cria o registro comum (`pontos_ensaios_geral`) e o registro do Local
  /// (`ponto_ensaio_extracao_local`) — passo 1 do fluxo de criação (Local +
  /// Planta), antes de qualquer ponto de extração existir.
  Future<Map<String, String>> criarLocalInicial({
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioId,
    required String nome,
    required String localId,
    required String plantaId,
  }) async {
    try {
      final geralResp = await _supabase.from('pontos_ensaios_geral').insert({
        'projeto_id': projetoId,
        'estrutura_id': estruturaId,
        'tipo_ensaio_id': tipoEnsaioId,
        'nome_ponto': nome,
        'tipo_ensaio': 'Extração e rompimento de testemunhos',
        'criado_por': _supabase.auth.currentUser?.id,
        'valor_resultado': 'Pendente',
        'cor_resultado': '#BDBDBD',
      }).select('id').single();
      final pontoGeralId = geralResp['id'] as String;

      final localResp = await _supabase.from('ponto_ensaio_extracao_local').insert({
        'ponto_id': pontoGeralId,
        'local_id': localId,
        'planta_id': plantaId,
      }).select('id').single();

      return {'pontoGeralId': pontoGeralId, 'pontoLocalId': localResp['id'] as String};
    } on PostgrestException catch (e) {
      throw Exception('Erro ao criar ensaio: ${e.message}');
    }
  }

  Future<void> renomearPonto({required String pontoGeralId, required String nome}) async {
    await _supabase.from('pontos_ensaios_geral').update({'nome_ponto': nome}).eq('id', pontoGeralId);
  }

  Future<void> salvarLeitura({
    required ExtracaoLocalModel localAtual,
    required LeituraExtracaoModel leitura,
    File? fotoExtraindoNova,
    File? fotoExtracaoNova,
    File? fotoRecomposicaoNova,
    File? fotoPlantaNova,
  }) async {
    try {
      String? urlExtraindo = leitura.fotoExtraindo;
      String? urlExtracao = leitura.fotoExtracao;
      String? urlRecomposicao = leitura.fotoRecomposicao;
      String? urlPlanta = leitura.fotoPlanta;
      if (fotoExtraindoNova != null) urlExtraindo = await uploadImagem(fotoExtraindoNova, 'extraindo');
      if (fotoExtracaoNova != null) urlExtracao = await uploadImagem(fotoExtracaoNova, 'extracao');
      if (fotoRecomposicaoNova != null) urlRecomposicao = await uploadImagem(fotoRecomposicaoNova, 'recomposicao');
      if (fotoPlantaNova != null) urlPlanta = await uploadImagem(fotoPlantaNova, 'planta_ponto');

      final leituraComFotos = LeituraExtracaoModel(
        id: leitura.id,
        pontoLocalId: localAtual.id,
        elementoId: leitura.elementoId,
        criadoEm: leitura.criadoEm,
        nomeTestemunho: leitura.nomeTestemunho,
        posX: leitura.posX,
        posY: leitura.posY,
        fotoExtraindo: urlExtraindo,
        fotoExtracao: urlExtracao,
        fotoRecomposicao: urlRecomposicao,
        fotoPlanta: urlPlanta,
        direcao: leitura.direcao,
        relacaoHD: leitura.relacaoHD,
        diametroTestemunho: leitura.diametroTestemunho,
        condicaoUmidade: leitura.condicaoUmidade,
        resistenciaSemCorrecao: leitura.resistenciaSemCorrecao,
      );

      final payload = leituraComFotos.toJson(localAtual.id!);
      if (leitura.id == null) {
        await _supabase.from('ponto_ensaio_extracao_leituras').insert(payload);
      } else {
        await _supabase.from('ponto_ensaio_extracao_leituras').update(payload).eq('id', leitura.id!);
      }
    } on PostgrestException catch (e) {
      throw Exception('Erro ao salvar ponto de extração: ${e.message}');
    }
  }

  Future<void> deletarLeitura(String leituraId) async {
    try {
      await _supabase.from('ponto_ensaio_extracao_leituras').delete().eq('id', leituraId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao excluir ponto de extração: ${e.message}');
    }
  }

  /// Salva a captura da planta com os pontos já desenhados por cima (gerada
  /// via `RepaintBoundary` na tela) — mesmo padrão de
  /// `ProvaCargaRepository.salvarImagemComposta`.
  static const _legendaImagemComposta = 'Planta com marcações';

  Future<void> salvarImagemComposta({required String pontoGeralId, required String pontoLocalId, required File imagem}) async {
    try {
      final path = await _supabase.storage.from('projetos').enviarArquivoSeguro(
        'ensaios/extracao_testemunho',
        imagem,
        prefixo: '${pontoGeralId}_marcada_',
        fileOptions: const FileOptions(upsert: true),
      );
      final url = _supabase.storage.from('projetos').getPublicUrl(path);

      await _supabase.from('galeria_pontos_ensaios_geral').delete().eq('ponto_ensaio_id', pontoGeralId).eq('legenda', _legendaImagemComposta);
      await _supabase.from('galeria_pontos_ensaios_geral').insert({
        'ponto_ensaio_id': pontoGeralId,
        'imagem_url': url,
        'legenda': _legendaImagemComposta,
        'criado_por': _supabase.auth.currentUser?.id,
        // `criado_em` não tem DEFAULT nessa tabela (diferente de outras) —
        // sem isso o insert falha com "null value ... violates not-null
        // constraint" (bug reportado).
        'criado_em': DateTime.now().toIso8601String(),
      });

      await _supabase.from('ponto_ensaio_extracao_local').update({'planta_marcada': url}).eq('id', pontoLocalId);
    } catch (e) {
      throw Exception('Erro ao salvar imagem da planta marcada: $e');
    }
  }

  Future<void> deletarPontoCompleto(String pontoGeralId) async {
    try {
      final localResp = await _supabase.from('ponto_ensaio_extracao_local').select('id').eq('ponto_id', pontoGeralId).maybeSingle();
      final pontoLocalId = localResp?['id']?.toString();

      if (pontoLocalId != null) {
        await _supabase.from('ponto_ensaio_extracao_leituras').delete().eq('ponto_local_id', pontoLocalId);
        await _supabase.from('ponto_ensaio_extracao_local').delete().eq('id', pontoLocalId);
      }

      await _supabase.from('galeria_pontos_ensaios_geral').delete().eq('ponto_ensaio_id', pontoGeralId);
      await _supabase.from('pontos_ensaios_geral').delete().eq('id', pontoGeralId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao excluir ponto: ${e.message}');
    }
  }
}
