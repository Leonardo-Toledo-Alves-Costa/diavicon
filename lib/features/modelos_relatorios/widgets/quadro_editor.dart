import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/quadro_model.dart';
import '../screens/decoracao_condicional_screen.dart';

// Editor reutilizável de Quadro: Linha -> Divisão -> Slot. Usado por
// Cabeçalho e Registros, e recursivamente pelo Bloco de anomalias (o mesmo
// widget renderiza o `quadroAninhado` de um slot do tipo `anomalias`).
class QuadroEditor extends StatefulWidget {
  final Quadro quadro;
  final ValueChanged<Quadro> onChanged;
  final List<CampoCatalogo> catalogo;
  final List<TipoConteudoSlot> tiposPermitidos;
  final String? legendaRepeticao;
  final bool somenteLeitura;
  final bool aninhado;
  // Só usados quando `tiposPermitidos` inclui `TipoConteudoSlot.subLista` —
  // catálogo e rótulo do bloco aninhado genérico (ex: "Pontos de leitura"
  // da Resistividade), mesmo mecanismo do Bloco de anomalias.
  final List<CampoCatalogo>? catalogoSubLista;
  final String? rotuloSubLista;

  const QuadroEditor({
    super.key,
    required this.quadro,
    required this.onChanged,
    required this.catalogo,
    required this.tiposPermitidos,
    this.legendaRepeticao,
    this.somenteLeitura = false,
    this.aninhado = false,
    this.catalogoSubLista,
    this.rotuloSubLista,
  });

  @override
  State<QuadroEditor> createState() => _QuadroEditorState();
}

class _QuadroEditorState extends State<QuadroEditor> {
  // ids de divisão com o editor de bloco aninhado aberto (anomalias ou
  // sub-lista genérica).
  final Set<String> _blocosAninhadosAbertos = {};

  void _atualizar(List<LinhaQuadro> linhas) => widget.onChanged(widget.quadro.copyWith(linhas: linhas));

  void _adicionarLinha() {
    _atualizar([...widget.quadro.linhas, LinhaQuadro.nova()]);
  }

  void _moverLinha(int index, int delta) {
    final linhas = List<LinhaQuadro>.from(widget.quadro.linhas);
    final novoIndex = index + delta;
    if (novoIndex < 0 || novoIndex >= linhas.length) return;
    final item = linhas.removeAt(index);
    linhas.insert(novoIndex, item);
    _atualizar(linhas);
  }

  void _removerLinha(int index) {
    final linhas = List<LinhaQuadro>.from(widget.quadro.linhas)..removeAt(index);
    _atualizar(linhas);
  }

  void _adicionarDivisao(int linhaIndex) {
    final linhas = List<LinhaQuadro>.from(widget.quadro.linhas);
    final linha = linhas[linhaIndex];
    final novaLargura = 100.0 / (linha.divisoes.length + 1);
    final divisoesAtualizadas = linha.divisoes
        .map((d) => d.copyWith(larguraPercentual: d.larguraPercentual * (1 - novaLargura / 100)))
        .toList()
      ..add(DivisaoQuadro(id: gerarIdQuadro(), larguraPercentual: novaLargura));
    linhas[linhaIndex] = linha.copyWith(divisoes: divisoesAtualizadas).normalizada();
    _atualizar(linhas);
  }

  void _removerDivisao(int linhaIndex) {
    final linhas = List<LinhaQuadro>.from(widget.quadro.linhas);
    final linha = linhas[linhaIndex];
    if (linha.divisoes.length <= 1) return;
    final divisoes = List<DivisaoQuadro>.from(linha.divisoes)..removeLast();
    linhas[linhaIndex] = linha.copyWith(divisoes: divisoes).normalizada();
    _atualizar(linhas);
  }

  // Só é chamado quando o usuário sai do campo (perde o foco / confirma) —
  // nunca a cada tecla, pra não brigar com quem está digitando/apagando.
  void _confirmarLargura(int linhaIndex, int divisaoIndex, double novaLargura) {
    final linhas = List<LinhaQuadro>.from(widget.quadro.linhas);
    final linha = linhas[linhaIndex];
    final divisoes = List<DivisaoQuadro>.from(linha.divisoes);
    final valor = novaLargura.clamp(0.0, 100.0);

    if (divisoes.length == 2) {
      final outroIndex = divisaoIndex == 0 ? 1 : 0;
      divisoes[divisaoIndex] = divisoes[divisaoIndex].copyWith(larguraPercentual: valor);
      divisoes[outroIndex] = divisoes[outroIndex].copyWith(larguraPercentual: 100 - valor);
    } else {
      divisoes[divisaoIndex] = divisoes[divisaoIndex].copyWith(larguraPercentual: valor);
    }
    linhas[linhaIndex] = linha.copyWith(divisoes: divisoes);
    _atualizar(linhas);
  }

