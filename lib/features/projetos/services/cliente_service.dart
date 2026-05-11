import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/projeto_form_provider.dart';

class ClienteService {
  final _supabase = Supabase.instance.client;

  /// Registra uma nova empresa e automaticamente a vincula à sua gestora
  Future<void> criarClienteComVinculo({
    required ProjetoFormState form,
    required String empresaGestoraId, // O ID da empresa do usuário logado
  }) async {
    try {
      // Formatação de dados auxiliares
      // Como a tabela empresas não tem colunas para email e área, guardamos na descrição.
      final String descricaoFormatada = 
          'Email de contato: ${form.emailNovoCliente ?? "N/A"} | Área: ${form.areaAtuacaoNovoCliente ?? "N/A"}';

      // Inserir a nova empresa
      final respostaEmpresa = await _supabase.from('empresas').insert({
        'nome': form.clienteNome,
        'tipo': form.tipoNovoCliente,
        'descricao': descricaoFormatada,
      }).select('id').single();

      final String novoClienteId = respostaEmpresa['id'];

      // Criar o vínculo na sua "carteira de clientes"
      await _supabase.from('empresa_clientes').insert({
        'gestora_id': empresaGestoraId,
        'cliente_id': novoClienteId,
        'status_vinculo': 'ativo', // Já entra ativo pois foi cadastrado internamente
      });

    } catch (e) {
      throw Exception('Falha ao cadastrar cliente e vínculo: $e');
    }
  }
}