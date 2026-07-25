import 'package:flutter/material.dart';

enum PeriodoRdo { manha, tarde, noite }

class NovoRdoScreen extends StatefulWidget {
  const NovoRdoScreen({super.key});

  @override
  State<NovoRdoScreen> createState() => _NovoRdoScreenState();
}

class _NovoRdoScreenState extends State<NovoRdoScreen> {
  static const Color corLaranja = Color(0xFFF5A623);
  static const Color corFundo = Color(0xFFE6E7E8);
  static const Color corTextoTitulo = Color(0xFF1A1A1A);
  static const Color corTextoSub = Color(0xFF8A8A8A);
  static const Color corBorda = Color(0xFFD0D0D0);

  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _atividadesController = TextEditingController();
  final TextEditingController _equipamentosController = TextEditingController();
  final TextEditingController _observacoesController = TextEditingController();

  final TextEditingController _chegadaController = TextEditingController();
  final TextEditingController _inicioController = TextEditingController();
  final TextEditingController _saidaController = TextEditingController();

  PeriodoRdo _periodoSelecionado = PeriodoRdo.tarde;

  final List<String> _equipeDisponivel = const [
    'Fulano - Engenheiro',
    'Ciclano - Estagiário',
    'Beltrano - Engenheiro',
  ];
  final List<String> _equipeSelecionada = ['Fulano', 'Ciclano', 'Fulano'];

  String? _condicoesTrabalho;
  String? _condicoesClimatica;

  @override
  void dispose() {
    _dataController.dispose();
    _atividadesController.dispose();
    _equipamentosController.dispose();
    _observacoesController.dispose();
    _chegadaController.dispose();
    _inicioController.dispose();
    _saidaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: corFundo,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Novo RDO',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: corTextoTitulo,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildEmpresaExecucao(),
                  const SizedBox(height: 20),
                  _buildRotulo('Equipe'),
                  const SizedBox(height: 6),
                  _buildSeletorEquipe(context),
                  const SizedBox(height: 10),
                  _buildAvataresEquipe(),
                  const SizedBox(height: 20),
                  _buildRotulo('Data'),
                  const SizedBox(height: 6),
                  _buildCampoData(context),
                  const SizedBox(height: 20),
                  _buildSeletorPeriodo(),
                  const SizedBox(height: 16),
                  _buildCampoTurno(),
                  const SizedBox(height: 20),
                  _buildRotulo('Condições de trabalho'),
                  const SizedBox(height: 6),
                  _buildDropdown(
                    valor: _condicoesTrabalho,
                    opcoes: const ['Praticável', 'Impraticável'],
                    onChanged: (v) => setState(() => _condicoesTrabalho = v),
                  ),
                  const SizedBox(height: 16),
                  _buildRotulo('Condições climática'),
                  const SizedBox(height: 6),
                  _buildDropdown(
                    valor: _condicoesClimatica,
                    opcoes: const ['Ensolarado', 'Nublado', 'Chuvoso'],
                    onChanged: (v) => setState(() => _condicoesClimatica = v),
                  ),
                  const SizedBox(height: 20),
                  _buildRotulo('Atividades realizadas'),
                  const SizedBox(height: 6),
                  _buildTextarea(_atividadesController, 'Medição de abc...'),
                  const SizedBox(height: 20),
                  _buildRotulo('Equipamentos utilizados'),
                  const SizedBox(height: 6),
                  _buildTextarea(_equipamentosController, 'Ultrassom...'),
                  const SizedBox(height: 20),
                  _buildRotulo('Observações'),
                  const SizedBox(height: 6),
                  _buildTextarea(
                    _observacoesController,
                    'No momento do uso do equipamento...',
                  ),
                  const SizedBox(height: 28),
                  _buildBotaoSalvar(context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: corLaranja,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 16,
        left: 8,
        right: 16,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'Projeto',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'RDO',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildEmpresaExecucao() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 18,
          backgroundColor: Color(0xFFEFEFEF),
          child: Icon(Icons.shield, size: 18, color: corLaranja),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Empresa Execução',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: corTextoTitulo,
              ),
            ),
            Text(
              'Responsável: Eng. Fulano',
              style: TextStyle(fontSize: 12, color: corTextoSub),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRotulo(String texto) {
    return Text(
      texto,
      style: const TextStyle(fontSize: 14, color: corTextoTitulo),
    );
  }

  Widget _buildSeletorEquipe(BuildContext context) {
    return InkWell(
      onTap: () => _abrirSeletorEquipe(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: corBorda),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _equipeSelecionada.isEmpty
                    ? 'Selecione'
                    : '${_equipeSelecionada.length} selecionado(s)',
                style: TextStyle(
                  color: _equipeSelecionada.isEmpty ? Colors.grey : corTextoTitulo,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildAvataresEquipe() {
    if (_equipeSelecionada.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        for (final nome in _equipeSelecionada)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFEFEFEF),
                  child: Icon(Icons.person, color: corTextoSub),
                ),
                const SizedBox(height: 4),
                Text(
                  nome,
                  style: const TextStyle(fontSize: 11, color: corTextoTitulo),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCampoData(BuildContext context) {
    return InkWell(
      onTap: () => _selecionarData(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: corBorda),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _dataController.text.isEmpty ? 'dd/mm/yyyy' : _dataController.text,
                style: TextStyle(
                  color: _dataController.text.isEmpty ? Colors.grey : corTextoTitulo,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSeletorPeriodo() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: corBorda),
      ),
      child: Row(
        children: [
          _buildBotaoPeriodo('Manhã', PeriodoRdo.manha),
          _buildBotaoPeriodo('Tarde', PeriodoRdo.tarde),
          _buildBotaoPeriodo('Noite', PeriodoRdo.noite),
        ],
      ),
    );
  }

  Widget _buildBotaoPeriodo(String texto, PeriodoRdo periodo) {
    final bool selecionado = _periodoSelecionado == periodo;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _periodoSelecionado = periodo),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selecionado ? corLaranja : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            texto,
            style: TextStyle(
              color: selecionado ? Colors.white : corTextoSub,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCampoTurno() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: _buildHorario('Chegada', _chegadaController)),
          const SizedBox(width: 10),
          Expanded(child: _buildHorario('Início ativ.', _inicioController)),
          const SizedBox(width: 10),
          Expanded(child: _buildHorario('Saída', _saidaController)),
        ],
      ),
    );
  }

