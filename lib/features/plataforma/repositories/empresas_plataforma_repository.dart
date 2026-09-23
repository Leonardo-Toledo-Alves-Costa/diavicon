import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/repositories/auth_operations_repository.dart';

/// Linha do controle de empresas cadastradas (painel da DIAVICON).
class EmpresaResumo {
  final String id;
  final String nome;
  final String? cnpj;
  final String? fotoUrl;
  final DateTime? criadoEm;
  final String? plano;
  final int usuarios;
  final int projetos;
  final int estruturas;
  final int pontosEnsaio;

  /// A DIAVICON: aparece na lista, mas nunca pode ser excluída.
  final bool protegida;

  const EmpresaResumo({
    required this.id,
    required this.nome,
    this.cnpj,
    this.fotoUrl,
    this.criadoEm,
    this.plano,
    this.usuarios = 0,
    this.projetos = 0,
    this.estruturas = 0,
    this.pontosEnsaio = 0,
    this.protegida = false,
  });

  factory EmpresaResumo.fromMap(Map<String, dynamic> map) {
    int n(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
    return EmpresaResumo(
      id: '${map['id']}',
      nome: (map['nome'] as String?)?.trim().isNotEmpty == true ? map['nome'] as String : 'Sem nome',
      cnpj: map['cnpj'] as String?,
      fotoUrl: map['foto_url'] as String?,
      criadoEm: DateTime.tryParse('${map['criado_em'] ?? ''}'),
      plano: map['plano'] as String?,
      usuarios: n(map['qtd_usuarios']),
      projetos: n(map['qtd_projetos']),
      estruturas: n(map['qtd_estruturas']),
      pontosEnsaio: n(map['qtd_pontos_ensaio']),
      protegida: map['protegida'] == true,
    );
  }
}

/// Mensagem legível de um erro da edge function `auth-operations`.
String mensagemErroOperacao(Object erro) {
  const semFuncao = 'Esta função ainda não está disponível no servidor. A equipe precisa publicar a atualização da função auth-operations.';
  if (erro is FunctionException) {
    final detalhes = erro.details;
    // Versão antiga da edge function publicada: não conhece a ação nova.
    if (detalhes is Map && detalhes['erro'] == 'Ação desconhecida.') return semFuncao;
    if (detalhes is Map && detalhes['erro'] != null) return '${detalhes['erro']}';
    if (erro.status == 404) return 'Esta função ainda não está disponível no servidor.';
    return 'Não foi possível concluir a operação (erro ${erro.status}).';
  }
  final texto = erro.toString().replaceFirst('Exception: ', '').trim();
  if (texto == 'Ação desconhecida.') return semFuncao;
  return texto.isEmpty ? 'Não foi possível concluir a operação.' : texto;
}

/// Exclusão de empresas e controle de empresas. Tudo passa pela edge function
/// (service role): o app nunca apaga dados de empresa direto.
class EmpresasPlataformaRepository {
  final AuthOperationsRepository _ops;

  EmpresasPlataformaRepository([AuthOperationsRepository? ops]) : _ops = ops ?? AuthOperationsRepository();

  Future<List<EmpresaResumo>> listarEmpresas() async {
    final resposta = await _ops.execute('platform_list_companies', {});
    final lista = resposta['empresas'];
    if (lista is! List) return [];
    return lista.whereType<Map>().map((m) => EmpresaResumo.fromMap(Map<String, dynamic>.from(m))).toList();
  }

  /// Painel da DIAVICON: apaga outra empresa e todos os dados dela.
  Future<Map<String, dynamic>> excluirEmpresa({required String empresaId, required String confirmacaoNome}) {
    return _ops.execute('platform_delete_company', {'empresa_id': empresaId, 'confirmacao_nome': confirmacaoNome});
  }

  /// Administrador principal apaga a própria empresa, a conta dele e as dos
  /// colaboradores.
  Future<Map<String, dynamic>> excluirMinhaEmpresa({required String confirmacaoNome}) {
    return _ops.execute('delete_own_company', {'confirmacao_nome': confirmacaoNome});
  }
}
