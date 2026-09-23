import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../models/area_ensaio.dart';
import '../progresso/progresso_ensaios.dart';
import '../models/ensaio_resumo_model.dart';
import '../widgets/abas_area_ensaio.dart';
import '../providers/ensaios_provider.dart';
import 'pontos_ensaio_screen.dart';
import '../../ensaios_inspecao_visual/screens/inspecao_visual_lista_screen.dart';

class EstruturaEnsaiosScreen extends ConsumerStatefulWidget {
  final String estruturaId;
  final String projetoId;
  final String projetoNome;
  final String estruturaNome;

  const EstruturaEnsaiosScreen({
    super.key,
    required this.estruturaId,
    required this.projetoId,
    this.projetoNome = 'Projeto',
    this.estruturaNome = 'Estrutura',
  });

  @override
  ConsumerState<EstruturaEnsaiosScreen> createState() =>
      _EstruturaEnsaiosScreenState();
}

class _EstruturaEnsaiosScreenState
    extends ConsumerState<EstruturaEnsaiosScreen> {
  // Concreto · Metálicas · Laboratório (coluna tipos_ensaio.area).
  AreaEnsaio _area = AreaEnsaio.concreto;

  String get estruturaId => widget.estruturaId;
  String get projetoId => widget.projetoId;
  String get projetoNome => widget.projetoNome;
  String get estruturaNome => widget.estruturaNome;

  @override
  Widget build(BuildContext context) {
    // 👈 Busca todos os ensaios da estrutura sem filtrar pelo ID específico
    final AsyncValue<List<ResumoEnsaioModel>> ensaiosAsync = ref.watch(
      resumoEnsaiosProvider(
        ResumoEnsaiosParams(projetoId: projetoId, estruturaId: estruturaId),
      ),
    );

    // Contratados/realizados da empresa do usuário, por tipo (mesma regra
    // das barras do projeto e da estrutura — progresso_ensaios.dart).
    final progressoAsync = ref.watch(progressoProjetoProvider(projetoId));
    final progressoEstrutura = progressoAsync.value?.estrutura(estruturaId);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const CustomAppBar(
        title: 'Ensaios',
        showBackButton: true,
        showMenuButton: false,
      ),
      body: ensaiosAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Erro ao carregar ensaios:\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (todos) {
          if (todos.isEmpty) {
            return const Center(
              child: Text('Nenhum tipo de ensaio cadastrado no sistema.'),
            );
          }
          final ensaios = todos.where((e) => e.area == _area).toList();

          return Column(
            children: [
              if (progressoEstrutura != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: _ResumoProgressoEstrutura(progresso: progressoEstrutura),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: AbasAreaEnsaio(
                  selecionada: _area,
                  onChanged: (a) => setState(() => _area = a),
                ),
              ),
              Expanded(
                child: ensaios.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum ensaio de ${_area.rotulo.toLowerCase()} cadastrado.',
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            color: AppColors.greyMedium,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(24.0),
                        itemCount: ensaios.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final ensaio = ensaios[index];
                          final progressoTipo = progressoEstrutura?.tipo(ensaio.id);
                          final contratadas = progressoTipo?.contratados ?? ensaio.contratadas;
                          final realizadas = progressoTipo?.realizados ?? ensaio.realizadas;

                          Color badgeColor = Colors.transparent;
                          Color badgeTextColor = Colors.transparent;
                          String badgeText = '';

                          if (realizadas > 0) {
                            if (contratadas > 0 && realizadas >= contratadas) {
                              badgeColor = const Color(0xFFE8F5E9);
                              badgeTextColor = const Color(0xFF4CAF50);
                              badgeText =
                                  '${realizadas.toString().padLeft(2, '0')} Und. realizadas';
                            } else {
                              badgeColor = const Color(0xFFFFF3E0);
                              badgeTextColor = const Color(0xFFFF9800);
                              badgeText =
                                  '${realizadas.toString().padLeft(2, '0')} Und. realizadas';
                            }
                          }

                          return GestureDetector(
                            onTap: () {
                              // 🌟 A LÓGICA DE ROTEAMENTO DINÂMICO ENTRA AQUI 🌟
                              final nomeEnsaioLower = ensaio.nome.toLowerCase();

                              if (nomeEnsaioLower.contains('inspeção visual') ||
                                  nomeEnsaioLower.contains('inspecao visual')) {
                                // Rota para o módulo de Inspeção Visual
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        InspecaoVisualListaScreen(
                                          projetoId: projetoId,
                                          projetoNome: projetoNome,
                                          estruturaNome: estruturaNome,
                                          estruturaId: estruturaId,
                                          iconeEnsaio: ensaio.iconePath,
                                        ),
                                  ),
                                ).then((_) => ref.invalidate(progressoProjetoProvider(projetoId)));
                              } else {
                                // Rota padrão para ensaios regulares (Potencial, Resistividade, etc)
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PontosEnsaioScreen(
                                      projetoId: projetoId,
                                      estruturaId: estruturaId,
                                      tipoEnsaioId: ensaio
                                          .id, // Pega o ID (UUID) da tabela tipos_ensaio
                                      iconeEnsaio: ensaio.iconePath,
                                    ),
                                  ),
                                );
                              }
                            },

                            child: Container(
                              padding: const EdgeInsets.all(16),
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
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: Image.asset(
                                      ensaio.iconePath,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.science_outlined,
                                              color: AppColors.textDark,
                                              size: 28,
                                            );
                                          },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ensaio.nome,
                                          style: GoogleFonts.lato(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF3E3E3D),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${contratadas.toString().padLeft(2, '0')} Und. contratadas',
                                              style: GoogleFonts.lato(
                                                fontSize: 12,
                                                color: AppColors.greyMedium,
                                              ),
                                            ),
                                            if (badgeText.isNotEmpty)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: badgeColor,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  badgeText,
                                                  style: GoogleFonts.lato(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: badgeTextColor,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (contratadas > 0) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: LinearProgressIndicator(
                                                    value: progressoTipo?.fracao ?? 0,
                                                    minHeight: 6,
                                                    backgroundColor: const Color(0xFFEEEEEE),
                                                    color: (progressoTipo?.fracao ?? 0) >= 1
                                                        ? const Color(0xFF4CAF50)
                                                        : AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                textoProgresso(progressoTipo?.fracao),
                                                style: GoogleFonts.lato(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF3E3E3D),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Barra geral da estrutura no topo da tela de ensaios.
class _ResumoProgressoEstrutura extends StatelessWidget {
  final ProgressoEstrutura progresso;
  const _ResumoProgressoEstrutura({required this.progresso});

  @override
  Widget build(BuildContext context) {
    final fracao = progresso.fracao;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Progresso da estrutura',
                  style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF3E3E3D)),
                ),
              ),
              Text(
                textoProgresso(fracao),
                style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fracao ?? 0,
              minHeight: 8,
              backgroundColor: const Color(0xFFFFE0B2),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            fracao == null
                ? 'Sem ensaios contratados para a sua empresa nesta estrutura.'
                : '${progresso.realizadosNaMeta} de ${progresso.contratados} pontos contratados realizados',
            style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF686868)),
          ),
        ],
      ),
    );
  }
}
