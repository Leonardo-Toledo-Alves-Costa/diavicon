import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/compact_button.dart';
import '../../../../core/widgets/custom_empty_state.dart';
import '../models/ponto_medicao_model.dart';
import 'informacoes_ponto_medicao_modal.dart';
import 'selecionar_ponto_medicao_modal.dart';

/// Lista os pontos de medição já marcados e permite criar/editar/apagar,
/// encadeando `SelecionarPontoMedicaoModal` -> `InformacoesPontoMedicaoModal`
/// (mesmo espírito do `ListaRegioesEnsaioModal`).
///
/// Trabalha inteiramente em memória — quem persiste é a tela principal, no
/// "Salvar Informações" — por isso avisa cada mudança via [onPontosChanged]
/// imediatamente, para não perder edições caso o usuário feche a folha
/// tocando fora dela (o que descarta o valor de retorno do `Navigator.pop`).
class ListaPontosMedicaoModal extends StatefulWidget {
  final String plantaUrl;
  final List<PontoMedicaoModel> pontosIniciais;
  final Map<String, bool> excedidoPorNome;
  final ValueChanged<List<PontoMedicaoModel>> onPontosChanged;
  final ValueChanged<String> onExcluirPontoPersistido;

  const ListaPontosMedicaoModal({
    super.key,
    required this.plantaUrl,
    required this.pontosIniciais,
    required this.onPontosChanged,
    required this.onExcluirPontoPersistido,
    this.excedidoPorNome = const {},
  });

  @override
  State<ListaPontosMedicaoModal> createState() => _ListaPontosMedicaoModalState();
}

class _ListaPontosMedicaoModalState extends State<ListaPontosMedicaoModal> {
  late List<PontoMedicaoModel> _pontos;

  @override
  void initState() {
    super.initState();
    _pontos = List.of(widget.pontosIniciais);
  }

  int get _proximoNumero {
    if (_pontos.isEmpty) return 1;
    final numeros = _pontos.map((p) => int.tryParse(p.nome.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0);
    return numeros.reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> _abrirFluxo({PontoMedicaoModel? existente}) async {
    final numero = existente != null
        ? (int.tryParse(existente.nome.replaceAll(RegExp(r'[^0-9]'), '')) ?? _proximoNumero)
        : _proximoNumero;

    final outrosPontos = existente == null ? _pontos : _pontos.where((p) => p.nome != existente.nome).toList();

    final posResult = await showModalBottomSheet<SelecaoPontoMedicaoResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelecionarPontoMedicaoModal(
        plantaUrl: widget.plantaUrl,
        numeroVisual: numero,
        pontosExistentes: outrosPontos,
        initialX: existente?.x,
        initialY: existente?.y,
        initialTamanho: existente?.tamanho,
      ),
    );
    if (posResult == null || !mounted) return;

    final infoResult = await showModalBottomSheet<InformacoesPontoResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InformacoesPontoMedicaoModal(pontoExistente: existente),
    );
    if (infoResult == null || !mounted) return;

    if (infoResult.apagar) {
      if (existente != null) {
        setState(() => _pontos.removeWhere((p) => p.nome == existente.nome));
        if (existente.id != null) widget.onExcluirPontoPersistido(existente.id!);
        widget.onPontosChanged(_pontos);
      }
      return;
    }

    final pontoAtualizado = PontoMedicaoModel(
      id: existente?.id,
      pontoCargaId: existente?.pontoCargaId,
      nome: existente?.nome ?? 'Ponto de Medição $numero',
      x: posResult.x,
      y: posResult.y,
      tamanho: posResult.tamanho,
      deslocMax: infoResult.deslocMax,
      descricao: infoResult.descricao,
      tipoElemento: infoResult.tipoElemento,
    );

    setState(() {
      if (existente != null) {
        final idx = _pontos.indexWhere((p) => p.nome == existente.nome);
        if (idx != -1) {
          _pontos[idx] = pontoAtualizado;
        } else {
          _pontos.add(pontoAtualizado);
        }
      } else {
        _pontos.add(pontoAtualizado);
      }
    });
    widget.onPontosChanged(_pontos);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFFF5F5F5), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('Lista de pontos de medição', style: GoogleFonts.lato(color: const Color(0xFF3E3E3D), fontSize: 22, fontWeight: FontWeight.w900)),
                ),
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: AppColors.greyMedium, size: 24)),
              ],
            ),
          ),
          Expanded(
            child: _pontos.isEmpty
                ? const CustomEmptyState(text: 'Nenhum ponto de medição criado.')
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: _pontos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final ponto = _pontos[index];
                      final numero = ponto.nome.replaceAll(RegExp(r'[^0-9]'), '');
                      final excedeu = widget.excedidoPorNome[ponto.nome] ?? false;

                      return GestureDetector(
                        onTap: () => _abrirFluxo(existente: ponto),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: excedeu ? Colors.red.shade700 : AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(numero, style: GoogleFonts.lato(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ponto.nome, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF3E3E3D))),
                                    Text(
                                      ponto.tipoElemento ?? 'Sem elemento vinculado',
                                      style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868)),
                                    ),
                                  ],
                                ),
                              ),
                              if (excedeu)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                  child: Text('Excedido', style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: CompactButton(text: 'Criar', icon: Icons.add, width: 160, height: 52, onPressed: () => _abrirFluxo()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
