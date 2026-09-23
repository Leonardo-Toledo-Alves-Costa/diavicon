import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_dropdown.dart';
import '../../../core/utils/diavicon_modal.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/campos_bi_catalogo.dart';
import '../models/dashboard_card_model.dart';
import '../models/dashboard_modelo_model.dart';
import '../models/monte_carlo_bi_model.dart';
import '../models/serie_bi_model.dart';
import '../models/variavel_bi_model.dart';
import '../repositories/variavel_bi_repository.dart';
import '../utils/classificadores_bi.dart';
import 'editor_variavel_bi.dart';
import 'editor_config_monte_carlo.dart';
import 'editores_series_bi.dart';
import '../utils/cores_bi.dart';

enum _CategoriaConstrutor { graficoEnsaio, galeria, texto, metricaCalculada, monteCarlo, multiEnsaio, graficoPersonalizado, badge, tabela }

/// Um campo conta como medida numérica (aceita Média/Desvio/Coef. de
/// variação) sempre que não for categórico/galeria/planta — brutos e
/// estatísticas recebem o mesmo seletor.
bool _eNumerico(CampoBiCatalogo campo) => campo.categoria == CategoriaDadoBi.estatistica || campo.categoria == CategoriaDadoBi.bruto;

/// Wizard Categoria → Ensaio → (Variável + Tipo de gráfico + Agrupamento,
/// juntos numa única tela) → Aparência → Adicionar/Salvar. Passe
/// [cardExistente] pra reabrir editando um card já criado (usado pelo menu
/// "⋮ Editar dados" do dashboard) — todo campo já vem preenchido e o
/// agrupamento pode ser trocado a qualquer momento, não só na criação.
/// Devolve um `DashboardCardModel` (preservando id/posição/tamanho quando
/// editando) ou `null` se cancelado.
Future<DashboardCardModel?> abrirConstrutorEixosModal(
  BuildContext context, {
  required NivelAplicacaoBi nivel,
  DashboardCardModel? cardExistente,
}) {
  return showDiaviconModal<DashboardCardModel>(
    context: context,
    title: cardExistente == null ? 'Adicionar card' : 'Editar dados do card',
    isScrollable: false,
    body: _ConstrutorEixosBody(nivel: nivel, cardExistente: cardExistente),
  );
}

class _ConstrutorEixosBody extends ConsumerStatefulWidget {
  final NivelAplicacaoBi nivel;
  final DashboardCardModel? cardExistente;
  const _ConstrutorEixosBody({required this.nivel, this.cardExistente});

  @override
  ConsumerState<_ConstrutorEixosBody> createState() => _ConstrutorEixosBodyState();
}

class _ConstrutorEixosBodyState extends ConsumerState<_ConstrutorEixosBody> {
  int _passo = 0;
  _CategoriaConstrutor? _categoria;
  FonteBiCatalogo? _fonte;
  TipoGraficoBi? _tipoGrafico;
  CampoBiCatalogo? _campoX;
  EstatisticaBi? _estatisticaX;
  CampoBiCatalogo? _campoY;
  EstatisticaBi? _estatisticaY;
  String? _agruparPor;
  int _corIndex = 0;
  String _textoConteudo = '';

  // ---- equacao (metrica calculada / multi-ensaio) ----
  VariavelBiModel? _variavel;

  /// Onde a equacao criada aqui vai parar. Salvar nos padroes deixa ela
  /// reutilizavel e editavel em Empresa > Padroes; "so neste card" e pratico
  /// pra experimentar, mas some da biblioteca — por isso o card sinaliza que
  /// a equacao e local.
  bool _salvarNaEmpresa = true;
  bool _salvando = false;

  bool get _ehEquacao =>
      _categoria == _CategoriaConstrutor.metricaCalculada || _categoria == _CategoriaConstrutor.multiEnsaio;

  // ---- badge / grafico personalizado / tabela ----
  String? _classificacaoId;
  List<SerieBi> _series = [];
  List<ColunaTabelaBi> _colunas = [];

  // ---- monte carlo ----
  ConfigMonteCarloBi _mc = const ConfigMonteCarloBi();

  /// Categorias montadas num passo so (sem ensaio/tipo/aparencia).
  bool get _passoUnico => const {
        _CategoriaConstrutor.galeria,
        _CategoriaConstrutor.texto,
        _CategoriaConstrutor.graficoPersonalizado,
        _CategoriaConstrutor.badge,
        _CategoriaConstrutor.tabela,
        _CategoriaConstrutor.monteCarlo,
      }.contains(_categoria);

  static const _cores = paletaBiInt;

