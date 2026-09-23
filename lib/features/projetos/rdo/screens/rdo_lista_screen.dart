import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/custom_appbar.dart';
import 'package:diavicon/core/widgets/custom_empty_state.dart';
import 'package:diavicon/core/widgets/diavicon_menu_item.dart';
import 'package:diavicon/core/widgets/menu_drawer_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/rdo_realizado_model.dart';
import '../providers/rdo_provider.dart';
import '../widgets/rdo_card.dart';
import 'novo_rdo_screen.dart';
import 'rdo_detalhe_screen.dart';
import 'relatorio_rdo_screen.dart';

class RdoListaScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String projetoNome;
  final String empresaId;
  final String empresaNome;
  final String? empresaFotoUrl;

  const RdoListaScreen({
    super.key,
    required this.projetoId,
    required this.empresaId,
    required this.empresaNome,
    this.projetoNome = 'Projeto',
    this.empresaFotoUrl,
  });

  @override
  ConsumerState<RdoListaScreen> createState() => _RdoListaScreenState();
}

class _RdoListaScreenState extends ConsumerState<RdoListaScreen> {
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
    final rdosAsync = ref.watch(
      rdosDoProjetoEmpresaProvider((projetoId: widget.projetoId, empresaId: widget.empresaId)),
    );
    final papelAsync = ref.watch(papelEmpresaNoProjetoProvider(widget.projetoId));

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
                MaterialPageRoute(
                  builder: (_) => RelatorioRdoScreen(
                    projetoId: widget.projetoId,
                    projetoNome: widget.projetoNome,
                    empresaId: widget.empresaId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      appBar: CustomAppBar(
        title: 'RDO',
        showBackButton: true,
        showMenuButton: true,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.projetoNome,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
            ),
            const Text('RDO', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'RDOs registrados',
                style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D)),
              ),
              const SizedBox(height: 12),
              _buildEmpresaHeader(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildBuscaField()),
                  if (papelAsync.value?.podeCriarRdo ?? false) ...[
                    const SizedBox(width: 10),
                    _buildBotaoNovoRdo(context),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: rdosAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (err, _) => Center(
                    child: Text('Erro ao carregar RDOs: $err', style: GoogleFonts.lato(color: AppColors.error)),
                  ),
                  data: (rdos) {
                    final filtrados = _filtro.isEmpty
                        ? rdos
                        : rdos.where((r) => r.data.toLowerCase().contains(_filtro)).toList();

                    if (filtrados.isEmpty) {
                      return const CustomEmptyState(text: 'Nenhum RDO registrado ainda.');
                    }

                    return ListView.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildRdoCard(context, filtrados[index]),
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

  Widget _buildEmpresaHeader() {
    final temLogo = widget.empresaFotoUrl != null && widget.empresaFotoUrl!.isNotEmpty;
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.greyVeryLight,
          backgroundImage: temLogo ? StorageNetworkImage(widget.empresaFotoUrl!) : null,
          child: temLogo ? null : const Icon(Icons.apartment, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          widget.empresaNome,
          style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF3E3E3D)),
        ),
      ],
    );
  }

  Widget _buildBuscaField() {
    return TextField(
      controller: _buscaController,
      style: GoogleFonts.lato(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Busque por data',
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
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NovoRdoScreen(projetoId: widget.projetoId, projetoNome: widget.projetoNome),
          ),
        );
        ref.invalidate(
          rdosDoProjetoEmpresaProvider((projetoId: widget.projetoId, empresaId: widget.empresaId)),
        );
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

  Widget _buildRdoCard(BuildContext context, RdoRealizadoModel rdo) {
    return RdoCard(
      rdo: rdo,
      projetoId: widget.projetoId,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RdoDetalheScreen(rdo: rdo, projetoNome: widget.projetoNome, empresaNome: widget.empresaNome),
          ),
        );
        ref.invalidate(
          rdosDoProjetoEmpresaProvider((projetoId: widget.projetoId, empresaId: widget.empresaId)),
        );
      },
    );
  }
}
