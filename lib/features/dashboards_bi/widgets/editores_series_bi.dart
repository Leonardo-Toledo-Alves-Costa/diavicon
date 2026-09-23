import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/diavicon_modal.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_dropdown.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/campos_bi_catalogo.dart';
import '../models/monte_carlo_bi_model.dart';
import '../models/serie_bi_model.dart';
import '../models/variavel_bi_model.dart';
import '../repositories/variavel_bi_repository.dart';
import '../utils/segmentacao_bi.dart';
import '../utils/variavel_bi_avaliador.dart';
import 'editor_variavel_bi.dart';
import '../utils/cores_bi.dart';

/// Cores oferecidas para séries — as mesmas do construtor de cards.
const coresSerieBi = paletaBiInt;

/// Cores das regras condicionais, da mais grave para a mais branda.
const coresRegraBi = [0xFFD32F2F, 0xFFF57C00, 0xFFF9A825, 0xFF388E3C, 0xFF1976D2];

bool _numerico(CampoBiCatalogo c) => c.categoria == CategoriaDadoBi.estatistica || c.categoria == CategoriaDadoBi.bruto;

// ── Seletor de valor ───────────────────────────────────────────────────────

/// Escolhe de onde vem um valor: variável de um ensaio (+ estatística) ou
/// uma equação dos padrões da empresa (ex.: SonReb). Usado por série de
/// gráfico e coluna de tabela.
class SeletorReferenciaValorBi extends ConsumerStatefulWidget {
  const SeletorReferenciaValorBi({super.key, required this.valor, required this.onChanged, this.mostrarEstatistica = true});

  final ReferenciaValorBi valor;
  final ValueChanged<ReferenciaValorBi> onChanged;

  /// False no Monte Carlo: lá a média e o desvio saem da população do
  /// contexto, então escolher "média" ou "CV" aqui não teria efeito.
  final bool mostrarEstatistica;

  @override
  ConsumerState<SeletorReferenciaValorBi> createState() => _SeletorReferenciaValorBiState();
}

class _SeletorReferenciaValorBiState extends ConsumerState<SeletorReferenciaValorBi> {
  late bool _equacao = widget.valor.ehVariavel;