  @override
  void initState() {
    super.initState();
    final existente = widget.cardExistente;
    if (existente == null) return;
    switch (existente.tipo) {
      case TipoCardBi.galeria:
        _categoria = _CategoriaConstrutor.galeria;
        _fonte = existente.galeriaFonteChave != null ? buscarFonteBi(existente.galeriaFonteChave!) : null;
        break;
      case TipoCardBi.texto:
        _categoria = _CategoriaConstrutor.texto;
        _textoConteudo = existente.textoConteudo ?? '';
        break;
      case TipoCardBi.badge:
        _categoria = _CategoriaConstrutor.badge;
        _classificacaoId = existente.classificacaoId;
        break;
      case TipoCardBi.tabela:
        _categoria = _CategoriaConstrutor.tabela;
        _colunas = List.of(existente.colunas);
        _agruparPor = existente.agruparPor ?? 'elemento';
        break;
      case TipoCardBi.monteCarlo:
        _categoria = _CategoriaConstrutor.monteCarlo;
        _mc = existente.monteCarlo ?? const ConfigMonteCarloBi();
        break;
      case TipoCardBi.grafico:
      case TipoCardBi.espaco:
        if (existente.tipoGrafico == TipoGraficoBi.personalizado) {
          _categoria = _CategoriaConstrutor.graficoPersonalizado;
          _series = List.of(existente.series);
          _agruparPor = existente.agruparPor ?? 'elemento';
          return;
        }
        if (existente.usaVariavel) {
          // A inline volta direto; a salva e recarregada pelo passo da
          // equacao, que ja lista as variaveis da empresa.
          if (existente.variavelInline != null) {
            _variavel = VariavelBiModel.fromMap(existente.variavelInline!);
            _salvarNaEmpresa = false;
          }
          _categoria = (_variavel?.ehMultiEnsaio ?? true)
              ? _CategoriaConstrutor.multiEnsaio
              : _CategoriaConstrutor.metricaCalculada;
          _tipoGrafico = existente.tipoGrafico;
          _agruparPor = existente.agruparPor;
          final corIdxVar = _cores.indexOf(existente.corBase ?? _cores[0]);
          _corIndex = corIdxVar >= 0 ? corIdxVar : 0;
          return;
        }
        _categoria = _CategoriaConstrutor.graficoEnsaio;
        _fonte = existente.fonteChave != null ? buscarFonteBi(existente.fonteChave!) : null;
        _tipoGrafico = existente.tipoGrafico;
        _campoX = existente.fonteChave != null && existente.campoX != null ? buscarCampoBi(existente.fonteChave!, existente.campoX!) : null;
        _estatisticaX = existente.estatisticaX != null ? EstatisticaBi.values.firstWhere((e) => e.name == existente.estatisticaX, orElse: () => EstatisticaBi.media) : null;
        _campoY = existente.fonteChave != null && existente.campoY != null ? buscarCampoBi(existente.fonteChave!, existente.campoY!) : null;
        _estatisticaY = existente.estatisticaY != null ? EstatisticaBi.values.firstWhere((e) => e.name == existente.estatisticaY, orElse: () => EstatisticaBi.media) : null;
        _agruparPor = existente.agruparPor;
        break;
    }
    final corIdx = _cores.indexOf(existente.corBase ?? _cores[0]);
    _corIndex = corIdx >= 0 ? corIdx : 0;
  }

  List<String> get _opcoesAgrupar {
    final opcoes = List<String>.from(_campoX?.opcoesAgrupamento ?? const ['local', 'tipoElemento', 'elemento', 'estrutura']);
    return _filtrarPorNivel(opcoes);
  }

  /// "Elemento" não faz sentido no dashboard de um elemento só; "Estrutura"
  /// só varia no de projeto (os demais níveis têm uma estrutura só).
  List<String> _filtrarPorNivel(List<String> opcoes) {
    if (widget.nivel == NivelAplicacaoBi.elementoNoProjeto) opcoes.remove('elemento');
    if (widget.nivel != NivelAplicacaoBi.projeto) opcoes.remove('estrutura');
    return opcoes;
  }

  String _rotuloAgrupar(String v) => switch (v) {
        'local' => 'Local',
        'tipoElemento' => 'Tipo de elemento',
        'elemento' => 'Elemento',
        'data' => 'Data',
        'estrutura' => 'Estrutura',
        _ => v,
      };

  bool get _exigeAgrupamento =>
      _tipoGrafico != null && _tipoGrafico != TipoGraficoBi.gauss && _tipoGrafico != TipoGraficoBi.linhas && _opcoesAgrupar.isNotEmpty;

  bool get _exigeSegundaSerie => _tipoGrafico == TipoGraficoBi.barraLinha2Eixos;
  bool get _exigeCategoriaSegmentacao => _tipoGrafico == TipoGraficoBi.barraSegmentada;

