import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../projetos/providers/projetos_provider.dart';
import '../models/gasto_model.dart';
import '../providers/gastos_providers.dart';
import '../utils/agregacao_gastos.dart';
import '../widgets/gasto_form_dialog.dart';
import '../widgets/gastos_widgets.dart';

enum _VisaoProjeto { categoria, usuario }

/// Gastos de um projeto (acesso pelo menu do projeto).
///
/// Sigilo por empresa: só aparecem gastos da empresa de quem está vendo.
/// O admin da empresa vê os de todos os colaboradores (sem poder editar os
/// de terceiros); os demais veem só os próprios. Quem decide é o RLS — a
/// tela só ajusta os textos e esconde a visão "Por usuário" de quem não é
/// admin (ela teria uma barra só).
class GastosProjetoScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String? projetoNome;

  const GastosProjetoScreen({super.key, required this.projetoId, this.projetoNome});

  @override
  ConsumerState<GastosProjetoScreen> createState() => _GastosProjetoScreenState();
}

class _GastosProjetoScreenState extends ConsumerState<GastosProjetoScreen> {
  late String _projetoId = widget.projetoId;
  _VisaoProjeto _visao = _VisaoProjeto.categoria;

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(ehAdminEmpresaProvider);
    final gastosAsync = ref.watch(gastosDoProjetoProvider(_projetoId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'Gastos do Projeto',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            Text(widget.projetoNome ?? 'Projeto', style: const TextStyle(fontSize: 12, color: Colors.white70), overflow: TextOverflow.ellipsis),
            const Text('Gastos do Projeto', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => abrirFormularioGasto(context, projetoFixoId: _projetoId),
        backgroundColor: AppColors.primary,
        tooltip: 'Novo gasto neste projeto',
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.refresh(gastosDoProjetoProvider(_projetoId).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _seletorProjeto(),
            const SizedBox(height: 10),
            _avisoAlcance(admin),
            const SizedBox(height: 14),
            ...gastosAsync.when(
              loading: () => [const CarregandoGastos()],
              error: (e, _) => [ErroGastos(erro: e, onTentarDeNovo: () => ref.invalidate(gastosDoProjetoProvider(_projetoId)))],
              data: (gastos) => _conteudo(gastos, admin),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _conteudo(List<GastoModel> gastos, bool admin) {
    final visao = admin ? _visao : _VisaoProjeto.categoria;
    final ranking = visao == _VisaoProjeto.categoria ? AgregacaoGastos.porCategoria(gastos) : AgregacaoGastos.porUsuario(gastos);
    final uid = ref.read(currentUserProvider)?.id;

    return [
      ResumoTotaisGastos(totais: AgregacaoGastos.totais(gastos)),
      const SizedBox(height: 16),
      if (admin)
        SeletorSegmentadoGastos<_VisaoProjeto>(
          opcoes: const [(_VisaoProjeto.categoria, 'Por categoria'), (_VisaoProjeto.usuario, 'Por usuário')],
          selecionado: _visao,
          onChanged: (v) => setState(() => _visao = v),
        )
      else
        const TituloSecaoGastos('Por categoria'),
      const SizedBox(height: 8),
      RankingBarrasGastos(itens: ranking, vazio: 'Nenhum gasto neste projeto.'),
      if (gastos.isNotEmpty) ...[
        const SizedBox(height: 20),
        const TituloSecaoGastos('Lançamentos'),
        const SizedBox(height: 8),
        for (final g in gastos) ...[
          ItemGastoTile(
            gasto: g,
            // O admin vê gastos de várias pessoas: o nome entra na linha.
            mostrarUsuario: admin && g.usuarioId != uid,
            onTap: () => abrirFormularioGasto(context, gasto: g),
          ),
          const SizedBox(height: 8),
        ],
      ],
    ];
  }

  Widget _avisoAlcance(bool admin) {
    final texto = admin
        ? 'Visão de admin: gastos de todos os colaboradores da sua empresa neste projeto. Você só edita os seus.'
        : 'Você vê apenas os seus gastos neste projeto.';
    return Row(
      children: [
        Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(child: Text(texto, style: GoogleFonts.lato(fontSize: 11.5, color: Colors.grey.shade600))),
      ],
    );
  }

  Widget _seletorProjeto() {
    final projetosAsync = ref.watch(projectsProvider);
    final projetos = projetosAsync.value ?? const [];
    final itens = [
      for (final p in projetos) DropdownMenuItem(value: p.id, child: Text(p.nome, overflow: TextOverflow.ellipsis)),
      if (!projetos.any((p) => p.id == _projetoId))
        DropdownMenuItem(value: _projetoId, child: Text(widget.projetoNome ?? 'Projeto', overflow: TextOverflow.ellipsis)),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _projetoId,
          isExpanded: true,
          items: itens,
          onChanged: (v) {
            if (v != null) setState(() => _projetoId = v);
          },
        ),
      ),
    );
  }
}
