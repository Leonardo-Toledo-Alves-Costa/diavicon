import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_appbar.dart';
import '../../core/widgets/diavicon_alerts.dart';
import '../planos/model/planos_model.dart';
import '../planos/providers/planos_provider.dart';
import '../plataforma/screens/empresas_cadastradas_screen.dart' show ehAdminDiaviconProvider;
import 'financeiro_repository.dart';
import 'financeiro_widgets.dart';

/// Painel da DIAVICON › Empresas cadastradas › Financeiro de uma empresa:
/// contrato (plano, valor, vencimento, especificidades) e as cobranças de
/// cada mês com boleto, nota fiscal e status.
class FinanceiroEmpresaScreen extends ConsumerStatefulWidget {
  final String empresaId;
  final String empresaNome;
  final String? empresaCnpj;

  const FinanceiroEmpresaScreen({super.key, required this.empresaId, required this.empresaNome, this.empresaCnpj});

  @override
  ConsumerState<FinanceiroEmpresaScreen> createState() => _FinanceiroEmpresaScreenState();
}

enum _Filtro { todas, emAberto, pagas, canceladas }

extension on _Filtro {
  String get rotulo => switch (this) {
        _Filtro.todas => 'Todas',
        _Filtro.emAberto => 'Em aberto',
        _Filtro.pagas => 'Pagas',
        _Filtro.canceladas => 'Canceladas',
      };

  bool aceita(CobrancaEmpresa c) => switch (this) {
        _Filtro.todas => true,
        _Filtro.emAberto => c.emAberto,
        _Filtro.pagas => c.status == StatusCobranca.pago,
        _Filtro.canceladas => c.status == StatusCobranca.cancelado,
      };
}

class _FinanceiroEmpresaScreenState extends ConsumerState<FinanceiroEmpresaScreen> {
  _Filtro _filtro = _Filtro.todas;
  bool _ocupado = false;

  FinanceiroRepository get _repo => ref.read(financeiroRepositoryProvider);

  void _recarregar() {
    ref.invalidate(contratoAtivoProvider(widget.empresaId));
    ref.invalidate(cobrancasEmpresaProvider(widget.empresaId));
    ref.invalidate(resumoFinanceiroProvider);
  }

