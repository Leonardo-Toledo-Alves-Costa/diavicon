import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../app_shell/widgets/perfil_drawer.dart';
import '../providers/feed_provider.dart';
import '../widgets/feed_widget.dart';
import '../widgets/empresas_header_widget.dart';
import '../../empresa/screens/empresa_profile_screen.dart';
import 'servico_detalhe_screen.dart';

class EmpresaScreen extends ConsumerStatefulWidget {
  const EmpresaScreen({super.key});

  @override
  ConsumerState<EmpresaScreen> createState() => _EmpresaScreenState();
}

class _EmpresaScreenState extends ConsumerState<EmpresaScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<String> filtrosEmpresa = [
    'Todos',
    'Inspeção',
    'Intervenção',
    'Produtos',
    'Equipamentos',
  ];
  final List<String> filtrosServico = [
    'Todos',
    'Produto',
    'Serviço',
    'Equipamento',
  ];

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(feedTabProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const PerfilDrawer(),
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          EmpresasHeader(
            topPadding: topPadding,
            onOpenDrawer: () {
              FocusManager.instance.primaryFocus?.unfocus();
              _scaffoldKey.currentState?.openDrawer();
            },
          ),

          // HEADER LARANJA
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // TOGGLE TABS
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    child: Row(
                      children: [
                        _buildTab(0, 'Empresas', currentTab),
                        _buildTab(1, 'Serviços e Produtos', currentTab),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // SEARCH E FILTRO
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextField(
                          onChanged: (val) => ref
                              .read(feedSearchProvider.notifier)
                              .updateBusca(val),
                          decoration: InputDecoration(
                            hintText: currentTab == 0
                                ? 'Buscar empresa'
                                : 'Buscar serviço/produto',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.grey,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: Colors.black12,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: Colors.black12,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: currentTab == 0
                              ? ref.watch(feedFilterEmpresaProvider)
                              : ref.watch(feedFilterServicoProvider),
                          icon: const Icon(Icons.keyboard_arrow_down),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                          hint: const Text(
                            'Todos',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          items:
                              (currentTab == 0
                                      ? filtrosEmpresa
                                      : filtrosServico)
                                  .map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value == 'Todos' ? null : value,
                                      child: Text(
                                        value,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  })
                                  .toList(),
                          onChanged: (newValue) {
                            if (currentTab == 0) {
                              ref
                                  .read(feedFilterEmpresaProvider.notifier)
                                  .setFiltro(newValue);
                            } else {
                              ref
                                  .read(feedFilterServicoProvider.notifier)
                                  .setFiltro(newValue);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // LISTA PRINCIPAL
                  Expanded(
                    child: currentTab == 0
                        ? _buildEmpresasFeed()
                        : _buildServicosFeed(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String title, int currentTab) {
    final isSelected = currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(feedTabProvider.notifier).set(index);
          ref.read(feedSearchProvider.notifier).updateBusca('');
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpresasFeed() {
    final empresasAsync = ref.watch(feedEmpresasProvider);

    return empresasAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(
        child: Text(e.toString(), style: const TextStyle(color: Colors.red)),
      ),
      data: (empresas) {
        if (empresas.isEmpty) {
          return const Center(child: Text('Nenhuma empresa encontrada.'));
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: empresas.length,
          itemBuilder: (context, index) {
            return EmpresaFeedCard(
              empresa: empresas[index],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EmpresaProfileScreen(empresaId: empresas[index].id),
                  ),
                );
              }, // Futuro: Redirecionamento para a tela da empresa
            );
          },
        );
      },
    );
  }

  Widget _buildServicosFeed() {
    final servicosAsync = ref.watch(feedServicosProvider);

    return servicosAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(
        child: Text(e.toString(), style: const TextStyle(color: Colors.red)),
      ),
      data: (servicos) {
        if (servicos.isEmpty) {
          return const Center(child: Text('Nenhum registro encontrado.'));
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: servicos.length,
          itemBuilder: (context, index) {
            final servico = servicos[index];

            return ServicoFeedCard(
              servico: servico,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ServicoDetalheScreen(
                      servico: servico,
                      empresaNome: servicos[index].empresaNome,
                      empresaFotoUrl: servicos[index].empresaFotoUrl,
                      empresaCidade: servicos[index].cidade,
                      empresaEstado: servicos[index].estado,
                    ),
                  ),
                );
              }, // Futuro: Redirecionamento para tela do produto
            );
          },
        );
      },
    );
  }
}