  @override
  Widget build(BuildContext context) {
    final v = widget.valor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Variável de ensaio'), icon: Icon(Icons.science_outlined, size: 16)),
            ButtonSegment(value: true, label: Text('Equação'), icon: Icon(Icons.functions, size: 16)),
          ],
          selected: {_equacao},
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            setState(() => _equacao = s.first);
            widget.onChanged(const ReferenciaValorBi());
          },
        ),
        const SizedBox(height: 12),
        if (_equacao) _seletorEquacao(v) else ..._seletorCampo(v),
      ],
    );
  }

  List<Widget> _seletorCampo(ReferenciaValorBi v) {
    final fontes = catalogoFontesBi.where((f) => f.implementado && f.campos.any(_numerico)).toList();
    final fonte = v.fonte == null ? null : fontes.where((f) => f.chave == v.fonte).firstOrNull;
    final campos = fonte?.campos.where(_numerico).toList() ?? const <CampoBiCatalogo>[];
    final campo = v.campo == null ? null : campos.where((c) => c.chave == v.campo).firstOrNull;

    return [
      CustomDropdown<String>(
        label: 'Ensaio',
        value: fonte?.chave,
        items: fontes.map((f) => DropdownMenuItem(value: f.chave, child: Text(f.rotulo, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (c) => widget.onChanged(ReferenciaValorBi(fonte: c)),
      ),
      if (fonte != null) ...[
        const SizedBox(height: 10),
        CustomDropdown<String>(
          label: 'Variável',
          value: campo?.chave,
          items: campos
              .map((c) => DropdownMenuItem(
                  value: c.chave,
                  child: Text(c.unidade == null ? c.rotulo : '${c.rotulo} (${c.unidade})', overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (c) {
            final escolhido = campos.where((x) => x.chave == c).firstOrNull;
            widget.onChanged(ReferenciaValorBi(
              fonte: fonte.chave,
              campo: c,
              // Campos "estatística" sempre precisam de uma; começa na média.
              estatistica: widget.mostrarEstatistica && escolhido?.categoria == CategoriaDadoBi.estatistica ? EstatisticaBi.media.name : null,
            ));
          },
        ),
      ],
      if (widget.mostrarEstatistica && campo?.categoria == CategoriaDadoBi.estatistica) ...[
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: EstatisticaBi.values.map((e) {
            return ChoiceChip(
              label: Text(e.rotulo, style: GoogleFonts.lato(fontSize: 12)),
              selected: v.estatistica == e.name,
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              onSelected: (_) => widget.onChanged(ReferenciaValorBi(fonte: v.fonte, campo: v.campo, estatistica: e.name)),
            );
          }).toList(),
        ),
      ],
    ];
  }

  Widget _seletorEquacao(ReferenciaValorBi v) {
    final empresaId = ref.read(currentUserProvider)?.empresaId;
    if (empresaId == null) return const Text('Empresa não identificada.');
    final variaveisAsync = ref.watch(variaveisBiProvider(empresaId));

    return variaveisAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Text('Não foi possível carregar as equações: $e'),
      data: (variaveis) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (variaveis.isEmpty)
            Text('Nenhuma equação cadastrada.', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey))
          else
            CustomDropdown<String>(
              label: 'Equação',
              value: v.variavelId,
              items: variaveis
                  .map((x) => DropdownMenuItem(
                      value: x.id,
                      child: Text(x.unidade == null ? x.nome : '${x.nome} (${x.unidade})', overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (id) => widget.onChanged(ReferenciaValorBi(variavelId: id)),
            ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _criarEquacao(empresaId),
              icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
              label: const Text('Criar nova equação', style: TextStyle(color: AppColors.primary)),
            ),
          ),
        ],
      ),
    );
  }

  /// Aqui a equação nova vai sempre para os padrões da empresa: uma série ou
  /// coluna aponta para ela por id, e uma equação embutida dentro de uma
  /// série de um card seria invisível em qualquer outro lugar.
  Future<void> _criarEquacao(String empresaId) async {
    final criada = await abrirEditorVariavelBi(context, empresaId: empresaId, criadoPor: ref.read(currentUserProvider)?.id);
    if (criada == null) return;
    try {
      final id = await ref.read(variavelBiRepositoryProvider).criar(criada);
      ref.invalidate(variaveisBiProvider(empresaId));
      widget.onChanged(ReferenciaValorBi(variavelId: id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar a equação: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// ── Editor de série ────────────────────────────────────────────────────────

Future<SerieBi?> abrirEditorSerieBi(BuildContext context, {SerieBi? existente, int indice = 0}) {
  return showDiaviconModal<SerieBi>(
    context: context,
    title: existente == null ? 'Nova série' : 'Editar série',
    isScrollable: false,
    body: _EditorSerie(
      inicial: existente ??
          SerieBi(
            id: 'serie_${DateTime.now().microsecondsSinceEpoch}',
            nome: '',
            valor: const ReferenciaValorBi(),
            cor: coresSerieBi[indice % coresSerieBi.length],
          ),
    ),
  );
}

class _EditorSerie extends StatefulWidget {
  const _EditorSerie({required this.inicial});
  final SerieBi inicial;

  @override
  State<_EditorSerie> createState() => _EditorSerieState();
}

class _EditorSerieState extends State<_EditorSerie> {
  late SerieBi _serie = widget.inicial;
  late final TextEditingController _nome = TextEditingController(text: widget.inicial.nome);

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  List<Widget> _seletorSegmentacao() {
    final atual = _serie.segmentarPor;
    final porClasse = segmentacaoPorClassificacao(atual);
    return [
      const SizedBox(height: 12),
      _secao('Segmentar por'),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: opcoesSegmentacaoBi.entries.map((e) {
          final selecionado = e.key == 'classificacao' ? porClasse : atual == e.key;
          return ChoiceChip(
            label: Text(e.value, style: GoogleFonts.lato(fontSize: 12)),
            selected: selecionado,
            selectedColor: AppColors.primary.withValues(alpha: 0.2),
            onSelected: (_) => setState(() => _serie = _serie.copyWith(
                  segmentarPor: e.key == 'classificacao' ? valorSegmentacaoClassificacao(escalasSegmentacaoBi.first.id) : e.key,
                )),
          );
        }).toList(),
      ),
      if (porClasse) ...[
        const SizedBox(height: 10),
        CustomDropdown<String>(
          label: 'Escala',
          value: escalaDaSegmentacao(atual),
          items: escalasSegmentacaoBi.map((e) => DropdownMenuItem(value: e.id, child: Text(e.rotulo, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (id) => setState(() => _serie = _serie.copyWith(segmentarPor: valorSegmentacaoClassificacao(id!))),
        ),
        _ajuda('A altura de cada pedaço é a quantidade de elementos naquela classe — use com a variável da '
            'escala (ex.: velocidade longitudinal para Whitehurst).'),
      ] else if (atual != null)
        _ajuda('Cada pedaço é o valor da variável naquele recorte. Com GUT (somatório) os pedaços somam o '
            'total do grupo; com médias, empilhar é só visual.'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _secao('Dado'),
                  SeletorReferenciaValorBi(valor: _serie.valor, onChanged: (v) => setState(() => _serie = _serie.copyWith(valor: v))),
                  const SizedBox(height: 18),
                  _secao('Eixo'),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('Eixo 1 (esquerda)')),
                      ButtonSegment(value: 2, label: Text('Eixo 2 (direita)')),
                    ],
                    selected: {_serie.eixo},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _serie = _serie.copyWith(eixo: s.first)),
                  ),
                  _ajuda('Use o eixo 2 para grandezas de ordem diferente — ex.: velocidade (m/s) e resistividade (kΩ·cm).'),
                  const SizedBox(height: 14),
                  _secao('Tipo'),
                  Wrap(
                    spacing: 8,
                    children: TipoSerieBi.values.map((t) {
                      return ChoiceChip(
                        label: Text(t.rotulo, style: GoogleFonts.lato(fontSize: 12)),
                        selected: _serie.tipo == t,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (_) => setState(() => _serie = _serie.copyWith(tipo: t)),
                      );
                    }).toList(),
                  ),
                  _ajuda('Barras empilhadas se somam com as outras empilhadas do mesmo eixo.'),
                  if (_serie.tipo == TipoSerieBi.barraSegmentada) ..._seletorSegmentacao(),
                  const SizedBox(height: 14),
                  _secao('Cor'),
                  _SeletorCor(cores: coresSerieBi, cor: _serie.cor, onChanged: (c) => setState(() => _serie = _serie.copyWith(cor: c))),
                  const SizedBox(height: 14),
                  _secao('Nome na legenda (opcional)'),
                  TextField(
                    controller: _nome,
                    decoration: InputDecoration(
                      isDense: true,
                      border: const OutlineInputBorder(),
                      hintText: _serie.valor.valida ? _serie.valor.rotuloPadrao() : 'Automático',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          CustomButton(
            text: 'Confirmar',
            onPressed: _serie.valor.valida && (_serie.tipo != TipoSerieBi.barraSegmentada || _serie.segmentarPor != null)
                ? () => Navigator.of(context).pop(_serie.copyWith(nome: _nome.text.trim()))
                : null,
          ),
        ],
      ),
    );
  }
}

// ── Editor de coluna ───────────────────────────────────────────────────────

Future<ColunaTabelaBi?> abrirEditorColunaBi(BuildContext context, {ColunaTabelaBi? existente}) {
  return showDiaviconModal<ColunaTabelaBi>(
    context: context,
    title: existente == null ? 'Nova coluna' : 'Editar coluna',
    isScrollable: false,
    body: _EditorColuna(
      inicial: existente ??
          ColunaTabelaBi(id: 'coluna_${DateTime.now().microsecondsSinceEpoch}', titulo: '', valor: const ReferenciaValorBi()),
    ),
  );
}

class _EditorColuna extends StatefulWidget {
  const _EditorColuna({required this.inicial});
  final ColunaTabelaBi inicial;

  @override
  State<_EditorColuna> createState() => _EditorColunaState();
}

class _EditorColunaState extends State<_EditorColuna> {
  late ColunaTabelaBi _coluna = widget.inicial;
  late final TextEditingController _titulo = TextEditingController(text: widget.inicial.titulo);

  @override
  void dispose() {
    _titulo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _secao('Dado'),
                  SeletorReferenciaValorBi(valor: _coluna.valor, onChanged: (v) => setState(() => _coluna = _coluna.copyWith(valor: v))),
                  const SizedBox(height: 16),
                  _secao('Título da coluna'),
                  TextField(
                    controller: _titulo,
                    decoration: InputDecoration(
                      isDense: true,
                      border: const OutlineInputBorder(),
                      hintText: _coluna.valor.valida ? _coluna.valor.rotuloPadrao() : 'Automático',
                    ),
                  ),
                  _ajuda('O título vale só neste dashboard.'),
                  const SizedBox(height: 16),
                  _secao('Cor condicional'),
                  _ajuda('A primeira regra que valer pinta a célula.'),
                  for (var i = 0; i < _coluna.regras.length; i++)
                    _LinhaRegra(
                      regra: _coluna.regras[i],
                      onChanged: (r) => setState(() => _coluna = _coluna.copyWith(regras: [..._coluna.regras]..[i] = r)),
                      onRemover: () => setState(() => _coluna = _coluna.copyWith(regras: [..._coluna.regras]..removeAt(i))),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _coluna = _coluna.copyWith(regras: [
                            ..._coluna.regras,
                            RegraCorBi(operador: OperadorRegraBi.menorQue, valor: 0, cor: coresRegraBi.first),
                          ])),
                      icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                      label: const Text('Adicionar regra', style: TextStyle(color: AppColors.primary)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          CustomButton(
            text: 'Confirmar',
            onPressed: _coluna.valor.valida
                ? () {
                    final titulo = _titulo.text.trim();
                    Navigator.of(context).pop(_coluna.copyWith(titulo: titulo.isEmpty ? _coluna.valor.rotuloPadrao() : titulo));
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _LinhaRegra extends StatefulWidget {
  const _LinhaRegra({required this.regra, required this.onChanged, required this.onRemover});
  final RegraCorBi regra;
  final ValueChanged<RegraCorBi> onChanged;
  final VoidCallback onRemover;

  @override
  State<_LinhaRegra> createState() => _LinhaRegraState();
}

class _LinhaRegraState extends State<_LinhaRegra> {
  late final TextEditingController _v1 = TextEditingController(text: _fmt(widget.regra.valor));
  late final TextEditingController _v2 = TextEditingController(text: widget.regra.valor2 == null ? '' : _fmt(widget.regra.valor2!));

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _v1.dispose();
    _v2.dispose();
    super.dispose();
  }

  void _emitir({OperadorRegraBi? operador, int? cor}) {
    final op = operador ?? widget.regra.operador;
    widget.onChanged(RegraCorBi(
      operador: op,
      valor: double.tryParse(_v1.text.replaceAll(',', '.')) ?? 0,
      valor2: op == OperadorRegraBi.entre ? double.tryParse(_v2.text.replaceAll(',', '.')) : null,
      cor: cor ?? widget.regra.cor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.regra;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Row(
            children: [
              DropdownButton<OperadorRegraBi>(
                value: r.operador,
                underline: const SizedBox.shrink(),
                items: OperadorRegraBi.values.map((o) => DropdownMenuItem(value: o, child: Text(o.simbolo))).toList(),
                onChanged: (o) => _emitir(operador: o),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _v1,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), labelText: 'Valor'),
                  onChanged: (_) => _emitir(),
                ),
              ),
              if (r.operador == OperadorRegraBi.entre) ...[
                const SizedBox(width: 6),
                const Text('e'),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _v2,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), labelText: 'Até'),
                    onChanged: (_) => _emitir(),
                  ),
                ),
              ],
              IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: widget.onRemover),
            ],
          ),
          const SizedBox(height: 6),
          _SeletorCor(cores: coresRegraBi, cor: r.cor, onChanged: (c) => _emitir(cor: c)),
        ],
      ),
    );
  }
}

// ── Peças comuns ───────────────────────────────────────────────────────────

class _SeletorCor extends StatelessWidget {
  const _SeletorCor({required this.cores, required this.cor, required this.onChanged});
  final List<int> cores;
  final int cor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      children: [
        for (final c in cores)
          InkWell(
            onTap: () => onChanged(c),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: c == cor ? Border.all(color: AppColors.textDark, width: 2.5) : null,
              ),
            ),
          ),
      ],
    );
  }
}