  void _definirConteudo(int linhaIndex, int divisaoIndex, ConteudoSlot? conteudo) {
    final linhas = List<LinhaQuadro>.from(widget.quadro.linhas);
    final linha = linhas[linhaIndex];
    final divisoes = List<DivisaoQuadro>.from(linha.divisoes);
    divisoes[divisaoIndex] = divisoes[divisaoIndex].copyWith(conteudo: conteudo, removerConteudo: conteudo == null);
    linhas[linhaIndex] = linha.copyWith(divisoes: divisoes);
    _atualizar(linhas);
  }

  Future<T?> _abrirListaBottomSheet<T>(String titulo, List<Widget> itens) {
    return showModalBottomSheet<T>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      // Altura máxima explícita + ListView (não Column) garante que listas
      // longas rolem dentro do sheet em vez de estourar a tela.
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ...itens,
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirSeletorDeSlot(int linhaIndex, int divisaoIndex) async {
    final linha = widget.quadro.linhas[linhaIndex];
    final tiposDisponiveis =
        linha.divisoes.length > 1 ? widget.tiposPermitidos.where((t) => !t.ehBloco).toList() : widget.tiposPermitidos;

    final tipoEscolhido = await _abrirListaBottomSheet<TipoConteudoSlot>('O que vai aqui?', [
      for (final tipo in tiposDisponiveis)
        ListTile(title: Text(tipo.rotulo), onTap: () => Navigator.pop(context, tipo)),
    ]);

    if (tipoEscolhido == null) return;

    switch (tipoEscolhido) {
      case TipoConteudoSlot.texto:
      case TipoConteudoSlot.imagem:
      case TipoConteudoSlot.matriz:
        // Cada tipo de slot só oferece campos do catálogo do MESMO tipo —
        // matriz tem seu próprio `TipoCampoCatalogo.matriz` (ver
        // TipoConteudoSlot.matriz), então não aparece no seletor de texto e
        // vice-versa.
        final tipoCampo = switch (tipoEscolhido) {
          TipoConteudoSlot.imagem => TipoCampoCatalogo.imagem,
          TipoConteudoSlot.matriz => TipoCampoCatalogo.matriz,
          _ => TipoCampoCatalogo.texto,
        };
        final opcoes = widget.catalogo.where((c) => c.tipo == tipoCampo).toList();
        if (!mounted) return;
        final campo = await _abrirListaBottomSheet<CampoCatalogo>('Qual campo?', [
          for (final campo in opcoes) ListTile(title: Text(campo.rotulo), onTap: () => Navigator.pop(context, campo)),
        ]);
        if (campo == null) return;
        _definirConteudo(linhaIndex, divisaoIndex, ConteudoSlot(tipo: tipoEscolhido, campoVinculado: campo.chave));
        break;
      case TipoConteudoSlot.galeria:
        final config = await _pedirConfigGaleria(3, true);
        if (config == null) return;
        _definirConteudo(
          linhaIndex,
          divisaoIndex,
          ConteudoSlot(tipo: TipoConteudoSlot.galeria, colunas: config.colunas, mostrarDescricao: config.mostrarDescricao),
        );
        break;
      case TipoConteudoSlot.anomalias:
        _definirConteudo(
          linhaIndex,
          divisaoIndex,
          const ConteudoSlot(tipo: TipoConteudoSlot.anomalias, quadroAninhado: Quadro(linhas: [])),
        );
        break;
      case TipoConteudoSlot.subLista:
        _definirConteudo(
          linhaIndex,
          divisaoIndex,
          const ConteudoSlot(tipo: TipoConteudoSlot.subLista, quadroAninhado: Quadro(linhas: [])),
        );
        break;
    }
  }

  Future<_ConfigGaleriaEscolhida?> _pedirConfigGaleria(int colunasAtual, bool mostrarDescricaoAtual) async {
    int colunas = colunasAtual;
    bool mostrarDescricao = mostrarDescricaoAtual;
    return showDialog<_ConfigGaleriaEscolhida>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Galeria de fotos'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Número de colunas', style: TextStyle(fontSize: 12, color: Colors.black54)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: colunas > 2 ? () => setDialogState(() => colunas--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(colunas.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: colunas < 6 ? () => setDialogState(() => colunas++) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mostrar descrição junto às fotos', style: TextStyle(fontSize: 13)),
                value: mostrarDescricao,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setDialogState(() => mostrarDescricao = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, _ConfigGaleriaEscolhida(colunas, mostrarDescricao)),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirMenuSlot(int linhaIndex, int divisaoIndex) async {
    final divisao = widget.quadro.linhas[linhaIndex].divisoes[divisaoIndex];
    final conteudo = divisao.conteudo!;
    final ehTexto = conteudo.tipo == TipoConteudoSlot.texto;
    final ehImagem = conteudo.tipo == TipoConteudoSlot.imagem;

    final acao = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Editar'), onTap: () => Navigator.pop(context, 'editar')),
            if (ehTexto)
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Condição (cor por valor)'),
                onTap: () => Navigator.pop(context, 'condicao'),
              ),
            if (ehImagem)
              ListTile(
                leading: const Icon(Icons.photo_size_select_large_outlined),
                title: const Text('Tamanho da imagem'),
                onTap: () => Navigator.pop(context, 'tamanho_imagem'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remover', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, 'remover'),
            ),
          ],
        ),
      ),
    );

    if (acao == 'remover') {
      _definirConteudo(linhaIndex, divisaoIndex, null);
    } else if (acao == 'editar') {
      if (conteudo.tipo == TipoConteudoSlot.galeria) {
        final config = await _pedirConfigGaleria(conteudo.colunas, conteudo.mostrarDescricao);
        if (config == null) return;
        _definirConteudo(
          linhaIndex,
          divisaoIndex,
          conteudo.copyWith(colunas: config.colunas, mostrarDescricao: config.mostrarDescricao),
        );
      } else {
        _abrirSeletorDeSlot(linhaIndex, divisaoIndex);
      }
    } else if (acao == 'condicao') {
      if (!mounted) return;
      final novasRegras = await Navigator.push<List<RegraCondicional>>(
        context,
        MaterialPageRoute(
          builder: (_) => DecoracaoCondicionalScreen(
            regras: conteudo.decoracaoCondicional,
            catalogo: widget.catalogo,
          ),
        ),
      );
      if (novasRegras != null) {
        _definirConteudo(linhaIndex, divisaoIndex, conteudo.copyWith(decoracaoCondicional: novasRegras));
      }
    } else if (acao == 'tamanho_imagem') {
      final resultado = await _pedirTamanhoImagem(conteudo.alturaImagem, conteudo.ajusteImagem);
      if (resultado == null) return;
      _definirConteudo(linhaIndex, divisaoIndex, conteudo.copyWith(alturaImagem: resultado.altura, ajusteImagem: resultado.ajuste));
    }
  }

