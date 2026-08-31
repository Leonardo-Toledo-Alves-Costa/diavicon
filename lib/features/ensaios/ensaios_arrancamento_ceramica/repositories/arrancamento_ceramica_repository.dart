import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ponto_arrancamento_ceramica_model.dart';

final arrancamentoCeramicaRepositoryProvider = Provider<ArrancamentoCeramicaRepository>((ref) {
  return ArrancamentoCeramicaRepository(Supabase.instance.client);
});

class ArrancamentoCeramicaRepository {
  final SupabaseClient _supabase;

  ArrancamentoCeramicaRepository(this._supabase);

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
      debugPrint('Erro desconhecido no upload: $e');
      return null;
    }
  }

  Future<String?> buscarIdadeEstruturaPorElemento(String elementoId) async {
    try {
      final res = await _supabase.from('elementos_estruturais').select('estruturas(ano_concepcao)').eq('id', elementoId).maybeSingle();
      if (res != null && res['estruturas'] != null && res['estruturas']['ano_concepcao'] != null) {
        final anoConcepcao = res['estruturas']['ano_concepcao'] as int;
        final idade = DateTime.now().year - anoConcepcao;
        return idade >= 0 ? idade.toString() : '0';
      }
    } catch (_) {}
    return null;
  }

  Future<PontoArrancamentoCeramicaModel?> buscarPontoArrancamento(String pontoGeralId) async {
    try {
      final res = await _supabase.from('ponto_ensaio_arrancamento').select('*').eq('ponto_ensaio_id', pontoGeralId).maybeSingle();
      if (res == null) return null;

      final idArrancamento = res['id'] as String;
      final leiturasRes = await _supabase.from('ponto_ensaio_arrancamento_leitura').select('*').eq('id_ponto_arrancamento', idArrancamento).order('criado_em', ascending: true);

      List<PontoLeituraCeramicaModel> leituras = [];
      for (var lMap in (leiturasRes as List)) {
        final lId = lMap['id'] as String;
        final rupturasRes = await _supabase.from('ponto_ensaio_arrancamento_ruptura').select('*').eq('id_ponto_leitura', lId);

        final rupturas = (rupturasRes as List).map((r) => RupturaCeramicaModel.fromMap(r)).toList();
        leituras.add(PontoLeituraCeramicaModel.fromMap(lMap, rupturas: rupturas));
      }

      return PontoArrancamentoCeramicaModel.fromMap(res, leituras: leituras);
    } on PostgrestException catch (e) {
      throw Exception('Erro no banco de dados: ${e.message}');
    } catch (e) {
      throw Exception('Erro ao carregar dados: $e');
    }
  }

  Future<void> atualizarResultadoGeral(String pontoGeralId, double mediaVal) async {
    try {
      final tagTexto = mediaVal > 0 ? '${mediaVal.toStringAsFixed(2)} MPa' : 'Pendente';
      final tagCor = mediaVal >= 0.30 ? '#4CAF50' : (mediaVal > 0 ? '#F44336' : '#9E9E9E');

      await _supabase.from('pontos_ensaios_geral').update({
        'valor_resultado': tagTexto,
        'cor_resultado': tagCor,
      }).eq('id', pontoGeralId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao atualizar resultado: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> salvarArrancamentoCompleto({
    required PontoArrancamentoCeramicaModel dados,
    required String projetoId,
    required String elementoId,
    required String tipoEnsaioId,
    required String pontoNome,
   //required String estruturaId,
    File? fotoRegiao,
    File? fotoColagem,
  }) async {
    try {
      String? urlRegiao = dados.imagemRegiao;
      String? urlColagem = dados.imagemColagem;

      if (fotoRegiao != null) urlRegiao = await uploadImagem(fotoRegiao, 'arrancamento_ceramica') ?? urlRegiao;
      if (fotoColagem != null) urlColagem = await uploadImagem(fotoColagem, 'arrancamento_ceramica') ?? urlColagem;

      String pontoGeralId = dados.pontoEnsaioId ?? '';
      final mediaVal = dados.mediaTensao;
      final tagTexto = mediaVal > 0 ? '${mediaVal.toStringAsFixed(2)} MPa' : 'Pendente';
      final tagCor = mediaVal >= 0.30 ? '#4CAF50' : (mediaVal > 0 ? '#F44336' : '#9E9E9E');
      //final userId = _supabase.auth.currentUser?.id; 
      final String? userIdT = _supabase.auth.currentUser?.id;
      if (userIdT == null) {
        throw const AuthException('Usuário não está autenticado ou a sessão expirou.');
      }
      final String userId = userIdT;
      final usuarioResponse = await _supabase
          .from('usuarios')
          .select('empresa_id')
          .eq('id', userIdT)
          .single();

      final String? empresaId = usuarioResponse['empresa_id'] as String?;

      if (empresaId == null) {
        throw Exception('Usuário não está vinculado a nenhuma empresa.');
      }

      

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

        final resGeral = await _supabase.from('pontos_ensaios_geral').insert({
          'nome_ponto': pontoNome,
          'tipo_ensaio': 'Arrancamento em Placa Cerâmica', 
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

      String arrancamentoId = dados.id ?? '';
      final payloadArrancamento = {
        'ponto_ensaio_id': pontoGeralId,
        'imagem_regiao': urlRegiao,
        'imagem_colagem': urlColagem,
        'norma': dados.norma,
        'temperatura': dados.temperatura,
        'umidade': dados.umidade,
        'idade_revestimento': dados.idadeRevestimento,
        'cola_utilizada': dados.colaUtilizada,
        // tipo_substrato removido intencionalmente
      };

      if (arrancamentoId.isEmpty) {
        final resArr = await _supabase.from('ponto_ensaio_arrancamento').insert(payloadArrancamento).select('id').single();
        arrancamentoId = resArr['id'] as String;
      } else {
        await _supabase.from('ponto_ensaio_arrancamento').update(payloadArrancamento).eq('id', arrancamentoId);
      }

      return {
        'pontoGeralId': pontoGeralId,
        'arrancamentoId': arrancamentoId,
        'urlRegiao': urlRegiao,
        'urlColagem': urlColagem,
      };
    } on PostgrestException catch (e) {
      throw Exception('Erro ao persistir no Supabase: ${e.message}');
    }
  }

  Future<void> deletarPontoCompleto(String pontoGeralId, String? arrancamentoId) async {
    try {
      if (arrancamentoId != null && arrancamentoId.isNotEmpty) {
        final leituras = await _supabase.from('ponto_ensaio_arrancamento_leitura').select('id').eq('id_ponto_arrancamento', arrancamentoId);
        for (var l in (leituras as List)) {
          await _supabase.from('ponto_ensaio_arrancamento_ruptura').delete().eq('id_ponto_leitura', l['id']);
        }
        await _supabase.from('ponto_ensaio_arrancamento_leitura').delete().eq('id_ponto_arrancamento', arrancamentoId);
        await _supabase.from('ponto_ensaio_arrancamento').delete().eq('id', arrancamentoId);
      }
      await _supabase.from('pontos_ensaios_geral').delete().eq('id', pontoGeralId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao excluir: ${e.message}');
    }
  }

  Future<void> salvarPontoLeitura({
    required String idArrancamento,
    required PontoLeituraCeramicaModel leitura,
    File? fotoEnsaio,
    File? fotoRuptura,
  }) async {
    try {
      String? urlEnsaio = leitura.imagemEnsaio;
      String? urlRuptura = leitura.imagemRuptura;

      if (fotoEnsaio != null) urlEnsaio = await uploadImagem(fotoEnsaio, 'arrancamento_ceramica') ?? urlEnsaio;
      if (fotoRuptura != null) urlRuptura = await uploadImagem(fotoRuptura, 'arrancamento_ceramica') ?? urlRuptura;

      final payload = {
        'id_ponto_arrancamento': idArrancamento,
        'nome': leitura.nome,
        'imagem_ensaio': urlEnsaio,
        'imgem_ruptura': urlRuptura, 
        'area': leitura.area,
        'carga': leitura.carga,
        // d1 e d2 omitidos
      };

      String leituraId = leitura.id ?? '';

      if (leituraId.isEmpty) {
        final res = await _supabase.from('ponto_ensaio_arrancamento_leitura').insert(payload).select('id').single();
        leituraId = res['id'] as String;
      } else {
        await _supabase.from('ponto_ensaio_arrancamento_leitura').update(payload).eq('id', leituraId);
      }

      await _supabase.from('ponto_ensaio_arrancamento_ruptura').delete().eq('id_ponto_leitura', leituraId);

      final rupturasValidas = leitura.rupturas.where((r) => r.porcentagem > 0).map((r) => {
        'id_ponto_leitura': leituraId,
        'tipo_ruptura': r.tipoRuptura,
        'porcentagem': r.porcentagem,
      }).toList();

      if (rupturasValidas.isNotEmpty) {
        await _supabase.from('ponto_ensaio_arrancamento_ruptura').insert(rupturasValidas);
      }
    } on PostgrestException catch (e) {
      throw Exception('Erro ao gravar leitura: ${e.message}');
    }
  }

  Future<void> deletarPontoLeitura(String leituraId) async {
    try {
      await _supabase.from('ponto_ensaio_arrancamento_ruptura').delete().eq('id_ponto_leitura', leituraId);
      await _supabase.from('ponto_ensaio_arrancamento_leitura').delete().eq('id', leituraId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao remover leitura: ${e.message}');
    }
  }
}