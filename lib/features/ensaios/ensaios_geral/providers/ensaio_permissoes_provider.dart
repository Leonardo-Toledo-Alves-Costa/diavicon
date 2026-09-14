import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Regras de permissão de um ensaio, compartilhadas por todas as telas de
/// coleta:
/// - só a empresa que criou o ensaio pode editar as informações dele;
/// - a empresa gestora do projeto pode excluir ensaios de qualquer empresa,
///   mas não pode editar as informações se não foi ela quem criou;
/// - qualquer outra empresa vinculada ao projeto (cliente, colaboradora)
///   só pode visualizar.
class EnsaioPermissoes {
  final bool canEdit;
  final bool canDelete;

  const EnsaioPermissoes({required this.canEdit, required this.canDelete});

  /// Ponto novo, ainda não salvo — quem está criando sempre pode editar.
  static const novo = EnsaioPermissoes(canEdit: true, canDelete: true);

  /// Falha ao resolver a autoria (erro, ponto não encontrado etc.) — por
  /// segurança, cai pra somente visualização em vez de liberar edição.
  static const somenteVisualizar = EnsaioPermissoes(canEdit: false, canDelete: false);
}

/// Resolve as permissões de um ponto de ensaio a partir de quem o criou
/// (`pontos_ensaios_geral.criado_por` -> `usuarios.empresa_id`) e da empresa
/// gestora do projeto (`projetos.empresa_gestora_id`), comparando com a
/// empresa do usuário logado.
///
/// Passe uma string vazia para um ensaio ainda não salvo (retorna
/// [EnsaioPermissoes.novo] direto, sem consultar o banco).
final ensaioPermissoesProvider = FutureProvider.family.autoDispose<EnsaioPermissoes, String>((ref, pontoGeralId) async {
  if (pontoGeralId.isEmpty) return EnsaioPermissoes.novo;

  final supabase = Supabase.instance.client;
  final meuUserId = supabase.auth.currentUser?.id;
  if (meuUserId == null) return EnsaioPermissoes.somenteVisualizar;

  try {
    final meuUsuario = await supabase.from('usuarios').select('empresa_id').eq('id', meuUserId).maybeSingle();
    final minhaEmpresaId = meuUsuario?['empresa_id'] as String?;
    if (minhaEmpresaId == null) return EnsaioPermissoes.somenteVisualizar;

    final ponto = await supabase.from('pontos_ensaios_geral').select('criado_por, projeto_id').eq('id', pontoGeralId).maybeSingle();
    if (ponto == null) return EnsaioPermissoes.somenteVisualizar;

    String? empresaCriadoraId;
    final criadoPor = ponto['criado_por'] as String?;
    if (criadoPor != null) {
      final criador = await supabase.from('usuarios').select('empresa_id').eq('id', criadoPor).maybeSingle();
      empresaCriadoraId = criador?['empresa_id'] as String?;
    }

    String? empresaGestoraId;
    final projetoId = ponto['projeto_id'] as String?;
    if (projetoId != null) {
      final projeto = await supabase.from('projetos').select('empresa_gestora_id').eq('id', projetoId).maybeSingle();
      empresaGestoraId = projeto?['empresa_gestora_id'] as String?;
    }

    final canEdit = empresaCriadoraId != null && empresaCriadoraId == minhaEmpresaId;
    final canDelete = canEdit || (empresaGestoraId != null && empresaGestoraId == minhaEmpresaId);

    return EnsaioPermissoes(canEdit: canEdit, canDelete: canDelete);
  } catch (_) {
    return EnsaioPermissoes.somenteVisualizar;
  }
});
