import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/modelo_relatorio_schema.dart';
import '../models/quadro_model.dart';

class ResumoEditor extends StatelessWidget {
  final ResumoConfig config;
  final ValueChanged<ResumoConfig> onChanged;
  final List<TabelaResumo> tabelas;

  const ResumoEditor({super.key, required this.config, required this.onChanged, required this.tabelas});

  void _mover(int index, int delta) {
    final novaLista = List<ResumoColuna>.from(config.colunas);
    final novoIndex = index + delta;
    if (novoIndex < 0 || novoIndex >= novaLista.length) return;
    final item = novaLista.removeAt(index);
    novaLista.insert(novoIndex, item);
    onChanged(config.copyWith(colunas: novaLista));
  }

  void _remover(int index) {
    final novaLista = List<ResumoColuna>.from(config.colunas)..removeAt(index);
    onChanged(config.copyWith(colunas: novaLista));
  }

  Future<T?> _abrirListaBottomSheet<T>(BuildContext context, String titulo, List<Widget> itens) {
    return showModalBottomSheet<T>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(padding: const EdgeInsets.all(16), child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              ...itens,
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _adicionarColuna(BuildContext context) async {
    final jaTemQuantidade = config.colunas.any((c) => c.campoVinculado == null && !c.ehCalculada);
    const chaveQuantidade = '__quantidade__';
    const chaveCalculada = '__calculada__';

    final chaveEscolhida = await _abrirListaBottomSheet<String>(context, 'De qual tabela extrair o dado?', [
      if (!jaTemQuantidade)
        ListTile(
          leading: const Icon(Icons.tag),
          title: const Text('Quantidade (contagem automática)'),
          onTap: () => Navigator.pop(context, chaveQuantidade),
        ),
      ListTile(
        leading: const Icon(Icons.functions, color: AppColors.primary),
        title: const Text('Coluna personalizada (fórmula)'),
        subtitle: const Text('Multiplica/soma variáveis e pode gerar um texto condicional'),
        onTap: () => Navigator.pop(context, chaveCalculada),
      ),
      for (final tabela in tabelas)
        ListTile(title: Text(tabela.rotulo), onTap: () => Navigator.pop(context, tabela.chave)),
    ]);

    if (chaveEscolhida == null) return; // fechou o sheet sem escolher

    if (chaveEscolhida == chaveQuantidade) {
      onChanged(config.copyWith(colunas: [
        ...config.colunas,
        const ResumoColuna(id: 'quantidade', rotulo: 'Quantidade', campoVinculado: null, tabela: null),
      ]));
      return;
    }

    if (chaveEscolhida == chaveCalculada) {
      if (!context.mounted) return;
      final novaColuna = await showDialog<ResumoColuna>(
        context: context,
        builder: (context) => _ColunaCalculadaDialog(tabelas: tabelas),
      );
      if (novaColuna == null) return;
      onChanged(config.copyWith(colunas: [...config.colunas, novaColuna]));
      return;
    }

    if (!context.mounted) return;
    _adicionarColunaCatalogo(context, chaveEscolhida);
  }

  Future<void> _editarColunaCalculada(BuildContext context, int index) async {
    final colunaEditada = await showDialog<ResumoColuna>(
      context: context,
      builder: (context) => _ColunaCalculadaDialog(tabelas: tabelas, existente: config.colunas[index]),
    );
    if (colunaEditada == null) return;
    final novaLista = List<ResumoColuna>.from(config.colunas);
    novaLista[index] = colunaEditada;
    onChanged(config.copyWith(colunas: novaLista));
  }

  Future<void> _adicionarColunaCatalogo(BuildContext context, String chaveEscolhida) async {
    final tabelaEscolhida = tabelas.firstWhere((t) => t.chave == chaveEscolhida);
    final usados = config.colunas.map((c) => c.campoVinculado).toSet();
    final disponiveis = tabelaEscolhida.campos.where((c) => !usados.contains(c.chave)).toList();

    if (disponiveis.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todos os campos dessa tabela já foram adicionados.')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final campo = await _abrirListaBottomSheet<CampoCatalogo>(context, tabelaEscolhida.rotulo, [
      for (final c in disponiveis) ListTile(title: Text(c.rotulo), onTap: () => Navigator.pop(context, c)),
    ]);
    if (campo == null) return;

    onChanged(config.copyWith(colunas: [
      ...config.colunas,
      ResumoColuna(id: campo.chave, rotulo: campo.rotulo, campoVinculado: campo.chave, tabela: tabelaEscolhida.chave),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fotos não entram na tabela resumo.', style: TextStyle(fontSize: 11, color: Colors.black38)),
        const SizedBox(height: 8),
        for (var i = 0; i < config.colunas.length; i++) _buildLinha(context, i),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _adicionarColuna(context),
          icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
          label: const Text('Adicionar coluna', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  String _resumoFormula(ResumoColuna coluna) {
    final rotulos = coluna.operandos.map((chave) {
      for (final tabela in tabelas) {
        for (final campo in tabela.campos) {
          if (campo.chave == chave) return campo.rotulo;
        }
      }
      return chave;
    }).toList();
    final buffer = StringBuffer();
    for (var i = 0; i < rotulos.length; i++) {
      if (i > 0) buffer.write(' ${i - 1 < coluna.operadores.length ? coluna.operadores[i - 1].simbolo : '?'} ');
      buffer.write(rotulos[i]);
    }
    return coluna.regras.isEmpty ? buffer.toString() : '$buffer (com texto condicional)';
  }

  Widget _buildLinha(BuildContext context, int index) {
    final coluna = config.colunas[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: index > 0 ? () => _mover(index, -1) : null,
                child: Icon(Icons.keyboard_arrow_up, size: 18, color: index > 0 ? Colors.black54 : Colors.black26),
              ),
              InkWell(
                onTap: index < config.colunas.length - 1 ? () => _mover(index, 1) : null,
                child: Icon(Icons.keyboard_arrow_down, size: 18, color: index < config.colunas.length - 1 ? Colors.black54 : Colors.black26),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(coluna.rotulo, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                if (coluna.ehCalculada)
                  Text(
                    _resumoFormula(coluna),
                    style: const TextStyle(fontSize: 10, color: Colors.black38),
                  )
                else if (coluna.tabela != null)
                  Text(
                    tabelas.firstWhere((t) => t.chave == coluna.tabela, orElse: () => tabelas.first).rotulo,
                    style: const TextStyle(fontSize: 10, color: Colors.black38),
                  ),
              ],
            ),
          ),
          if (coluna.ehCalculada)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => _editarColunaCalculada(context, index),
              icon: const Icon(Icons.edit, size: 18, color: Colors.black54),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _remover(index),
            icon: const Icon(Icons.close, size: 18, color: Colors.red),
          ),
        ],
      ),
    );
  }
}

class _OperandoEscolhido {
  final String chave;
  final String rotulo;
  _OperandoEscolhido({required this.chave, required this.rotulo});
}

class _RegraForm {
  OperadorCondicional operador = OperadorCondicional.maiorQue;
  final valorController = TextEditingController();
  final textoController = TextEditingController();

