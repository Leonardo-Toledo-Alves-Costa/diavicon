import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Modelo auxiliar para o estado interno da célula na UI
class CelulaPotencial {
  int? valorMv;
  bool possuiResistividade;

  CelulaPotencial({this.valorMv, this.possuiResistividade = false});
}

class PotencialGridWidget extends StatefulWidget {
  final int linhas;
  final int colunas;
  final int espacamentoX;
  final int espacamentoY;

  const PotencialGridWidget({
    super.key,
    required this.linhas,
    required this.colunas,
    required this.espacamentoX,
    required this.espacamentoY,
  });

  @override
  State<PotencialGridWidget> createState() => _PotencialGridWidgetState();
}

class _PotencialGridWidgetState extends State<PotencialGridWidget> {
  // Matriz de estado: [linha][coluna]
  late List<List<CelulaPotencial>> _malha;

  @override
  void initState() {
    super.initState();
    _inicializarMalha();
  }

  @override
  void didUpdateWidget(covariant PotencialGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.linhas != widget.linhas || oldWidget.colunas != widget.colunas) {
      _inicializarMalha();
    }
  }

  void _inicializarMalha() {
    _malha = List.generate(
      widget.linhas,
      (l) => List.generate(widget.colunas, (c) => CelulaPotencial()),
    );
  }

  // Lógica de cores baseada no design (valores em módulo)
  Color _getBackgroundColor(int? valor) {
    if (valor == null) return Colors.white;
    if (valor <= 200) return const Color(0xFFE8F5E9); // Verde claro
    if (valor <= 350) return const Color(0xFFFFF3E0); // Laranja claro
    return const Color(0xFFFFEBEE); // Vermelho claro
  }

  Color _getTextColor(int? valor) {
    if (valor == null) return Colors.grey.shade400;
    if (valor <= 200) return const Color(0xFF2E7D32); // Verde escuro
    if (valor <= 350) return const Color(0xFFE65100); // Laranja escuro
    return const Color(0xFFC62828); // Vermelho escuro
  }

  void _abrirModalEdicao(int l, int c) {
    // Simulação de abertura do teclado/modal para inserir o valor e linkar a resistividade
    // Na implementação real, aqui você chama um showModalBottomSheet
    setState(() {
      // Mock de inserção para teste visual
      if (_malha[l][c].valorMv == null) {
        _malha[l][c].valorMv = 210; // Exemplo verde
        _malha[l][c].possuiResistividade = true;
      } else if (_malha[l][c].valorMv == 210) {
        _malha[l][c].valorMv = 265; // Exemplo laranja
        _malha[l][c].possuiResistividade = false;
      } else if (_malha[l][c].valorMv == 265) {
        _malha[l][c].valorMv = 351; // Exemplo vermelho
      } else {
        _malha[l][c].valorMv = null; // Reseta
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dica de UI do Design
        Row(
          children: [
            const Icon(Icons.link, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              'ponto com resistividade vinculada · toque na célula para linkar',
              style: GoogleFonts.lato(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Scroll Bidirecional para suportar malhas grandes
        SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(70.0),
              border: TableBorder.all(color: Colors.transparent, width: 0),
              children: [
                // 1. LINHA DE CABEÇALHO (Eixo X)
                TableRow(
                  children: [
                    const SizedBox(), // Célula vazia no canto superior esquerdo (0,0 da grid visual)
                    ...List.generate(widget.colunas, (c) {
                      int distanciaX = (c + 1) * widget.espacamentoX;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          distanciaX.toString(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                        ),
                      );
                    }),
                  ],
                ),
                // 2. LINHAS DA MALHA (Eixo Y + Células)
                ...List.generate(widget.linhas, (l) {
                  int distanciaY = l * widget.espacamentoY;
                  return TableRow(
                    children: [
                      // Cabeçalho da Linha (Eixo Y)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0, top: 16.0),
                        child: Text(
                          distanciaY.toString(),
                          textAlign: TextAlign.right,
                          style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                        ),
                      ),
                      // Células Interativas
                      ...List.generate(widget.colunas, (c) {
                        final celula = _malha[l][c];
                        final isPreenchido = celula.valorMv != null;

                        return GestureDetector(
                          onTap: () => _abrirModalEdicao(l, c),
                          child: Container(
                            height: 44,
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: _getBackgroundColor(celula.valorMv),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isPreenchido ? _getTextColor(celula.valorMv).withValues(alpha: 0.3) : Colors.grey.shade300,
                                style: isPreenchido ? BorderStyle.solid : BorderStyle.none,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Estado Vazio
                                if (!isPreenchido)
                                  Icon(Icons.add, color: Colors.grey.shade400, size: 20),
                                  
                                // Estado Preenchido
                                if (isPreenchido)
                                  Text(
                                    celula.valorMv.toString(),
                                    style: GoogleFonts.lato(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: _getTextColor(celula.valorMv),
                                    ),
                                  ),
                                  
                                // Ícone de Vínculo de Resistividade
                                if (isPreenchido && celula.possuiResistividade)
                                  Positioned(
                                    top: 2,
                                    right: 4,
                                    child: Transform.rotate(
                                      angle: -0.785, // Rotaciona ~45 graus para ficar igual ao design
                                      child: const Icon(Icons.link, size: 12, color: Color(0xFF2E7D32)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}