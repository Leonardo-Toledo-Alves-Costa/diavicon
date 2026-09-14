import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ponto_potencial_model.dart';

final potencialRepositoryProvider = Provider<PotencialRepository>((ref) {
  return PotencialRepository(Supabase.instance.client);
});

class PotencialRepository {
  final SupabaseClient _supabase;

  PotencialRepository(this._supabase);

  Future<String?> uploadImagem(File file, String folder) async {
    try {
      final fileExt = file.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final fullPath = 'ensaios/$folder/$fileName';

      await _supabase.storage.from('projetos').upload(
        fullPath,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      return _supabase.storage.from('projetos').getPublicUrl(fullPath);
    } on StorageException catch (e) {
      debugPrint('Erro de Storage: ${e.message}');
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<PontoPotencialModel?> buscarPontoPotencial(String pontoGeralId) async {
    try {
      final res = await _supabase
          .from('ponto_ensaio_potencial')
          .select('*')
          .eq('ponto_ensaio_id', pontoGeralId)
          .maybeSingle();

      if (res == null) return null;

      final idPotencial = res['id'] as String;

      final leiturasRes = await _supabase
          .from('ponto_ensaio_potencial_leitura')
          .select('*')
          .eq('ponto_potencial_id', idPotencial)
          .order('linha', ascending: true)
          .order('coluna', ascending: true);

      List<PontoPotencialLeituraModel> leituras = (leiturasRes as List)
          .map((lMap) => PontoPotencialLeituraModel.fromMap(lMap))
          .toList();

      return PontoPotencialModel.fromMap(res, leituras: leituras);
    } on PostgrestException catch (e) {
      throw Exception('Erro no banco de dados: ${e.message}');
    }
  }


  Future<Map<String, dynamic>> salvarPotencialCompleto({
    required PontoPotencialModel dados,
    required String projetoId,
    required String elementoId,
    required String tipoEnsaioId,
    required String pontoNome,
    //required String estruturaId,
    File? fotoElementoLocal,
    File? fotoEnsaioLocal,
    File? fotoSobreposicaoLocal,

  }) async {
    try {
      String? urlElem = dados.imagemElemento;
      String? urlEns = dados.imagemEnsaio;
      String? urlSob = dados.imagemElementoEnsaio;

      if (fotoElementoLocal != null) urlElem = await uploadImagem(fotoElementoLocal, 'potencial');
      if (fotoEnsaioLocal != null) urlEns = await uploadImagem(fotoEnsaioLocal, 'potencial');
      if (fotoSobreposicaoLocal != null) urlSob = await uploadImagem(fotoSobreposicaoLocal, 'potencial');

      String pontoGeralId = dados.pontoEnsaioId ?? '';
      
      final double valorMedia = dados.mediaPotencial;
      final tagTexto = valorMedia != 0.0 ? '-${valorMedia.toStringAsFixed(0)} mV' : 'Pendente';
      final tagCor = valorMedia > 350 ? '#F44336' : (valorMedia > 200 ? '#FF9800' : '#4CAF50');
      final userId = _supabase.auth.currentUser?.id;

      final String? userIdT = _supabase.auth.currentUser?.id;
      if (userIdT == null) {
        throw const AuthException('Usuário não está autenticado ou a sessão expirou.');
      }
          final elementoResponse = await _supabase
          .from('elementos_estruturais')
          .select('estrutura_id')
          .eq('id', elementoId)
          .single();

          final String? estruturaId = elementoResponse['estrutura_id'] as String?;

          if (estruturaId == null) {
            throw Exception('Nenhuma estrutura vinculada a este elemento foi encontrada.');
          }

      

      // 1. Tabela Geral
      if (pontoGeralId.isEmpty) {
        final resGeral = await _supabase.from('pontos_ensaios_geral').insert({
          'nome_ponto': pontoNome,
          'tipo_ensaio': 'Potencial de Corrosão', 
          'tipo_ensaio_id': tipoEnsaioId, 
          'elemento_estrutural_id': elementoId,
          'projeto_id': projetoId,
          'valor_resultado': tagTexto,
          'cor_resultado': tagCor,
          'criado_por': userId, 
          'estrutura_id': estruturaId,
        }).select('id').single();
        pontoGeralId = resGeral['id'] as String;
      } else {
        await _supabase.from('pontos_ensaios_geral').update({
          'nome_ponto': pontoNome,
          'tipo_ensaio_id': tipoEnsaioId, 
          'valor_resultado': tagTexto,
          'cor_resultado': tagCor,
        }).eq('id', pontoGeralId);
      }

      // 2. Tabela Potencial (AGORA COM OS DADOS COMPLETOS DA HOMOGRAFIA E ANÁLISE)
      String potencialId = dados.id ?? '';
      final payloadPotencial = {
        'ponto_ensaio_id': pontoGeralId,
        'eletrodo': dados.eletrodo,
        'tempo_saturacao': dados.tempoSaturacao,
        'temperatura': dados.temperatura,
        'espaçamento_x': dados.espacamentoX,
        'espaçamento_y': dados.espacamentoY,
        'imagem_elemento': urlElem,
        'imagem_ensaio': urlEns,
        'imagem_elemento_ensaio': urlSob,
        
        // --- CHAVES QUE FALTAVAM PARA A ANÁLISE ---
        'imagem_mapa_calor': dados.imagemMapaCalor,
        'imagem_elemento_mapa': dados.imagemElementoMapa,
        'opacidade': dados.opacidade,
        'p1_x': dados.p1X, 'p1_y': dados.p1Y,
        'p2_x': dados.p2X, 'p2_y': dados.p2Y,
        'p3_x': dados.p3X, 'p3_y': dados.p3Y,
        'p4_x': dados.p4X, 'p4_y': dados.p4Y,
      };

      if (potencialId.isEmpty) {
        final res = await _supabase.from('ponto_ensaio_potencial').insert(payloadPotencial).select('id').single();
        potencialId = res['id'] as String;
      } else {
        await _supabase.from('ponto_ensaio_potencial').update(payloadPotencial).eq('id', potencialId);
      }

      // 3. Deletar leituras antigas e inserir a malha nova
      if (potencialId.isNotEmpty) {
        await _supabase.from('ponto_ensaio_potencial_leitura').delete().eq('ponto_potencial_id', potencialId);

        final leiturasValidas = dados.leituras.where((l) => l.potencialMv != null).map((l) => {
          'ponto_potencial_id': potencialId,
          'linha': l.linha,
          'coluna': l.coluna,
          'potencial_mv': l.potencialMv,
          'id_leitura_resistividade': l.idLeituraResistividade,
        }).toList();

        if (leiturasValidas.isNotEmpty) {
          await _supabase.from('ponto_ensaio_potencial_leitura').insert(leiturasValidas);
        }
      }

      return {
        'pontoGeralId': pontoGeralId,
        'potencialId': potencialId,
        'urlElemento': urlElem,
        'urlEnsaio': urlEns,
        'urlSobreposicao': urlSob,
      };
    } on PostgrestException catch (e) {
      throw Exception('Erro ao persistir no Supabase: ${e.message}');
    }
  }

  Future<void> deletarPontoCompleto(String pontoGeralId, String? potencialId) async {
    try {
      if (potencialId != null && potencialId.isNotEmpty) {
        await _supabase.from('ponto_ensaio_potencial_leitura').delete().eq('ponto_potencial_id', potencialId);
        await _supabase.from('ponto_ensaio_potencial').delete().eq('id', potencialId);
      }
      await _supabase.from('pontos_ensaios_geral').delete().eq('id', pontoGeralId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao excluir: ${e.message}');
    }
  }
}