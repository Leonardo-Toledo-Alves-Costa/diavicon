import 'package:diavicon/features/elementos/providers/elemento_provider.dart';
import 'package:diavicon/features/auth/providers/auth_provider.dart'; 
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

final opcoesFormularioElementoProvider = FutureProvider.autoDispose<OpcoesFormularioElemento>((ref) async {
  final repo = ref.watch(elementoRepositoryProvider);
  
  //  Pega a empresa do usuário logado direto do seu provider de auth!
  final user = ref.watch(currentUserProvider); 
  final minhaEmpresaId = user?.empresaId;
  const diaviconId = '96b9a6b9-32d0-453e-9f69-74a2691ac5cc';

  // Monta a lista com as empresas permitidas
  final empresasIds = <String>[
    if (minhaEmpresaId != null) minhaEmpresaId,
    diaviconId,
  ];

  final resultados = await Future.wait([
    repo.buscarTiposElemento(empresasIds),
    repo.buscarTipologiasElemento(empresasIds),
    repo.buscarRevestimentosElemento(empresasIds),
  ]);

  return OpcoesFormularioElemento(
    tipos: resultados[0],
    tipologias: resultados[1],
    revestimentos: resultados[2],
  );
});