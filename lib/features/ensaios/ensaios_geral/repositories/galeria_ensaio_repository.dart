import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/galeria_ensaio_model.dart';

final galeriaEnsaioRepositoryProvider = Provider<GaleriaEnsaioRepository>((ref) {
  return GaleriaEnsaioRepository(Supabase.instance.client);
});

// Stream reativo: a UI atualiza automaticamente quando houver mudanças no Supabase
final galeriaPontoProvider = StreamProvider.family.autoDispose<List<GaleriaEnsaioModel>, String>((ref, pontoEnsaioId) {
  final supabase = Supabase.instance.client;
  
  return supabase
      .from('galeria_pontos_ensaios_geral')
      .stream(primaryKey: ['id'])
      .eq('ponto_ensaio_id', pontoEnsaioId)
      .order('criado_em', ascending: false)
      .map((list) => list.map((json) => GaleriaEnsaioModel.fromJson(json)).toList());
});

class GaleriaEnsaioRepository {
  final SupabaseClient _supabase;
  GaleriaEnsaioRepository(this._supabase);

  Future<String> _uploadFoto(File arquivo) async {
    try {
      final ext = arquivo.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'ensaios/galeria_geral/$fileName';

      await _supabase.storage.from('projetos').upload(
        path, 
        arquivo,
        fileOptions: const FileOptions(upsert: true),
      );
      return _supabase.storage.from('projetos').getPublicUrl(path);
    } on StorageException catch (e) {
      throw Exception('Erro de Storage: ${e.message}');
    } catch (e) {
      throw Exception('Erro inesperado no upload: $e');
    }
  }

  // CREATE
  Future<void> adicionarImagem({
    required String pontoEnsaioId,
    required File imagemLocal,
    required String legenda,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const AuthException('Usuário não autenticado.');

      final url = await _uploadFoto(imagemLocal);

      await _supabase.from('galeria_pontos_ensaios_geral').insert({
        'criado_por': userId,
        'criado_em': DateTime.now().toIso8601String(),
        'ponto_ensaio_id': pontoEnsaioId,
        'imagem_url': url,
        'legenda': legenda,
      });
    } on PostgrestException catch (e) {
      throw Exception('Erro de Banco de Dados: ${e.message}');
    }
  }

  // UPDATE
  Future<void> atualizarImagem({
    required String imagemId,
    required String urlAtual,
    File? novaImagemLocal,
    required String novaLegenda,
  }) async {
    try {
      String urlFinal = urlAtual;
      
      // Se o usuário selecionou uma nova foto, faz o upload e substitui a URL
      if (novaImagemLocal != null) {
        urlFinal = await _uploadFoto(novaImagemLocal);
      }

      await _supabase.from('galeria_pontos_ensaios_geral').update({
        'imagem_url': urlFinal,
        'legenda': novaLegenda,
      }).eq('id', imagemId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao atualizar: ${e.message}');
    }
  }

  // DELETE
  Future<void> deletarImagem(String imagemId) async {
    try {
      await _supabase.from('galeria_pontos_ensaios_geral').delete().eq('id', imagemId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao deletar imagem: ${e.message}');
    }
  }
}