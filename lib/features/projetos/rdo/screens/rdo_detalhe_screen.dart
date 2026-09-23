import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/custom_appbar.dart';
import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../equipe/providers/equipe_provider.dart';
import '../models/galeria_rdo_model.dart';
import '../models/rdo_realizado_model.dart';
import '../providers/rdo_provider.dart';
import '../repositories/galeria_rdo_repository.dart';
import '../widgets/equipe_helpers.dart';
import 'gerar_relatorio_rdo_screen.dart';
import '../widgets/rdo_modals.dart';
import '../widgets/rdo_status_badge.dart';
import '../widgets/turno_resumo_card.dart';
import 'package:diavicon/features/planos/acesso_plano.dart';

class RdoDetalheScreen extends ConsumerStatefulWidget {
  final RdoRealizadoModel rdo;
  final String projetoNome;
  final String empresaNome;

  const RdoDetalheScreen({
    super.key,
    required this.rdo,
    this.projetoNome = 'Projeto',
    this.empresaNome = 'Empresa',
  });

  @override
  ConsumerState<RdoDetalheScreen> createState() => _RdoDetalheScreenState();
}

class _RdoDetalheScreenState extends ConsumerState<RdoDetalheScreen> {
  late RdoStatus _status;
  bool _alterandoStatus = false;

  @override
  void initState() {
    super.initState();
    _status = widget.rdo.status;
  }