Widget _secao(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t, style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.textDark)),
    );

Widget _ajuda(String t) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(t, style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600, height: 1.3)),
    );

// ── Monte Carlo ────────────────────────────────────────────────────────────

final RegExp _identificadorMC = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

const Map<String, String> _semAcento = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'é': 'e', 'ê': 'e', 'í': 'i',
  'ó': 'o', 'ô': 'o', 'õ': 'o', 'ú': 'u', 'ç': 'c',
};

/// Nome de identificador a partir de um texto livre ("Resistência estimada
/// SonReb" → "Resistencia_estimada_SonReb").
String identificadorDeTexto(String texto) {
  final buffer = StringBuffer();
  for (final c in texto.split('')) {
    final minuscula = c.toLowerCase();
    final troca = _semAcento[minuscula];
    if (troca == null) {
      buffer.write(c);
    } else {
      buffer.write(c == minuscula ? troca : troca.toUpperCase());
    }
  }
  var s = buffer.toString().replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_').replaceAll(RegExp(r'_+'), '_');
  s = s.replaceAll(RegExp(r'^_|_$'), '');
  if (s.isEmpty || RegExp(r'^[0-9]').hasMatch(s)) s = 'r_$s';
  return s.length > 24 ? s.substring(0, 24) : s;
}