  void dispose() {
    valorController.dispose();
    textoController.dispose();
  }
}

// O que a coluna deve mostrar: o número calculado da fórmula, ou um texto
// escolhido a partir de regras condicionais sobre esse número.
enum _ModoResultadoFormula { numero, textoCondicional }

class _ColunaCalculadaDialog extends StatefulWidget {
  final List<TabelaResumo> tabelas;
  final ResumoColuna? existente; // não-nulo = editando uma coluna já criada
  const _ColunaCalculadaDialog({required this.tabelas, this.existente});

  @override
  State<_ColunaCalculadaDialog> createState() => _ColunaCalculadaDialogState();
}

class _ColunaCalculadaDialogState extends State<_ColunaCalculadaDialog> {
  final _rotuloController = TextEditingController();
  final _textoPadraoController = TextEditingController();
  final List<_OperandoEscolhido> _operandos = [];
  final List<OperadorFormula> _operadores = []; // length == _operandos.length - 1; operadores[i] liga operandos[i] a operandos[i+1]
  final List<NumeralizacaoCampo> _numeralizacoes = []; // uma por operando categórico presente em _operandos
  int _casasDecimais = 2;
  final List<_RegraForm> _regras = [];
  var _modoResultado = _ModoResultadoFormula.numero;

  @override
  void initState() {
    super.initState();
    final existente = widget.existente;
    if (existente == null) return;
    _rotuloController.text = existente.rotulo;
    _textoPadraoController.text = existente.textoPadrao ?? '';
    _casasDecimais = existente.casasDecimais;
    _modoResultado = existente.regras.isNotEmpty ? _ModoResultadoFormula.textoCondicional : _ModoResultadoFormula.numero;
    final todosCampos = widget.tabelas.expand((t) => t.campos).toList();
    for (final chave in existente.operandos) {
      final campo = todosCampos.firstWhere((c) => c.chave == chave, orElse: () => CampoCatalogo(chave, chave, TipoCampoCatalogo.texto));
      _operandos.add(_OperandoEscolhido(chave: campo.chave, rotulo: campo.rotulo));
    }
    _operadores.addAll(existente.operadores);
    _numeralizacoes.addAll(existente.numeralizacoes);
    for (final r in existente.regras) {
      _regras.add(_RegraForm()
        ..operador = r.operador
        ..valorController.text = r.valorComparacao.toString()
        ..textoController.text = r.textoResultado);
    }
  }

