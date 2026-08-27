import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../home/screens/perfil_drawer.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/feed_provider.dart';
import '../models/feed_post_model.dart';
import 'criar_post_screen.dart';
import '../widgets/feed_header_widget.dart';

class EducacaoFeedScreen extends ConsumerWidget {
  const EducacaoFeedScreen({super.key});
  


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(educacaoFeedControllerProvider);
    final isAdminAsync = ref.watch(isUserAdminProvider); 
    final topPadding = MediaQuery.of(context).padding.top;
    final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

    // Lógica combinada de Filtro por Tag + Pesquisa por Texto/Empresa/Usuário
    bool passaNosFiltros(FeedPostModel p, String tagFiltro, String termoPesquisa) {
      // 1. Validação da Tag
      bool passaTag = true;
      if (tagFiltro != 'todos') {
        if (tagFiltro == 'ebooks' && p.tag != 'ebook') passaTag = false;
        else if (tagFiltro == 'artigos' && p.tag != 'artigo acadêmico') passaTag = false;
        else if (tagFiltro == 'associações' && p.tag != 'associação') passaTag = false;
        else if (tagFiltro == 'produto' && p.tag != 'produto') passaTag = false;
        else if (tagFiltro == 'equipamento' && p.tag != 'equipamento') passaTag = false;
        else if (tagFiltro == 'campo' && p.tag != 'direto do campo') passaTag = false;
      }

      if (!passaTag) return false;

      // 2. Validação da Pesquisa (Texto, Nome da Empresa ou Nome do Usuário)
      if (termoPesquisa.isEmpty) return true;

      final textoPost = p.texto.toLowerCase();
      final nomeEmpresa = p.empresaNome.toLowerCase();
      final nomeUsuario = p.usuarioNome.toLowerCase();
      final tagPost = p.tag.toLowerCase();

      return textoPost.contains(termoPesquisa) ||
             nomeEmpresa.contains(termoPesquisa) ||
             nomeUsuario.contains(termoPesquisa) ||
             tagPost.contains(termoPesquisa);
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: const PerfilDrawer(),
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [

        FeedHeader(
                  topPadding: topPadding,
                  onOpenDrawer: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),

          // BARRA DE PESQUISA
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              onChanged: (valor) => controller.setPesquisa(valor),
              decoration: InputDecoration(
                hintText: 'Pesquisar por termo, corrosão, ultrassom, empresa...',
                hintStyle: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFE87B1D)),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE87B1D), width: 1),
                ),
              ),
            ),
          ),

          // FILTRO HORIZONTAL DE TAGS
          ValueListenableBuilder<String>(
            valueListenable: controller.filtro,
            builder: (context, filtroAtual, _) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: ['Todos', 'Ebooks', 'Artigos', 'Associações','Produto','Equipamento','Campo'].map((tag) {
                    final tagLower = tag.toLowerCase();
                    return _CategoryChip(
                      label: tag, 
                      isSelected: filtroAtual == tagLower,
                      onTap: () => controller.setFiltro(tagLower),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          
          // FEED PULL-TO-REFRESH COM ESCUTA REATIVA MÚLTIPLA
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFFE87B1D),
              onRefresh: () async => controller.carregarFeed(),
              child: ListenableBuilder(
                listenable: Listenable.merge([controller.state, controller.filtro, controller.pesquisa]),
                builder: (context, _) {
                  return controller.state.value.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFE87B1D))),
                    error: (err, _) => Center(child: Text('Erro: $err')),
                    data: (posts) {
                      final postsFiltrados = posts.where((p) => passaNosFiltros(p, controller.filtro.value, controller.pesquisa.value)).toList();

                      if (postsFiltrados.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              'Nenhuma publicação encontrada para os critérios informados.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.lato(color: Colors.grey.shade600),
                            ),
                          ),
                        );
                      }
                      
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: postsFiltrados.length,
                        itemBuilder: (context, index) => FeedPostCard(post: postsFiltrados[index], controller: controller),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// O CARTÃO DO POST
class FeedPostCard extends ConsumerWidget {
  final FeedPostModel post;
  final EducacaoFeedController controller; 
  
  const FeedPostCard({super.key, required this.post, required this.controller});

