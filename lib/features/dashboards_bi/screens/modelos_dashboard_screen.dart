import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/diavicon_modal.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/custom_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../models/dashboard_modelo_model.dart';
import '../repositories/dashboard_bi_repository.dart';
import 'dashboard_screen.dart';
import '../widgets/bi_tema.dart';

final _dashboardBiRepoProvider = Provider((ref) => DashboardBiRepository());

final _modelosPorNivelProvider = FutureProvider.family<Map<NivelAplicacaoBi, List<DashboardModeloModel>>, String>((ref, empresaId) async {
  final repo = ref.watch(_dashboardBiRepoProvider);
  final resultado = <NivelAplicacaoBi, List<DashboardModeloModel>>{};
  for (final nivel in NivelAplicacaoBi.values) {
    resultado[nivel] = await repo.listarModelos(empresaId: empresaId, nivel: nivel);
  }
  return resultado;
});

/// "Padrões da empresa > Modelos de Dashboard" — lista os 4 níveis de
/// aplicação como categorias, cada uma com os modelos já criados; mesmo
/// padrão visual de `ModelosRelatoriosScreen`.
class ModelosDashboardScreen extends ConsumerWidget {
  final String empresaId;
  const ModelosDashboardScreen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelosAsync = ref.watch(_modelosPorNivelProvider(empresaId));

    return Scaffold(
      backgroundColor: kBiFundo,
      appBar: const CustomAppBar(
        title: 'Empresa',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            Text('Padrões da empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Modelos de Dashboard', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: modelosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, s) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Erro ao carregar modelos:\n$e', textAlign: TextAlign.center))),
        data: (porNivel) {
          return ListView(
            padding: preenchimentoListaBi(context, inferior: 40),
            children: NivelAplicacaoBi.values.map((nivel) {
              final modelos = porNivel[nivel] ?? [];
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(nivel.rotulo, style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark))),
                        TextButton.icon(
                          onPressed: () => _criarModelo(context, ref, nivel),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Novo modelo'),
                        ),
                      ],
                    ),
                    if (modelos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Nenhum modelo cadastrado.', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
                      )
                    else
                      ...modelos.map((m) {
                        final bool ehTemplateDiavicon = m.empresaId == DIAVICON_EMPRESA_ID && m.empresaId != empresaId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: ehTemplateDiavicon ? null : () => _abrirEditor(context, m),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBiBorda)),
                              child: Row(
                                children: [
                                  const Icon(Icons.dashboard_customize_outlined, color: AppColors.primary, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(m.nome, style: GoogleFonts.lato(fontSize: 13, color: AppColors.textDark))),
                                  Text('${m.cards.length} card${m.cards.length == 1 ? '' : 's'}', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey)),
                                  if (ehTemplateDiavicon) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(6)),
                                      child: const Text('Padrão DIAVICON', style: TextStyle(fontSize: 9, color: Color(0xFFA85A00), fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      tooltip: 'Duplicar para minha empresa',
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.copy_outlined, color: Colors.grey, size: 18),
                                      onPressed: () => _duplicarModelo(context, ref, m),
                                    ),
                                  ] else if (m.isPadrao) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6)),
                                      child: const Text('Padrão', style: TextStyle(fontSize: 9, color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Future<void> _criarModelo(BuildContext context, WidgetRef ref, NivelAplicacaoBi nivel) async {
    final nomeCtrl = TextEditingController();
    final nome = await showDiaviconModal<String>(
      context: context,
      title: 'Novo modelo — ${nivel.rotulo}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: 'Nome do modelo', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          CustomButton(text: 'Criar', onPressed: () => Navigator.of(context).pop(nomeCtrl.text.trim())),
        ],
      ),
    );
    if (nome == null || nome.isEmpty) return;

    final repo = ref.read(_dashboardBiRepoProvider);
    final criadoPor = ref.read(currentUserProvider)?.id;
    final id = await repo.criarModelo(
      DashboardModeloModel(id: '', criadoEm: DateTime.now(), empresaId: empresaId, nivelAplicacao: nivel, nome: nome, cards: const []),
      empresaId: empresaId,
      criadoPor: criadoPor,
    );
    ref.invalidate(_modelosPorNivelProvider(empresaId));
    if (!context.mounted) return;
    final modelo = await repo.buscarModelo(id);
    if (modelo == null || !context.mounted) return;
    await _abrirEditor(context, modelo);
    ref.invalidate(_modelosPorNivelProvider(empresaId));
  }

  Future<void> _duplicarModelo(BuildContext context, WidgetRef ref, DashboardModeloModel origem) async {
    final nomeCtrl = TextEditingController(text: '${origem.nome} (cópia)');
    final nome = await showDiaviconModal<String>(
      context: context,
      title: 'Duplicar modelo',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: 'Nome do novo modelo', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          CustomButton(text: 'Duplicar', onPressed: () => Navigator.of(context).pop(nomeCtrl.text.trim())),
        ],
      ),
    );
    if (nome == null || nome.isEmpty) return;

    final repo = ref.read(_dashboardBiRepoProvider);
    final criadoPor = ref.read(currentUserProvider)?.id;
    await repo.duplicarModelo(origem, novoNome: nome, empresaId: empresaId, criadoPor: criadoPor);
    ref.invalidate(_modelosPorNivelProvider(empresaId));
  }

  Future<void> _abrirEditor(BuildContext context, DashboardModeloModel modelo) {
    return Navigator.push(context, MaterialPageRoute(builder: (_) => DashboardScreen(nivel: modelo.nivelAplicacao, titulo: modelo.nome, modeloParaEditar: modelo)));
  }
}
