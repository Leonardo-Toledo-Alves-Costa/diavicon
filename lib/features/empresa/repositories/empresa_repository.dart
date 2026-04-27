import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/empresa_model.dart';

class EmpresaRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Salva a empresa no Supabase e retorna o ID gerado.
  /// Fluxo:
  ///   1. Insere endereço na tabela 'enderecos' → pega o ID
  ///   2. Insere empresa na tabela 'empresas' com o enderecoId
  ///   3. Vincula o usuário criador na tabela 'usuario_empresa'
  Future<String> salvarEmpresa({
    required Map<String, dynamic> dadosEmpresa,
    required String userId,
  }) async {
    // ── 1. Salva endereço ──────────────────────────────────────────────────
    final enderecoResponse = await _supabase
        .from('enderecos')
        .insert({
          'cep': dadosEmpresa['cep'],
          'cidade': dadosEmpresa['cidade'],
          'rua': dadosEmpresa['rua'],
          'bairro': dadosEmpresa['bairro'],
          'numero': dadosEmpresa['numero'],
          'complemento': dadosEmpresa['complemento'],
          'estado': dadosEmpresa['estado'],
          'pais': dadosEmpresa['pais'],
        })
        .select('id')
        .single();

    final enderecoId = enderecoResponse['id'] as String;

    // ── 2. Salva empresa ───────────────────────────────────────────────────
    final empresaResponse = await _supabase
        .from('empresas')
        .insert({
          'nome': dadosEmpresa['nome'],
          'cnpj': dadosEmpresa['cnpj'],
          'tamanho': dadosEmpresa['colaboradores'],
          'tipo': dadosEmpresa['tipo'] ?? 'Profissional',
          'site': dadosEmpresa['site'],
          'endereco_id': enderecoId,
          'ativo': true,
        })
        .select('id')
        .single();

    final empresaId = empresaResponse['id'] as String;

    // ── 3. Vincula usuário criador como admin da empresa ───────────────────
    await _supabase.from('usuario_empresa').insert({
      'usuario_id': userId,
      'empresa_id': empresaId,
      'cargo': dadosEmpresa['cargo'],
      'nivel': dadosEmpresa['nivel'],
      'is_admin': true,
      'ativo': true,
    });

    // ── 4. Atualiza empresa_id no perfil do usuário ────────────────────────
    await _supabase
        .from('usuarios')
        .update({'empresa_id': empresaId})
        .eq('id', userId);

    return empresaId;
  }

  /// Busca dados da empresa pelo ID.
  Future<EmpresaModel?> getEmpresa(String empresaId) async {
    final data = await _supabase
        .from('empresas')
        .select()
        .eq('id', empresaId)
        .maybeSingle();

    if (data == null) return null;
    return EmpresaModel.fromMap(data);
  }
}