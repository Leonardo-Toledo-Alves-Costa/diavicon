import 'package:diavicon/core/providers/supabase_provider.dart';
import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/empresas_projeto_provider.dart';
import '../models/rdo_realizado_model.dart';
import '../repositories/rdo_repository.dart';

final rdoRepositoryProvider = Provider<RdoRepository>((ref) {
  return RdoRepository(ref.watch(supabaseClientProvider));
});

/// Papel da empresa do usuário logado no projeto — gestora, cliente ou
/// colaboradora comum. Ver [PapelEmpresaProjeto] para o que cada um habilita.
final papelEmpresaNoProjetoProvider = FutureProvider.autoDispose
    .family<PapelEmpresaProjeto, String>((ref, projetoId) {
      final empresaUsuarioId = ref.watch(currentUserProvider)?.empresaId;
      return ref
          .watch(rdoRepositoryProvider)
          .resolverPapel(projetoId: projetoId, empresaUsuarioId: empresaUsuarioId);
    });

/// Empresas do projeto (gestora + colaboradoras aceitas + cliente vinculado —
/// reaproveita [projetoEmpresasIntegrantesProvider], já usado na tela de
/// Empresas do projeto) com a contagem/data de RDO de cada uma anexada.
final empresasComRdoProvider = FutureProvider.autoDispose
    .family<List<EmpresaRdoResumo>, String>((ref, projetoId) async {
      final empresas = await ref.watch(
        projetoEmpresasIntegrantesProvider(projetoId).future,
      );
      final contagem = await ref
          .watch(rdoRepositoryProvider)
          .contarRdosPorEmpresa(projetoId);

      return empresas.map((mapa) {
        final id = mapa['id']?.toString() ?? '';
        final resumo = contagem[id];
        return EmpresaRdoResumo(
          id: id,
          nome: mapa['nome']?.toString() ?? 'Empresa',
          fotoUrl: mapa['foto_url']?.toString(),
          cidade: mapa['cidade']?.toString(),
          estado: mapa['estado']?.toString(),
          totalRdos: resumo?.total ?? 0,
          ultimoRdoEm: resumo?.ultimo,
        );
      }).toList()
        ..sort((a, b) => b.totalRdos.compareTo(a.totalRdos));
    });

typedef _ProjetoEmpresaChave = ({String projetoId, String empresaId});

final rdosDoProjetoEmpresaProvider = FutureProvider.autoDispose
    .family<List<RdoRealizadoModel>, _ProjetoEmpresaChave>((ref, chave) {
      return ref
          .watch(rdoRepositoryProvider)
          .listarRdosDoProjetoEmpresa(
            projetoId: chave.projetoId,
            empresaId: chave.empresaId,
          );
    });

/// RDOs da empresa do usuário logado em todos os projetos — entrada "Meus
/// RDOs" do menu lateral.
final meusRdosProvider = FutureProvider.autoDispose<List<RdoComProjeto>>((
  ref,
) {
  final empresaId = ref.watch(currentUserProvider)?.empresaId;
  if (empresaId == null) return Future.value(const []);
  return ref.watch(rdoRepositoryProvider).listarRdosDaEmpresa(empresaId);
});