  Future<_ConfigImagemEscolhida?> _pedirTamanhoImagem(double alturaAtual, AjusteImagem ajusteAtual) async {
    double altura = alturaAtual;
    AjusteImagem ajuste = ajusteAtual;
    return showDialog<_ConfigImagemEscolhida>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tamanho da imagem'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Altura da linha (px)', style: TextStyle(fontSize: 12, color: Colors.black54)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: altura > 60 ? () => setDialogState(() => altura -= 20) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(altura.round().toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: altura < 500 ? () => setDialogState(() => altura += 20) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Ajuste', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 6),
              Row(
                children: AjusteImagem.values.map((a) {
                  final ativo = a == ajuste;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(a.rotulo),
                      selected: ativo,
                      onSelected: (_) => setDialogState(() => ajuste = a),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, _ConfigImagemEscolhida(altura, ajuste)), child: const Text('OK')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (widget.legendaRepeticao != null)
              Expanded(
                child: Text(widget.legendaRepeticao!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              )
            else
              const Spacer(),
            if (!widget.somenteLeitura)
              TextButton.icon(
                onPressed: _adicionarLinha,
                icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                label: const Text('linha', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        for (var i = 0; i < widget.quadro.linhas.length; i++) _buildLinha(i),
      ],
    );
  }

  Widget _buildLinha(int linhaIndex) {
    final linha = widget.quadro.linhas[linhaIndex];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.aninhado ? const Color(0xFFE8EEFB) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              InkWell(
                onTap: linhaIndex > 0 ? () => _moverLinha(linhaIndex, -1) : null,
                child: Icon(Icons.keyboard_arrow_up, size: 18, color: linhaIndex > 0 ? Colors.black54 : Colors.black26),
              ),
              InkWell(
                onTap: linhaIndex < widget.quadro.linhas.length - 1 ? () => _moverLinha(linhaIndex, 1) : null,
                child: Icon(Icons.keyboard_arrow_down, size: 18,
                    color: linhaIndex < widget.quadro.linhas.length - 1 ? Colors.black54 : Colors.black26),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var d = 0; d < linha.divisoes.length; d++) ...[
                      if (d > 0) const SizedBox(width: 8),
                      Expanded(
                        flex: linha.divisoes[d].larguraPercentual.round().clamp(1, 100),
                        child: _buildSlot(linhaIndex, d),
                      ),
                    ],
                  ],
                ),
                if (linha.divisoes.length > 1) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (var d = 0; d < linha.divisoes.length; d++) ...[
                        if (d > 0) const SizedBox(width: 8),
                        Expanded(
                          flex: linha.divisoes[d].larguraPercentual.round().clamp(1, 100),
                          child: _CampoLargura(
                            key: ValueKey(linha.divisoes[d].id),
                            valorInicial: linha.divisoes[d].larguraPercentual,
                            habilitado: !widget.somenteLeitura,
                            onConfirmado: (n) => _confirmarLargura(linhaIndex, d, n),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (!widget.somenteLeitura && !linha.ehBloco)
                      TextButton(
                        onPressed: () => _adicionarDivisao(linhaIndex),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                        child: const Text('+ divisão', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                      ),
                    if (!widget.somenteLeitura && !linha.ehBloco && linha.divisoes.length > 1) ...[
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () => _removerDivisao(linhaIndex),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                        child: const Text('− divisão', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                      ),
                    ],
                    const Spacer(),
                    if (!widget.somenteLeitura)
                      TextButton(
                        onPressed: () => _removerLinha(linhaIndex),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                        child: const Text('Remover linha', style: TextStyle(fontSize: 12, color: Colors.red)),
                      ),
                  ],
                ),
                if (linha.ehBloco &&
                    (linha.divisoes.first.conteudo!.tipo == TipoConteudoSlot.anomalias ||
                        linha.divisoes.first.conteudo!.tipo == TipoConteudoSlot.subLista))
                  _buildEditorAninhado(linhaIndex, linha.divisoes.first),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlot(int linhaIndex, int divisaoIndex) {
    final divisao = widget.quadro.linhas[linhaIndex].divisoes[divisaoIndex];
    final conteudo = divisao.conteudo;

    if (conteudo == null) {
      return InkWell(
        onTap: widget.somenteLeitura ? null : () => _abrirSeletorDeSlot(linhaIndex, divisaoIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: Colors.black12, width: 1), borderRadius: BorderRadius.circular(6)),
          child: const Text('+ Toque para adicionar', style: TextStyle(fontSize: 11, color: Colors.black38)),
        ),
      );
    }

    if (conteudo.tipo == TipoConteudoSlot.anomalias || conteudo.tipo == TipoConteudoSlot.subLista) {
      final aberto = _blocosAninhadosAbertos.contains(divisao.id);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => setState(() {
              aberto ? _blocosAninhadosAbertos.remove(divisao.id) : _blocosAninhadosAbertos.add(divisao.id);
            }),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
            child: Text(aberto ? 'Fechar' : 'Abrir editor', style: const TextStyle(fontSize: 13, color: AppColors.primary)),
          ),
          if (!widget.somenteLeitura) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => _definirConteudo(linhaIndex, divisaoIndex, null),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
              child: const Text('Remover', style: TextStyle(fontSize: 13, color: Colors.red)),
            ),
          ],
        ],
      );
    }

    String rotulo;
    bool ehCampo = false;
    switch (conteudo.tipo) {
      case TipoConteudoSlot.texto:
      case TipoConteudoSlot.imagem:
      case TipoConteudoSlot.matriz:
        rotulo = buscarCampo(widget.catalogo, conteudo.campoVinculado)?.rotulo ?? '(campo removido)';
        ehCampo = true;
        break;
      case TipoConteudoSlot.galeria:
        rotulo = 'Galeria de fotos (${conteudo.colunas} col.)';
        break;
      case TipoConteudoSlot.anomalias:
        rotulo = 'Bloco de anomalias';
        break;
      case TipoConteudoSlot.subLista:
        rotulo = widget.rotuloSubLista ?? 'Sub-lista';
        break;
    }

    final temCondicao = conteudo.tipo == TipoConteudoSlot.texto && conteudo.decoracaoCondicional.isNotEmpty;

    return InkWell(
      onTap: widget.somenteLeitura ? null : () => _abrirMenuSlot(linhaIndex, divisaoIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ehCampo ? '«$rotulo»' : rotulo,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ehCampo ? const Color(0xFFB05A00) : const Color(0xFF3E3E3D)),
            ),
            if (temCondicao) ...[
              const SizedBox(height: 4),
              const Icon(Icons.palette_outlined, size: 14, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditorAninhado(int linhaIndex, DivisaoQuadro divisao) {
    if (!_blocosAninhadosAbertos.contains(divisao.id)) return const SizedBox.shrink();

    final ehAnomalias = divisao.conteudo!.tipo == TipoConteudoSlot.anomalias;
    final catalogoAninhado = ehAnomalias ? camposAnomalia : (widget.catalogoSubLista ?? const <CampoCatalogo>[]);
    final tituloAninhado = ehAnomalias ? 'Bloco de anomalias' : (widget.rotuloSubLista ?? 'Sub-lista');

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB9CBF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.black45),
              const SizedBox(width: 4),
              Text('Editando: $tituloAninhado', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
            ],
          ),
          QuadroEditor(
            quadro: divisao.conteudo!.quadroAninhado ?? const Quadro(linhas: []),
            catalogo: catalogoAninhado,
            tiposPermitidos: const [TipoConteudoSlot.texto, TipoConteudoSlot.imagem, TipoConteudoSlot.matriz],
            somenteLeitura: widget.somenteLeitura,
            aninhado: true,
            onChanged: (novoQuadroAninhado) {
              // Uma linha-bloco (galeria/anomalias/subLista) sempre tem
              // exatamente 1 divisão, então o índice é sempre 0.
              _definirConteudo(
                linhaIndex,
                0,
                divisao.conteudo!.copyWith(quadroAninhado: novoQuadroAninhado),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ConfigGaleriaEscolhida {
  final int colunas;
  final bool mostrarDescricao;
  const _ConfigGaleriaEscolhida(this.colunas, this.mostrarDescricao);
}

class _ConfigImagemEscolhida {
  final double altura;
  final AjusteImagem ajuste;
  const _ConfigImagemEscolhida(this.altura, this.ajuste);
}

// Campo de % com controller/foco próprios: o usuário pode apagar, zerar ou
// digitar livremente, e só quando sai do campo (perde o foco / confirma) é
// que o valor é aplicado — evita que o campo "pule" enquanto digita.
class _CampoLargura extends StatefulWidget {
  final double valorInicial;
  final bool habilitado;
  final ValueChanged<double> onConfirmado;

  const _CampoLargura({super.key, required this.valorInicial, required this.habilitado, required this.onConfirmado});

  @override
  State<_CampoLargura> createState() => _CampoLarguraState();
}

class _CampoLarguraState extends State<_CampoLargura> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late double _ultimoValorConfirmado;

  @override
  void initState() {
    super.initState();
    _ultimoValorConfirmado = widget.valorInicial;
    _controller = TextEditingController(text: widget.valorInicial.round().toString());
    _focusNode = FocusNode()..addListener(_aoMudarFoco);
  }

  @override
  void didUpdateWidget(covariant _CampoLargura old) {
    super.didUpdateWidget(old);
    // Só sincroniza com o valor externo (ex: rebalanceado pela outra divisão)
    // quando o campo não está em edição, pra não atropelar o usuário digitando.
    if (!_focusNode.hasFocus && old.valorInicial != widget.valorInicial) {
      _ultimoValorConfirmado = widget.valorInicial;
      _controller.text = widget.valorInicial.round().toString();
    }
  }

  void _aoMudarFoco() {
    if (!_focusNode.hasFocus) _confirmar();
  }

  void _confirmar() {
    final n = double.tryParse(_controller.text);
    if (n == null) {
      _controller.text = _ultimoValorConfirmado.round().toString();
      return;
    }
    _ultimoValorConfirmado = n.clamp(0.0, 100.0);
    _controller.text = _ultimoValorConfirmado.round().toString();
    widget.onConfirmado(_ultimoValorConfirmado);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_aoMudarFoco);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.habilitado,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        suffixText: '%',
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
      onFieldSubmitted: (_) => _confirmar(),
    );
  }
}
