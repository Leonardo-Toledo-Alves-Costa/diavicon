import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/paleta_cores.dart';
import '../models/quadro_model.dart';

// Editor de regras de decoração condicional de um slot de texto: a primeira
// regra (na ordem da lista) cujo campo de referência bater com o valor de
// comparação define a cor do texto e do fundo. Ex: "GUT > 500 -> fundo âmbar".
class DecoracaoCondicionalScreen extends StatefulWidget {
  final List<RegraCondicional> regras;
  final List<CampoCatalogo> catalogo;

  const DecoracaoCondicionalScreen({super.key, required this.regras, required this.catalogo});

  @override
  State<DecoracaoCondicionalScreen> createState() => _DecoracaoCondicionalScreenState();
}

class _DecoracaoCondicionalScreenState extends State<DecoracaoCondicionalScreen> {
  late List<RegraCondicional> _regras;

  @override
  void initState() {
    super.initState();
    _regras = List.from(widget.regras);
  }

  void _adicionarRegra() {
    setState(() {
      _regras = [
        ..._regras,
        RegraCondicional(
          campoReferencia: widget.catalogo.first.chave,
          operador: OperadorCondicional.igual,
          valorComparacao: '',
          corTexto: 'preto',
          corFundo: 'branco',
        ),
      ];
    });
  }

  void _atualizarRegra(int index, RegraCondicional regra) {
    setState(() {
      final novas = List<RegraCondicional>.from(_regras);
      novas[index] = regra;
      _regras = novas;
    });
  }

  void _removerRegra(int index) {
    setState(() {
      final novas = List<RegraCondicional>.from(_regras)..removeAt(index);
      _regras = novas;
    });
  }

  void _moverRegra(int index, int delta) {
    final novoIndex = index + delta;
    if (novoIndex < 0 || novoIndex >= _regras.length) return;
    setState(() {
      final novas = List<RegraCondicional>.from(_regras);
      final item = novas.removeAt(index);
      novas.insert(novoIndex, item);
      _regras = novas;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Condição'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _regras),
            child: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'A primeira regra que bater com o valor do campo define a cor. Se nenhuma bater, usa a cor padrão do texto.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _regras.length; i++) _buildRegra(i),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _adicionarRegra,
            icon: const Icon(Icons.add, color: AppColors.primary),
            label: const Text('Adicionar regra', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRegra(int index) {
    final regra = _regras[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Regra ${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
              const Spacer(),
              InkWell(onTap: index > 0 ? () => _moverRegra(index, -1) : null, child: Icon(Icons.keyboard_arrow_up, size: 18, color: index > 0 ? Colors.black54 : Colors.black26)),
              InkWell(
                onTap: index < _regras.length - 1 ? () => _moverRegra(index, 1) : null,
                child: Icon(Icons.keyboard_arrow_down, size: 18, color: index < _regras.length - 1 ? Colors.black54 : Colors.black26),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _removerRegra(index),
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: widget.catalogo.any((c) => c.chave == regra.campoReferencia) ? regra.campoReferencia : widget.catalogo.first.chave,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Campo', isDense: true),
                  items: widget.catalogo.map((c) => DropdownMenuItem(value: c.chave, child: Text(c.rotulo, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) {
                    if (v != null) _atualizarRegra(index, regra.copyWith(campoReferencia: v));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<OperadorCondicional>(
                  initialValue: regra.operador,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Operador', isDense: true),
                  items: OperadorCondicional.values.map((o) => DropdownMenuItem(value: o, child: Text(o.rotulo))).toList(),
                  onChanged: (v) {
                    if (v != null) _atualizarRegra(index, regra.copyWith(operador: v));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: regra.valorComparacao,
                  decoration: const InputDecoration(labelText: 'Valor', isDense: true),
                  onChanged: (v) => _atualizarRegra(index, regra.copyWith(valorComparacao: v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Cor do texto', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          SeletorCorChips(
            selecionada: regra.corTexto,
            onSelecionada: (cor) => _atualizarRegra(index, regra.copyWith(corTexto: cor)),
          ),
          const SizedBox(height: 12),
          const Text('Cor do fundo', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          SeletorCorChips(
            selecionada: regra.corFundo,
            onSelecionada: (cor) => _atualizarRegra(index, regra.copyWith(corFundo: cor)),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: corDaPaleta(regra.corFundo), borderRadius: BorderRadius.circular(6)),
              child: Text(
                'Exemplo: ${widget.catalogo.firstWhere((c) => c.chave == regra.campoReferencia, orElse: () => widget.catalogo.first).rotulo} ${regra.operador.rotulo} "${regra.valorComparacao}"',
                style: TextStyle(color: corDaPaleta(regra.corTexto), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
