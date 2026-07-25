import 'package:flutter/material.dart';
import 'rdo_lista_screen.dart';

class RdoDetalheScreen extends StatelessWidget {
  final RdoItem rdo;

  const RdoDetalheScreen({super.key, required this.rdo});

  static const Color corLaranja = Color(0xFFF5A623);
  static const Color corFundo = Color(0xFFE6E7E8);
  static const Color corTextoTitulo = Color(0xFF1A1A1A);
  static const Color corTextoSub = Color(0xFF8A8A8A);

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
                  _buildCabecalho(),
                  const SizedBox(height: 20),
                  _buildSecaoParticipante(
                    titulo: 'Cliente',
                    nome: 'Empresa Abc',
                    responsavel: 'Cicrano',
                  ),
                  const SizedBox(height: 16),
                  _buildSecaoParticipante(
                    titulo: 'Responsável',
                    nome: 'Empresa Execução',
                    responsavel: 'Eng. Fulano',
                  ),
                  const SizedBox(height: 16),
                  _buildSecaoEquipe(),
                  const SizedBox(height: 16),
                  _buildStatus(),
                  const SizedBox(height: 20),
                  _buildCardTurno(
                    titulo: 'Manhã',
                    condicoesTrabalho: 'Praticável',
                    condicoesClimatica: 'Ensolarado',
                    turno: rdo.manha,
                  ),
                  const SizedBox(height: 12),
                  _buildCardTurno(
                    titulo: 'Tarde',
                    condicoesTrabalho: 'Praticável',
                    condicoesClimatica: 'Ensolarado',
                    turno: rdo.tarde,
                  ),
                  const SizedBox(height: 12),
                  _buildCardTurno(
                    titulo: 'Noite',
                    condicoesTrabalho: 'Praticável',
                    condicoesClimatica: 'Nublado',
                    turno: rdo.noite,
                  ),
                  const SizedBox(height: 24),
                  _buildBlocoTexto(
                    'Atividades realizadas:',
                    'Lorem ipsum dolor sit amet consectetur. Montes urna fringilla nulla volutpat facilisi. Sapien lacus ultricies enim porttitor amet.',
                  ),
                  const SizedBox(height: 20),
                  _buildBlocoTexto(
                    'Equipamentos utilizados:',
                    'Lorem ipsum dolor sit amet consectetur. Montes urna fringilla nulla volutpat facilisi. Sapien lacus ultricies enim porttitor amet.',
                  ),
                  const SizedBox(height: 20),
                  _buildBlocoTexto(
                    'Observações:',
                    'Lorem ipsum dolor sit amet consectetur. Montes urna fringilla nulla volutpat facilisi. Sapien lacus ultricies enim porttitor amet.',
                  ),
                  const SizedBox(height: 28),
                  _buildBotoesAcao(context),
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

  Widget _buildCabecalho() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Relatório Diário de Obra',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: corTextoTitulo,
          ),
        ),
        const Text(
          'Projeto ABC',
          style: TextStyle(fontSize: 14, color: corTextoTitulo),
        ),
        const SizedBox(height: 4),
        Text(
          rdo.data,
          style: const TextStyle(fontSize: 12, color: corTextoSub),
        ),
      ],
    );
  }

  Widget _buildSecaoParticipante({
    required String titulo,
    required String nome,
    required String responsavel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: corTextoTitulo,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFEFEFEF),
              child: Icon(Icons.shield, size: 16, color: corLaranja),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: const TextStyle(fontSize: 14, color: corTextoTitulo),
                ),
                Text(
                  'Responsável: $responsavel',
                  style: const TextStyle(fontSize: 12, color: corTextoSub),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecaoEquipe() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Equipe',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: corTextoTitulo,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final nome in rdo.equipe.take(3))
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 18,
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
        ),
      ],
    );
  }

  Widget _buildStatus() {
    final bool visto = rdo.status == StatusRdo.visto;
    final Color corFundoBadge = visto ? const Color(0xFFDFF5E3) : const Color(0xFFFCE7CC);
    final Color corTextoBadge = visto ? const Color(0xFF3AA655) : corLaranja;
    final IconData icone = visto ? Icons.check : Icons.upload;
    final String texto = visto ? 'Visto' : 'Postado';

    return Row(
      children: [
        const Text(
          'Status: ',
          style: TextStyle(fontSize: 14, color: corTextoTitulo),
        ),
        Container(
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
        ),
      ],
    );
  }

  Widget _buildCardTurno({
    required String titulo,
    required String condicoesTrabalho,
    required String condicoesClimatica,
    required Turno turno,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: corTextoTitulo,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Condições de trabalho: $condicoesTrabalho',
            style: const TextStyle(fontSize: 12, color: corTextoSub),
          ),
          Text(
            'Condições climáticas: $condicoesClimatica',
            style: const TextStyle(fontSize: 12, color: corTextoSub),
          ),
          const SizedBox(height: 4),
          Text(
            'Chegada: ${turno.chegada}    Início: ${turno.inicio}    Saída: ${turno.saida.isEmpty ? '-' : turno.saida}',
            style: const TextStyle(fontSize: 12, color: corTextoSub),
          ),
        ],
      ),
    );
  }

  Widget _buildBlocoTexto(String titulo, String conteudo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: corTextoTitulo,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          conteudo,
          style: const TextStyle(fontSize: 13, color: corTextoSub, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildBotoesAcao(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton(
          onPressed: () => _confirmarExclusao(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          ),
          child: const Text('Apagar'),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: corLaranja,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            elevation: 0,
          ),
          child: const Text(
            'Imprimir',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  void _confirmarExclusao(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Apagar RDO'),
        content: const Text('Tem certeza que deseja apagar este RDO?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Apagar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}