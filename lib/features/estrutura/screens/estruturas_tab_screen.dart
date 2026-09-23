import 'package:diavicon/features/app_shell/widgets/perfil_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_empty_state.dart';
import '../providers/estrutura_provider.dart';
import '../providers/estruturas_dropdown_provider.dart';
import '../widgets/estruturas_header.dart';
import '../widgets/estruturas_filter_row.dart';
import '../widgets/conjunto_estrutural_card.dart';
import '../widgets/estrutura_compact_card.dart';
import '../widgets/conjuntos_estruturais_list.dart';

// --- PROVEDORES DE ESTADO LOCAIS DA ABA ESTRUTURAS ---
final estruturaSearchQueryProvider = StateProvider<String>((ref) => '');
// null = "Todos" (mostra a lista de Conjuntos Estruturais); um id = o
// conjunto "aberto" (mostra os cards das suas estruturas) — ver
// ConjuntosEstruturaisList e ConjuntoEstruturalCard.
final estruturaConjuntoFiltroProvider = StateProvider<String?>((ref) => null);

// Modo da aba Estruturas. Os dois modos têm layouts diferentes:
//
//  - true  ("Monitoradas"): lista plana, só com as estruturas monitoradas,
//    em EstruturaCompactCard — o acompanhamento do dia a dia;
//  - false ("Todas"): a hierarquia Conjunto Estrutural -> estruturas, com
//    todas as estruturas da empresa, monitoradas ou não.
//
// O alternador vive em EstruturasFilterRow. A home abre em "Monitoradas".
final estruturaSomenteMonitoradasProvider = StateProvider<bool>((ref) => true);

// 👇 CHAVE GLOBAL IGUAL À DA TELA DE PROJETOS ADICIONADA AQUI
final GlobalKey<ScaffoldState> _estruturasScaffoldKey =
    GlobalKey<ScaffoldState>();

class EstruturasTabScreen extends ConsumerWidget {
  const EstruturasTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final conjuntoFiltroId = ref.watch(estruturaConjuntoFiltroProvider);
    final somenteMonitoradas = ref.watch(estruturaSomenteMonitoradasProvider);

    return Scaffold(
      // 👇 CHAVE E DRAWER LIGADOS AO SCAFFOLD
      key: _estruturasScaffoldKey,
      drawer: const PerfilDrawer(),
      backgroundColor: const Color(0xFFF5F5F5),
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // HEADER EXTRAÍDO
          EstruturasHeader(
            topPadding: topPadding,
            // 👇 FUNÇÃO DE ABRIR O DRAWER IGUAL À DA TELA DE PROJETOS
            onOpenDrawer: () {
              _estruturasScaffoldKey.currentState?.openDrawer();
            },
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // FILTROS EXTRAÍDOS
                  const EstruturasFilterRow(),

                  const SizedBox(height: 16),

                  // "Monitoradas" -> lista plana das estruturas monitoradas.
                  // "Todas" -> lista de Conjuntos Estruturais; um conjunto
                  // aberto -> cards de todas as estruturas desse conjunto.
                  Expanded(
                    child: somenteMonitoradas
                        ? _MonitoradasView(conjuntoId: conjuntoFiltroId)
                        : conjuntoFiltroId == null
                            ? const ConjuntosEstruturaisList()
                            : _ConjuntoAbertoView(conjuntoId: conjuntoFiltroId),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConjuntoAbertoView extends ConsumerWidget {
  final String conjuntoId;
  const _ConjuntoAbertoView({required this.conjuntoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // So aparece no modo "Todas" (ver o build da aba), por isso a fonte e
    // fixa: todas as estruturas do conjunto, monitoradas ou nao.
    final estruturasAsync = ref.watch(todasEstruturasDaMinhaEmpresaProvider);
    final searchQuery = ref.watch(estruturaSearchQueryProvider);
    final conjuntosAsync = ref.watch(conjuntosEstruturaisProvider);

    final nomeConjunto = conjuntosAsync.whenOrNull(
          data: (conjuntos) => conjuntos.firstWhere(
            (c) => c['id'].toString() == conjuntoId,
            orElse: () => {'nome': ''},
          )['nome']?.toString(),
        ) ??
        '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => ref.read(estruturaConjuntoFiltroProvider.notifier).state = null,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(Icons.arrow_back, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  nomeConjunto.isEmpty ? 'Todos os conjuntos' : nomeConjunto,
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: estruturasAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (err, stack) => Center(child: Text('Erro: $err')),
            data: (lista) {
              final filtradas = lista.where((e) {
                final matchBusca = (e.nome ?? '').toLowerCase().contains(searchQuery.toLowerCase());
                final matchConjunto = e.conjuntoEstruturalId == conjuntoId;
                return matchBusca && matchConjunto;
              }).toList();

              if (filtradas.isEmpty) {
                return const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [CustomEmptyState(text: 'Nenhuma estrutura encontrada'), SizedBox(height: 80)],
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 100),
                itemCount: filtradas.length,
                itemBuilder: (context, index) => ConjuntoEstruturalCard(estrutura: filtradas[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Modo "Monitoradas": lista plana, sem o nível de conjuntos, só com as
/// estruturas monitoradas da empresa.
///
/// O seletor de conjunto da barra de filtros continua valendo aqui, como
/// filtro da lista — em vez de "abrir" o conjunto, como faz no modo "Todas".
class _MonitoradasView extends ConsumerWidget {
  final String? conjuntoId;
  const _MonitoradasView({this.conjuntoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estruturasAsync = ref.watch(estruturasDaMinhaEmpresaProvider);
    final searchQuery = ref.watch(estruturaSearchQueryProvider).toLowerCase();

    return estruturasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (err, stack) => Center(child: Text('Erro: $err')),
      data: (lista) {
        final filtradas = lista.where((e) {
          final matchBusca = (e.nome ?? '').toLowerCase().contains(searchQuery);
          final matchConjunto = conjuntoId == null || e.conjuntoEstruturalId == conjuntoId;
          return matchBusca && matchConjunto;
        }).toList();

        if (filtradas.isEmpty) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomEmptyState(
                text: lista.isEmpty
                    ? 'Nenhuma estrutura monitorada ainda'
                    : 'Nenhuma estrutura monitorada encontrada',
              ),
              const SizedBox(height: 80),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          itemCount: filtradas.length,
          itemBuilder: (context, index) => EstruturaCompactCard(estrutura: filtradas[index]),
        );
      },
    );
  }
}