  /// Roda uma ação com indicador de ocupado e mensagem de erro legível.
  Future<bool> _executar(Future<void> Function() acao, {String? sucesso}) async {
    setState(() => _ocupado = true);
    try {
      await acao();
      _recarregar();
      if (mounted && sucesso != null) mostrarAvisoFinanceiro(context, sucesso);
      return true;
    } catch (e) {
      if (mounted) DiaviconAlerts.show(context, 'Não foi possível concluir', mensagemErroFinanceiro(e), isErro: true);
      return false;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  // --- Contrato ------------------------------------------------------------

  Future<void> _editarContrato(ContratoEmpresa? atual) async {
    final dados = await showDialog<_DadosContrato>(
      context: context,
      builder: (_) => _DialogoContrato(atual: atual, empresaNome: widget.empresaNome),
    );
    if (dados == null) return;
    final ok = await _executar(
      () => _repo.salvarContrato(
        id: atual?.id,
        empresaId: widget.empresaId,
        planoId: dados.planoId,
        valorMensal: dados.valor,
        diaVencimento: dados.diaVencimento,
        inicio: dados.inicio,
        fim: dados.fim,
        especificidades: dados.especificidades,
      ),
      sucesso: atual == null ? 'Contrato cadastrado. O plano da empresa foi atualizado.' : 'Contrato atualizado.',
    );
    if (ok && atual == null && mounted) {
      final contrato = await ref.read(contratoAtivoProvider(widget.empresaId).future);
      if (contrato != null && mounted) await _perguntarGerar(contrato);
    }
  }

  Future<void> _perguntarGerar(ContratoEmpresa contrato) async {
    final gerar = await confirmarFinanceiro(
      context,
      titulo: 'Gerar as mensalidades?',
      mensagem: contrato.fim == null
          ? 'Cria as cobranças pendentes de ${formatarCompetencia(contrato.inicio)} até o mês que vem, com vencimento todo dia ${contrato.diaVencimento}.'
          : 'Cria as cobranças pendentes de ${formatarCompetencia(contrato.inicio)} a ${formatarCompetencia(contrato.fim!)}, com vencimento todo dia ${contrato.diaVencimento}.',
      confirmar: 'Gerar',
    );
    if (!gerar) return;
    await _gerar(contrato);
  }

  Future<void> _gerar(ContratoEmpresa contrato) async {
    var criadas = 0;
    final ok = await _executar(() async => criadas = await _repo.gerarMensalidades(contrato.id));
    if (!ok || !mounted) return;
    mostrarAvisoFinanceiro(
      context,
      criadas == 0 ? 'Todas as mensalidades do período já estavam lançadas.' : '$criadas ${criadas == 1 ? 'mensalidade criada' : 'mensalidades criadas'}.',
    );
  }

  Future<void> _encerrarContrato(ContratoEmpresa contrato) async {
    final ok = await confirmarFinanceiro(
      context,
      titulo: 'Encerrar o contrato?',
      mensagem: 'O contrato fica no histórico e as cobranças já lançadas continuam. O plano da empresa não muda: '
          'troque-o cadastrando um novo contrato.',
      confirmar: 'Encerrar',
      perigoso: true,
    );
    if (!ok) return;
    await _executar(() => _repo.encerrarContrato(contrato.id), sucesso: 'Contrato encerrado.');
  }

  // --- Cobranças -----------------------------------------------------------

  Future<void> _editarCobranca(CobrancaEmpresa? atual, ContratoEmpresa? contrato) async {
    final dados = await showDialog<_DadosCobranca>(
      context: context,
      builder: (_) => _DialogoCobranca(atual: atual, valorSugerido: contrato?.valorMensal, diaSugerido: contrato?.diaVencimento),
    );
    if (dados == null) return;
    await _executar(
      () => _repo.salvarCobranca(
        id: atual?.id,
        empresaId: widget.empresaId,
        competencia: dados.competencia,
        descricao: dados.descricao,
        valor: dados.valor,
        vencimento: dados.vencimento,
        observacao: dados.observacao,
      ),
      sucesso: atual == null ? 'Cobrança lançada.' : 'Cobrança atualizada.',
    );
  }

  Future<void> _marcarPago(CobrancaEmpresa c) async {
    final data = await showDatePicker(
      context: context,
      helpText: 'Data do pagamento',
      cancelText: 'Cancelar',
      confirmText: 'Marcar como pago',
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (data == null) return;
    await _executar(() => _repo.alterarStatus(c.id, StatusCobranca.pago, pagoEm: data), sucesso: 'Pagamento registrado.');
  }

  Future<void> _mudarStatus(CobrancaEmpresa c, StatusCobranca s) async {
    if (s == StatusCobranca.cancelado) {
      final ok = await confirmarFinanceiro(
        context,
        titulo: 'Cancelar a cobrança de ${formatarCompetencia(c.competencia)}?',
        mensagem: 'Ela deixa de contar como em aberto. Boleto e nota fiscal continuam anexados.',
        confirmar: 'Cancelar cobrança',
        perigoso: true,
      );
      if (!ok) return;
    }
    await _executar(() => _repo.alterarStatus(c.id, s), sucesso: 'Status alterado para ${s.rotulo.toLowerCase()}.');
  }

  Future<void> _excluir(CobrancaEmpresa c) async {
    final ok = await confirmarFinanceiro(
      context,
      titulo: 'Excluir a cobrança de ${formatarCompetencia(c.competencia)}?',
      mensagem: 'A cobrança, o boleto e a nota fiscal anexados são apagados. Para manter o registro, prefira cancelar.',
      confirmar: 'Excluir',
      perigoso: true,
    );
    if (!ok) return;
    await _executar(() => _repo.excluirCobranca(c), sucesso: 'Cobrança excluída.');
  }

  Future<void> _anexar(CobrancaEmpresa c, TipoAnexo tipo) async {
    final escolha = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'xml'],
      withData: true,
    );
    final arquivo = escolha?.files.firstOrNull;
    final bytes = arquivo?.bytes;
    if (arquivo == null || bytes == null) return;
    if (bytes.length > 10 * 1024 * 1024) {
      if (mounted) DiaviconAlerts.show(context, 'Arquivo grande demais', 'O limite é 10 MB por arquivo.', isAviso: true);
      return;
    }
    await _executar(
      () => _repo.anexar(cobranca: c, tipo: tipo, bytes: bytes, nomeOriginal: arquivo.name),
      sucesso: '${tipo.rotulo} anexado${tipo == TipoAnexo.notaFiscal ? 'a' : ''}.',
    );
  }

  Future<void> _removerAnexo(CobrancaEmpresa c, TipoAnexo tipo) async {
    final ok = await confirmarFinanceiro(
      context,
      titulo: 'Remover ${tipo == TipoAnexo.boleto ? 'o boleto' : 'a nota fiscal'}?',
      mensagem: 'O arquivo é apagado. Você pode anexar outro depois.',
      confirmar: 'Remover',
      perigoso: true,
    );
    if (!ok) return;
    await _executar(() => _repo.removerAnexo(c, tipo), sucesso: '${tipo.rotulo} removid${tipo == TipoAnexo.boleto ? 'o' : 'a'}.');
  }

  @override
  Widget build(BuildContext context) {
    final autorizado = ref.watch(ehAdminDiaviconProvider);
    final contratoAsync = ref.watch(contratoAtivoProvider(widget.empresaId));
    final cobrancasAsync = ref.watch(cobrancasEmpresaProvider(widget.empresaId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const CustomAppBar(title: 'Financeiro', showBackButton: true, showMenuButton: false),
      body: !autorizado
          ? const EstadoFinanceiro(icone: Icons.lock_outline_rounded, texto: 'Área restrita à administração da DIAVICON.')
          : Stack(
              children: [
                RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => _recarregar(),
                  child: LayoutBuilder(builder: (context, c) {
                    final largura = c.maxWidth.clamp(0.0, 1100.0);
                    final largo = largura >= 820;
                    return ListView(
                      padding: EdgeInsets.symmetric(horizontal: ((c.maxWidth - largura) / 2) + 16, vertical: 16),
                      children: [
                        _cabecalho(cobrancasAsync.value ?? const []),
                        const SizedBox(height: 16),
                        contratoAsync.when(
                          loading: () => const CartaoFinanceiro(
                            child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
                          ),
                          error: (e, _) => CartaoFinanceiro(
                            child: EstadoFinanceiro(icone: Icons.cloud_off_rounded, texto: mensagemErroFinanceiro(e)),
                          ),
                          data: (contrato) => _cartaoContrato(contrato, largo),
                        ),
                        const SizedBox(height: 16),
                        _cartaoCobrancas(cobrancasAsync, contratoAsync.value, largo),
                        const SizedBox(height: 40),
                      ],
                    );
                  }),
                ),
                if (_ocupado)
                  const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(color: AppColors.primary, minHeight: 3)),
              ],
            ),
    );
  }