  @override
  Widget build(BuildContext context) {
    final papelAsync = ref.watch(papelEmpresaNoProjetoProvider(widget.rdo.projetoId));
    final papel = papelAsync.value;
    final podeAlterarStatus = papel?.podeAlterarStatus ?? false;
    final podeExcluir = papel != null && papel != PapelEmpresaProjeto.cliente;

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCabecalho(),
              const SizedBox(height: 16),
              _buildStatusLinha(podeAlterarStatus),
              const SizedBox(height: 12),
              Text('Equipe', style: _tituloSecao()),
              const SizedBox(height: 8),
              _buildEquipe(),
              const SizedBox(height: 20),
              TurnoResumoCard(titulo: 'Manhã', icone: Icons.wb_sunny_outlined, turno: widget.rdo.manha),
              const SizedBox(height: 12),
              TurnoResumoCard(titulo: 'Tarde', icone: Icons.engineering_outlined, turno: widget.rdo.tarde),
              const SizedBox(height: 12),
              TurnoResumoCard(titulo: 'Noite', icone: Icons.nightlight_round, turno: widget.rdo.noite),
              const SizedBox(height: 24),
              _buildBlocoTexto('Atividades realizadas', widget.rdo.atividadesRealizadas),
              const SizedBox(height: 16),
              _buildBlocoTexto('Equipamentos utilizados', widget.rdo.equipamentosUtilizados),
              const SizedBox(height: 16),
              _buildBlocoTexto('Observações', widget.rdo.observacoes),
              const SizedBox(height: 24),
              _buildGaleria(context),
              const SizedBox(height: 28),
              _buildBotoesAcao(context, podeExcluir: podeExcluir),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _tituloSecao() =>
      GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D));

  Widget _buildCabecalho() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Relatório Diário de Obra', style: _tituloSecao().copyWith(fontSize: 18)),
        Text(widget.projetoNome, style: GoogleFonts.lato(fontSize: 14, color: const Color(0xFF3E3E3D))),
        const SizedBox(height: 2),
        Text(widget.empresaNome, style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyMedium)),
        const SizedBox(height: 4),
        Text(widget.rdo.data, style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyMedium)),
      ],
    );
  }

  Widget _buildStatusLinha(bool podeAlterarStatus) {
    return Row(
      children: [
        Text('Status: ', style: GoogleFonts.lato(fontSize: 14, color: const Color(0xFF3E3E3D))),
        RdoStatusBadge(status: _status),
        if (podeAlterarStatus) ...[
          const SizedBox(width: 10),
          if (_alterandoStatus)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          else
            TextButton(
              onPressed: () => _abrirSeletorStatus(context),
              child: Text('Alterar', style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
        ],
      ],
    );
  }

  Widget _buildEquipe() {
    if (widget.rdo.equipe.isEmpty) {
      return Text('Sem equipe registrada', style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyLight));
    }

    final membros = ref.watch(colaboradoresProjetoVisiveisProvider(widget.rdo.projetoId)).value ?? const [];
    final mapaEquipe = mapaEquipePorNome(membros);

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        for (final nome in widget.rdo.equipe)
          SizedBox(
            width: 72,
            child: Column(
              children: [
                _buildAvatarMembro(fotoDoMembro(mapaEquipe[nome]), radius: 20),
                const SizedBox(height: 4),
                Text(
                  nome,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF3E3E3D)),
                ),
                Builder(builder: (context) {
                  final cargo = cargoDoMembro(mapaEquipe[nome]);
                  if (cargo.isEmpty) return const SizedBox.shrink();
                  return Text(
                    cargo,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lato(fontSize: 10, color: AppColors.greyMedium),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarMembro(String? fotoUrl, {required double radius}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.greyVeryLight,
      backgroundImage: fotoUrl != null ? StorageNetworkImage(fotoUrl) : null,
      child: fotoUrl == null ? Icon(Icons.person, size: radius, color: AppColors.greyMedium) : null,
    );
  }

  Widget _buildBlocoTexto(String titulo, String conteudo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: _tituloSecao()),
        const SizedBox(height: 6),
        Text(
          conteudo.isEmpty ? 'Não informado.' : conteudo,
          style: GoogleFonts.lato(fontSize: 13, color: AppColors.greyMedium, height: 1.4),
        ),
      ],
    );
  }

  // Galeria só como consulta aqui: fotos entram no momento da criação do RDO
  // (NovoRdoScreen) — depois de salvo, o RDO (fotos incluídas) não é mais
  // editável, só visualizável (e apagável/status pelo dono/gestora/cliente).
  Widget _buildGaleria(BuildContext context) {
    final fotosAsync = ref.watch(galeriaRdoProvider(widget.rdo.id!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Galeria', style: _tituloSecao()),
        const SizedBox(height: 8),
        fotosAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ),
          error: (err, _) => Text('Erro ao carregar fotos: $err', style: GoogleFonts.lato(fontSize: 12, color: AppColors.error)),
          data: (fotos) {
            if (fotos.isEmpty) {
              return Text('Nenhuma foto anexada.', style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyLight));
            }
            return Column(
              children: [
                for (final foto in fotos) ...[
                  _buildFotoCard(context, foto),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFotoCard(BuildContext context, GaleriaRdoModel foto) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _visualizarFoto(context, foto),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ImagemStorage.network(
                foto.foto,
                width: 84,
                height: 84,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 84,
                  height: 84,
                  color: AppColors.greyVeryLight,
                  child: const Icon(Icons.broken_image_outlined, color: AppColors.greyMedium),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                (foto.descricao?.isNotEmpty ?? false) ? foto.descricao! : 'Sem descrição',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lato(fontSize: 13, color: AppColors.greyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _visualizarFoto(BuildContext context, GaleriaRdoModel foto) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ImagemStorage.network(foto.foto, fit: BoxFit.contain),
            ),
            if (foto.descricao?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Text(foto.descricao!, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF3E3E3D))),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBotoesAcao(BuildContext context, {required bool podeExcluir}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (podeExcluir)
          OutlinedButton(
            onPressed: () => _confirmarExclusao(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            ),
            child: const Text('Apagar'),
          ),
        if (podeExcluir) const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () => _abrirGerarRelatorio(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            elevation: 0,
          ),
          child: Text('Imprimir', style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  void _abrirGerarRelatorio(BuildContext context) {
    final partes = widget.rdo.data.split('/');
    final data = partes.length == 3 ? DateTime.tryParse('${partes[2]}-${partes[1]}-${partes[0]}') : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuardaModuloPlano(modulo: ModuloPlano.relatorios, child: GerarRelatorioRdoScreen(
          projetoId: widget.rdo.projetoId,
          projetoNome: widget.projetoNome,
          empresaId: widget.rdo.empresaId,
          dataInicialPadrao: data,
          dataFinalPadrao: data,
        )),
      ),
    );
  }

  Future<void> _abrirSeletorStatus(BuildContext context) async {
    final novoStatus = await showModalBottomSheet<RdoStatus>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text('Alterar status do RDO', style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),
            for (final status in RdoStatus.values)
              ListTile(
                leading: RdoStatusBadge(status: status),
                trailing: status == _status ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () => Navigator.of(context).pop(status),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (novoStatus == null || novoStatus == _status || widget.rdo.id == null) return;

    setState(() => _alterandoStatus = true);
    try {
      await ref.read(rdoRepositoryProvider).atualizarStatus(rdoId: widget.rdo.id!, status: novoStatus);
      if (!mounted) return;
      setState(() {
        _status = novoStatus;
        _alterandoStatus = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _alterandoStatus = false);
      if (!context.mounted) return;
      DiaviconAlerts.show(context, 'Erro', '$e', isErro: true);
    }
  }

  Future<void> _confirmarExclusao(BuildContext context) async {
    final confirmou = await RdoConfirmDialogs.mostrarConfirmarExclusao(context);
    if (!confirmou || !context.mounted || widget.rdo.id == null) return;

    try {
      await ref.read(rdoRepositoryProvider).excluir(widget.rdo.id!);
      if (!context.mounted) return;
      await RdoConfirmDialogs.mostrarApagado(context);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      DiaviconAlerts.show(context, 'Erro ao apagar', '$e', isErro: true);
    }
  }
}
