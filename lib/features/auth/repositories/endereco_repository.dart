import 'package:diavicon/features/auth/models/endereco_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/uuid_generator.dart';

class EnderecoRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> salvarEndereco(
    Map<String, dynamic> dadosEndereco,
  ) async {
    try {
      final enderecoData = {
        'id': UuidGenerator.v4(),
        'endereco': dadosEndereco['rua'],
        'cidade': dadosEndereco['cidade'],
        'estado': dadosEndereco['estado'],
        'cep': dadosEndereco['cep'],
        'bairro': dadosEndereco['bairro'],
        'numero': dadosEndereco['numero'],
        'complemento': dadosEndereco['complemento'],
        'pais': 'Brasil',
      };

      await _supabase.from('enderecos').insert(enderecoData);

      return enderecoData;
    } catch (e) {
      print('Erro ao salvar endereço: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> atualizarEndereco(
    String enderecoId,
    Map<String, dynamic> dadosAtualizados,
  ) async {
    try {
      final enderecoData = await _supabase
          .from('enderecos')
          .update({
            'endereco': dadosAtualizados['endereco'],
            'cidade': dadosAtualizados['cidade'],
            'estado': dadosAtualizados['estado'],
            'cep': dadosAtualizados['cep'],
            'bairro': dadosAtualizados['bairro'],
            'numero': dadosAtualizados['numero'],
            'complemento': dadosAtualizados['complemento'],
            'pais': 'Brasil',
          })
          .eq('id', enderecoId)
          .select()
          .single();

      return enderecoData;
    } catch (e) {
      print('Erro ao atualizar endereço: $e');
      return null;
    }
  }

  Future<EnderecoModel?> getEndereco(String enderecoId) async {
    try {
      final enderecoData = await _supabase
          .from('enderecos')
          .select()
          .eq('id', enderecoId)
          .single();

      return EnderecoModel.fromMap(enderecoData);
    } catch (e) {
      print('Erro ao buscar endereço: $e');
      return null;
    }
  }
}
