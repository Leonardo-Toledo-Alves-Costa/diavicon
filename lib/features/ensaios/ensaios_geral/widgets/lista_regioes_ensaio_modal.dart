import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/compact_button.dart';
import 'package:diavicon/core/widgets/custom_empty_state.dart';
import 'package:diavicon/features/elementos/providers/info_planejamento_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

import 'package:diavicon/features/ensaios/ensaios_geral/widgets/selecionar_local_regiao_modal.dart';
import 'package:diavicon/features/ensaios/ensaios_geral/widgets/nova_regiao_ensaio_modal.dart';

class ListaRegioesEnsaioModal extends ConsumerWidget {
  final String estruturaId,
      plantaId,
      plantaUrl,
      empresaIdSelecionada,
      empresaNome;
  final String? empresaFotoUrl;
  final String plantaLocal; 

  const ListaRegioesEnsaioModal({
    super.key,
    required this.estruturaId,
    required this.plantaId,
    required this.plantaUrl,
    required this.empresaIdSelecionada,
    required this.empresaNome,
    this.empresaFotoUrl,
    required this.plantaLocal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regioesAsync = ref.watch(
      regioesEnsaioProvider(
        RegioesFiltro(plantaId: plantaId, empresaId: empresaIdSelecionada),
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                  child: Text(
                    'Lista de regiões de ensaio',
                    style: GoogleFonts.lato(
                      color: const Color(0xFF3E3E3D),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.greyMedium,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      (empresaFotoUrl != null && empresaFotoUrl!.isNotEmpty)
                      ? NetworkImage(empresaFotoUrl!)
                      : null,
                  child: (empresaFotoUrl == null || empresaFotoUrl!.isEmpty)
                      ? const Icon(Icons.business, color: AppColors.greyMedium)
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  empresaNome,
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF3E3E3D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: regioesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Erro: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (regioes) {
                if (regioes.isEmpty) {
                  return const CustomEmptyState(
                    text: 'Nenhuma região de ensaio criada.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  itemCount: regioes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final regiao = regioes[index];
                    final corPino = Color(
                      int.parse(regiao.corMarcacao.replaceFirst('#', '0xff')),
                    );
                    final isCirculo = regiao.tipoMarcacao == 'Círculo';

                    return GestureDetector(
                      onTap: () async {
                        final nav = Navigator.of(context);
                        nav.pop();

                        bool emFluxoEdicao = true;
                        double mapX = regiao.posicaoX,
                            mapY = regiao.posicaoY,
                            mapLargura = regiao.marcacaoLargura,
                            mapAltura = regiao.marcacaoAltura,
                            mapRotacao = regiao.marcacaoRotacao;
                        String mapTipo = regiao.tipoMarcacao,
                            mapCor = regiao.corMarcacao;
                        String? tempDescricao, tempElementoId;

                        while (emFluxoEdicao && nav.mounted) {
                          final resultadoForm =
                              await showModalBottomSheet<Map<String, dynamic>>(
                                context: nav.context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => NovaRegiaoEnsaioModal(
                                  estruturaId: estruturaId,
                                  plantaId: plantaId,
                                  plantaUrl: plantaUrl,
                                  empresaId: empresaIdSelecionada,
                                  empresaNome: empresaNome,
                                  empresaFotoUrl: empresaFotoUrl,
                                  plantaLocal: plantaLocal,
                                  posicaoX: mapX,
                                  posicaoY: mapY,
                                  larguraMarcacao: mapLargura,
                                  alturaMarcacao: mapAltura,
                                  rotacaoMarcacao: mapRotacao,
                                  tipoMarcacao: mapTipo,
                                  corMarcacao: mapCor,
                                  numeroMarcacao: regiao.numero,
                                  regiao: regiao,
                                  inicialDescricao: tempDescricao,
                                  inicialElementoId: tempElementoId,
                                ),
                              );

                          final acao = resultadoForm?['acao'];
                          if (acao == 'editar') {
                            tempDescricao = resultadoForm?['descricao'];
                            tempElementoId = resultadoForm?['elementoId'];

                            if (nav.mounted) {
                              final resultadoMapa =
                                  await showModalBottomSheet<LocalRegiaoResult>(
                                    context: nav.context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) =>
                                        SelecionarLocalRegiaoModal(
                                          estruturaId: estruturaId,
                                          plantaId: plantaId,
                                          empresaId: empresaIdSelecionada,
                                          arquivoUrl: plantaUrl,
                                          proximoNumero: regiao.numero,
                                          initialX: mapX,
                                          initialY: mapY,
                                          initialLargura: mapLargura,
                                          initialAltura: mapAltura,
                                          initialRotacao: mapRotacao,
                                          initialTipo: mapTipo,
                                          initialCor: mapCor,
                                        ),
                                  );

                              if (resultadoMapa != null) {
                                mapX = resultadoMapa.x;
                                mapY = resultadoMapa.y;
                                mapLargura = resultadoMapa.largura;
                                mapAltura = resultadoMapa.altura;
                                mapRotacao = resultadoMapa.rotacao;
                                mapTipo = resultadoMapa.tipo;
                                mapCor = resultadoMapa.cor;
                              }
                            }
                            continue;
                          } else {
                            emFluxoEdicao = false;
                          }
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: corPino,
                                shape: isCirculo
                                    ? BoxShape.circle
                                    : BoxShape.rectangle,
                                borderRadius: isCirculo
                                    ? null
                                    : BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: corPino.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                regiao.numero.toString(),
                                style: GoogleFonts.lato(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${regiao.elementoTipo ?? 'Elemento'} - ${regiao.elementoNome ?? 'Sem Vínculo'}',
                                          style: GoogleFonts.lato(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF3E3E3D),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${regiao.qtdEnsaios.toString().padLeft(2, '0')} Ensaios',
                                        style: GoogleFonts.lato(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.greyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    regiao.descricao ?? 'Sem descrição',
                                    style: GoogleFonts.lato(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: const Color(0xFF686868),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: CompactButton(
                  text: 'Criar',
                  icon: Icons.add,
                  width: 160,
                  height: 52,
                  onPressed: () async {
                    int proximoNumero = 1;
                    if (regioesAsync.value != null &&
                        regioesAsync.value!.isNotEmpty) {
                      proximoNumero =
                          regioesAsync.value!
                              .map((e) => e.numero)
                              .reduce(math.max) +
                          1;
                    }

                    final nav = Navigator.of(context);
                    nav.pop();

                    bool emFluxoCriacao = true;
                    double? mapX, mapY, mapLargura, mapAltura, mapRotacao;
                    String? mapCor, mapTipo;
                    String? tempDescricao, tempElementoId;

                    while (emFluxoCriacao && nav.mounted) {
                      final resultadoMapa =
                          await showModalBottomSheet<LocalRegiaoResult>(
                            context: nav.context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => SelecionarLocalRegiaoModal(
                              estruturaId: estruturaId,
                              plantaId: plantaId,
                              empresaId: empresaIdSelecionada,
                              arquivoUrl: plantaUrl,
                              proximoNumero: proximoNumero,
                              initialX: mapX,
                              initialY: mapY,
                              initialLargura: mapLargura,
                              initialAltura: mapAltura,
                              initialRotacao: mapRotacao,
                              initialTipo: mapTipo,
                              initialCor: mapCor,
                            ),
                          );

                      if (resultadoMapa == null) {
                        emFluxoCriacao = false;
                        break;
                      }

                      mapX = resultadoMapa.x;
                      mapY = resultadoMapa.y;
                      mapLargura = resultadoMapa.largura;
                      mapAltura = resultadoMapa.altura;
                      mapRotacao = resultadoMapa.rotacao;
                      mapTipo = resultadoMapa.tipo;
                      mapCor = resultadoMapa.cor;

                      if (nav.mounted) {
                        final resultadoForm =
                            await showModalBottomSheet<Map<String, dynamic>>(
                              context: nav.context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => NovaRegiaoEnsaioModal(
                                estruturaId: estruturaId,
                                plantaId: plantaId,
                                plantaUrl: plantaUrl,
                                empresaId: empresaIdSelecionada,
                                empresaNome: empresaNome,
                                empresaFotoUrl: empresaFotoUrl,
                                plantaLocal: plantaLocal, 
                                posicaoX: mapX!,
                                posicaoY: mapY!,
                                larguraMarcacao: mapLargura!,
                                alturaMarcacao: mapAltura!,
                                rotacaoMarcacao: mapRotacao!,
                                tipoMarcacao: mapTipo!,
                                corMarcacao: mapCor!,
                                numeroMarcacao: proximoNumero,
                                inicialDescricao: tempDescricao,
                                inicialElementoId: tempElementoId,
                              ),
                            );

                        final acao = resultadoForm?['acao'];
                        if (acao == 'editar') {
                          tempDescricao = resultadoForm?['descricao'];
                          tempElementoId = resultadoForm?['elementoId'];
                          continue;
                        } else {
                          emFluxoCriacao = false;
                        }
                      }
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showListaRegioesModal(
  BuildContext context, {
  required String estruturaId,
  required String plantaId,
  required String plantaUrl,
  required String empresaIdSelecionada,
  required String empresaNome,
  String? empresaFotoUrl,
  required String plantaLocal, 
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ListaRegioesEnsaioModal(
      estruturaId: estruturaId,
      plantaId: plantaId,
      plantaUrl: plantaUrl,
      empresaIdSelecionada: empresaIdSelecionada,
      empresaNome: empresaNome,
      empresaFotoUrl: empresaFotoUrl,
      plantaLocal: plantaLocal,
    ),
  );
}