  Widget _cabecalho(List<CobrancaEmpresa> cobrancas) {
    final abertas = cobrancas.where((c) => c.emAberto).toList();
    final atrasadas = abertas.where((c) => c.status == StatusCobranca.atrasado).toList();
    final ano = DateTime.now().year;
    final pagoNoAno = cobrancas
        .where((c) => c.status == StatusCobranca.pago && (c.pagoEm ?? c.vencimento).year == ano)
        .fold<double>(0, (s, c) => s + c.valor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.empresaNome, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 2),
        Text(
          (widget.empresaCnpj ?? '').isEmpty ? 'CNPJ não informado' : 'CNPJ ${widget.empresaCnpj}',
          style: const TextStyle(fontSize: 13, color: AppColors.greyMedium),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            IndicadorFinanceiro(
              icone: Icons.schedule_rounded,
              rotulo: 'Em aberto',
              valor: formatarReais(abertas.fold(0, (s, c) => s + c.valor)),
              detalhe: '${abertas.length} ${abertas.length == 1 ? 'cobrança' : 'cobranças'}',
            ),
            IndicadorFinanceiro(
              icone: Icons.warning_amber_rounded,
              rotulo: 'Atrasadas',
              valor: formatarReais(atrasadas.fold(0, (s, c) => s + c.valor)),
              detalhe: '${atrasadas.length} ${atrasadas.length == 1 ? 'cobrança' : 'cobranças'}',
              cor: atrasadas.isEmpty ? null : corStatusCobranca(StatusCobranca.atrasado),
            ),
            IndicadorFinanceiro(
              icone: Icons.check_circle_outline_rounded,
              rotulo: 'Recebido em $ano',
              valor: formatarReais(pagoNoAno),
              cor: corStatusCobranca(StatusCobranca.pago),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cartaoContrato(ContratoEmpresa? contrato, bool largo) {
    if (contrato == null) {
      return CartaoFinanceiro(
        titulo: 'Contrato',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nenhum contrato ativo. Cadastre o plano, o valor mensal e o dia de vencimento: o plano da empresa '
              'é atualizado na hora e as mensalidades podem ser geradas automaticamente.',
              style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.greyMedium),
            ),
            const SizedBox(height: 14),
            BotaoFinanceiro(icone: Icons.add, texto: 'Cadastrar contrato', onPressed: _ocupado ? null : () => _editarContrato(null)),
          ],
        ),
      );
    }

