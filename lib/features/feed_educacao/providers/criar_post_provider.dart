import 'package:diavicon/core/security/upload_seguro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import 'feed_provider.dart'; 

class CriarPostController {
  final Ref ref;
  final ValueNotifier<bool> isUploading = ValueNotifier(false);

  CriarPostController(this.ref);

  // CRIA UM NOVO POST
  Future<void> criarPostagem({
    required String texto,
    required String tag,
    required bool patrocinado,
    required List<XFile> fotos,
    String? anexoNome, 
    String? anexoUrl,  
  }) async {
    isUploading.value = true; 
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuário não autenticado.');

      final postResp = await supabase.from('feed_posts').insert({
        'usuario_id': userId,
        'texto': texto,
        'tag': tag,
        'patrocinado': patrocinado,
        'anexo_nome': (anexoNome != null && anexoNome.trim().isNotEmpty) ? anexoNome.trim() : null,
        'anexo_url': (anexoUrl != null && anexoUrl.trim().isNotEmpty) ? anexoUrl.trim() : null,
      }).select('id').single();

      final postId = postResp['id'];

      if (fotos.isNotEmpty) {
        final uidEnvio = userId;
        final List<Map<String, dynamic>> fotosParaInserir = [];
        for (var foto in fotos) {
          final bytes = await foto.readAsBytes();
          // avatars/feed/<uid de quem envia>/<uuid>.<ext>: a política do
          // bucket só deixa cada usuário gravar na própria pasta.
          final caminho = await supabase.storage
              .from('avatars')
              .enviarBytesSeguro('feed/$uidEnvio', bytes);
          final fotoUrl = supabase.storage.from('avatars').getPublicUrl(caminho);

          fotosParaInserir.add({'post_id': postId, 'foto_url': fotoUrl});
        }
        await supabase.from('feed_fotos').insert(fotosParaInserir);
      }

      ref.read(educacaoFeedControllerProvider).carregarFeed();
    } on PostgrestException catch (e) {
      throw Exception('Erro de banco de dados: ${e.message}');
    } on AuthException catch (e) {
      throw Exception('Erro de autenticação: ${e.message}');
    } catch (e) {
      throw Exception('Erro ao publicar: $e');
    } finally {
      isUploading.value = false; 
    }
  }

  // EDITA UM POST EXISTENTE (Agora com suporte total a fotos)
  Future<void> editarPostagem({
    required String postId,
    required String texto,
    required String tag,
    required bool patrocinado,
    required List<String> fotosAtuais, // Fotos que vieram da web e não foram apagadas
    required List<XFile> novasFotos,   // Novas fotos selecionadas do celular
    String? anexoNome, 
    String? anexoUrl,
  }) async {
    isUploading.value = true;
    try {
      final supabase = Supabase.instance.client;
      
      // 1. Atualiza os textos e propriedades do post
      await supabase.from('feed_posts').update({
        'texto': texto,
        'tag': tag,
        'patrocinado': patrocinado,
        'anexo_nome': (anexoNome != null && anexoNome.trim().isNotEmpty) ? anexoNome.trim() : null,
        'anexo_url': (anexoUrl != null && anexoUrl.trim().isNotEmpty) ? anexoUrl.trim() : null,
      }).eq('id', postId);

      // 2. Limpeza de Fotos Antigas Removidas
      final fotosDB = await supabase.from('feed_fotos').select('foto_url').eq('post_id', postId);
      final urlsDB = fotosDB.map((e) => e['foto_url'].toString()).toList();
      final urlsParaDeletar = urlsDB.where((url) => !fotosAtuais.contains(url)).toList();
      
      for (var url in urlsParaDeletar) {
        await supabase.from('feed_fotos').delete().eq('foto_url', url);
      }

      // 3. Upload das Novas Fotos
      if (novasFotos.isNotEmpty) {
        final uidEnvio = supabase.auth.currentUser?.id;
        if (uidEnvio == null) throw Exception('Usuário não autenticado.');
        final List<Map<String, dynamic>> fotosParaInserir = [];
        for (var foto in novasFotos) {
          final bytes = await foto.readAsBytes();
          // avatars/feed/<uid de quem envia>/<uuid>.<ext>: a política do
          // bucket só deixa cada usuário gravar na própria pasta.
          final caminho = await supabase.storage
              .from('avatars')
              .enviarBytesSeguro('feed/$uidEnvio', bytes);
          final fotoUrl = supabase.storage.from('avatars').getPublicUrl(caminho);

          fotosParaInserir.add({'post_id': postId, 'foto_url': fotoUrl});
        }
        await supabase.from('feed_fotos').insert(fotosParaInserir);
      }

      // 4. Atualiza o feed visualmente chamando o controller principal
      ref.read(educacaoFeedControllerProvider).carregarFeed();
    } on PostgrestException catch (e) {
      throw Exception('Erro de banco de dados: ${e.message}');
    } catch (e) {
      throw Exception('Erro ao editar: $e');
    } finally {
      isUploading.value = false;
    }
  }
}

final criarPostProvider = Provider.autoDispose<CriarPostController>((ref) {
  final controller = CriarPostController(ref);
  ref.onDispose(() => controller.isUploading.dispose());
  return controller;
});