import 'package:flutter/material.dart';

enum ModoSelecaoEstrutura { unica, grupo }

class NovoRelatorioModal extends StatefulWidget {
  const NovoRelatorioModal({super.key});

  @override
  State<NovoRelatorioModal> createState() => _NovoRelatorioModalState();
}

class _NovoRelatorioModalState extends State<NovoRelatorioModal> {
  static const Color corLaranja = Color(0xFFF5A623);
  static const Color corTexto = Color(0xFF3A3A3A);

  final TextEditingController _nomeController = TextEditingController();

  ModoSelecaoEstrutura _modoEstrutura = ModoSelecaoEstrutura.unica;
  final List<String> _estruturasDisponiveis = const [
    'Und. Britador 1',
    'Decantador Sul',
    'Barragem Norte',
    'Reservatório Central',
  ];
  final List<String> _estruturasSelecionadas = [];

  final List<String> _empresasDisponiveis = const [
    'P&D Engenharia',
    'Housing Engenharia',
    'HMCM Engenharia',
    'Inspecione Engenharia',
  ];
  final List<String> _empresasSelecionadas = [];

  final int _tokensUtilizados = 6;
  final int _tokensLimite = 10;

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCabecalho(context),
            const SizedBox(height: 20),
            _buildRotulo('Nome do Relatório'),
            const SizedBox(height: 6),
            _buildCampoNome(),
            const SizedBox(height: 16),
            _buildRotulo('Estruturas'),
            const SizedBox(height: 6),
            _buildSeletorEstruturas(context),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildRotulo('Dados das Empresas'),
                const SizedBox(width: 6),
                const Icon(Icons.info_outline, size: 16, color: corTexto),
              ],
            ),
            const SizedBox(height: 6),
            _buildSeletorEmpresas(context),
            const SizedBox(height: 24),
            _buildRodape(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCabecalho(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Novo Relatório',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.grey),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildRotulo(String texto) {
    return RichText(
      text: TextSpan(
        text: texto,
        style: const TextStyle(fontSize: 15, color: corTexto),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoNome() {
    return TextField(
      controller: _nomeController,
      decoration: InputDecoration(
        hintText: 'Nome',
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
        ),
      ),
    );
  }

  Widget _buildSeletorEstruturas(BuildContext context) {
    final String textoResumo = _estruturasSelecionadas.isEmpty
        ? 'Selecione'
        : _estruturasSelecionadas.join(', ');

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _abrirSeletorEstruturas(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD0D0D0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      textoResumo,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _estruturasSelecionadas.isEmpty ? Colors.grey : corTexto,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: () => _abrirModoSelecaoEstrutura(context),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD0D0D0)),
            ),
            child: const Icon(Icons.tune, color: corLaranja),
          ),
        ),
      ],
    );
  }

  Widget _buildSeletorEmpresas(BuildContext context) {
    final String textoResumo = _empresasSelecionadas.isEmpty
        ? 'Selecione'
        : '${_empresasSelecionadas.length} selecionada(s)';

    return InkWell(
      onTap: () => _abrirSeletorEmpresas(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD0D0D0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                textoResumo,
                style: TextStyle(
                  color: _empresasSelecionadas.isEmpty ? Colors.grey : corTexto,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildRodape(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Tokens Utilizados: $_tokensUtilizados/$_tokensLimite',
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        ElevatedButton(
          onPressed: _podeGerar() ? () => _gerarRelatorio(context) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: corLaranja,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            elevation: 0,
          ),
          child: const Text(
            'Gerar',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  bool _podeGerar() {
    return _nomeController.text.isNotEmpty &&
        _estruturasSelecionadas.isNotEmpty &&
        _empresasSelecionadas.isNotEmpty;
  }

  void _abrirModoSelecaoEstrutura(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ModoSelecaoEstrutura>(
                title: const Text('Estrutura única'),
                value: ModoSelecaoEstrutura.unica,
                groupValue: _modoEstrutura,
                activeColor: corLaranja,
                onChanged: (valor) {
                  setState(() {
                    _modoEstrutura = valor!;
                    _estruturasSelecionadas.clear();
                  });
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<ModoSelecaoEstrutura>(
                title: const Text('Grupo de estruturas'),
                value: ModoSelecaoEstrutura.grupo,
                groupValue: _modoEstrutura,
                activeColor: corLaranja,
                onChanged: (valor) {
                  setState(() {
                    _modoEstrutura = valor!;
                    _estruturasSelecionadas.clear();
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _abrirSeletorEstruturas(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _estruturasDisponiveis.map((estrutura) {
                  final bool selecionada = _estruturasSelecionadas.contains(estrutura);
                  return ListTile(
                    title: Text(estrutura),
                    trailing: selecionada
                        ? const Icon(Icons.check, color: corLaranja)
                        : null,
                    onTap: () {
                      setModalState(() {
                        setState(() {
                          if (_modoEstrutura == ModoSelecaoEstrutura.unica) {
                            _estruturasSelecionadas
                              ..clear()
                              ..add(estrutura);
                            Navigator.of(context).pop();
                          } else {
                            if (selecionada) {
                              _estruturasSelecionadas.remove(estrutura);
                            } else {
                              _estruturasSelecionadas.add(estrutura);
                            }
                          }
                        });
                      });
                    },
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  void _abrirSeletorEmpresas(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _empresasDisponiveis.map((empresa) {
                  final bool selecionada = _empresasSelecionadas.contains(empresa);
                  return CheckboxListTile(
                    title: Text(empresa),
                    value: selecionada,
                    activeColor: corLaranja,
                    onChanged: (marcado) {
                      setModalState(() {
                        setState(() {
                          if (marcado == true) {
                            _empresasSelecionadas.add(empresa);
                          } else {
                            _empresasSelecionadas.remove(empresa);
                          }
                        });
                      });
                    },
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  void _gerarRelatorio(BuildContext context) {
    Navigator.of(context).pop();
  }
}