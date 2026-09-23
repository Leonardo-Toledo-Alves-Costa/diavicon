import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/custom_appbar.dart';
import 'package:diavicon/core/widgets/custom_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../auth/providers/auth_provider.dart';
import '../models/rdo_realizado_model.dart';
import '../providers/rdo_provider.dart';
import 'novo_rdo_screen.dart';
import 'rdo_lista_screen.dart';

/// Lista de empresas do projeto com RDO — só alcançada por quem enxerga o
/// RDO de todas as empresas (gestora/cliente); uma colaboradora comum é
/// roteada direto para o próprio [RdoListaScreen] por [RdoAcessoScreen].
class RdoEmpresasScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String projetoNome;

  const RdoEmpresasScreen({
    super.key,
    required this.projetoId,
    this.projetoNome = 'Projeto',
  });

  @override
  ConsumerState<RdoEmpresasScreen> createState() => _RdoEmpresasScreenState();
}

class _RdoEmpresasScreenState extends ConsumerState<RdoEmpresasScreen> {
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
    final empresasAsync = ref.watch(empresasComRdoProvider(widget.projetoId));
    final papelAsync = ref.watch(papelEmpresaNoProjetoProvider(widget.projetoId));
    final minhaEmpresaId = ref.watch(currentUserProvider)?.empresaId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'RDO',
        showBackButton: true,
        showMenuButton: false,
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
                'RDOs por empresa',
                style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D)),
              ),
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
                child: empresasAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (err, _) => Center(
                    child: Text('Erro ao carregar empresas: $err', style: GoogleFonts.lato(color: AppColors.error)),
                  ),
                  data: (empresas) {
                    final papel = papelAsync.value;
                    final visiveis = (papel != null && !papel.vePapeisDeTodasEmpresas)
                        ? empresas.where((e) => e.id == minhaEmpresaId).toList()
                        : empresas;
                    final filtradas = _filtro.isEmpty
                        ? visiveis
                        : visiveis.where((e) => e.nome.toLowerCase().contains(_filtro)).toList();

                    if (filtradas.isEmpty) {
                      return const CustomEmptyState(text: 'Nenhuma empresa com RDO ainda.');
                    }

                    return ListView.separated(
                      itemCount: filtradas.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildEmpresaCard(context, filtradas[index]),
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
        hintText: 'Busque por empresa',
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
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NovoRdoScreen(projetoId: widget.projetoId, projetoNome: widget.projetoNome),
          ),
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

  Widget _buildEmpresaCard(BuildContext context, EmpresaRdoResumo empresa) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RdoListaScreen(
              projetoId: widget.projetoId,
              projetoNome: widget.projetoNome,
              empresaId: empresa.id,
              empresaNome: empresa.nome,
              empresaFotoUrl: empresa.fotoUrl,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.greyVeryLight,
              backgroundImage: (empresa.fotoUrl != null && empresa.fotoUrl!.isNotEmpty)
                  ? StorageNetworkImage(empresa.fotoUrl!)
                  : null,
              child: (empresa.fotoUrl == null || empresa.fotoUrl!.isEmpty)
                  ? const Icon(Icons.apartment, color: AppColors.primary)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    empresa.nome,
                    style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D)),
                  ),
                  if (empresa.local.isNotEmpty)
                    Text(empresa.local, style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyMedium)),
                  const SizedBox(height: 4),
                  Text(
                    empresa.ultimoRdoEm == null
                        ? 'Nenhum RDO registrado'
                        : 'Última atualização: ${_formatarData(empresa.ultimoRdoEm!)}',
                    style: GoogleFonts.lato(fontSize: 11, color: AppColors.greyMedium),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildBadgeContagem(empresa.totalRdos),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeContagem(int total) {
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: total > 0 ? const Color(0xFFFCE7CC) : AppColors.greyVeryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$total',
        textAlign: TextAlign.center,
        style: GoogleFonts.lato(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: total > 0 ? AppColors.primary : AppColors.greyMedium,
        ),
      ),
    );
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }
}