  void _abrirComentarios(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true, 
      backgroundColor: Colors.transparent,
      builder: (context) => ComentariosBottomSheet(postId: post.id),
    );
  }

  void _confirmarDelecao(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deletar postagem?'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), 
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext); 
              try {
                await controller.deletarPost(post.id);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Postagem deletada com sucesso!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Deletar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _abrirLink(BuildContext context, String url) async {
    String parsedUrl = url.trim();
    if (!parsedUrl.startsWith('http://') && !parsedUrl.startsWith('https://')) parsedUrl = 'https://$parsedUrl';
    try {
      await launchUrl(Uri.parse(parsedUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o link.'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDonoDoPost = Supabase.instance.client.auth.currentUser?.id == post.usuarioId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: post.patrocinado ? const Color(0xFFFFF8F2) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: post.patrocinado ? const Color(0xFFE87B1D) : Colors.grey.shade200,
          width: post.patrocinado ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE87B1D),
                backgroundImage: post.empresaFoto != null ? NetworkImage(post.empresaFoto!) : null,
                child: post.empresaFoto == null ? Text(post.empresaNome[0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.empresaNome, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Por ${post.usuarioNome}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              if (isDonoDoPost)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) {
                    if (value == 'editar') Navigator.push(context, MaterialPageRoute(builder: (_) => CriarPostScreen(postParaEditar: post)));
                    else if (value == 'deletar') _confirmarDelecao(context);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'editar', child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text('Editar', style: TextStyle(fontSize: 14)), contentPadding: EdgeInsets.zero, dense: true)),
                    const PopupMenuItem(value: 'deletar', child: ListTile(leading: Icon(Icons.delete, color: Colors.red, size: 20), title: Text('Deletar', style: TextStyle(color: Colors.red, fontSize: 14)), contentPadding: EdgeInsets.zero, dense: true)),
                  ],
                )
            ],
          ),
          const SizedBox(height: 12),
          Text(post.texto, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 12),
          
          if (post.fotos.isNotEmpty) _FotosGrid(fotos: post.fotos),
          
          if (post.anexoNome != null && post.anexoUrl != null)
            GestureDetector(
              onTap: () => _abrirLink(context, post.anexoUrl!),
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                child: Row(
                  children: [
                    const Icon(Icons.link, color: Color(0xFFE87B1D), size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(post.anexoNome!, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFFE87B1D), fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              _TagBadge(tag: post.tag, isPatrocinado: false),
              if (post.patrocinado) ...[
                const SizedBox(width: 8),
                const _TagBadge(tag: 'Patrocinado', isPatrocinado: true),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => controller.toggleLike(post.id, post.userLiked),
                child: Row(
                  children: [
                    Icon(post.userLiked ? Icons.favorite : Icons.favorite_border, color: post.userLiked ? const Color(0xFFE87B1D) : Colors.grey),
                    const SizedBox(width: 4),
                    Text('${post.totalLikes}'),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => _abrirComentarios(context),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${post.totalComentarios}'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ComentariosBottomSheet extends ConsumerStatefulWidget {
  final String postId;
  const ComentariosBottomSheet({super.key, required this.postId});

  @override
  ConsumerState<ComentariosBottomSheet> createState() => _ComentariosBottomSheetState();
}

class _ComentariosBottomSheetState extends ConsumerState<ComentariosBottomSheet> {
  final _commentController = TextEditingController();

  void _enviarComentario(ComentariosController controller) async {
    if (_commentController.text.trim().isEmpty) return;
    try {
      await controller.adicionarComentario(ref, widget.postId, _commentController.text.trim());
      _commentController.clear();
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final comentariosAsync = ref.watch(comentariosPostProvider(widget.postId));
    final controller = ref.watch(comentariosControllerProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24),
                const Text('Comentários', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: comentariosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFE87B1D))),
              error: (err, _) => Center(child: Text('Erro: $err')),
              data: (comentarios) {
                if (comentarios.isEmpty) return const Center(child: Text('Nenhum comentário ainda.'));
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: comentarios.length,
                  itemBuilder: (context, index) {
                    final c = comentarios[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16, 
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: c['usuarios']?['foto_url'] != null ? NetworkImage(c['usuarios']['foto_url']) : null,
                            child: c['usuarios']?['foto_url'] == null ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c['usuarios']?['nome'] ?? 'Usuário', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(c['texto'] ?? ''),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(hintText: 'Comentar...', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: controller.isEnviando,
                    builder: (context, isEnviando, child) {
                      return isEnviando 
                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFFE87B1D), strokeWidth: 2)))
                        : IconButton(icon: const Icon(Icons.send, color: Color(0xFFE87B1D)), onPressed: () => _enviarComentario(controller));
                    }
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: Chip(
          label: Text(label, style: TextStyle(color: isSelected ? Colors.black87 : Colors.grey.shade600, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), 
          backgroundColor: isSelected ? Colors.grey.shade200 : Colors.white,
          side: isSelected ? BorderSide.none : BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  final String tag;
  final bool isPatrocinado;
  const _TagBadge({required this.tag, required this.isPatrocinado});
  @override
  Widget build(BuildContext context) {
    Color bgColor = isPatrocinado ? const Color(0xFFFFF3E0) : Colors.grey.shade100;
    Color textColor = isPatrocinado ? const Color(0xFFE87B1D) : Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(tag, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _FotosGrid extends StatelessWidget {
  final List<String> fotos;
  const _FotosGrid({required this.fotos});

  void _abrirGaleria(BuildContext context, int initialIndex) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenGallery(fotos: fotos, initialIndex: initialIndex)));
  }

  @override
  Widget build(BuildContext context) {
    if (fotos.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 120,
      margin: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(child: GestureDetector(onTap: () => _abrirGaleria(context, 0), child: _buildImg(fotos[0]))),
          if (fotos.length > 1) ...[
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(onTap: () => _abrirGaleria(context, 1), child: _buildImg(fotos[1]))),
          ],
          if (fotos.length > 2) ...[
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => _abrirGaleria(context, 2),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImg(fotos[2]),
                    if (fotos.length > 3)
                      Container(
                        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                        alignment: Alignment.center,
                        child: Text('+${fotos.length - 3}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      )
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildImg(String url) => Container(
    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8), image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)),
  );
}

class FullScreenGallery extends StatefulWidget {
  final List<String> fotos;
  final int initialIndex;
  const FullScreenGallery({super.key, required this.fotos, required this.initialIndex});

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white), title: Text('${_currentIndex + 1} de ${widget.fotos.length}', style: const TextStyle(color: Colors.white))),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemCount: widget.fotos.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(child: Image.network(widget.fotos[index], fit: BoxFit.contain));
        },
      ),
    );
  }
}