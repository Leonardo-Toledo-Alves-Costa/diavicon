import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'campos_personalizaveis_provider.dart';

final sistemasDropdownProvider = FutureProvider.family.autoDispose<List<CampoItemModel>, String>((ref, empresaId) async {
  try {
    final response = await Supabase.instance.client
        .from('sistemas_habitacionais')
        .select('*')
        .or('empresa_id.eq.$empresaId, empresa_id.eq.$DIAVICON_EMPRESA_ID') // Regra rígida aplicada
        .order('nome', ascending: true);

    return response.map((e) => CampoItemModel.fromMap(e)).toList();
  } on PostgrestException catch (e) {
    throw Exception('Erro de banco de dados ao carregar sistemas: ${e.message}');
  } on AuthException catch (e) {
    throw Exception('Erro de autenticação: ${e.message}');
  } catch (e) {
    throw Exception('Erro inesperado: $e');
  }
});

final tiposElementoDropdownProvider = FutureProvider.family.autoDispose<List<CampoItemModel>, String>((ref, empresaId) async {
  try {
    final response = await Supabase.instance.client
        .from('tipos_elemento')
        .select('*')
        .or('empresa_id.eq.$empresaId, empresa_id.eq.$DIAVICON_EMPRESA_ID') // Regra rígida aplicada
        .order('nome', ascending: true);

    return response.map((e) => CampoItemModel.fromMap(e)).toList();
  } on PostgrestException catch (e) {
    throw Exception('Erro de banco de dados ao carregar tipos de elemento: ${e.message}');
  } on AuthException catch (e) {
    throw Exception('Erro de autenticação: ${e.message}');
  } catch (e) {
    throw Exception('Erro inesperado: $e');
  }
});