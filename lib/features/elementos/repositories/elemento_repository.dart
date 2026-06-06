import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/elemento_model.dart';

class ElementoRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── Listar elementos de uma estrutura ──────────────────────────────────────
  Future<List<ElementoModel>> listarPorEstrutura(String estruturaId) async {
    final data = await _supabase
        .from('elementos_estruturais')
        .select()
        .eq('estrutura_id', estruturaId)
        .eq('ativo', true)
        .order('nome');

    return (data as List)
        .map((e) => ElementoModel.fromMap(e))
        .toList();
  }

  // ── Buscar elemento por ID ─────────────────────────────────────────────────
  Future<ElementoModel?> buscarPorId(String id) async {
    final data = await _supabase
        .from('elementos_estruturais')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (data == null) return null;
    return ElementoModel.fromMap(data);
  }

  // ── Criar elemento ─────────────────────────────────────────────────────────
  Future<ElementoModel> criar(ElementoModel elemento) async {
    final response = await _supabase
        .from('elementos_estruturais')
        .insert(elemento.toMap())
        .select()
        .single();

    return ElementoModel.fromMap(response);
  }

  // ── Atualizar elemento ─────────────────────────────────────────────────────
  Future<ElementoModel> atualizar(ElementoModel elemento) async {
    final response = await _supabase
        .from('elementos_estruturais')
        .update(elemento.toMap())
        .eq('id', elemento.id!)
        .select()
        .single();

    return ElementoModel.fromMap(response);
  }

  // ── Deletar (soft delete) ──────────────────────────────────────────────────
  Future<void> deletar(String id) async {
    await _supabase
        .from('elementos_estruturais')
        .update({'ativo': false})
        .eq('id', id);
  }

  // ── Upload de fotos do elemento ────────────────────────────────────────────
  /// Faz upload de uma foto para o Storage do Supabase e retorna a URL pública.
  Future<String> uploadFoto({
    required String elementoId,
    required String caminhoLocalFoto,
  }) async {
    final nomeArquivo =
        '$elementoId/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await _supabase.storage
        .from('elementos-fotos')
        .upload(nomeArquivo, Uri.file(caminhoLocalFoto) as dynamic);

    final url = _supabase.storage
        .from('elementos-fotos')
        .getPublicUrl(nomeArquivo);

    return url;
  }
}