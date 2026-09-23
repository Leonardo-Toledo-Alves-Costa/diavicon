import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../models/gasto_model.dart';
import '../providers/gastos_providers.dart';
import '../reports/gastos_export_service.dart';
import '../utils/agregacao_gastos.dart';
import '../widgets/gastos_widgets.dart';

enum _AbaUsuario { reembolso, categoria, projeto }

/// Análise gerencial: gastos da empresa inteira, todos os projetos, num
/// período. Só admin da empresa (Painel da empresa). O RLS também só
/// devolve gastos de terceiros para admin — a checagem aqui é de UX.
class AnaliseGastosScreen extends ConsumerStatefulWidget {
  final String empresaId;
  final String empresaNome;

  const AnaliseGastosScreen({super.key, required this.empresaId, required this.empresaNome});

  @override
  ConsumerState<AnaliseGastosScreen> createState() => _AnaliseGastosScreenState();
}

class _AnaliseGastosScreenState extends ConsumerState<AnaliseGastosScreen> {
  late DateTime _inicio;
  late DateTime _fim;
  String? _usuarioAberto;
  final Map<String, _AbaUsuario> _abaPorUsuario = {};
  bool _exportando = false;

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    _fim = DateTime(hoje.year, hoje.month, hoje.day);
    _inicio = DateTime(hoje.year, hoje.month, 1);
  }

  FiltroAnaliseGastos get _filtro => (empresaId: widget.empresaId, inicio: _inicio, fim: _fim);

  Future<void> _escolherData({required bool inicio}) async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: inicio ? _inicio : _fim,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (escolhida == null) return;
    setState(() {
      if (inicio) {
        _inicio = escolhida;
        if (_fim.isBefore(_inicio)) _fim = _inicio;
      } else {
        _fim = escolhida;
        if (_inicio.isAfter(_fim)) _inicio = _fim;
      }
    });
  }

  /// Categorias marcadas nos chips. Vazio = todas.
  final Set<String> _categoriasFiltro = {};

  /// Aplica o filtro de categoria antes de qualquer conta da tela.
  ///
  /// Vale também para a exportação: o arquivo sai com exatamente o que está
  /// na tela, senão o relatório não bate com o que a pessoa viu.
  List<GastoModel> _filtradosPorCategoria(List<GastoModel> gastos) {
    if (_categoriasFiltro.isEmpty) return gastos;
    return gastos.where((g) => _categoriasFiltro.contains(g.categoriaId)).toList();
  }

  void _alternarCategoria(String chave) {
    setState(() {
      if (!_categoriasFiltro.remove(chave)) _categoriasFiltro.add(chave);
    });
  }

  void _limparCategorias() => setState(_categoriasFiltro.clear);

  Future<void> _exportar(List<GastoModel> todos) async {
    // O arquivo sai com o que está na tela, filtro de categoria incluído.
    final gastos = _filtradosPorCategoria(todos);
    final formato = await showModalBottomSheet<FormatoExportacaoGastos>(
      context: context,
      // Branco de propósito: sem isto o tema pinta a folha com um tom
      // alaranjado tirado da cor da marca.
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Exportar ${gastos.length} lançamento(s) de ${formatarData(_inicio)} a ${formatarData(_fim)}',
                style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            for (final f in FormatoExportacaoGastos.values)
              ListTile(
                leading: Icon(
                  f == FormatoExportacaoGastos.csv
                      ? Icons.table_chart_outlined
                      : f == FormatoExportacaoGastos.pdf
                          ? Icons.picture_as_pdf_outlined
                          : Icons.code,
                  color: AppColors.primary,
                ),
                title: Text(f.rotulo),
                onTap: () => Navigator.pop(c, f),
              ),
          ],
        ),
      ),
    );
    if (formato == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exportando = true);
    try {
      await GastosExportService.exportar(
        formato: formato,
        empresaNome: widget.empresaNome,
        inicio: _inicio,
        fim: _fim,
        gastos: gastos,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Não foi possível exportar: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(ehAdminEmpresaProvider);
    final gastosAsync = admin ? ref.watch(gastosDaEmpresaProvider(_filtro)) : null;
    final gastos = gastosAsync?.value;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'Análise de Gastos',
        showBackButton: true,
        showMenuButton: false,
        extraActions: [
          if (admin)
            _exportando
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  )
                : IconButton(
                    tooltip: 'Exportar',
                    icon: const Icon(Icons.download_outlined, color: Colors.white),
                    onPressed: gastos == null ? null : () => _exportar(gastos),
                  ),
        ],
      ),
      body: !admin
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'A análise de gastos da empresa é restrita aos administradores.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade700),
                ),
              ),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.refresh(gastosDaEmpresaProvider(_filtro).future),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  Row(
                    children: [
                      Expanded(child: _botaoData('De', _inicio, () => _escolherData(inicio: true))),
                      const SizedBox(width: 10),
                      Expanded(child: _botaoData('Até', _fim, () => _escolherData(inicio: false))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...gastosAsync!.when(
                    loading: () => [const CarregandoGastos()],
                    error: (e, _) => [ErroGastos(erro: e, onTentarDeNovo: () => ref.invalidate(gastosDaEmpresaProvider(_filtro)))],
                    data: _conteudo,
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _conteudo(List<GastoModel> todos) {
    // Os chips mostram TODAS as categorias do período, mesmo com filtro
    // ativo — senão, ao marcar uma, as outras sumiriam e não haveria como
    // voltar atrás.
    final categoriasDoPeriodo = AgregacaoGastos.porCategoria(todos);
    final gastos = _filtradosPorCategoria(todos);

    final porProjeto = AgregacaoGastos.porProjeto(gastos);
    final porUsuario = AgregacaoGastos.porUsuario(gastos);
    final porMes = AgregacaoGastos.porMesNoPeriodo(gastos, _inicio, _fim);

    return [
      ResumoTotaisGastos(totais: AgregacaoGastos.totais(gastos)),
      const Divider(height: 32),

      // Filtro primeiro: o que for marcado vale para tudo que vem abaixo.
      const TituloSecaoGastos('Categorias'),
      const SizedBox(height: 8),
      FiltroCategoriasGastos(
        categorias: categoriasDoPeriodo,
        selecionadas: _categoriasFiltro,
        aoAlternar: _alternarCategoria,
        aoLimpar: _limparCategorias,
      ),
      const Divider(height: 32),

      // O período é escolhido por data, então o primeiro gráfico é o que
      // responde à pergunta "quanto gastei em cada mês".
      const TituloSecaoGastos('Gasto por mês'),
      const SizedBox(height: 8),
      GraficoColunasGastos(dados: [for (final m in porMes) (rotuloMesAnoCurto(m.mes), m.valor)]),
      const Divider(height: 32),

      const TituloSecaoGastos('Gasto por projeto'),
      const SizedBox(height: 8),
      RankingBarrasGastos(itens: porProjeto, vazio: 'Sem gastos no período.'),
      const Divider(height: 32),

      const TituloSecaoGastos('Gasto por usuário'),
      const SizedBox(height: 8),
      if (porUsuario.isEmpty)
        Text('Sem gastos no período.', style: GoogleFonts.lato(fontSize: 13, color: Colors.grey))
      else
        for (final u in porUsuario) ...[
          _cartaoUsuario(u, gastos.where((g) => g.usuarioId == u.chave).toList()),
          const SizedBox(height: 8),
        ],
    ];
  }

  Widget _cartaoUsuario(ItemAgregado usuario, List<GastoModel> gastosDoUsuario) {
    final aberto = _usuarioAberto == usuario.chave;
    final aba = _abaPorUsuario[usuario.chave] ?? _AbaUsuario.reembolso;

    Widget detalhe() {
      switch (aba) {
        case _AbaUsuario.reembolso:
          final maximo = usuario.reembolsavel > usuario.naoReembolsavel ? usuario.reembolsavel : usuario.naoReembolsavel;
          return Column(children: [
            BarraValorGasto(rotulo: 'Reembolsável', valor: usuario.reembolsavel, maximo: maximo),
            BarraValorGasto(rotulo: 'Não reembolsável', valor: usuario.naoReembolsavel, maximo: maximo),
          ]);
        case _AbaUsuario.categoria:
          return RankingBarrasGastos(itens: AgregacaoGastos.porCategoria(gastosDoUsuario));
        case _AbaUsuario.projeto:
          return RankingBarrasGastos(itens: AgregacaoGastos.porProjeto(gastosDoUsuario));
      }
    }

    return Container(
      decoration: BoxDecoration(color: CoresGastos.cartao, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _usuarioAberto = aberto ? null : usuario.chave),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(usuario.rotulo, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w800, color: CoresGastos.texto)),
                  ),
                  Text(formatarMoeda(usuario.valor, centavos: false), style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w800, color: CoresGastos.texto)),
                  Icon(aberto ? Icons.expand_less : Icons.expand_more, color: Colors.grey.shade600),
                ],
              ),
            ),
          ),
          if (aberto)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SeletorSegmentadoGastos<_AbaUsuario>(
                    compacto: true,
                    opcoes: const [
                      (_AbaUsuario.reembolso, 'Reembolsável'),
                      (_AbaUsuario.categoria, 'Categoria'),
                      (_AbaUsuario.projeto, 'Projeto'),
                    ],
                    selecionado: aba,
                    onChanged: (v) => setState(() => _abaPorUsuario[usuario.chave] = v),
                  ),
                  const SizedBox(height: 6),
                  detalhe(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _botaoData(String rotulo, DateTime data, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Expanded(child: Text('$rotulo: ${formatarData(data)}', style: GoogleFonts.lato(fontSize: 13.5, fontWeight: FontWeight.w600))),
            Icon(Icons.expand_more, color: Colors.grey.shade600, size: 20),
          ],
        ),
      ),
    );
  }
}
