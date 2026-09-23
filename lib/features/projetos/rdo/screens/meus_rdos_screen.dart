import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/custom_appbar.dart';
import 'package:diavicon/core/widgets/custom_empty_state.dart';
import 'package:diavicon/core/widgets/diavicon_menu_item.dart';
import 'package:diavicon/core/widgets/menu_drawer_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../providers/empresas_projeto_provider.dart';
import '../providers/rdo_provider.dart';
import '../repositories/rdo_repository.dart';
import '../widgets/rdo_card.dart';
import 'meus_relatorios_rdo_screen.dart';
import 'novo_rdo_screen.dart';
import 'rdo_detalhe_screen.dart';
import 'selecionar_projeto_rdo_screen.dart';

/// RDOs da empresa do usuário logado em todos os projetos — acessível pelo
/// menu lateral, sem contexto de projeto pré-definido. Criar um RDO daqui
/// exige escolher o projeto primeiro ([SelecionarProjetoRdoScreen]).
class MeusRdosScreen extends ConsumerStatefulWidget {
  const MeusRdosScreen({super.key});

  @override
  ConsumerState<MeusRdosScreen> createState() => _MeusRdosScreenState();
}

class _MeusRdosScreenState extends ConsumerState<MeusRdosScreen> {
  final TextEditingController _buscaController = TextEditingController();
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _buscaController.addListener(() {
      setState(() => _filtro = _buscaController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rdosAsync = ref.watch(meusRdosProvider);
    final minhaEmpresaAsync = ref.watch(minhaEmpresaProvider);
    final empresaNome = minhaEmpresaAsync.value?['nome']?.toString() ?? 'Minha empresa';
    final empresaId = ref.watch(currentUserProvider)?.empresaId ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      endDrawer: MenuDrawerAppBar(
        title: 'RDO',
        items: [
          DiaviconMenuItem(
            icon: Icons.assessment_outlined,
            label: 'Relatórios',
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(
                MaterialPageRoute(builder: (_) => MeusRelatoriosRdoScreen(empresaId: empresaId)),
              );
            },
          ),
        ],
      ),
      appBar: CustomAppBar(
        title: 'Meus RDOs',
        showBackButton: true,
        showMenuButton: true,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Todos os projetos', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
            const Text('Meus RDOs', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _buildBuscaField()),
                  const SizedBox(width: 10),
                  _buildBotaoNovoRdo(context),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: rdosAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (err, _) => Center(
                    child: Text('Erro ao carregar seus RDOs: $err', style: GoogleFonts.lato(color: AppColors.error)),
                  ),
                  data: (rdos) {
                    final filtrados = _filtro.isEmpty
                        ? rdos
                        : rdos
                              .where((r) =>
                                  r.rdo.data.toLowerCase().contains(_filtro) ||
                                  r.projetoNome.toLowerCase().contains(_filtro))
                              .toList();

                    if (filtrados.isEmpty) {
                      return const CustomEmptyState(text: 'Você ainda não tem RDOs registrados.');
                    }

                    return ListView.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildRdoCard(context, filtrados[index], empresaNome),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuscaField() {
    return TextField(
      controller: _buscaController,
      style: GoogleFonts.lato(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Busque por data ou projeto',
        hintStyle: GoogleFonts.lato(color: AppColors.hintText, fontSize: 14),
        prefixIcon: const Icon(Icons.search, color: AppColors.hintText),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildBotaoNovoRdo(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () async {
        final projeto = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SelecionarProjetoRdoScreen()),
        );
        if (projeto == null || !context.mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NovoRdoScreen(projetoId: projeto.id, projetoNome: projeto.nome),
          ),
        );
        ref.invalidate(meusRdosProvider);
      },
      icon: const Icon(Icons.add, size: 18, color: Colors.white),
      label: Text('Novo RDO', style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        elevation: 0,
      ),
    );
  }

  Widget _buildRdoCard(BuildContext context, RdoComProjeto item, String empresaNome) {
    return RdoCard(
      rdo: item.rdo,
      projetoId: item.rdo.projetoId,
      subtituloProjeto: item.projetoNome,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RdoDetalheScreen(rdo: item.rdo, projetoNome: item.projetoNome, empresaNome: empresaNome),
          ),
        );
        ref.invalidate(meusRdosProvider);
      },
    );
  }
}