  @override
  void dispose() {
    _rotuloController.dispose();
    _textoPadraoController.dispose();
    for (final r in _regras) {
      r.dispose();
    }
    super.dispose();
  }

  // Só variáveis numéricas (usam-se direto) ou categóricas numeralizáveis
  // entram numa fórmula — o resto (nomes, descrições, endereço...) é só
  // texto e não faz sentido operar matematicamente.
  List<CampoCatalogo> get _camposDisponiveis {
    final usados = _operandos.map((o) => o.chave).toSet();
    final vistos = <String>{};
    final lista = <CampoCatalogo>[];
    for (final tabela in widget.tabelas) {
      for (final campo in tabela.campos) {
        final elegivel = camposNumericosParaFormula.contains(campo.chave) || camposCategoricosParaFormula.contains(campo.chave);
        if (!elegivel) continue;
        if (usados.contains(campo.chave) || vistos.contains(campo.chave)) continue;
        vistos.add(campo.chave);
        lista.add(campo);
      }
    }
    return lista;
  }

  Future<void> _adicionarOperando() async {
    final disponiveis = _camposDisponiveis;
    if (disponiveis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma outra variável disponível.')));
      return;
    }
    final campo = await showModalBottomSheet<CampoCatalogo>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Escolha a variável', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              for (final c in disponiveis)
                ListTile(
                  title: Text(c.rotulo),
                  trailing: camposCategoricosParaFormula.contains(c.chave)
                      ? const Icon(Icons.tag, size: 18, color: Colors.black38)
                      : null,
                  subtitle: camposCategoricosParaFormula.contains(c.chave) ? const Text('Precisa numeralizar os valores') : null,
                  onTap: () => Navigator.pop(context, c),
                ),
            ],
          ),
        ),
      ),
    );
    if (campo == null) return;

    if (camposCategoricosParaFormula.contains(campo.chave)) {
      if (!mounted) return;
      final numeralizacao = await showDialog<NumeralizacaoCampo>(
        context: context,
        builder: (context) => _NumeralizacaoDialog(campo: campo),
      );
      if (numeralizacao == null) return; // cancelou a numeralização, não adiciona a variável
      setState(() {
        _operandos.add(_OperandoEscolhido(chave: campo.chave, rotulo: campo.rotulo));
        _numeralizacoes.add(numeralizacao);
        if (_operandos.length > 1) {
          _operadores.add(_operadores.isNotEmpty ? _operadores.last : OperadorFormula.multiplicar);
        }
      });
      return;
    }

    setState(() {
      _operandos.add(_OperandoEscolhido(chave: campo.chave, rotulo: campo.rotulo));
      if (_operandos.length > 1) {
        // Novo espaço entre a variável anterior e essa: copia o último operador usado, se houver.
        _operadores.add(_operadores.isNotEmpty ? _operadores.last : OperadorFormula.multiplicar);
      }
    });
  }

  Future<void> _editarNumeralizacao(int index) async {
    final chave = _operandos[index].chave;
    final atualIndex = _numeralizacoes.indexWhere((n) => n.campo == chave);
    if (atualIndex == -1) return;
    final campo = widget.tabelas.expand((t) => t.campos).firstWhere((c) => c.chave == chave);
    final editada = await showDialog<NumeralizacaoCampo>(
      context: context,
      builder: (context) => _NumeralizacaoDialog(campo: campo, existente: _numeralizacoes[atualIndex]),
    );
    if (editada == null) return;
    setState(() => _numeralizacoes[atualIndex] = editada);
  }

  void _removerOperando(int index) {
    setState(() {
      final chave = _operandos[index].chave;
      _operandos.removeAt(index);
      _numeralizacoes.removeWhere((n) => n.campo == chave);
      if (_operadores.isNotEmpty) {
        final removerGap = index > 0 ? index - 1 : 0;
        _operadores.removeAt(removerGap.clamp(0, _operadores.length - 1));
      }
    });
  }

  void _adicionarRegra() => setState(() => _regras.add(_RegraForm()));

  void _removerRegra(int index) {
    setState(() {
      _regras[index].dispose();
      _regras.removeAt(index);
    });
  }

  List<RegraColunaCalculada> get _regrasValidas {
    final regras = <RegraColunaCalculada>[];
    for (final r in _regras) {
      final valor = double.tryParse(r.valorController.text.trim().replaceAll(',', '.'));
      final texto = r.textoController.text.trim();
      if (valor == null || texto.isEmpty) continue;
      regras.add(RegraColunaCalculada(operador: r.operador, valorComparacao: valor, textoResultado: texto));
    }
    return regras;
  }

  void _confirmar() {
    final rotulo = _rotuloController.text.trim();
    if (rotulo.isEmpty || _operandos.length < 2) return;
    final usaTexto = _modoResultado == _ModoResultadoFormula.textoCondicional;
    final coluna = ResumoColuna(
      id: widget.existente?.id ?? 'calc_${DateTime.now().millisecondsSinceEpoch}',
      rotulo: rotulo,
      tipo: TipoResumoColuna.calculada,
      operandos: _operandos.map((o) => o.chave).toList(),
      operadores: List.of(_operadores),
      numeralizacoes: List.of(_numeralizacoes),
      regras: usaTexto ? _regrasValidas : const [],
      textoPadrao: usaTexto && _textoPadraoController.text.trim().isNotEmpty ? _textoPadraoController.text.trim() : null,
      casasDecimais: _casasDecimais,
    );
    Navigator.pop(context, coluna);
  }

  @override
  Widget build(BuildContext context) {
    final usaTexto = _modoResultado == _ModoResultadoFormula.textoCondicional;
    final podeConfirmar = _rotuloController.text.trim().isNotEmpty &&
        _operandos.length >= 2 &&
        (!usaTexto || _regrasValidas.isNotEmpty);
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.functions, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.existente == null ? 'Coluna personalizada (fórmula)' : 'Editar coluna personalizada',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Multiplique, some, subtraia ou divida variáveis do relatório e, se quiser, gere um texto a partir do resultado.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _rotuloController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Nome da coluna',
                          hintText: 'Ex: CP',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Fórmula', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      const Text(
                        'Toque no símbolo entre duas variáveis pra trocar a operação — dá pra misturar, ex: A × B + C.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      if (_operandos.isNotEmpty) ...[
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var i = 0; i < _operandos.length; i++) ...[
                              if (i > 0) _buildOperadorPill(i - 1),
                              _numeralizacoes.any((n) => n.campo == _operandos[i].chave)
                                  ? InputChip(
                                      avatar: const Icon(Icons.tag, size: 16),
                                      label: Text(_operandos[i].rotulo),
                                      onPressed: () => _editarNumeralizacao(i),
                                      onDeleted: () => _removerOperando(i),
                                      deleteIconColor: Colors.red,
                                    )
                                  : Chip(
                                      label: Text(_operandos[i].rotulo),
                                      onDeleted: () => _removerOperando(i),
                                      deleteIconColor: Colors.red,
                                    ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextButton.icon(
                        onPressed: _adicionarOperando,
                        icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                        label: const Text('Adicionar variável', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                      const Divider(height: 32),
                      const Text('O que essa coluna deve mostrar?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Valor numérico da fórmula'),
                            selected: !usaTexto,
                            onSelected: (_) => setState(() => _modoResultado = _ModoResultadoFormula.numero),
                          ),
                          ChoiceChip(
                            label: const Text('Texto condicional'),
                            selected: usaTexto,
                            onSelected: (_) => setState(() => _modoResultado = _ModoResultadoFormula.textoCondicional),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!usaTexto)
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Casas decimais', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: _casasDecimais > 0 ? () => setState(() => _casasDecimais--) : null,
                              icon: const Icon(Icons.remove_circle_outline, size: 20),
                            ),
                            Text('$_casasDecimais', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: _casasDecimais < 4 ? () => setState(() => _casasDecimais++) : null,
                              icon: const Icon(Icons.add_circle_outline, size: 20),
                            ),
                          ],
                        )
                      else ...[
                        const Text(
                          'Ex: se o resultado for maior que 20, mostrar "Necessidade de intervenção" em vez do número.',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                        const SizedBox(height: 10),
                        for (var i = 0; i < _regras.length; i++) _buildRegraLinha(i),
                        TextButton.icon(
                          onPressed: _adicionarRegra,
                          icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                          label: const Text('Adicionar regra', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _textoPadraoController,
                          decoration: const InputDecoration(
                            labelText: 'Texto padrão (senão)',
                            hintText: 'Ex: Sem necessidade de intervenção',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: podeConfirmar ? _confirmar : null,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    child: Text(widget.existente == null ? 'Adicionar coluna' : 'Salvar alterações'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperadorPill(int gap) {
    final operador = _operadores[gap];
    return PopupMenuButton<OperadorFormula>(
      tooltip: 'Trocar a operação',
      initialValue: operador,
      onSelected: (op) => setState(() => _operadores[gap] = op),
      itemBuilder: (context) => [
        for (final op in OperadorFormula.values)
          PopupMenuItem(value: op, child: Text('${op.simbolo}  ${op.rotulo}')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Text(operador.simbolo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
      ),
    );
  }

  Widget _buildRegraLinha(int index) {
    final regra = _regras[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Se o resultado for...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _removerRegra(index),
                icon: const Icon(Icons.close, size: 18, color: Colors.red),
              ),
            ],
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              DropdownButton<OperadorCondicional>(
                value: regra.operador,
                isDense: true,
                items: const [
                  DropdownMenuItem(value: OperadorCondicional.maiorQue, child: Text('maior que')),
                  DropdownMenuItem(value: OperadorCondicional.menorQue, child: Text('menor que')),
                  DropdownMenuItem(value: OperadorCondicional.igual, child: Text('igual a')),
                  DropdownMenuItem(value: OperadorCondicional.diferente, child: Text('diferente de')),
                ],
                onChanged: (v) => setState(() => regra.operador = v ?? regra.operador),
              ),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: regra.valorController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: regra.textoController,
            decoration: const InputDecoration(
              labelText: 'então mostrar o texto',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegraNumeralizacaoForm {
  final valorController = TextEditingController();
  final numeroController = TextEditingController();

  _RegraNumeralizacaoForm({String valor = '', String numero = ''}) {
    valorController.text = valor;
    numeroController.text = numero;
  }

  void dispose() {
    valorController.dispose();
    numeroController.dispose();
  }
}

// "Numeralizar" um campo categórico (ex: CAA) pra poder usar dentro de uma
// fórmula: o usuário lista os valores possíveis do campo (ex: "I", "II",
// "III", "IV") e o número que cada um vale (ex: CAA "II" = 40), mais um
// valor padrão pra quando a linha não bater com nenhuma regra.
class _NumeralizacaoDialog extends StatefulWidget {
  final CampoCatalogo campo;
  final NumeralizacaoCampo? existente;
  const _NumeralizacaoDialog({required this.campo, this.existente});

  @override
  State<_NumeralizacaoDialog> createState() => _NumeralizacaoDialogState();
}

class _NumeralizacaoDialogState extends State<_NumeralizacaoDialog> {
  late final List<_RegraNumeralizacaoForm> _regras;
  late final TextEditingController _padraoController;

  @override
  void initState() {
    super.initState();
    final existente = widget.existente;
    _regras = existente == null || existente.regras.isEmpty
        ? [_RegraNumeralizacaoForm()]
        : existente.regras.map((r) => _RegraNumeralizacaoForm(valor: r.valor, numero: r.numero.toString())).toList();
    _padraoController = TextEditingController(text: existente != null ? existente.padrao.toString() : '0');
  }

  @override
  void dispose() {
    for (final r in _regras) {
      r.dispose();
    }
    _padraoController.dispose();
    super.dispose();
  }

  void _adicionarRegra() => setState(() => _regras.add(_RegraNumeralizacaoForm()));

  void _removerRegra(int index) {
    if (_regras.length == 1) return;
    setState(() {
      _regras[index].dispose();
      _regras.removeAt(index);
    });
  }

  void _confirmar() {
    final regras = <RegraNumeralizacao>[];
    for (final r in _regras) {
      final valor = r.valorController.text.trim();
      final numero = double.tryParse(r.numeroController.text.trim().replaceAll(',', '.'));
      if (valor.isEmpty || numero == null) continue;
      regras.add(RegraNumeralizacao(valor: valor, numero: numero));
    }
    if (regras.isEmpty) return;
    final padrao = double.tryParse(_padraoController.text.trim().replaceAll(',', '.')) ?? 0;
    Navigator.pop(context, NumeralizacaoCampo(campo: widget.campo.chave, regras: regras, padrao: padrao));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tag, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Numeralizar "${widget.campo.rotulo}"', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '"${widget.campo.rotulo}" é um texto — diga que número cada valor possível representa pra poder usá-lo na fórmula. Ex: CAA "II" = 40.',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < _regras.length; i++) _buildRegraLinha(i),
                      TextButton.icon(
                        onPressed: _adicionarRegra,
                        icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                        label: const Text('Adicionar valor', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _padraoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Valor padrão (se não bater com nenhum acima)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _confirmar,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    child: const Text('Confirmar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegraLinha(int index) {
    final regra = _regras[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: regra.valorController,
              decoration: const InputDecoration(labelText: 'Valor (ex: II)', isDense: true, border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 8),
          const Text('=', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: TextField(
              controller: regra.numeroController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Número', isDense: true, border: OutlineInputBorder()),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _regras.length > 1 ? () => _removerRegra(index) : null,
            icon: const Icon(Icons.close, size: 18, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
