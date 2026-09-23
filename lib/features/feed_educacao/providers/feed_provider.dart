import 'dart:math';
import 'package:flutter/material.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/feed_post_model.dart';

// 1. CHECAGEM DE ADMIN DA EMPRESA
final isUserAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return false;
  try {
    final response = await supabase.from('usuarios').select('is_admin_empresa').eq('id', userId).single();
    return response['is_admin_empresa'] == true;
  } catch (_) {
    return false;
  }
});

// ==========================================
// 2. CONTROLLER DO FEED EDUCACIONAL
// ==========================================
class EducacaoFeedController {
  // Estados blindados contra erros do Riverpod 3.x
  final ValueNotifier<AsyncValue<List<FeedPostModel>>> state = ValueNotifier(const AsyncValue.loading());
  final ValueNotifier<String> filtro = ValueNotifier('todos'); // Substitui o StateProvider antigo!
  final ValueNotifier<String> pesquisa = ValueNotifier('');

  EducacaoFeedController() {
    carregarFeed();
  }

  void dispose() {
    state.dispose();
    filtro.dispose();
    pesquisa.dispose();
  }

  void setFiltro(String novoFiltro) {
    filtro.value = novoFiltro;
  }

  void setPesquisa(String termo) { // <--- NOVO: Atualiza o termo de busca
    pesquisa.value = termo.trim().toLowerCase();
  }

  Future<void> carregarFeed() async {
    state.value = const AsyncValue.loading();
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    try {
      final response = await supabase
          .from('feed_posts')
          .select('''
            *,
            feed_likes (usuario_id),
            feed_comentarios (id),
            feed_fotos (foto_url)
          ''')
          .order('criado_em', ascending: false)
          .limit(100);

      final postsJson = (response as List).cast<Map<String, dynamic>>();

      // RLS só deixa cada usuário ler a própria linha de `usuarios`/`empresas`
      // (dado sensível: email, celular, is_admin...) — um embed direto
      // `usuarios(nome, foto_url, empresas(...))` resolve null pra posts de
      // qualquer outro autor, daí o "Empresa Desconhecida". `get_perfis_feed`
      // é uma function SECURITY DEFINER que expõe só nome/foto (autor e
      // empresa) de usuários ativos, do mesmo jeito que list_public_companies
      // já expõe dado público de empresa pra descoberta.
      final autorIds = postsJson.map((p) => p['usuario_id']?.toString()).whereType<String>().toSet().toList();
      final perfis = autorIds.isEmpty ? const [] : await supabase.rpc('get_perfis_feed', params: {'p_usuario_ids': autorIds});
      final perfisPorUsuario = {for (final p in (perfis as List).cast<Map<String, dynamic>>()) p['usuario_id'].toString(): p};

      List<FeedPostModel> posts = postsJson.map((json) {
        final likes = json['feed_likes'] as List? ?? [];
        final comentarios = json['feed_comentarios'] as List? ?? [];
        final fotosJson = json['feed_fotos'] as List? ?? [];

        json['user_liked'] = userId != null && likes.any((l) => l['usuario_id'] == userId);
        json['total_likes'] = likes.length;
        json['total_comentarios'] = comentarios.length;
        json['fotos'] = fotosJson.map((f) => f['foto_url'].toString()).toList();

        final perfil = perfisPorUsuario[json['usuario_id']?.toString()];
        if (perfil != null) {
          json['usuarios'] = {
            'nome': perfil['nome'],
            'foto_url': perfil['foto_url'],
            'empresas': {'nome': perfil['empresa_nome'], 'foto_url': perfil['empresa_foto_url']},
          };
        }

        return FeedPostModel.fromMap(json);
      }).toList();

      final random = Random();
      posts.sort((a, b) {
        final pesoA = (a.patrocinado ? 3.0 : 1.0) * random.nextDouble();
        final pesoB = (b.patrocinado ? 3.0 : 1.0) * random.nextDouble();
        return pesoB.compareTo(pesoA); 
      });

      state.value = AsyncValue.data(posts);
    } catch (e, stack) {
      state.value = AsyncValue.error(e, stack);
    }
  }