    final itens = <(String, String)>[
      ('Plano', contrato.planoNome ?? '—'),
      ('Valor mensal', formatarReais(contrato.valorMensal)),
      ('Vencimento', 'Todo dia ${contrato.diaVencimento}'),
      ('Vigência', contrato.fim == null ? 'Desde ${formatarDataBr(contrato.inicio)} (sem data de fim)' : '${formatarDataBr(contrato.inicio)} a ${formatarDataBr(contrato.fim!)}'),
    ];

    return CartaoFinanceiro(
      titulo: 'Contrato',
      acao: PopupMenuButton<String>(
        tooltip: 'Mais opções do contrato',
        color: Colors.white,
        onSelected: (v) => v == 'encerrar' ? _encerrarContrato(contrato) : _editarContrato(null),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'novo', child: Text('Substituir por um novo contrato')),
          PopupMenuItem(value: 'encerrar', child: Text('Encerrar contrato', style: TextStyle(color: AppColors.error))),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              for (final (rotulo, valor) in itens)
                SizedBox(
                  width: largo ? 230 : double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rotulo, style: const TextStyle(fontSize: 12, color: AppColors.greyMedium)),
                      const SizedBox(height: 2),
                      Text(valor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    ],
                  ),
                ),
            ],
          ),
          if (contrato.especificidades.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Especificidades', style: TextStyle(fontSize: 12, color: AppColors.greyMedium)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8F7F4), borderRadius: BorderRadius.circular(10)),
              child: Text(contrato.especificidades, style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textDark)),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              BotaoFinanceiro(
                icone: Icons.event_repeat_rounded,
                texto: 'Gerar mensalidades',
                onPressed: _ocupado ? null : () => _perguntarGerar(contrato),
              ),
              BotaoFinanceiro(
                icone: Icons.edit_outlined,
                texto: 'Editar contrato',
                secundario: true,
                onPressed: _ocupado ? null : () => _editarContrato(contrato),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cartaoCobrancas(AsyncValue<List<CobrancaEmpresa>> async, ContratoEmpresa? contrato, bool largo) {
    return CartaoFinanceiro(
      titulo: 'Cobranças',
      acao: TextButton.icon(
        onPressed: _ocupado ? null : () => _editarCobranca(null, contrato),
        style: TextButton.styleFrom(foregroundColor: const Color(0xFFA85A00), minimumSize: const Size(44, 40)),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Cobrança avulsa', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      child: async.when(
        loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
        error: (e, _) => EstadoFinanceiro(icone: Icons.cloud_off_rounded, texto: mensagemErroFinanceiro(e)),
        data: (lista) {
          if (lista.isEmpty) {
            return EstadoFinanceiro(
              icone: Icons.receipt_long_outlined,
              texto: contrato == null
                  ? 'Nenhuma cobrança lançada. Cadastre o contrato para gerar as mensalidades.'
                  : 'Nenhuma cobrança lançada. Use "Gerar mensalidades" no contrato.',
            );
          }
          final visiveis = lista.where(_filtro.aceita).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in _Filtro.values)
                    ChoiceChip(
                      label: Text('${f.rotulo} (${lista.where(f.aceita).length})'),
                      selected: _filtro == f,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _filtro = f),
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xFFFFF3E0),
                      side: BorderSide(color: _filtro == f ? AppColors.primary : const Color(0xFFE7E3DC)),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: _filtro == f ? FontWeight.w700 : FontWeight.w500,
                        color: _filtro == f ? const Color(0xFFA85A00) : AppColors.textDark,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (visiveis.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Nenhuma cobrança neste filtro.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.greyMedium)),
                )
              else
                for (final c in visiveis)
                  LinhaCobranca(
                    cobranca: c,
                    largo: largo,
                    aoAbrirAnexo: (tipo) => abrirAnexoFinanceiro(context, ref, c, tipo),
                    aoAnexar: _ocupado ? null : (tipo) => _anexar(c, tipo),
                    aoRemoverAnexo: _ocupado ? null : (tipo) => _removerAnexo(c, tipo),
                    menu: _menuCobranca(c, contrato),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _menuCobranca(CobrancaEmpresa c, ContratoEmpresa? contrato) {
    return PopupMenuButton<String>(
      tooltip: 'Ações da cobrança',
      enabled: !_ocupado,
      color: Colors.white,
      icon: const Icon(Icons.more_vert, color: AppColors.greyMedium),
      onSelected: (v) {
        switch (v) {
          case 'pago':
            _marcarPago(c);
          case 'pendente':
            _mudarStatus(c, StatusCobranca.pendente);
          case 'cancelar':
            _mudarStatus(c, StatusCobranca.cancelado);
          case 'editar':
            _editarCobranca(c, contrato);
          case 'excluir':
            _excluir(c);
        }
      },
      itemBuilder: (_) => [
        if (c.status != StatusCobranca.pago)
          const PopupMenuItem(value: 'pago', child: ListTile(dense: true, leading: Icon(Icons.check_circle_outline), title: Text('Marcar como pago'))),
        if (c.status == StatusCobranca.pago || c.status == StatusCobranca.cancelado)
          const PopupMenuItem(value: 'pendente', child: ListTile(dense: true, leading: Icon(Icons.undo_rounded), title: Text('Voltar para pendente'))),
        if (c.status != StatusCobranca.cancelado)
          const PopupMenuItem(value: 'cancelar', child: ListTile(dense: true, leading: Icon(Icons.block_rounded), title: Text('Cancelar cobrança'))),
        const PopupMenuItem(value: 'editar', child: ListTile(dense: true, leading: Icon(Icons.edit_outlined), title: Text('Editar valor e datas'))),
        const PopupMenuItem(
          value: 'excluir',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.delete_outline, color: AppColors.error),
            title: Text('Excluir', style: TextStyle(color: AppColors.error)),
          ),
        ),
      ],
    );
  }
}