/// Traz uma equação dos padrões para o Monte Carlo: cria uma série base para
/// cada entrada da equação (reaproveitando uma série existente com o mesmo
/// nome E a mesma variável) e uma série derivada com a fórmula, os
/// coeficientes já substituídos pelos valores.
///
/// É o que faz o SonReb propagar a incerteza de V e de R, em vez de ser
/// calculado só sobre as médias.
({List<SerieMonteCarloBi> series, String resultado}) importarEquacaoMC(
  VariavelBiModel equacao,
  List<SerieMonteCarloBi> atuais, {
  required String Function() novoId,
  int cor = 0xFFE0526B,
}) {
  final series = [...atuais];
  final nomes = series.map((s) => s.nome).toSet();
  final renomear = <String, String>{};

  for (final e in equacao.entradas) {
    final existente = series.where((s) => s.nome == e.alias).firstOrNull;
    final mesmaVariavel =
        existente != null && !existente.derivada && existente.valor?.fonte == e.fonte && existente.valor?.campo == e.campo;
    if (mesmaVariavel) continue;

    // Nome ocupado por OUTRA coisa: usa um nome novo e troca na fórmula, em
    // vez de ligar a fórmula à série errada em silêncio.
    var nome = e.alias;
    var i = 2;
    while (nomes.contains(nome)) {
      nome = '${e.alias}_$i';
      i++;
    }
    if (nome != e.alias) renomear[e.alias] = nome;
    nomes.add(nome);
    series.add(SerieMonteCarloBi(id: novoId(), nome: nome, valor: ReferenciaValorBi(fonte: e.fonte, campo: e.campo)));
  }

  final expressao = equacao.expressao.replaceAllMapped(RegExp(r'[A-Za-z_][A-Za-z0-9_]*'), (m) {
    final id = m.group(0)!;
    if (renomear.containsKey(id)) return renomear[id]!;
    if (equacao.parametros.containsKey(id)) return '(${equacao.parametros[id]})';
    return id;
  });

  final base = identificadorDeTexto(equacao.nome);
  var resultado = base;
  var i = 2;
  while (nomes.contains(resultado)) {
    resultado = '${base}_$i';
    i++;
  }
  series.add(SerieMonteCarloBi(id: novoId(), nome: resultado, expressao: expressao, cor: cor));
  return (series: series, resultado: resultado);
}