  /// Candidatos pro segundo campo — mesma fonte, sem repetir o campo X.
  /// Segmentado exige um campo categórico (é ele que vira a legenda/cores);
  /// 2 eixos aceita qualquer medida numérica pra virar a linha.
  List<CampoBiCatalogo> get _opcoesCampoY {
    final campos = (_fonte?.campos ?? []).where((c) => c.categoria != CategoriaDadoBi.galeria && c.categoria != CategoriaDadoBi.planta && c.chave != _campoX?.chave);
    if (_exigeCategoriaSegmentacao) return campos.where((c) => c.categoria == CategoriaDadoBi.categorico).toList();
    if (_exigeSegundaSerie) return campos.where(_eNumerico).toList();
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.66,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: SingleChildScrollView(child: _buildPasso())),
          const SizedBox(height: 12),
          _buildBarraNavegacao(),
        ],
      ),
    );
  }

  Widget _buildPasso() {
    switch (_passo) {
      case 0:
        return _passoCategoria();
      case 1:
        if (_categoria == _CategoriaConstrutor.galeria) return _passoGaleriaFonte();
        if (_categoria == _CategoriaConstrutor.texto) return _passoTexto();
        if (_ehEquacao) return _passoEquacao();
        if (_categoria == _CategoriaConstrutor.badge) return _passoBadge();
        if (_categoria == _CategoriaConstrutor.graficoPersonalizado) return _passoSeries();
        if (_categoria == _CategoriaConstrutor.tabela) return _passoColunas();
        if (_categoria == _CategoriaConstrutor.monteCarlo) return _passoMonteCarlo();
        return _passoEnsaio();
      case 2:
        if (_ehEquacao) return _passoConfiguracaoEquacao();
        return _passoConfiguracao();
      default:
        return _passoAparencia();
    }
  }

  int get _ultimoPasso {
    if (_passoUnico) return 1;
    return 3;
  }

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
      );

  Widget _passoCategoria() {
    Widget chip(String label, _CategoriaConstrutor? cat, {bool habilitado = true}) {
      final selecionado = _categoria == cat;
      return InkWell(
        onTap: habilitado
            ? () => setState(() {
                  _categoria = cat;
                  _fonte = null;
                  _tipoGrafico = null;
                  _campoX = null;
                  _variavel = null;
                })
            : null,
        borderRadius: BorderRadius.circular(10),
        child: Opacity(
          opacity: habilitado ? 1 : 0.4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: selecionado ? AppColors.primary.withValues(alpha: 0.12) : Colors.white,
              border: Border.all(color: selecionado ? AppColors.primary : AppColors.inputBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(child: Text(label, style: GoogleFonts.lato(fontSize: 14, color: AppColors.textDark))),
                if (!habilitado) Text('Em breve', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                if (selecionado) const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titulo('O que você quer adicionar?'),
        chip('Gráfico de um ensaio', _CategoriaConstrutor.graficoEnsaio),
        const SizedBox(height: 8),
        chip('Galeria de fotos', _CategoriaConstrutor.galeria),
        const SizedBox(height: 8),
        chip('Texto', _CategoriaConstrutor.texto),
        const SizedBox(height: 8),
        chip('Métrica calculada', _CategoriaConstrutor.metricaCalculada),
        const SizedBox(height: 8),
        chip('Simulação de Monte Carlo', _CategoriaConstrutor.monteCarlo),
        const SizedBox(height: 8),
        chip('Multi-ensaio (correlação)', _CategoriaConstrutor.multiEnsaio),
        const SizedBox(height: 8),
        chip('Gráfico personalizado (várias séries)', _CategoriaConstrutor.graficoPersonalizado),
        const SizedBox(height: 8),
        chip('Badge de classificação', _CategoriaConstrutor.badge),
        const SizedBox(height: 8),
        chip('Tabela', _CategoriaConstrutor.tabela),
      ],
    );
  }

  Widget _passoEnsaio() {
    final fontes = catalogoFontesBi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titulo('Qual ensaio?'),
        CustomDropdown<String>(
          label: '',
          hint: 'Selecione o ensaio',
          value: _fonte?.chave,
          items: fontes.map((f) => DropdownMenuItem(value: f.chave, child: Text(f.rotulo + (f.implementado ? '' : ' (em breve)')))).toList(),
          onChanged: (v) => setState(() {
            _fonte = buscarFonteBi(v!);
            _campoX = null;
            _campoY = null;
            _estatisticaY = null;
            _tipoGrafico = null;
            _agruparPor = null;
          }),
        ),
        if (_fonte != null && !_fonte!.implementado)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Fonte ainda não conectada — o card ficará vazio até essa integração ser feita.', style: GoogleFonts.lato(fontSize: 12, color: Colors.orange.shade800)),
          ),
      ],
    );
  }

  /// Uma única tela com tudo que define o gráfico: qual variável do ensaio
  /// escolhido, qual tipo de gráfico exibi-la, e como agrupar — igual ao
  /// fluxo pedido: escolhe o ensaio, e a tela já mostra as variáveis e os
  /// tipos de gráfico disponíveis junto com o agrupamento.
  Widget _passoConfiguracao() {
    final campos = (_fonte?.campos ?? []).where((c) => c.categoria != CategoriaDadoBi.galeria && c.categoria != CategoriaDadoBi.planta).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titulo('Variável'),
        ...campos.map((c) => RadioListTile<String>(
              value: c.chave,
              groupValue: _campoX?.chave,
              contentPadding: EdgeInsets.zero,
              title: Text(c.rotulo, style: GoogleFonts.lato(fontSize: 14)),
              subtitle: c.unidade != null ? Text(c.unidade!, style: GoogleFonts.lato(fontSize: 11, color: Colors.grey)) : null,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() {
                _campoX = c;
                _estatisticaX = _eNumerico(c) ? (_estatisticaX ?? EstatisticaBi.media) : null;
              }),
            )),
        if (_campoX != null && _eNumerico(_campoX!)) ...[
          const SizedBox(height: 8),
          Text('Estatística', style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: EstatisticaBi.values.map((e) {
              final sel = _estatisticaX == e;
              return ChoiceChip(
                label: Text(e.rotulo, style: GoogleFonts.lato(fontSize: 12)),
                selected: sel,
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                onSelected: (_) => setState(() => _estatisticaX = e),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 24),
        _titulo('Tipo de gráfico'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TipoGraficoBi.values.where((t) => t != TipoGraficoBi.personalizado).map((t) {
            final sel = _tipoGrafico == t;
            return ChoiceChip(
              label: Text(t.rotulo, style: GoogleFonts.lato(fontSize: 12)),
              selected: sel,
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              onSelected: (_) => setState(() {
                _tipoGrafico = t;
                _campoY = null;
                _estatisticaY = null;
              }),
            );
          }).toList(),
        ),
        if (_exigeAgrupamento) ...[
          const SizedBox(height: 24),
          _titulo('Agrupar por (eixo X)'),
          Text('Pode ser trocado depois a qualquer momento, em "Editar dados".', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          ..._opcoesAgrupar.map((op) => RadioListTile<String>(
                value: op,
                groupValue: _agruparPor,
                contentPadding: EdgeInsets.zero,
                title: Text(_rotuloAgrupar(op), style: GoogleFonts.lato(fontSize: 14)),
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _agruparPor = v),
              )),
        ],
        if (_exigeSegundaSerie || _exigeCategoriaSegmentacao) ...[
          const SizedBox(height: 24),
          _titulo(_exigeSegundaSerie ? 'Segunda série (linha)' : 'Categoria pra segmentar'),
          if (_opcoesCampoY.isEmpty)
            Text('Esse ensaio não tem outro campo ${_exigeCategoriaSegmentacao ? 'categórico' : 'numérico'} disponível.', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600))
          else
            ..._opcoesCampoY.map((c) => RadioListTile<String>(
                  value: c.chave,
                  groupValue: _campoY?.chave,
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.rotulo, style: GoogleFonts.lato(fontSize: 14)),
                  subtitle: c.unidade != null ? Text(c.unidade!, style: GoogleFonts.lato(fontSize: 11, color: Colors.grey)) : null,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() {
                    _campoY = c;
                    _estatisticaY = _exigeSegundaSerie && _eNumerico(c) ? (_estatisticaY ?? EstatisticaBi.media) : null;
                  }),
                )),
          if (_exigeSegundaSerie && _campoY != null && _eNumerico(_campoY!)) ...[
            const SizedBox(height: 8),
            Text('Estatística da segunda série', style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: EstatisticaBi.values.map((e) {
                final sel = _estatisticaY == e;
                return ChoiceChip(
                  label: Text(e.rotulo, style: GoogleFonts.lato(fontSize: 12)),
                  selected: sel,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  onSelected: (_) => setState(() => _estatisticaY = e),
                );
              }).toList(),
            ),
          ],
        ],
      ],
    );
  }

  /// Escolhe a equacao: uma ja cadastrada nos padroes da empresa (ou padrao
  /// DIAVICON), ou uma nova criada na hora.
  Widget _passoEquacao() {
    final empresaId = ref.read(currentUserProvider)?.empresaId;
    if (empresaId == null) {
      return Text('Empresa nao identificada.', style: GoogleFonts.lato(fontSize: 13));
    }

    final soMultiEnsaio = _categoria == _CategoriaConstrutor.multiEnsaio;
    final variaveisAsync = ref.watch(variaveisBiProvider(empresaId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titulo(soMultiEnsaio ? 'Qual correlacao?' : 'Qual metrica?'),
        Text(
          soMultiEnsaio
              ? 'Combina variaveis de ensaios diferentes. O cruzamento e feito por elemento estrutural: '
                  'cada ensaio e resumido a um valor no elemento antes da formula rodar.'
              : 'Calcula um valor a partir das variaveis de um unico ensaio.',
          style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
        ),
        const SizedBox(height: 12),
        variaveisAsync.when(
          loading: () => const Center(
              child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.primary))),
          error: (e, _) =>
              Text('Nao foi possivel carregar as equacoes: $e', style: GoogleFonts.lato(fontSize: 12, color: Colors.red)),
          data: (variaveis) {
            final elegiveis = variaveis.where((v) => v.ehMultiEnsaio == soMultiEnsaio).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (elegiveis.isEmpty)
                  Text(
                    soMultiEnsaio
                        ? 'Nenhuma equacao multi-ensaio cadastrada ainda.'
                        : 'Nenhuma metrica cadastrada ainda.',
                    style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ...elegiveis.map((v) => RadioListTile<String>(
                      value: v.id,
                      groupValue: _variavel?.id,
                      contentPadding: EdgeInsets.zero,
                      title: Text(v.unidade == null ? v.nome : '${v.nome} (${v.unidade})',
                          style: GoogleFonts.lato(fontSize: 14)),
                      subtitle: Text(v.expressao, style: GoogleFonts.robotoMono(fontSize: 11, color: Colors.grey)),
                      activeColor: AppColors.primary,
                      onChanged: (_) => setState(() => _variavel = v),
                    )),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _criarEquacao(empresaId),
                  icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                  label: const Text('Criar nova equacao', style: TextStyle(color: AppColors.primary)),
                ),
                if (_variavel != null && _variavel!.id.isEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Equacao nova: "${_variavel!.nome}"',
                            style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        RadioListTile<bool>(
                          value: true,
                          groupValue: _salvarNaEmpresa,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: AppColors.primary,
                          title: Text('Salvar nos padroes da empresa', style: GoogleFonts.lato(fontSize: 13)),
                          subtitle: Text('Fica reutilizavel em outros dashboards e editavel em Padroes.',
                              style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600)),
                          onChanged: (v) => setState(() => _salvarNaEmpresa = v ?? true),
                        ),
                        RadioListTile<bool>(
                          value: false,
                          groupValue: _salvarNaEmpresa,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: AppColors.primary,
                          title: Text('Usar so neste card', style: GoogleFonts.lato(fontSize: 13)),
                          subtitle: Text('Nao aparece na biblioteca da empresa - some junto com o card.',
                              style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600)),
                          onChanged: (v) => setState(() => _salvarNaEmpresa = v ?? true),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _criarEquacao(String empresaId) async {
    final criada = await abrirEditorVariavelBi(
      context,
      empresaId: empresaId,
      criadoPor: ref.read(currentUserProvider)?.id,
    );
    if (criada == null) return;
    setState(() {
      _variavel = criada;
      // Multi-ensaio e metrica sao a mesma entidade; a categoria so filtra a
      // lista. Se a equacao criada nao bate com a categoria escolhida, segue
      // a equacao - ela e quem manda.
      _categoria =
          criada.ehMultiEnsaio ? _CategoriaConstrutor.multiEnsaio : _CategoriaConstrutor.metricaCalculada;
    });
  }

  /// Grafico e agrupamento pra um card de equacao. Nao tem selecao de
  /// variavel: a propria equacao E a medida.
  Widget _passoConfiguracaoEquacao() {
    // Tipos que fazem sentido pra um valor continuo por elemento. Pizza e os
    // de duas series ficam de fora: exigem um campo categorico ou um segundo
    // campo do mesmo ensaio, que a equacao nao tem.
    const tipos = [TipoGraficoBi.barra, TipoGraficoBi.boxplot, TipoGraficoBi.gauss];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titulo('Tipo de grafico'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tipos.map((t) {
            final sel = _tipoGrafico == t;
            return ChoiceChip(
              label: Text(t.rotulo, style: GoogleFonts.lato(fontSize: 12)),
              selected: sel,
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              onSelected: (_) => setState(() => _tipoGrafico = t),
            );
          }).toList(),
        ),
        if (_exigeAgrupamento) ...[
          const SizedBox(height: 24),
          _titulo('Agrupar por (eixo X)'),
          ..._opcoesAgrupar.map((op) => RadioListTile<String>(
                value: op,
                groupValue: _agruparPor,
                contentPadding: EdgeInsets.zero,
                title: Text(_rotuloAgrupar(op), style: GoogleFonts.lato(fontSize: 14)),
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _agruparPor = v),
              )),
        ],
      ],
    );
  }

  // ── Badge ────────────────────────────────────────────────────────────────

  Widget _passoBadge() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titulo('Qual classificação?'),
        Text(
          'Cada elemento é classificado pela própria média. Com vários elementos o card mostra '
          'quantos caíram em cada classe; com um só, mostra o selo e o valor.',
          style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
        ),
        const SizedBox(height: 8),
        ...classificadoresBi.map((c) => RadioListTile<String>(
              value: c.id,
              groupValue: _classificacaoId,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primary,
              title: Text(c.rotulo, style: GoogleFonts.lato(fontSize: 14)),
              subtitle: Text(c.descricao, style: GoogleFonts.lato(fontSize: 11, color: Colors.grey)),
              onChanged: (v) => setState(() => _classificacaoId = v),
            )),
      ],
    );
  }

  // ── Eixo X / linhas (compartilhado por grafico personalizado e tabela) ─────

  Widget _seletorAgrupamento(String titulo) {
    // Grafico personalizado e tabela sempre agrupam; comeca em elemento.
    _agruparPor ??= 'elemento';
    final opcoes = _filtrarPorNivel(['elemento', 'local', 'tipoElemento', 'estrutura']);
    if (!opcoes.contains(_agruparPor)) _agruparPor = opcoes.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titulo(titulo),
        Wrap(
          spacing: 8,
          children: opcoes
              .map((o) => ChoiceChip(
                    label: Text(_rotuloAgrupar(o), style: GoogleFonts.lato(fontSize: 12)),
                    selected: _agruparPor == o,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    onSelected: (_) => setState(() => _agruparPor = o),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── Grafico personalizado ──────────────────────────────────────────────────

  Widget _passoSeries() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _seletorAgrupamento('Eixo X'),
        const SizedBox(height: 20),
        _titulo('Séries'),
        if (_series.isEmpty)
          Text('Adicione ao menos uma série.', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
        for (var i = 0; i < _series.length; i++)
          _itemLista(
            cor: _series[i].corCor,
            titulo: _series[i].nome.isEmpty ? _series[i].valor.rotuloPadrao() : _series[i].nome,
            subtitulo: '${_series[i].tipo.rotulo} · eixo ${_series[i].eixo}',
            onEditar: () async {
              final editada = await abrirEditorSerieBi(context, existente: _series[i]);
              if (editada != null) setState(() => _series[i] = editada);
            },
            onRemover: () => setState(() => _series.removeAt(i)),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () async {
            final nova = await abrirEditorSerieBi(context, indice: _series.length);
            if (nova != null) setState(() => _series.add(nova));
          },
          icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
          label: const Text('Nova série', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }

  // ── Tabela ───────────────────────────────────────────────────────────────

  Widget _passoColunas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _seletorAgrupamento('Uma linha por'),
        const SizedBox(height: 20),
        _titulo('Colunas'),
        if (_colunas.isEmpty)
          Text('Adicione ao menos uma coluna.', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey))
        else
          Text('Arraste para reordenar.', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600)),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: (de, para) => setState(() {
            final item = _colunas.removeAt(de);
            _colunas.insert(para > de ? para - 1 : para, item);
          }),
          children: [
            for (var i = 0; i < _colunas.length; i++)
              KeyedSubtree(
                key: ValueKey(_colunas[i].id),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.drag_indicator, color: Colors.grey),
                      ),
                    ),
                    Expanded(
                      child: _itemLista(
                        titulo: _colunas[i].titulo,
                        subtitulo: [
                          _colunas[i].valor.rotuloPadrao(),
                          if (_colunas[i].regras.isNotEmpty)
                            '${_colunas[i].regras.length} ${_colunas[i].regras.length == 1 ? 'regra' : 'regras'} de cor',
                        ].join(' · '),
                        onEditar: () async {
                          final editada = await abrirEditorColunaBi(context, existente: _colunas[i]);
                          if (editada != null) setState(() => _colunas[i] = editada);
                        },
                        onRemover: () => setState(() => _colunas.removeAt(i)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () async {
            final nova = await abrirEditorColunaBi(context);
            if (nova != null) setState(() => _colunas.add(nova));
          },
          icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
          label: const Text('Nova coluna', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }

  Widget _itemLista({
    Color? cor,
    required String titulo,
    required String subtitulo,
    required VoidCallback onEditar,
    required VoidCallback onRemover,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(border: Border.all(color: AppColors.inputBorder), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          if (cor != null) ...[
            Container(width: 12, height: 12, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                Text(subtitulo, style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEditar),
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: onRemover),
        ],
      ),
    );
  }

  // ── Monte Carlo ──────────────────────────────────────────────────────────

  /// Mesmo editor da biblioteca (Padrões > Dashboard > Modelos de
  /// simulação), com "partir de/salvar como modelo" habilitados.
  Widget _passoMonteCarlo() => EditorConfigMonteCarlo(
        config: _mc,
        comBiblioteca: true,
        onChanged: (c) => setState(() => _mc = c),
      );

  Widget _passoAparencia() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titulo('Cor do card'),
        Wrap(
          spacing: 10,
          children: List.generate(_cores.length, (i) {
            final sel = _corIndex == i;
            return InkWell(
              onTap: () => setState(() => _corIndex = i),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(_cores[i]),
                  shape: BoxShape.circle,
                  border: sel ? Border.all(color: AppColors.textDark, width: 2) : null,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _passoGaleriaFonte() {
    final fontesComGaleria = catalogoFontesBi.where((f) => f.campos.any((c) => c.categoria == CategoriaDadoBi.galeria)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titulo('Galeria de qual ensaio?'),
        CustomDropdown<String>(
          label: '',
          hint: 'Selecione o ensaio',
          value: _fonte?.chave,
          items: fontesComGaleria.map((f) => DropdownMenuItem(value: f.chave, child: Text(f.rotulo))).toList(),
          onChanged: (v) => setState(() => _fonte = buscarFonteBi(v!)),
        ),
      ],
    );
  }

  Widget _passoTexto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titulo('Texto do card'),
        TextFormField(
          initialValue: _textoConteudo,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(hintText: 'Escreva uma nota, observação ou título de seção...', border: OutlineInputBorder()),
          onChanged: (v) => _textoConteudo = v,
        ),
      ],
    );
  }

  bool get _podeAvancar {
    switch (_passo) {
      case 0:
        return _categoria != null;
      case 1:
        if (_categoria == _CategoriaConstrutor.galeria) return _fonte != null;
        if (_categoria == _CategoriaConstrutor.texto) return true;
        if (_ehEquacao) return _variavel != null;
        if (_categoria == _CategoriaConstrutor.badge) return _classificacaoId != null;
        if (_categoria == _CategoriaConstrutor.graficoPersonalizado) return _series.isNotEmpty && _agruparPor != null;
        if (_categoria == _CategoriaConstrutor.tabela) return _colunas.isNotEmpty && _agruparPor != null;
        if (_categoria == _CategoriaConstrutor.monteCarlo) {
          return switch (_mc.analise) {
            AnaliseMonteCarloBi.despassivacao => true,
            AnaliseMonteCarloBi.distribuicao => _mc.series.isNotEmpty,
            AnaliseMonteCarloBi.probabilidade =>
              _mc.operandoA != null && (_mc.operandoB?.trim().isNotEmpty ?? false),
          };
        }
        return _fonte != null;
      case 2:
        if (_ehEquacao) return _tipoGrafico != null && (!_exigeAgrupamento || _agruparPor != null);
        final campoOk = _campoX != null && (!_eNumerico(_campoX!) || _estatisticaX != null);
        final tipoOk = _tipoGrafico != null;
        final agrupamentoOk = !_exigeAgrupamento || _agruparPor != null;
        final segundoCampoOk = !(_exigeSegundaSerie || _exigeCategoriaSegmentacao) || _opcoesCampoY.isEmpty || (_campoY != null && (!_exigeSegundaSerie || !_eNumerico(_campoY!) || _estatisticaY != null));
        return campoOk && tipoOk && agrupamentoOk && segundoCampoOk;
      default:
        return true;
    }
  }

  Widget _buildBarraNavegacao() {
    final ultimo = _passo == _ultimoPasso;
    final editando = widget.cardExistente != null;
    return Row(
      children: [
        if (_passo > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _passo--),
              child: const Text('Voltar'),
            ),
          ),
        if (_passo > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: CustomButton(
            text: ultimo ? (editando ? 'Salvar' : 'Adicionar') : 'Próximo',
            onPressed: (_podeAvancar && !_salvando)
                ? () {
                    if (ultimo) {
                      _finalizar();
                    } else {
                      setState(() => _passo++);
                    }
                  }
                : null,
          ),
        ),
      ],
    );
  }

  /// Fecha o wizard. Quando a equacao e nova E o usuario pediu pra guardar
  /// nos padroes da empresa, ela e persistida ANTES de o card ser montado —
  /// so assim o card pode referencia-la por id em vez de carregar uma copia
  /// embutida. Se o salvamento falhar, o card ainda sai com a equacao
  /// embutida, pra nao perder o que o usuario acabou de montar.
  Future<void> _finalizar() async {
    final variavel = _variavel;
    if (_ehEquacao && variavel != null && variavel.id.isEmpty && _salvarNaEmpresa) {
      setState(() => _salvando = true);
      try {
        final id = await ref.read(variavelBiRepositoryProvider).criar(variavel);
        final empresaId = ref.read(currentUserProvider)?.empresaId;
        if (empresaId != null) ref.invalidate(variaveisBiProvider(empresaId));
        if (!mounted) return;
        setState(() {
          _variavel = VariavelBiModel(
            id: id,
            empresaId: variavel.empresaId,
            criadoPor: variavel.criadoPor,
            nome: variavel.nome,
            unidade: variavel.unidade,
            descricao: variavel.descricao,
            expressao: variavel.expressao,
            entradas: variavel.entradas,
            parametros: variavel.parametros,
            referencia: variavel.referencia,
            valorMin: variavel.valorMin,
            valorMax: variavel.valorMax,
            variavelOrigemId: variavel.variavelOrigemId,
          );
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A equacao nao pode ser salva nos padroes ($e). Ela ficara so neste card.'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _salvarNaEmpresa = false);
      } finally {
        if (mounted) setState(() => _salvando = false);
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(_montarCard());
  }

  DashboardCardModel _montarCard() {
    final existente = widget.cardExistente;
    final id = existente?.id ?? 'card_${DateTime.now().microsecondsSinceEpoch}';
    final gridX = existente?.gridX ?? 0;
    final gridY = existente?.gridY ?? 0;
    final largura = existente?.largura ?? 3;
    final altura = existente?.altura ?? 2;
    final visivel = existente?.visivel ?? true;

    if (_categoria == _CategoriaConstrutor.galeria) {
      return DashboardCardModel(id: id, tipo: TipoCardBi.galeria, gridX: gridX, gridY: gridY, largura: largura, altura: altura, visivel: visivel, galeriaFonteChave: _fonte?.chave);
    }
    if (_categoria == _CategoriaConstrutor.texto) {
      return DashboardCardModel(id: id, tipo: TipoCardBi.texto, gridX: gridX, gridY: gridY, largura: largura, altura: altura, visivel: visivel, textoConteudo: _textoConteudo);
    }
    if (_categoria == _CategoriaConstrutor.monteCarlo) {
      final nomes = _mc.series.map((x) => x.nome).toList();
      // A série exibida precisa existir: se foi removida, cai na última.
      final exibida = nomes.contains(_mc.serieExibida) ? _mc.serieExibida : (nomes.isEmpty ? null : nomes.last);
      return DashboardCardModel(
        id: id, tipo: TipoCardBi.monteCarlo, gridX: gridX, gridY: gridY, largura: largura, altura: altura, visivel: visivel,
        monteCarlo: ConfigMonteCarloBi(
          analise: _mc.analise,
          series: _mc.series,
          serieExibida: exibida,
          operandoA: _mc.operandoA,
          comparacao: _mc.comparacao,
          operandoB: _mc.operandoB,
        ),
      );
    }
    if (_categoria == _CategoriaConstrutor.badge) {
      return DashboardCardModel(id: id, tipo: TipoCardBi.badge, gridX: gridX, gridY: gridY, largura: largura, altura: altura, visivel: visivel, classificacaoId: _classificacaoId);
    }
    if (_categoria == _CategoriaConstrutor.tabela) {
      return DashboardCardModel(id: id, tipo: TipoCardBi.tabela, gridX: gridX, gridY: gridY, largura: largura, altura: altura, visivel: visivel, colunas: _colunas, agruparPor: _agruparPor);
    }
    if (_categoria == _CategoriaConstrutor.graficoPersonalizado) {
      return DashboardCardModel(
        id: id, tipo: TipoCardBi.grafico, gridX: gridX, gridY: gridY, largura: largura, altura: altura, visivel: visivel,
        tipoGrafico: TipoGraficoBi.personalizado, series: _series, agruparPor: _agruparPor,
      );
    }
    if (_ehEquacao && _variavel != null) {
      final variavel = _variavel!;
      // Equacao salva nos padroes vira referencia por id (edita-la em
      // Padroes atualiza todos os cards). Equacao local viaja dentro do
      // proprio card.
      final salva = variavel.id.isNotEmpty;
      return DashboardCardModel(
        id: id,
        tipo: TipoCardBi.grafico,
        gridX: gridX,
        gridY: gridY,
        largura: largura,
        altura: altura,
        visivel: visivel,
        tipoGrafico: _tipoGrafico,
        agruparPor: _exigeAgrupamento ? _agruparPor : null,
        corBase: _cores[_corIndex],
        variavelId: salva ? variavel.id : null,
        variavelInline: salva ? null : variavel.toMap(),
      );
    }
    return DashboardCardModel(
      id: id,
      tipo: TipoCardBi.grafico,
      gridX: gridX,
      gridY: gridY,
      largura: largura,
      altura: altura,
      visivel: visivel,
      tipoGrafico: _tipoGrafico,
      fonteChave: _fonte?.chave,
      campoX: _campoX?.chave,
      estatisticaX: _estatisticaX?.name,
      campoY: (_exigeSegundaSerie || _exigeCategoriaSegmentacao) ? _campoY?.chave : null,
      estatisticaY: _exigeSegundaSerie ? _estatisticaY?.name : null,
      agruparPor: _exigeAgrupamento ? _agruparPor : null,
      corBase: _cores[_corIndex],
    );
  }
}
