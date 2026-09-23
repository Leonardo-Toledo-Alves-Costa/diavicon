import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/diavicon_modal.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_dropdown.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../models/campos_bi_catalogo.dart';
import '../models/variavel_bi_model.dart';
import '../utils/variavel_bi_avaliador.dart';

/// Abre o editor de uma variável derivada. Devolve a variável montada (ainda
/// não persistida — quem chama decide se salva na empresa ou usa local) ou
/// `null` se cancelado.
Future<VariavelBiModel?> abrirEditorVariavelBi(
  BuildContext context, {
  required String empresaId,
  String? criadoPor,
  VariavelBiModel? existente,
  bool somenteLeitura = false,
  Map<String, double>? valoresReais,
}) {
  return showDiaviconModal<VariavelBiModel>(
    context: context,
    title: existente == null
        ? 'Nova equação'
        : somenteLeitura
            ? existente.nome
            : 'Editar equação',
    isScrollable: false,
    body: _EditorVariavelBody(
      empresaId: empresaId,
      criadoPor: criadoPor,
      existente: existente,
      somenteLeitura: somenteLeitura,
      valoresReais: valoresReais,
    ),
  );
}

class _EditorVariavelBody extends StatefulWidget {
  const _EditorVariavelBody({
    required this.empresaId,
    required this.criadoPor,
    required this.existente,
    required this.somenteLeitura,
    required this.valoresReais,
  });

  final String empresaId;
  final String? criadoPor;
  final VariavelBiModel? existente;
  final bool somenteLeitura;

  /// Valores já observados no contexto atual (ex.: a média de V e de R do
  /// elemento aberto). Quando vêm preenchidos, o preview mostra o número que
  /// a equação realmente produziria — que é a checagem que pega coeficiente
  /// trocado, coisa que nenhum parser detecta.
  final Map<String, double>? valoresReais;

  @override
  State<_EditorVariavelBody> createState() => _EditorVariavelBodyState();
}

class _EditorVariavelBodyState extends State<_EditorVariavelBody> {
  late final TextEditingController _nome;
  late final TextEditingController _unidade;
  late final TextEditingController _descricao;
  late final TextEditingController _expressao;
  late final TextEditingController _referencia;
  late final TextEditingController _min;
  late final TextEditingController _max;

  late List<EntradaVariavelBi> _entradas;
  late List<_ParametroEditavel> _parametros;

  /// Valores usados no preview, por alias. Começam nos reais (quando há) e
  /// podem ser ajustados à mão para testar a fórmula.
  final Map<String, TextEditingController> _teste = {};

