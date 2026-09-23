import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/custom_empty_state.dart';
import '../../projetos/models/projeto_model.dart';
import '../../projetos/rdo/screens/selecionar_projeto_rdo_screen.dart';
import '../models/gasto_model.dart';
import '../providers/gastos_providers.dart';
import '../utils/agregacao_gastos.dart';
import '../widgets/gasto_form_dialog.dart';
import '../widgets/gastos_widgets.dart';

/// Gastos do próprio usuário, em todos os projetos (acesso pelo menu do
/// perfil). Análise individual: gráfico dos últimos meses, totais do mês e
/// a lista do mês escolhido.
class MeusGastosScreen extends ConsumerStatefulWidget {
  const MeusGastosScreen({super.key});

  @override
  ConsumerState<MeusGastosScreen> createState() => _MeusGastosScreenState();
}

class _MeusGastosScreenState extends ConsumerState<MeusGastosScreen> {
  bool _verReembolsavel = true;
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);

  /// Como no RDO: primeiro escolhe o projeto, depois abre o formulário já
  /// com ele fixo.
  Future<void> _novoGasto() async {
    final projeto = await Navigator.of(context).push<ProjetoModel>(
      MaterialPageRoute(builder: (_) => const SelecionarProjetoRdoScreen(pergunta: 'Para qual projeto é este gasto?')),
    );
    if (projeto == null || !mounted) return;
    await abrirFormularioGasto(context, projetoFixoId: projeto.id);
  }

  @override
  Widget build(BuildContext context) {
    final gastosAsync = ref.watch(meusGastosProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(
        title: 'Meus Gastos',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            Text('Todos os projetos', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Meus Gastos', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _novoGasto,
        backgroundColor: AppColors.primary,
        tooltip: 'Novo gasto',
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: gastosAsync.when(
        loading: () => const CarregandoGastos(),
        error: (e, _) => ErroGastos(erro: e, onTentarDeNovo: () => ref.invalidate(meusGastosProvider)),
        data: (gastos) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.refresh(meusGastosProvider.future),
          child: _conteudo(gastos),
        ),
      ),
    );
  }

  Widget _conteudo(List<GastoModel> gastos) {
    // Nenhum gasto lançado ainda: gráfico e totais zerados não dizem nada.
    // (Dentro de um ListView para o "puxar para atualizar" continuar valendo.)
    if (gastos.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 96),
        children: const [
          CustomEmptyState(
            text: 'Nenhum gasto registrado.\nToque em + para lançar o primeiro.',
            icon: Icons.receipt_long_outlined,
          ),
        ],
      );
    }

    final doTipo = gastos.where((g) => g.reembolsavel == _verReembolsavel);
    final meses = AgregacaoGastos.ultimosMeses(doTipo, _mes);
    final doMes = gastos.where((g) => AgregacaoGastos.mesmoMes(g.data, _mes)).toList();
    final totaisMes = AgregacaoGastos.totais(doMes);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        SeletorSegmentadoGastos<bool>(
          opcoes: const [(true, 'Reembolsável'), (false, 'Não reembolsável')],
          selecionado: _verReembolsavel,
          onChanged: (v) => setState(() => _verReembolsavel = v),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text('Mês de\nanálise', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(width: 12),
            Expanded(child: _seletorMes(gastos)),
          ],
        ),
        const SizedBox(height: 12),
        GraficoColunasGastos(
          dados: [for (final m in meses) (rotuloMesCurto(m.mes), m.valor)],
          cor: _verReembolsavel ? CoresGastos.reembolsavel : CoresGastos.naoReembolsavel,
          mostrarEixoY: false,
          altura: 150,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: CardValorGasto(
                rotulo: 'Reembolsável',
                valor: totaisMes.reembolsavel,
                destaque: _verReembolsavel,
                centavos: true,
                alinhamento: CrossAxisAlignment.start,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CardValorGasto(
                rotulo: 'Não reembolsável',
                valor: totaisMes.naoReembolsavel,
                destaque: !_verReembolsavel,
                centavos: true,
                alinhamento: CrossAxisAlignment.start,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (doMes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(
              'Nenhum gasto em ${formatarMesAno(_mes)}.\nToque em + para lançar.',
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(fontSize: 13, color: Colors.grey),
            ),
          )
        else
          for (final g in doMes) ...[
            ItemGastoTile(gasto: g, onTap: () => abrirFormularioGasto(context, gasto: g)),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  /// Meses com gasto + o mês atual + o escolhido, do mais recente ao mais antigo.
  Widget _seletorMes(List<GastoModel> gastos) {
    final hoje = DateTime.now();
    final chaves = <int>{
      hoje.year * 12 + hoje.month,
      _mes.year * 12 + _mes.month,
      for (final g in gastos) g.data.year * 12 + g.data.month,
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    DateTime deChave(int k) => DateTime((k - 1) ~/ 12, (k - 1) % 12 + 1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _mes.year * 12 + _mes.month,
          isExpanded: true,
          items: [
            for (final k in chaves) DropdownMenuItem(value: k, child: Text(formatarMesAno(deChave(k)), style: GoogleFonts.lato(fontSize: 14))),
          ],
          onChanged: (k) {
            if (k != null) setState(() => _mes = deChave(k));
          },
        ),
      ),
    );
  }
}
