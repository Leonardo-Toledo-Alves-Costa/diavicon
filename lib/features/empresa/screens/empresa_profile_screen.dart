import 'package:diavicon/core/widgets/imagem_storage.dart';
import '../../../core/widgets/icone_rede.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart'; 
import '../../auth/providers/auth_provider.dart';
import '../providers/empresa_profile_provider.dart';
import 'empresa_painel_screen.dart'; 
import '../../empresas_servicos/screens/servico_detalhe_screen.dart';

class EmpresaProfileScreen extends ConsumerWidget {
  final String empresaId;

  const EmpresaProfileScreen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalheAsync = ref.watch(empresaDetalheProvider(empresaId));
    final currentTab = ref.watch(empresaProfileTabProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        systemNavigationBarColor: const Color(0xFFF5F5F5),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        // 🔥 Permite que o corpo (imagem) passe por baixo do AppBar
        extendBodyBehindAppBar: true, 
        
        appBar: const CustomAppBar(
          title: 'Empresa',
          showBackButton: true,
          showMenuButton: false, // Pode remover se não existir no seu CustomAppBar
        ),
        body: detalheAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.red))),
          data: (empresa) {
            // 🔥 Remove o recuo automático do topo para a imagem encostar na borda da tela
            return MediaQuery.removePadding(
              context: context,
              removeTop: true, 
              child: CustomScrollView(
                // 🔥 Remove o efeito elástico (não deixa forçar a rolagem pra cima/baixo)
                physics: const ClampingScrollPhysics(), 
                slivers: [
                  // Header (Capa, Logo, Info e Redes Sociais)
                  SliverToBoxAdapter(
                    child: _EmpresaHeaderWidget(empresa: empresa),
                  ),
                  
                  // Toggle de Abas (Sobre / Serviços)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Row(
                          children: [
                            _buildTab(0, 'Sobre', currentTab, ref),
                            _buildTab(1, 'Serviços', currentTab, ref),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Conteúdo da Aba Selecionada
                  currentTab == 0
                      ? _SliverSobreTab(empresa: empresa)
                      : _SliverServicosTab(empresa: empresa),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTab(int index, String title, int currentTab, WidgetRef ref) {
    final isSelected = currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(empresaProfileTabProvider.notifier).set(index),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// WIDGETS MODULARES
// ==========================================

class _EmpresaHeaderWidget extends ConsumerWidget {
  final EmpresaDetalheModel empresa;

  const _EmpresaHeaderWidget({required this.empresa});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final bool pertenceAEmpresa = currentUser != null && currentUser.empresaId == empresa.id;
    // Quem abre o Painel: o Gestor, o admin da empresa (é lá que ele
    // gerencia colaboradores e serviços) e quem recebeu acesso só de
    // visualização. O admin faltava nesta lista: tinha permissão para
    // gerenciar, mas nenhum caminho na tela para chegar até o Painel.
    final podeAbrirPainel = pertenceAEmpresa &&
        (currentUser.isAdminEmpresa == true ||
            currentUser.isAdmin == true ||
            currentUser.podeVisualizarEmpresa == true);

    return Column(
      
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 75),
        Stack(
          clipBehavior: Clip.none,
          children: [
            
            // Imagem de Capa (🔥 Altura aumentada para 260 para caber atrás do AppBar)
            empresa.fotoCapa != null && empresa.fotoCapa!.isNotEmpty
                ? ImagemStorage.network(empresa.fotoCapa!, height: 220, width: double.infinity, fit: BoxFit.cover)
                : Container(height: 260, color: Colors.grey[400]),
            
            // Botão Painel
            if (podeAbrirPainel)
              Positioned(
                bottom: 16,
                right: 20,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA726), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    elevation: 4,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => EmpresaPainelScreen(empresa: empresa))
                    );
                  },
                  child: const Text('Painel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),

            // Logo Flutuante
            Positioned(
              bottom: -50,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white, 
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: CircleAvatar(
                  radius: 54,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: (empresa.fotoUrl != null && empresa.fotoUrl!.isNotEmpty) ? StorageNetworkImage(empresa.fotoUrl!) : null,
                  child: (empresa.fotoUrl == null || empresa.fotoUrl!.isEmpty) ? const Icon(Icons.business, size: 40, color: Colors.grey) : null,
                ),
              ),
            ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(empresa.nome, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF3E3E3D))),
              const SizedBox(height: 6),
              
              if (empresa.descricao != null && empresa.descricao!.isNotEmpty)
                Text(
                  empresa.descricao!, 
                  style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              
              const SizedBox(height: 6),
              if (empresa.cidade != null && empresa.estado != null)
                Text('${empresa.cidade}, ${empresa.estado}', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              
              const SizedBox(height: 10),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isValid(empresa.linkedin)) 
                    _SocialIcon(CanalContato.linkedin, _formatUrl(empresa.linkedin!)),
                  if (_isValid(empresa.instagram)) 
                    _SocialIcon(CanalContato.instagram, _formatUrl(empresa.instagram!)),
                  if (_isValid(empresa.youtube)) 
                    _SocialIcon(CanalContato.youtube, _formatUrl(empresa.youtube!)),
                  if (_isValid(empresa.site)) 
                    _SocialIcon(CanalContato.site, _formatUrl(empresa.site!)),
                  if (_isValid(empresa.emailContato)) 
                    _SocialIcon(CanalContato.email, 'mailto:${empresa.emailContato!}'),
                  if (_isValid(empresa.whatsapp)) 
                    _SocialIcon(CanalContato.whatsapp, 'https://wa.me/55${empresa.whatsapp!.replaceAll(RegExp(r'\D'), '')}'),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  bool _isValid(String? value) => value != null && value.trim().isNotEmpty;

  String _formatUrl(String url) {
    if (!url.startsWith('http') && !url.startsWith('mailto:')) {
      return 'https://$url';
    }
    return url;
  }
}

class _SocialIcon extends StatelessWidget {
  final CanalContato canal;
  final String url;
  
  const _SocialIcon(this.canal, this.url);

  Future<void> _abrirLink(BuildContext context) async {
    try {
      final uri = Uri.parse(url);
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o link. Verifique se o app está instalado.'),
            backgroundColor: Colors.orange,
          )
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('O formato do link cadastrado é inválido.'),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _abrirLink(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: IconeRede(canal, tamanho: 20),
      ),
    );
  }
}

// ==========================================
// TABS SLIVERS
// ==========================================

class _SliverSobreTab extends ConsumerWidget {
  final EmpresaDetalheModel empresa;

  const _SliverSobreTab({required this.empresa});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colaboradoresAsync = ref.watch(empresaColaboradoresProvider(empresa.id));

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Colaboradores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                const SizedBox(height: 10),
                colaboradoresAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (e, _) => Text('Erro ao carregar colaboradores: $e', style: const TextStyle(color: Colors.red)),
                  data: (colaboradores) {
                    if (colaboradores.isEmpty) return const Text('Nenhum colaborador encontrado.', style: TextStyle(color: Colors.grey));
                    return SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: colaboradores.length,
                        itemBuilder: (context, i) {
                          final colab = colaboradores[i];
                          return Padding(
                            padding: const EdgeInsets.only(right: 20),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: (colab.fotoUrl != null && colab.fotoUrl!.isNotEmpty) ? StorageNetworkImage(colab.fotoUrl!) : null,
                                  child: (colab.fotoUrl == null || colab.fotoUrl!.isEmpty) ? const Icon(Icons.person, color: Colors.grey) : null,
                                ),
                                const SizedBox(height: 8),
                                Text(colab.nome, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                Text(colab.cargo ?? 'Membro', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sobre a empresa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                const SizedBox(height: 12),
                Text(
                  (empresa.sobre != null && empresa.sobre!.isNotEmpty) 
                      ? empresa.sobre! 
                      : 'Nenhuma informação adicional foi fornecida.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

class _SliverServicosTab extends ConsumerWidget {
  final EmpresaDetalheModel empresa;
  const _SliverServicosTab({required this.empresa});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🔥 Usamos empresa.id para buscar os serviços
    final servicosAsync = ref.watch(empresaProfileServicosProvider(empresa.id));

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Barra de Busca
          TextField(
            onChanged: (val) => ref.read(empresaServicoSearchProvider.notifier).setBusca(val),
            decoration: InputDecoration(
              hintText: 'Buscar serviço, produto ou equipamento',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.black12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.black12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 20),

          // Lista de Serviços
          servicosAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primary))),
            error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.red))),
            data: (servicos) {
              if (servicos.isEmpty) return const Center(child: Text('Nenhum serviço/produto encontrado.', style: TextStyle(color: Colors.grey)));
              
              return Column(
                children: servicos.map((servico) {
                  // 🔥 Envolvemos o Container inteiro com o GestureDetector para navegação
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServicoDetalheScreen(
                            servico: servico,
                            empresaNome: empresa.nome, // Passando os dados reais
                            empresaFotoUrl: empresa.fotoUrl,
                            empresaCidade: empresa.cidade,
                            empresaEstado: empresa.estado,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: (servico.fotoPrincipal != null && servico.fotoPrincipal!.isNotEmpty)
                                ? ImagemStorage.network(servico.fotoPrincipal!, height: 120, fit: BoxFit.cover)
                                : Container(height: 120, color: Colors.grey[300]),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (servico.categoria != null && servico.categoria!.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
                                    child: Text(servico.categoria!, style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                Text(servico.nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D))),
                                if (servico.objetivo != null && servico.objetivo!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(servico.objetivo!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                  ),
                                  
                                // 🔥 O GestureDetector interno protege o clique apenas no anexo
                                if (servico.linkAnexo != null && servico.linkAnexo!.isNotEmpty)
                                  GestureDetector(
                                    onTap: () async {
                                      try {
                                        final bruto = servico.linkAnexo!.trim();
                                        final uri = Uri.parse(bruto.contains('://') ? bruto : 'https://$bruto');
                                        // Só endereços web: bloqueia javascript:, data:, file: e afins.
                                        if (uri.scheme != 'https' && uri.scheme != 'http') {
                                          throw const FormatException('esquema não permitido');
                                        }
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Link inválido ou indisponível.'), backgroundColor: Colors.red),
                                          );
                                        }
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.insert_drive_file, size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              servico.nomeAnexo ?? 'Documento anexo',
                                              maxLines: 1, 
                                              overflow: TextOverflow.ellipsis, 
                                              style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)
                                            ),
                                          ),
                                          const Icon(Icons.open_in_new, size: 14, color: Colors.grey),
                                        ],
                                      ),
                                    ),
                                  )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}