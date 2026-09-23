import 'package:diavicon/core/security/upload_seguro.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/galeria_rdo_model.dart';

final galeriaRdoRepositoryProvider = Provider<GaleriaRdoRepository>((ref) {
  return GaleriaRdoRepository(Supabase.instance.client);
});

/// Stream reativo — a UI atualiza sozinha quando uma foto é adicionada,
/// editada ou removida, sem precisar de invalidate manual.
final galeriaRdoProvider = StreamProvider.family.autoDispose<List<GaleriaRdoModel>, String>((ref, rdoId) {
  final supabase = Supabase.instance.client;

  return supabase
      .from('rdo_galeria')
      .stream(primaryKey: ['id'])
      .eq('rdo_id', rdoId)
      .order('criado_em', ascending: false)
      .map((list) => list.map((json) => GaleriaRdoModel.fromJson(json)).toList());
});

class GaleriaRdoRepository {
  final SupabaseClient _supabase;
  GaleriaRdoRepository(this._supabase);

  Future<String> _uploadFoto(File arquivo) async {
    try {
      // Tipo, nome e Content-Type decididos pelo app (ver upload_seguro.dart).
      final path = await _supabase.storage.from('projetos').enviarArquivoSeguro(
            'rdo/galeria',
            arquivo,
            fileOptions: const FileOptions(upsert: true),
          );
      return _supabase.storage.from('projetos').getPublicUrl(path);
    } on ArquivoInvalidoException {
      rethrow;
    } on StorageException catch (e) {
      throw Exception('Erro de Storage: ${e.message}');
    } catch (e) {
      throw Exception('Erro inesperado no upload: $e');
    }
  }

  Future<void> adicionarFoto({
    required String rdoId,
    required File fotoLocal,
    required String descricao,
  }) async {
    try {
      final url = await _uploadFoto(fotoLocal);
      await _supabase.from('rdo_galeria').insert({
        'rdo_id': rdoId,
        'foto': url,
        'descricao': descricao,
      });
    } on PostgrestException catch (e) {
      throw Exception('Erro de banco de dados: ${e.message}');
    }
  }

  Future<void> atualizarFoto({
    required String fotoId,
    required String urlAtual,
    File? novaFotoLocal,
    required String novaDescricao,
  }) async {
    try {
      final urlFinal = novaFotoLocal != null ? await _uploadFoto(novaFotoLocal) : urlAtual;
      await _supabase.from('rdo_galeria').update({
        'foto': urlFinal,
        'descricao': novaDescricao,
      }).eq('id', fotoId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao atualizar: ${e.message}');
    }
  }

  Future<void> deletarFoto(String fotoId) async {
    try {
      await _supabase.from('rdo_galeria').delete().eq('id', fotoId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao apagar foto: ${e.message}');
    }
  }
}