Future<SerieMonteCarloBi?> abrirEditorSerieMC(
  BuildContext context, {
  SerieMonteCarloBi? existente,
  required Set<String> outrosNomes,
  int indice = 0,
}) {
  return showDiaviconModal<SerieMonteCarloBi>(
    context: context,
    title: existente == null ? 'Nova série simulada' : 'Editar série simulada',
    isScrollable: false,
    body: _EditorSerieMC(
      outrosNomes: outrosNomes,
      inicial: existente ??
          SerieMonteCarloBi(
            id: 'mc_${DateTime.now().microsecondsSinceEpoch}',
            nome: '',
            valor: const ReferenciaValorBi(),
            cor: coresSerieBi[indice % coresSerieBi.length],
          ),
    ),
  );
}

class _EditorSerieMC extends StatefulWidget {
  const _EditorSerieMC({required this.inicial, required this.outrosNomes});
  final SerieMonteCarloBi inicial;
  final Set<String> outrosNomes;

  @override
  State<_EditorSerieMC> createState() => _EditorSerieMCState();
}

class _EditorSerieMCState extends State<_EditorSerieMC> {
  late final TextEditingController _nome = TextEditingController(text: widget.inicial.nome);
  late final TextEditingController _expressao = TextEditingController(text: widget.inicial.expressao ?? '');
  late bool _derivada = widget.inicial.derivada;
  late ReferenciaValorBi _valor = widget.inicial.valor ?? const ReferenciaValorBi();
  late int _cor = widget.inicial.cor;
  List<String> _erros = const [];

  @override
  void dispose() {
    _nome.dispose();
    _expressao.dispose();
    super.dispose();
  }