  Future<void> toggleLike(String postId, bool isCurrentlyLiked) async {
    final currentState = state.value;
    if (currentState is! AsyncData<List<FeedPostModel>>) return;

    state.value = AsyncValue.data(
      currentState.value.map((post) {
        if (post.id == postId) {
          return post.copyWith(
            userLiked: !isCurrentlyLiked,
            totalLikes: post.totalLikes + (isCurrentlyLiked ? -1 : 1),
          );
        }
        return post;
      }).toList()
    );

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      if (isCurrentlyLiked) {
        await supabase.from('feed_likes').delete().eq('post_id', postId).eq('usuario_id', userId);
      } else {
        await supabase.from('feed_likes').insert({'post_id': postId, 'usuario_id': userId});
      }
    } catch (e) {
      state.value = currentState; 
    }
  }

  // AÇÃO: Deletar Post com tratamento de exceções do Supabase
  Future<void> deletarPost(String postId) async {
    final currentState = state.value;
    if (currentState is! AsyncData<List<FeedPostModel>>) return;

    // Atualização otimista: remove da tela na hora
    state.value = AsyncValue.data(
      currentState.value.where((p) => p.id != postId).toList(),
    );

    try {
      final supabase = Supabase.instance.client;
      
      // Deleta do banco de dados na tabela correta (feed_posts)
      await supabase.from('feed_posts').delete().eq('id', postId);
      
    } on PostgrestException catch (e) {
      // Reverte o estado otimista caso ocorra erro no Postgres
      state.value = currentState;
      throw Exception('Erro no banco de dados ao deletar: ${e.message}');
    } on AuthException catch (e) {
      state.value = currentState;
      throw Exception('Erro de autenticação: ${e.message}');
    } catch (e) {
      state.value = currentState;
      throw Exception('Erro inesperado ao deletar post: $e');
    }
  }

  Future<void> editarPost(String postId, String novoTexto) async {
    final currentState = state.value;
    if (currentState is! AsyncData<List<FeedPostModel>>) return;

    state.value = AsyncValue.data(
      currentState.value.map((post) {
        if (post.id == postId) return post.copyWith(texto: novoTexto);
        return post;
      }).toList()
    );

    try {
      await Supabase.instance.client.from('feed_posts').update({'texto': novoTexto}).eq('id', postId);
    } catch (e) {
      state.value = currentState; 
    }
  }

  void incrementarComentarios(String postId) {
    final currentState = state.value;
    if (currentState is! AsyncData<List<FeedPostModel>>) return;

    state.value = AsyncValue.data(
      currentState.value.map((post) {
        if (post.id == postId) return post.copyWith(totalComentarios: post.totalComentarios + 1);
        return post;
      }).toList()
    );
  }
}

// Injetando no Riverpod com Provider ultra-seguro
final educacaoFeedControllerProvider = Provider.autoDispose<EducacaoFeedController>((ref) {
  final controller = EducacaoFeedController();
  ref.onDispose(() => controller.dispose());
  return controller;
});


// ==========================================
// 3. CONTROLLERS DOS COMENTÁRIOS
// ==========================================
final comentariosPostProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, postId) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('feed_comentarios')
      .select('id, texto, criado_em, usuarios (nome, foto_url)')
      .eq('post_id', postId)
      .order('criado_em', ascending: true);
  return List<Map<String, dynamic>>.from(response);
});

class ComentariosController {
  final ValueNotifier<bool> isEnviando = ValueNotifier(false);

  Future<void> adicionarComentario(WidgetRef ref, String postId, String texto) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    isEnviando.value = true;
    try {
      await supabase.from('feed_comentarios').insert({
        'post_id': postId,
        'usuario_id': userId,
        'texto': texto,
      });
      ref.invalidate(comentariosPostProvider(postId));
      ref.read(educacaoFeedControllerProvider).incrementarComentarios(postId);
    } catch (e) {
      throw Exception('Erro ao enviar comentário.');
    } finally {
      isEnviando.value = false;
    }
  }
}

final comentariosControllerProvider = Provider.autoDispose<ComentariosController>((ref) {
  final controller = ComentariosController();
  ref.onDispose(() => controller.isEnviando.dispose());
  return controller;
});