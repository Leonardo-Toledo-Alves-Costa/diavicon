import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ponto_inspecao_model.dart';

final pontoInspecaoRepoProvider = Provider((ref) => PontoInspecaoRepository(Supabase.instance.client));

// Provider para a tela "Inspeção Visual Local"
final listaPontosLocalProvider = FutureProvider.family.autoDispose<List<PontoInspecaoVisualModel>, String>((ref, idLocal) async {
  final repo = ref.read(pontoInspecaoRepoProvider);
  return repo.buscarPontosPorLocal(idLocal);
});

class PontoInspecaoRepository {
  final SupabaseClient _supabase;
  PontoInspecaoRepository(this._supabase);

  Future<List<PontoInspecaoVisualModel>> buscarPontosPorLocal(String idLocal) async {
    final res = await _supabase
        .from('ponto_inspecao_visual')
        .select('''
          *,
          tipos_elemento (nome),
          ponto_inspecao_visual_galeria (foto_url),
          ponto_inspecao_visual_anomalia (risco_maj, anomalias(nome))
        ''')
        .eq('id_local', idLocal)
        .order('criado_em', ascending: false);

    return (res as List).map((e) => PontoInspecaoVisualModel.fromMap(e)).toList();
  }

  Future<void> criarNovoRegistro({required String registro, required String descricao, required String idLocal, required String idGeral}) async {
    await _supabase.from('ponto_inspecao_visual').insert({
      'registro': registro,
      'descricao': descricao,
      'id_local': idLocal,
      'id_ponto_geral': idGeral,
      'criado_por': _supabase.auth.currentUser?.id,
    });
  }

  Future<void> adicionarFotoGaleria(String idPonto, File foto, String descricao) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _supabase.storage.from('projetos').upload('inspecoes/$fileName', foto);
    final url = _supabase.storage.from('projetos').getPublicUrl('inspecoes/$fileName');

    await _supabase.from('ponto_inspecao_visual_galeria').insert({
      'id_inspecao': idPonto,
      'foto_url': url,
      'descricao': descricao,
      'criado_por': _supabase.auth.currentUser?.id,
    });
  }
}