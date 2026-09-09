import 'package:flutter/material.dart';
import 'rdo_empresas_screen.dart';
import 'novo_rdo_screen.dart';
import 'rdo_detalhe_screen.dart';

enum StatusRdo { visto, postado }

class Turno {
  final String chegada;
  final String inicio;
  final String saida;

  const Turno({
    required this.chegada,
    required this.inicio,
    required this.saida,
  });
}

class RdoItem {
  final String data;
  final List<String> equipe;
  final StatusRdo status;
  final Turno manha;
  final Turno tarde;
  final Turno noite;

  const RdoItem({
    required this.data,
    required this.equipe,
    required this.status,
    required this.manha,
    required this.tarde,
    required this.noite,
  });
}

class RdoListaScreen extends StatefulWidget {
  final EmpresaRdo empresa;

  const RdoListaScreen({super.key, required this.empresa});

  @override
  State<RdoListaScreen> createState() => _RdoListaScreenState();
}

class _RdoListaScreenState extends State<RdoListaScreen> {
  static const Color corLaranja = Color(0xFFF5A623);
  static const Color corFundo = Color(0xFFE6E7E8);
  static const Color corTextoTitulo = Color(0xFF1A1A1A);
  static const Color corTextoSub = Color(0xFF8A8A8A);

  final TextEditingController _buscaController = TextEditingController();

  final List<RdoItem> _rdos = const [
    RdoItem(
      data: '22/03/2026',
      equipe: ['Fulano', 'Ciclano', 'Beltrano', 'Sicrano', 'Zutano'],
      status: StatusRdo.visto,
      manha: Turno(chegada: '09:30', inicio: '10:45', saida: ''),
      tarde: Turno(chegada: '13:10', inicio: '17:45', saida: ''),
      noite: Turno(chegada: '18:05', inicio: '22:10', saida: ''),
    ),
    RdoItem(
      data: '02/02/2026',
      equipe: ['Fulano', 'Ciclano', 'Beltrano', 'Sicrano', 'Zutano'],
      status: StatusRdo.postado,
      manha: Turno(chegada: '09:30', inicio: '10:45', saida: ''),
      tarde: Turno(chegada: '13:10', inicio: '17:45', saida: ''),
      noite: Turno(chegada: '18:05', inicio: '22:10', saida: ''),
    ),
    RdoItem(
      data: '01/02/2026',
      equipe: ['Fulano', 'Ciclano', 'Beltrano', 'Sicrano', 'Zutano'],
      status: StatusRdo.visto,
      manha: Turno(chegada: '09:30', inicio: '10:45', saida: ''),
      tarde: Turno(chegada: '13:10', inicio: '17:45', saida: ''),
      noite: Turno(chegada: '18:05', inicio: '22:10', saida: ''),
    ),
  ];

  @override
  void dispose() {
    _buscaController.dispose();
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'RDOs registrados',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: corTextoTitulo,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildEmpresaHeader(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildBuscaField()),
                      const SizedBox(width: 10),
                      _buildBotaoNovoRdo(context),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _rdos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildRdoCard(context, _rdos[index]);
                      },
                    ),
                  ),
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
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildEmpresaHeader() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 16,
          backgroundColor: Color(0xFFEFEFEF),
          child: Icon(Icons.apartment, size: 16, color: corLaranja),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.empresa.nome,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: corTextoTitulo,
              ),
            ),
            Text(
              widget.empresa.local,
              style: const TextStyle(fontSize: 12, color: corTextoSub),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBuscaField() {
    return TextField(
      controller: _buscaController,
      decoration: InputDecoration(
        hintText: 'Busque por data',
        hintStyle: const TextStyle(color: corTextoSub, fontSize: 14),
        prefixIcon: const Icon(Icons.search, color: corTextoSub),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildBotaoNovoRdo(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NovoRdoScreen()),
        );
      },
      icon: const Icon(Icons.add, size: 18, color: Colors.white),
      label: const Text(
        'Novo RDO',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: corLaranja,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        elevation: 0,
      ),
    );
  }

  Widget _buildRdoCard(BuildContext context, RdoItem rdo) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RdoDetalheScreen(rdo: rdo)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rdo.data,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: corTextoTitulo,
                  ),
                ),
                _buildStatusBadge(rdo.status),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Equipe:',
              style: TextStyle(fontSize: 12, color: corTextoSub),
            ),
            const SizedBox(height: 6),
            _buildEquipeAvatares(rdo.equipe),
            const SizedBox(height: 10),
            _buildLinhaTurno(Icons.wb_sunny_outlined, rdo.manha),
            const SizedBox(height: 4),
            _buildLinhaTurno(Icons.engineering_outlined, rdo.tarde),
            const SizedBox(height: 4),
            _buildLinhaTurno(Icons.nightlight_round, rdo.noite),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipeAvatares(List<String> equipe) {
    final int visiveis = equipe.length > 3 ? 3 : equipe.length;
    final int restante = equipe.length - visiveis;

    return SizedBox(
      height: 32,
      child: Stack(
        children: [
          for (int i = 0; i < visiveis; i++)
            Positioned(
              left: i * 22.0,
              child: const CircleAvatar(
                radius: 15,
                backgroundColor: Color(0xFFEFEFEF),
                child: Icon(Icons.person, size: 16, color: corTextoSub),
              ),
            ),
          if (restante > 0)
            Positioned(
              left: visiveis * 22.0,
              child: CircleAvatar(
                radius: 15,
                backgroundColor: corLaranja,
                child: Text(
                  '+$restante',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLinhaTurno(IconData icone, Turno turno) {
    return Row(
      children: [
        Icon(icone, size: 16, color: corTextoSub),
        const SizedBox(width: 6),
        Text(
          '${turno.chegada} - ${turno.inicio}',
          style: const TextStyle(fontSize: 12, color: corTextoSub),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(StatusRdo status) {
    final bool visto = status == StatusRdo.visto;
    final Color corFundoBadge = visto ? const Color(0xFFDFF5E3) : const Color(0xFFFCE7CC);
    final Color corTextoBadge = visto ? const Color(0xFF3AA655) : corLaranja;
    final IconData icone = visto ? Icons.check : Icons.upload;
    final String texto = visto ? 'Visto' : 'Postado';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: corFundoBadge,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 12, color: corTextoBadge),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: corTextoBadge,
            ),
          ),
        ],
      ),
    );
  }
}