  /// Insere [texto] na posição do cursor da equação (ou no fim).
  void _inserir(String texto) {
    final atual = _expressao.text;
    final sel = _expressao.selection;
    final ini = sel.isValid ? sel.start : atual.length;
    final fim = sel.isValid ? sel.end : atual.length;
    _expressao.value = TextEditingValue(
      text: atual.replaceRange(ini, fim, texto),
      selection: TextSelection.collapsed(offset: ini + texto.length),
    );
    setState(() {});
  }

  void _confirmar() {
    final nome = _nome.text.trim();
    final erros = <String>[];
    if (!_identificadorMC.hasMatch(nome)) {
      erros.add('O nome precisa começar por letra e ter só letras, números e _ (ele é usado nas fórmulas).');
    } else if (widget.outrosNomes.contains(nome)) {
      erros.add('Já existe uma série chamada "$nome".');
    } else if (VariavelBiAvaliador.funcoes.contains(nome)) {
      erros.add('"$nome" é nome de função; escolha outro.');
    }
    if (_derivada) {
      final expr = _expressao.text.trim();
      erros.addAll(VariavelBiAvaliador.validarExpressao(expr, widget.outrosNomes));
      if (VariavelBiAvaliador.nomesUsados(expr).contains(nome)) erros.add('A série não pode usar a si mesma na fórmula.');
    } else if (!_valor.valida) {
      erros.add('Escolha o ensaio e a variável.');
    }
    setState(() => _erros = erros);
    if (erros.isNotEmpty) return;

    Navigator.of(context).pop(SerieMonteCarloBi(
      id: widget.inicial.id,
      nome: nome,
      valor: _derivada ? null : _valor,
      expressao: _derivada ? _expressao.text.trim() : null,
      cor: _cor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final disponiveis = widget.outrosNomes.toList()..sort();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _secao('Nome'),
                  TextField(
                    controller: _nome,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: 'Ex.: V, R, cob'),
                  ),
                  _ajuda('É o nome usado nas fórmulas de outras séries.'),
                  const SizedBox(height: 14),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Variável de ensaio')),
                      ButtonSegment(value: true, label: Text('Calculada (equação)')),
                    ],
                    selected: {_derivada},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _derivada = s.first),
                  ),
                  const SizedBox(height: 14),
                  if (!_derivada) ...[
                    SeletorReferenciaValorBi(valor: _valor, mostrarEstatistica: false, onChanged: (v) => setState(() => _valor = v)),
                    _ajuda('Média e desvio padrão de todos os valores no contexto do dashboard; a série é '
                        'média + z·σ, com z normal, sorteada 1.000 vezes.'),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        'Uma série calculada combina outras séries desta simulação com uma conta. '
                        'Exemplo: com as séries V (velocidade) e R (esclerometria) criadas, a série '
                        'fc = 0.0286 * pow(V/1000, 1.246) * pow(R, 1.85) dá a resistência pelo SonReb '
                        'já com a incerteza de V e de R — a conta é feita em cada uma das 1.000 amostras.\n\n'
                        'Atalho: o botão "Importar equação" monta isso sozinho a partir de uma equação '
                        'dos padrões da empresa.',
                        style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade800, height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _expressao,
                      maxLines: 2,
                      style: GoogleFonts.robotoMono(fontSize: 13),
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), labelText: 'Equação'),
                    ),
                    const SizedBox(height: 8),
                    if (disponiveis.isEmpty)
                      _ajuda('Crie antes as séries de variável de ensaio que a equação vai usar.')
                    else ...[
                      _ajuda('Toque para inserir na equação:'),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final n in disponiveis)
                            ActionChip(
                              label: Text(n, style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w700)),
                              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                              onPressed: () => _inserir(n),
                            ),
                          for (final op in const ['+', '-', '*', '/', '(', ')', 'pow(', 'sqrt('])
                            ActionChip(label: Text(op, style: GoogleFonts.robotoMono(fontSize: 12)), onPressed: () => _inserir(op)),
                        ],
                      ),
                      _ajuda('pow(x, n) = x elevado a n. Números podem ser digitados direto (use ponto: 0.0286).'),
                    ],
                  ],
                  const SizedBox(height: 14),
                  _secao('Cor'),
                  _SeletorCor(cores: coresSerieBi, cor: _cor, onChanged: (c) => setState(() => _cor = c)),
                  if (_erros.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final e in _erros) Text('• $e', style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFFB3261E))),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          CustomButton(text: 'Confirmar', onPressed: _confirmar),
        ],
      ),
    );
  }
}
