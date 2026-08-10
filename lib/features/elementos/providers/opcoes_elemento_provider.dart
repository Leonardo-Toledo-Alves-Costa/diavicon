import 'package:diavicon/features/elementos/providers/elemento_provider.dart';
import 'package:diavicon/features/auth/providers/auth_provider.dart'; // 🔥 Import do seu auth
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OpcoesFormularioElemento {
  final List<String> tipos;
  final List<String> tipologias;
  final List<String> revestimentos;

  OpcoesFormularioElemento({
    required this.tipos,
    required this.tipologias,
    required this.revestimentos,
  });
}

// 🔥 Tiramos o .family. Ele se resolve sozinho agora!
final opcoesFormularioElementoProvider = FutureProvider.autoDispose<OpcoesFormularioElemento>((ref) async {
  final repo = ref.watch(elementoRepositoryProvider);
  
  // 🔥 Pega a empresa do usuário logado direto do seu provider de auth!
  final user = ref.watch(currentUserProvider); 
  final minhaEmpresaId = user?.empresaId;

  final resultados = await Future.wait([
    repo.buscarTiposElemento(minhaEmpresaId),
    repo.buscarTipologiasElemento(minhaEmpresaId),
    repo.buscarRevestimentosElemento(minhaEmpresaId),
  ]);

  return OpcoesFormularioElemento(
    tipos: resultados[0] as List<String>,
    tipologias: resultados[1] as List<String>,
    revestimentos: resultados[2] as List<String>,
  );
});