import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/estrutura_repository.dart';
import '../models/estrutura_model.dart';

// --- REPOSITORY PROVIDER ---
final estruturaRepositoryProvider = Provider<EstruturaRepository>((ref) {
  return EstruturaRepository(Supabase.instance.client);
});

// --- PROVIDER: ESTRUTURAS DO PROJETO (VINCULADAS) ---
final projetoEstruturasProvider = StreamProvider.family<List<EstruturaModel>, String>((ref, projetoId) {
  final supabase = Supabase.instance.client;
  final repo = ref.watch(estruturaRepositoryProvider);

  // O Supabase vigia a tabela de ligação. Sempre que houver INSERT ou DELETE nela,
  // esse fluxo dispara e nós chamamos o repo.buscarEstruturasPorProjeto()
  return supabase
      .from('projeto_estruturas')
      .stream(primaryKey: ['projeto_id', 'estrutura_id'])
      .eq('projeto_id', projetoId)
      .asyncMap((event) => repo.buscarEstruturasPorProjeto(projetoId));
});

// --- PROVIDER: TODAS AS ESTRUTURAS DA PLATAFORMA ---
final todasEstruturasProvider = StreamProvider.autoDispose<List<EstruturaModel>>((ref) {
  final supabase = Supabase.instance.client;
  
  // Retorna todas as estruturas em tempo real, ordenadas pelas mais recentes
  return supabase
      .from('estruturas')
      .stream(primaryKey: ['id'])
      .order('criado_em', ascending: false)
      .map((lista) => lista.map((item) => EstruturaModel.fromMap(item)).toList());
});

// --- PROVIDER: APENAS AS ESTRUTURAS DO UTILIZADOR LOGADO ---
final minhasEstruturasProvider = StreamProvider.autoDispose.family<List<EstruturaModel>, String>((ref, projetoId) {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) {
    return Stream.value([]);
  }

  // Filtra pelo usuário logado E pelo projeto atual
  return supabase
      .from('estruturas')
      .stream(primaryKey: ['id'])
      .eq('projeto_id', projetoId) 
      .order('criado_em', ascending: false)
      .map((lista) {
        return lista
            .where((item) => item['user_id'] == userId) 
            .map((item) => EstruturaModel.fromMap(item))
            .toList();
      });
});