  List<String> _erros = const [];

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    _nome = TextEditingController(text: e?.nome ?? '');
    _unidade = TextEditingController(text: e?.unidade ?? '');
    _descricao = TextEditingController(text: e?.descricao ?? '');
    _expressao = TextEditingController(text: e?.expressao ?? '');
    _referencia = TextEditingController(text: e?.referencia ?? '');
    _min = TextEditingController(text: e?.valorMin?.toString() ?? '');
    _max = TextEditingController(text: e?.valorMax?.toString() ?? '');
    _entradas = List.of(e?.entradas ?? const []);
    _parametros = (e?.parametros ?? const <String, double>{})
        .entries
        .map((p) => _ParametroEditavel(nome: p.key, valor: p.value))
        .toList();
    _sincronizarTeste();
  }

  @override
  void dispose() {
    for (final c in [_nome, _unidade, _descricao, _expressao, _referencia, _min, _max, ..._teste.values]) {
      c.dispose();
    }
    for (final p in _parametros) {
      p.dispose();
    }
    super.dispose();
  }

  // Mantém um campo de teste por alias, preservando o que já foi digitado.
  void _sincronizarTeste() {
    final aliases = _entradas.map((e) => e.alias).where((a) => a.isNotEmpty).toSet();
    for (final alias in aliases) {
      _teste.putIfAbsent(
        alias,
        () => TextEditingController(text: widget.valoresReais?[alias]?.toString() ?? '1'),
      );
    }
    for (final alias in _teste.keys.toList()) {
      if (!aliases.contains(alias)) _teste.remove(alias)?.dispose();
    }
  }

  VariavelBiModel _montar() => VariavelBiModel(
        id: widget.existente?.id ?? '',
        empresaId: widget.existente?.empresaId ?? widget.empresaId,
        criadoPor: widget.existente?.criadoPor ?? widget.criadoPor,
        nome: _nome.text.trim(),
        unidade: _unidade.text.trim().isEmpty ? null : _unidade.text.trim(),
        descricao: _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
        expressao: _expressao.text.trim(),
        entradas: _entradas,
        parametros: {for (final p in _parametros) p.nome: p.valor},
        referencia: _referencia.text.trim().isEmpty ? null : _referencia.text.trim(),
        valorMin: double.tryParse(_min.text.replaceAll(',', '.')),
        valorMax: double.tryParse(_max.text.replaceAll(',', '.')),
        variavelOrigemId: widget.existente?.variavelOrigemId,
      );

  void _confirmar() {
    final variavel = _montar();
    final erros = <String>[];

    // Nomes de coeficiente repetidos colapsariam no mapa sem aviso nenhum:
    // o usuario veria um coeficiente sumir. Checagem feita aqui porque o
    // modelo ja recebe um mapa, onde a duplicata nao existe mais.
    final vistos = <String>{};
    for (final p in _parametros) {
      if (p.nome.isNotEmpty && !vistos.add(p.nome)) {
        erros.add('Há mais de um coeficiente chamado "${p.nome}".');
      }
    }

    erros.addAll(VariavelBiAvaliador.validar(variavel).erros);
    setState(() => _erros = erros);
    final validacao = ValidacaoVariavelBi(erros);
    if (!validacao.ok) return;
    Navigator.of(context).pop(variavel);
  }

  @override
  Widget build(BuildContext context) {
    final somenteLeitura = widget.somenteLeitura;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomTextField(
                    label: 'Nome',
                    hint: 'Ex.: Resistência estimada SonReb',
                    controller: _nome,
                    isRequired: true,
                    enabled: !somenteLeitura,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Unidade',
                          hint: 'MPa',
                          controller: _unidade,
                          enabled: !somenteLeitura,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomTextField(
                          label: 'Referência',
                          hint: 'Norma ou artigo',
                          controller: _referencia,
                          enabled: !somenteLeitura,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _secao('Variáveis de ensaio'),
                  _ajuda(
                    'Cada variável vira um número por elemento estrutural — a estatística escolhida '
                    'resume as leituras daquele ensaio no elemento. Ensaios diferentes são combinados '
                    'por elemento, não leitura a leitura.',
                  ),
                  ..._entradas.asMap().entries.map((e) => _linhaEntrada(e.key, e.value, somenteLeitura)),
                  if (!somenteLeitura)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() {
                          _entradas = [..._entradas, const EntradaVariavelBi(alias: '', fonte: '', campo: '')];
                        }),
                        icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                        label: const Text('Adicionar variável', style: TextStyle(color: AppColors.primary)),
                      ),
                    ),

                  const SizedBox(height: 8),
                  _secao('Coeficientes'),
                  _ajuda(
                    'Ficam separados da fórmula de propósito: a expressão é a norma, os coeficientes '
                    'são a calibração da sua obra. Assim recalibrar não cria uma fórmula nova.',
                  ),
                  ..._parametros.asMap().entries.map((p) => _linhaParametro(p.key, somenteLeitura)),
                  if (!somenteLeitura)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _adicionarParametro,
                        icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                        label: const Text('Adicionar coeficiente', style: TextStyle(color: AppColors.primary)),
                      ),
                    ),

                  const SizedBox(height: 8),
                  _secao('Fórmula'),
                  CustomTextField(
                    label: '',
                    hint: 'a * pow(V, b) * pow(R, c)',
                    controller: _expressao,
                    enabled: !somenteLeitura,
                    maxLines: 2,
                  ),
                  _ajuda('Funções disponíveis: pow, sqrt, log, exp, abs, min, max.'),

                  const SizedBox(height: 8),
                  _secao('Faixa esperada do resultado'),
                  _ajuda(
                    'Opcional, mas é o que denuncia erro de unidade ou coeficiente trocado — casos em '
                    'que a fórmula roda sem erro e devolve um número impossível.',
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Mínimo',
                          hint: '5',
                          controller: _min,
                          keyboardType: TextInputType.number,
                          enabled: !somenteLeitura,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomTextField(
                          label: 'Máximo',
                          hint: '150',
                          controller: _max,
                          keyboardType: TextInputType.number,
                          enabled: !somenteLeitura,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  _preview(),

                  if (_erros.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _erros
                            .map((e) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text('• $e',
                                      style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFFB3261E))),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (!somenteLeitura)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: CustomButton(text: 'Confirmar', onPressed: _confirmar),
            ),
        ],
      ),
    );
  }

  // ── Preview ───────────────────────────────────────────────────────────────

  Widget _preview() {
    final variavel = _montar();
    final valores = {
      for (final entry in _teste.entries) entry.key: double.tryParse(entry.value.text.replaceAll(',', '.')),
    };
    final resultado = variavel.expressao.isEmpty || variavel.entradas.isEmpty
        ? null
        : VariavelBiAvaliador.avaliar(variavel, valores);
    final fora = resultado != null && VariavelBiAvaliador.foraDaFaixa(variavel, resultado);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fora ? const Color(0xFFE8A33D) : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Teste da fórmula',
              style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 2),
          Text(
            widget.valoresReais == null
                ? 'Ajuste os valores para conferir se o resultado faz sentido.'
                : 'Pré-preenchido com os dados reais deste contexto.',
            style: GoogleFonts.lato(fontSize: 11, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: _teste.entries
                .map((entry) => SizedBox(
                      width: 110,
                      child: TextField(
                        controller: entry.value,
                        keyboardType: TextInputType.number,
                        enabled: !widget.somenteLeitura,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: entry.key,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        style: GoogleFonts.lato(fontSize: 13),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Resultado: ',
                  style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[700])),
              Expanded(
                child: Text(
                  resultado == null
                      ? '—'
                      : '${resultado.toStringAsFixed(2)}${_unidade.text.trim().isEmpty ? '' : ' ${_unidade.text.trim()}'}',
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: fora ? const Color(0xFFB26A00) : AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          if (fora)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Fora da faixa esperada. Confira a unidade das variáveis e a ordem dos coeficientes.',
                style: GoogleFonts.lato(fontSize: 11, color: const Color(0xFFB26A00)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Linhas de edição ──────────────────────────────────────────────────────

  Widget _linhaEntrada(int indice, EntradaVariavelBi entrada, bool somenteLeitura) {
    final fonte = catalogoFontesBi.where((f) => f.chave == entrada.fonte).firstOrNull;
    final campo = fonte?.campos.where((c) => c.chave == entrada.campo).firstOrNull;
    final aceitaEstatistica = campo?.categoria == CategoriaDadoBi.estatistica;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 76,
                child: TextFormField(
                  initialValue: entrada.alias,
                  enabled: !somenteLeitura,
                  decoration: const InputDecoration(labelText: 'Nome', isDense: true, border: OutlineInputBorder()),
                  onChanged: (v) => setState(() {
                    _entradas[indice] = EntradaVariavelBi(
                      alias: v.trim(),
                      fonte: entrada.fonte,
                      campo: entrada.campo,
                      estatistica: entrada.estatistica,
                    );
                    _sincronizarTeste();
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomDropdown<String>(
                  label: 'Ensaio',
                  value: entrada.fonte.isEmpty ? null : entrada.fonte,
                  items: catalogoFontesBi
                      .where((f) => f.implementado)
                      .map((f) => DropdownMenuItem(value: f.chave, child: Text(f.rotulo, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: somenteLeitura
                      ? (_) {}
                      : (v) => setState(() {
                            // Trocar de ensaio invalida o campo escolhido.
                            _entradas[indice] = EntradaVariavelBi(alias: entrada.alias, fonte: v ?? '', campo: '');
                          }),
                ),
              ),
              if (!somenteLeitura)
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  onPressed: () => setState(() {
                    _entradas = [..._entradas]..removeAt(indice);
                    _sincronizarTeste();
                  }),
                ),
            ],
          ),
          if (fonte != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomDropdown<String>(
                    label: 'Variável',
                    value: entrada.campo.isEmpty ? null : entrada.campo,
                    items: fonte.campos
                        .where((c) =>
                            c.categoria == CategoriaDadoBi.estatistica || c.categoria == CategoriaDadoBi.bruto)
                        .map((c) => DropdownMenuItem(
                            value: c.chave,
                            child: Text(c.unidade == null ? c.rotulo : '${c.rotulo} (${c.unidade})',
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: somenteLeitura
                        ? (_) {}
                        : (v) => setState(() {
                              _entradas[indice] = EntradaVariavelBi(
                                alias: entrada.alias,
                                fonte: entrada.fonte,
                                campo: v ?? '',
                                estatistica: EstatisticaBi.media.name,
                              );
                            }),
                  ),
                ),
                if (aceitaEstatistica) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomDropdown<String>(
                      label: 'Estatística',
                      value: entrada.estatistica ?? EstatisticaBi.media.name,
                      items: EstatisticaBi.values
                          .map((e) => DropdownMenuItem(value: e.name, child: Text(e.rotulo, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: somenteLeitura
                          ? (_) {}
                          : (v) => setState(() {
                                _entradas[indice] = EntradaVariavelBi(
                                  alias: entrada.alias,
                                  fonte: entrada.fonte,
                                  campo: entrada.campo,
                                  estatistica: v,
                                );
                              }),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _linhaParametro(int indice, bool somenteLeitura) {
    final parametro = _parametros[indice];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: TextField(
              controller: parametro.nomeCtrl,
              enabled: !somenteLeitura,
              decoration: const InputDecoration(labelText: 'Nome', isDense: true, border: OutlineInputBorder()),
              // Rebuild pro preview e a validacao acompanharem o que esta
              // sendo digitado.
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: parametro.valorCtrl,
              enabled: !somenteLeitura,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(labelText: 'Valor', isDense: true, border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (!somenteLeitura)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
              onPressed: () => setState(() {
                _parametros.removeAt(indice).dispose();
              }),
            ),
        ],
      ),
    );
  }

  /// Acrescenta uma linha vazia pro usuario nomear ali mesmo.
  ///
  /// Antes isto abria um AlertDialog pra pedir o nome, e o
  /// TextEditingController dele era descartado assim que o `await showDialog`
  /// retornava — mas o dialogo continua montado durante a animacao de saida,
  /// entao o TextField passava a usar um controller ja descartado e lancava a
  /// cada frame, travando a tela. Editar na propria linha elimina o problema
  /// em vez de contorna-lo.
  void _adicionarParametro() {
    setState(() => _parametros.add(_ParametroEditavel(nome: '', valor: 1)));
  }

  Widget _secao(String titulo) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(titulo,
            style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.textDark)),
      );

  Widget _ajuda(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(texto, style: GoogleFonts.lato(fontSize: 11, color: Colors.grey[600], height: 1.3)),
      );
}

/// Um coeficiente enquanto esta sendo editado.
///
/// Guarda os proprios controllers pra que digitar o nome nao recrie a linha
/// (era o que acontecia quando os coeficientes viviam num Map: a chave mudava
/// a cada tecla e o campo perdia o foco).
class _ParametroEditavel {
  _ParametroEditavel({required String nome, required double valor})
      : nomeCtrl = TextEditingController(text: nome),
        valorCtrl = TextEditingController(text: _semZeroInutil(valor));

  final TextEditingController nomeCtrl;
  final TextEditingController valorCtrl;

  String get nome => nomeCtrl.text.trim();
  double get valor => double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0;

  void dispose() {
    nomeCtrl.dispose();
    valorCtrl.dispose();
  }

  // 1.0 exibido como "1" — coeficiente e numero digitado a mao, e o zero
  // decimal so atrapalha na hora de editar.
  static String _semZeroInutil(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
