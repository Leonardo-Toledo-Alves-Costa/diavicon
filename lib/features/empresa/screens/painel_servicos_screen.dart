import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/diavicon_alerts.dart';
import '../../planos/planos_mensagens.dart';
import '../../planos/providers/armazenamento_provider.dart';
import '../../planos/providers/empresa_plano_atual_provider.dart';
import '../providers/painel_servicos_provider.dart';
import 'servico_form_screen.dart';
import 'package:diavicon/features/planos/acesso_plano.dart';

class PainelServicosScreen extends ConsumerWidget {
  final String empresaId;
  final String empresaNome;
  final String? empresaFotoUrl;

  const PainelServicosScreen({
    super.key, 
    required this.empresaId,
    required this.empresaNome,
    this.empresaFotoUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicosAsync = ref.watch(painelServicosListProvider(empresaId));
    final planoAsync = ref.watch(empresaPlanoAtualProvider);
    final categorias = ['Todos', 'Produto', 'Serviço', 'Equipamento'];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      // Cabeçalho curto: três linhas empilhadas ocupavam quase toda a barra e
      // ninguém lia nenhuma delas.
      appBar: const CustomAppBar(
        title: 'Serviços',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Painel', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Serviços', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          if (planoAsync.value?.servicos == false) {
            DiaviconAlerts.show(
              context,
              'Recurso do seu plano',
              'Seu plano atual não permite cadastrar serviços ou produtos. $kMensagemContatoVendas',
              isAviso: true,
            );
            return;
          }
          if (!await podeAdicionarArquivo(ref)) {
            if (context.mounted) {
              DiaviconAlerts.show(
                context,
                'Armazenamento esgotado',
                'Sua empresa atingiu o limite de armazenamento do plano atual. $kMensagemContatoVendas',
                isAviso: true,
              );
            }
            return;
          }
          if (!context.mounted) return;
          // Navega para a tela de formulário no modo CRIAÇÃO (servico = null)
          Navigator.push(context, MaterialPageRoute(builder: (_) => GuardaModuloPlano(modulo: ModuloPlano.servicos, child: ServicoFormScreen(empresaId: empresaId))));
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // BARRA DE BUSCA E FILTRO
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    onChanged: (val) => ref.read(painelServicoSearchProvider.notifier).setBusca(val),
                    decoration: InputDecoration(
                      hintText: 'Buscar serviço, produto...',
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: ref.watch(painelServicoFilterProvider),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    decoration: const InputDecoration(border: InputBorder.none),
                    hint: const Text('Todos', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                    items: categorias.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value == 'Todos' ? null : value,
                        child: Text(value, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (newValue) => ref.read(painelServicoFilterProvider.notifier).setFiltro(newValue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // LISTA DE SERVIÇOS
            Expanded(
              child: servicosAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.red))),
                data: (servicos) {
                  if (servicos.isEmpty) return const Center(child: Text('Nenhum item cadastrado.'));
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: servicos.length,
                    itemBuilder: (context, index) {
                      final servico = servicos[index];
                      return _ServicoCard(
                        servico: servico, 
                        empresaNome: empresaNome, 
                        empresaFotoUrl: empresaFotoUrl,
                        onTap: () {
                          // Navega para edição passando o serviço existente
                          Navigator.push(context, MaterialPageRoute(builder: (_) => GuardaModuloPlano(modulo: ModuloPlano.servicos, child: ServicoFormScreen(empresaId: empresaId, servico: servico))));
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServicoCard extends StatelessWidget {
  final ServicoEmpresaModel servico;
  final String empresaNome;
  final String? empresaFotoUrl;
  final VoidCallback onTap;

  const _ServicoCard({required this.servico, required this.empresaNome, this.empresaFotoUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: servico.fotoPrincipal != null 
                      ? ImagemStorage.network(servico.fotoPrincipal!, height: 140, width: double.infinity, fit: BoxFit.cover)
                      : Container(height: 140, color: Colors.grey[300], child: const Icon(Icons.image, color: Colors.grey, size: 40)),
                ),
                if (servico.categoria != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: TagCategoriaServico(servico.categoria),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: empresaFotoUrl != null ? StorageNetworkImage(empresaFotoUrl!) : null,
                      ),
                      const SizedBox(width: 8),
                      Text(empresaNome, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(servico.nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                  
                  if (servico.objetivo != null || servico.descricao != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        (servico.objetivo ?? servico.descricao)!, 
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis, 
                        style: TextStyle(fontSize: 13, color: Colors.grey[600])
                      ),
                    ),
                  
                  if (servico.nomeAnexo != null && servico.linkAnexo != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(servico.nomeAnexo!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Tipo do item do catálogo: serviço, produto ou equipamento.
//
// Os três apareciam com a mesma tag verde e só o texto mudava — de longe
// ficavam idênticos. Agora cada um tem a própria cor e o próprio ícone.
// ---------------------------------------------------------------------------

IconData iconeCategoriaServico(String? categoria) {
  switch (categoria?.trim()) {
    case 'Serviço':
      return Icons.handyman_outlined;
    case 'Produto':
      return Icons.inventory_2_outlined;
    case 'Equipamento':
      return Icons.precision_manufacturing_outlined;
    default:
      return Icons.sell_outlined;
  }
}

({Color fundo, Color frente}) coresCategoriaServico(String? categoria) {
  switch (categoria?.trim()) {
    case 'Serviço':
      return (fundo: const Color(0xFFE3F0FB), frente: const Color(0xFF1565A0));
    case 'Produto':
      return (fundo: const Color(0xFFFDF0E0), frente: const Color(0xFFA85A00));
    case 'Equipamento':
      return (fundo: const Color(0xFFEDE7F6), frente: const Color(0xFF5E35B1));
    default:
      return (fundo: const Color(0xFFEDEAE4), frente: const Color(0xFF5B5C5E));
  }
}

/// Tag colorida com o ícone do tipo.
class TagCategoriaServico extends StatelessWidget {
  final String? categoria;

  const TagCategoriaServico(this.categoria, {super.key});

  @override
  Widget build(BuildContext context) {
    final texto = categoria?.trim() ?? '';
    if (texto.isEmpty) return const SizedBox.shrink();
    final cores = coresCategoriaServico(texto);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: cores.fundo, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconeCategoriaServico(texto), size: 14, color: cores.frente),
          const SizedBox(width: 5),
          Text(
            texto,
            style: TextStyle(color: cores.frente, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