/// Abre o boleto ou a nota fiscal por link temporário (aba nova no
/// navegador; no celular, o app que abre PDF).
Future<void> abrirAnexoFinanceiro(BuildContext context, WidgetRef ref, CobrancaEmpresa c, TipoAnexo tipo) async {
  final caminho = tipo == TipoAnexo.boleto ? c.boletoPath : c.notaFiscalPath;
  if (caminho == null) return;
  try {
    final link = await ref.read(financeiroRepositoryProvider).linkTemporario(caminho);
    final abriu = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    if (!abriu && context.mounted) {
      DiaviconAlerts.show(context, 'Não foi possível abrir', 'Tente de novo em instantes.', isErro: true);
    }
  } catch (e) {
    if (context.mounted) DiaviconAlerts.show(context, 'Não foi possível abrir', mensagemErroFinanceiro(e), isErro: true);
  }
}

// ---------------------------------------------------------------------------
// Diálogo: contrato
// ---------------------------------------------------------------------------
class _DadosContrato {
  final String planoId;
  final double valor;
  final int diaVencimento;
  final DateTime inicio;
  final DateTime? fim;
  final String especificidades;

  const _DadosContrato({
    required this.planoId,
    required this.valor,
    required this.diaVencimento,
    required this.inicio,
    this.fim,
    required this.especificidades,
  });
}

class _DialogoContrato extends ConsumerStatefulWidget {
  final ContratoEmpresa? atual;
  final String empresaNome;

  const _DialogoContrato({required this.atual, required this.empresaNome});

  @override
  ConsumerState<_DialogoContrato> createState() => _DialogoContratoState();
}

