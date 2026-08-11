import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_empty_state.dart';
// 👇 IMPORT DO DRAWER ADICIONADO AQUI
import '../../home/screens/perfil_drawer.dart'; 
import '../providers/estrutura_provider.dart';
import '../widgets/estruturas_header.dart';
import '../widgets/estruturas_filter_row.dart';
import '../widgets/estrutura_large_card.dart';
import '../widgets/estrutura_compact_card.dart';

// --- PROVEDORES DE ESTADO LOCAIS DA ABA ESTRUTURAS ---
final estruturaSearchQueryProvider = StateProvider<String>((ref) => '');
final estruturaConjuntoFiltroProvider = StateProvider<String?>((ref) => null);
final estruturaIsCompactViewProvider = StateProvider<bool>((ref) => false);

// 👇 CHAVE GLOBAL IGUAL À DA TELA DE PROJETOS ADICIONADA AQUI
final GlobalKey<ScaffoldState> _estruturasScaffoldKey = GlobalKey<ScaffoldState>();

class EstruturasTabScreen extends ConsumerWidget {
  const EstruturasTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final estruturasAsync = ref.watch(estruturasDaMinhaEmpresaProvider);
    
    final searchQuery = ref.watch(estruturaSearchQueryProvider);
    final conjuntoFiltroId = ref.watch(estruturaConjuntoFiltroProvider);
    final isCompactView = ref.watch(estruturaIsCompactViewProvider);

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

                  // LISTA DE ESTRUTURAS
                  Expanded(
                    child: estruturasAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                      error: (err, stack) => Center(child: Text('Erro: $err')),
                      data: (lista) {
                        // Filtro Duplo
                        final filtradas = lista.where((e) {
                          final matchBusca = (e.nome ?? '').toLowerCase().contains(searchQuery.toLowerCase());
                          final matchConjunto = conjuntoFiltroId == null || e.conjuntoEstruturalId == conjuntoFiltroId;
                          return matchBusca && matchConjunto;
                        }).toList();

                        if (filtradas.isEmpty) {
                          return const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomEmptyState(text: 'Nenhuma estrutura encontrada'),
                              SizedBox(height: 80), 
                            ],
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 100), 
                          itemCount: filtradas.length,
                          itemBuilder: (context, index) {
                            final estrutura = filtradas[index];

                            return isCompactView
                                ? EstruturaCompactCard(estrutura: estrutura)
                                : EstruturaLargeCard(estrutura: estrutura);
                          },
                        );
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
}