  Widget _buildHorario(String rotulo, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo, style: const TextStyle(fontSize: 12, color: corTextoSub)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _selecionarHorario(controller),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: corBorda),
            ),
            alignment: Alignment.center,
            child: Text(
              controller.text.isEmpty ? '09:00' : controller.text,
              style: TextStyle(
                fontSize: 13,
                color: controller.text.isEmpty ? Colors.grey : corTextoTitulo,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? valor,
    required List<String> opcoes,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: corBorda),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valor,
          isExpanded: true,
          hint: const Text('Selecione', style: TextStyle(color: Colors.grey)),
          items: opcoes
              .map((opcao) => DropdownMenuItem(value: opcao, child: Text(opcao)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextarea(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: corBorda),
        ),
      ),
    );
  }

  Widget _buildBotaoSalvar(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: ElevatedButton.styleFrom(
          backgroundColor: corLaranja,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
          elevation: 0,
        ),
        child: const Text(
          'Salvar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _abrirSeletorEquipe(BuildContext context) {
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
                children: _equipeDisponivel.map((membro) {
                  final nome = membro.split(' - ').first;
                  final selecionado = _equipeSelecionada.contains(nome);
                  return CheckboxListTile(
                    title: Text(membro),
                    value: selecionado,
                    activeColor: corLaranja,
                    onChanged: (marcado) {
                      setModalState(() {
                        setState(() {
                          if (marcado == true) {
                            _equipeSelecionada.add(nome);
                          } else {
                            _equipeSelecionada.remove(nome);
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

  Future<void> _selecionarData(BuildContext context) async {
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data != null) {
      setState(() {
        _dataController.text =
            '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
      });
    }
  }

  Future<void> _selecionarHorario(TextEditingController controller) async {
    final horario = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (horario != null) {
      setState(() {
        controller.text =
            '${horario.hour.toString().padLeft(2, '0')}:${horario.minute.toString().padLeft(2, '0')}';
      });
    }
  }
}