class _DialogoContratoState extends ConsumerState<_DialogoContrato> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _valor;
  late final TextEditingController _especificidades;
  String? _planoId;
  late int _dia;
  late DateTime _inicio;
  DateTime? _fim;

  @override
  void initState() {
    super.initState();
    final a = widget.atual;
    _planoId = a?.planoId;
    _valor = TextEditingController(text: a == null ? '' : formatarReais(a.valorMensal).replaceFirst('R\$ ', ''));
    _especificidades = TextEditingController(text: a?.especificidades ?? '');
    _dia = a?.diaVencimento ?? 10;
    final hoje = DateTime.now();
    _inicio = a?.inicio ?? DateTime(hoje.year, hoje.month, 1);
    _fim = a?.fim;
  }

  @override
  void dispose() {
    _valor.dispose();
    _especificidades.dispose();
    super.dispose();
  }

  Future<void> _escolherData({required bool inicio}) async {
    final d = await showDatePicker(
      context: context,
      helpText: inicio ? 'Início do contrato' : 'Fim do contrato',
      cancelText: 'Cancelar',
      confirmText: 'OK',
      initialDate: inicio ? _inicio : (_fim ?? DateTime(_inicio.year + 1, _inicio.month, _inicio.day)),
      firstDate: inicio ? DateTime(2020) : _inicio,
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      if (inicio) {
        _inicio = d;
        if (_fim != null && _fim!.isBefore(d)) _fim = null;
      } else {
        _fim = d;
      }
    });
  }

  void _salvar(List<PlanosModel> planos) {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _DadosContrato(
        planoId: _planoId!,
        valor: lerValorReais(_valor.text)!,
        diaVencimento: _dia,
        inicio: _inicio,
        fim: _fim,
        especificidades: _especificidades.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final planosAsync = ref.watch(planosListProvider);
    final planos = planosAsync.value ?? const <PlanosModel>[];

    return DialogoFinanceiro(
      titulo: widget.atual == null ? 'Novo contrato' : 'Editar contrato',
      subtitulo: widget.empresaNome,
      acoes: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        BotaoFinanceiro(icone: Icons.check, texto: 'Salvar contrato', onPressed: planos.isEmpty ? null : () => _salvar(planos)),
      ],
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RotuloFinanceiro('Plano', obrigatorio: true),
            DropdownButtonFormField<String>(
              initialValue: planos.any((p) => p.id == _planoId) ? _planoId : null,
              isExpanded: true,
              dropdownColor: Colors.white,
              decoration: decoracaoFinanceiro(planosAsync.isLoading ? 'Carregando planos…' : 'Escolha o plano'),
              items: [
                for (final p in planos)
                  DropdownMenuItem(value: p.id, child: Text('${p.nome} · ${formatarReais(p.valor)}/mês', overflow: TextOverflow.ellipsis)),
              ],
              validator: (v) => v == null ? 'Escolha o plano.' : null,
              onChanged: (v) {
                setState(() => _planoId = v);
                // Sugere o preço de tabela; o valor negociado pode ser outro.
                final plano = planos.where((p) => p.id == v).firstOrNull;
                if (plano != null && _valor.text.trim().isEmpty) {
                  _valor.text = formatarReais(plano.valor).replaceFirst('R\$ ', '');
                }
              },
            ),
            const SizedBox(height: 6),
            const Text(
              'Ao salvar, a empresa passa para este plano (limites e módulos).',
              style: TextStyle(fontSize: 12, color: AppColors.greyMedium),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const RotuloFinanceiro('Valor mensal (R\$)', obrigatorio: true),
                      TextFormField(
                        controller: _valor,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: decoracaoFinanceiro('0,00'),
                        validator: (v) {
                          final n = lerValorReais(v ?? '');
                          if (n == null) return 'Informe o valor.';
                          if (n < 0) return 'Valor inválido.';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const RotuloFinanceiro('Dia do vencimento', obrigatorio: true),
                      DropdownButtonFormField<int>(
                        initialValue: _dia,
                        dropdownColor: Colors.white,
                        menuMaxHeight: 320,
                        decoration: decoracaoFinanceiro(''),
                        items: [for (var d = 1; d <= 28; d++) DropdownMenuItem(value: d, child: Text('Dia $d'))],
                        onChanged: (v) => setState(() => _dia = v ?? _dia),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const RotuloFinanceiro('Início', obrigatorio: true),
                      CampoDataFinanceiro(valor: _inicio, dica: 'dd/mm/aaaa', aoTocar: () => _escolherData(inicio: true)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const RotuloFinanceiro('Fim (opcional)'),
                      CampoDataFinanceiro(
                        valor: _fim,
                        dica: 'Sem data de fim',
                        aoTocar: () => _escolherData(inicio: false),
                        aoLimpar: _fim == null ? null : () => setState(() => _fim = null),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const RotuloFinanceiro('Especificidades'),
            TextFormField(
              controller: _especificidades,
              minLines: 3,
              maxLines: 6,
              decoration: decoracaoFinanceiro('Ex.: desconto de 20% nos 3 primeiros meses, 5 usuários extras, suporte dedicado…'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Diálogo: cobrança (avulsa ou edição)
// ---------------------------------------------------------------------------
class _DadosCobranca {
  final DateTime competencia;
  final String descricao;
  final double valor;
  final DateTime vencimento;
  final String observacao;

  const _DadosCobranca({
    required this.competencia,
    required this.descricao,
    required this.valor,
    required this.vencimento,
    required this.observacao,
  });
}

class _DialogoCobranca extends StatefulWidget {
  final CobrancaEmpresa? atual;
  final double? valorSugerido;
  final int? diaSugerido;

  const _DialogoCobranca({required this.atual, this.valorSugerido, this.diaSugerido});

  @override
  State<_DialogoCobranca> createState() => _DialogoCobrancaState();
}

class _DialogoCobrancaState extends State<_DialogoCobranca> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _descricao;
  late final TextEditingController _valor;
  late final TextEditingController _observacao;
  late DateTime _competencia;
  late DateTime _vencimento;

  @override
  void initState() {
    super.initState();
    final a = widget.atual;
    final hoje = DateTime.now();
    _descricao = TextEditingController(text: a?.descricao ?? '');
    final valor = a?.valor ?? widget.valorSugerido;
    _valor = TextEditingController(text: valor == null ? '' : formatarReais(valor).replaceFirst('R\$ ', ''));
    _observacao = TextEditingController(text: a?.observacao ?? '');
    _competencia = a?.competencia ?? DateTime(hoje.year, hoje.month);
    _vencimento = a?.vencimento ?? DateTime(hoje.year, hoje.month, widget.diaSugerido ?? 10);
  }

  @override
  void dispose() {
    _descricao.dispose();
    _valor.dispose();
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _escolher({required bool competencia}) async {
    final d = await showDatePicker(
      context: context,
      helpText: competencia ? 'Mês de referência (qualquer dia do mês)' : 'Vencimento',
      cancelText: 'Cancelar',
      confirmText: 'OK',
      initialDate: competencia ? _competencia : _vencimento,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() => competencia ? _competencia = DateTime(d.year, d.month) : _vencimento = d);
  }

  @override
  Widget build(BuildContext context) {
    return DialogoFinanceiro(
      titulo: widget.atual == null ? 'Cobrança avulsa' : 'Editar cobrança',
      subtitulo: widget.atual == null ? 'Para serviços extras, ajustes ou meses fora do contrato.' : null,
      acoes: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        BotaoFinanceiro(
          icone: Icons.check,
          texto: 'Salvar',
          onPressed: () {
            if (!(_form.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              _DadosCobranca(
                competencia: _competencia,
                descricao: _descricao.text,
                valor: lerValorReais(_valor.text)!,
                vencimento: _vencimento,
                observacao: _observacao.text,
              ),
            );
          },
        ),
      ],
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RotuloFinanceiro('Descrição'),
            TextFormField(controller: _descricao, decoration: decoracaoFinanceiro('Ex.: Mensalidade, Treinamento, Usuários extras')),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const RotuloFinanceiro('Mês de referência', obrigatorio: true),
                      CampoDataFinanceiro(
                        valor: _competencia,
                        dica: '',
                        texto: formatarCompetencia(_competencia),
                        aoTocar: () => _escolher(competencia: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const RotuloFinanceiro('Vencimento', obrigatorio: true),
                      CampoDataFinanceiro(valor: _vencimento, dica: '', aoTocar: () => _escolher(competencia: false)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const RotuloFinanceiro('Valor (R\$)', obrigatorio: true),
            TextFormField(
              controller: _valor,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: decoracaoFinanceiro('0,00'),
              validator: (v) {
                final n = lerValorReais(v ?? '');
                if (n == null) return 'Informe o valor.';
                if (n < 0) return 'Valor inválido.';
                return null;
              },
            ),
            const SizedBox(height: 14),
            const RotuloFinanceiro('Observação'),
            TextFormField(controller: _observacao, minLines: 2, maxLines: 4, decoration: decoracaoFinanceiro('Opcional')),
          ],
        ),
      ),
    );
  }
}
