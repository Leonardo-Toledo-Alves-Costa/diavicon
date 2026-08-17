

import 'package:diavicon/features/planos/model/planos_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlanosRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<PlanosModel>> getPlanos() async {
    try {
      final data = await _supabase.from('planos').select();
      return (data as List).map((map) => PlanosModel.fromMap(map)).toList();
    } catch (e) {
      print('Error fetching planos: $e');
      rethrow;
    }
    
  }
  
}