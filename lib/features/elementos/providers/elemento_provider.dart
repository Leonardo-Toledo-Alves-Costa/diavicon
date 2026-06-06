import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/elemento_model.dart';
import '../repositories/elemento_repository.dart';

final elementoRepositoryProvider =
    Provider((ref) => ElementoRepository());

// ── Lista de elementos da estrutura atual ──────────────────────────────────
final elementosProvider = StateNotifierProvider.family<
    ElementosNotifier, AsyncValue<List<ElementoModel>>, String>(
  (ref, estruturaId) =>
      ElementosNotifier(ref.read(elementoRepositoryProvider), estruturaId),
);

class ElementosNotifier
    extends StateNotifier<AsyncValue<List<ElementoModel>>> {
  final ElementoRepository _repo;
  final String estruturaId;

  ElementosNotifier(this._repo, this.estruturaId)
      : super(const AsyncValue.loading()) {
    carregar();
  }

  // ── Carregar ───────────────────────────────────────────────────────────────
  Future<void> carregar() async {
    state = const AsyncValue.loading();
    try {
      final lista = await _repo.listarPorEstrutura(estruturaId);
      state = AsyncValue.data(lista);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ── Criar ──────────────────────────────────────────────────────────────────
  Future<void> criar(ElementoModel elemento) async {
    try {
      final novo = await _repo.criar(elemento);
      state.whenData((lista) {
        state = AsyncValue.data([...lista, novo]);
      });
    } catch (e) {
      rethrow;
    }
  }

  // ── Atualizar ──────────────────────────────────────────────────────────────
  Future<void> atualizar(ElementoModel elemento) async {
    try {
      final atualizado = await _repo.atualizar(elemento);
      state.whenData((lista) {
        state = AsyncValue.data(
          lista.map((e) => e.id == atualizado.id ? atualizado : e).toList(),
        );
      });
    } catch (e) {
      rethrow;
    }
  }

  // ── Deletar ────────────────────────────────────────────────────────────────
  Future<void> deletar(String id) async {
    try {
      await _repo.deletar(id);
      state.whenData((lista) {
        state = AsyncValue.data(
          lista.where((e) => e.id != id).toList(),
        );
      });
    } catch (e) {
      rethrow;
    }
  }
}

// ── Controller de loading para form ───────────────────────────────────────
final elementoFormLoadingProvider = StateProvider<bool>((ref) => false);