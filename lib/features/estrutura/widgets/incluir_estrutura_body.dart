import 'package:diavicon/core/utils/diavicon_modal.dart';
import 'package:diavicon/core/widgets/compact_button.dart';
import 'package:diavicon/core/widgets/custom_text_button.dart';
import 'package:diavicon/features/estrutura/widgets/estrutura_adicionada_body.dart';
import 'package:diavicon/features/estrutura/widgets/nova_estrutura_body.dart';
import 'package:diavicon/features/estrutura/widgets/solicitacao_acesso_body.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/compact_search_bar.dart';
import 'package:diavicon/features/estrutura/widgets/card_estrutura.dart';
// import '../../models/estrutura_model.dart';

class IncluirEstruturaBody extends StatefulWidget {
  final String empresaNome;
  final String clienteNome;
  final String? empresaLogoUrl;
  final List<dynamic> estruturas;
  final String projetoId;

  const IncluirEstruturaBody({
    super.key,
    required this.empresaNome,
    required this.clienteNome,
    this.empresaLogoUrl,
    required this.estruturas,
    required this.projetoId,
  });

  @override
  State<IncluirEstruturaBody> createState() => _IncluirEstruturaBodyState();
}

class _IncluirEstruturaBodyState extends State<IncluirEstruturaBody> {
  final Set<String> _selectedStructures = {};

  // Variavel que guarda o texto na barra de pesquisa
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // logica do filtro
    final estruturasFiltradas = widget.estruturas.where((est) {
      if (_searchQuery.isEmpty)
        return true; // Se a busca estiver vazia, mostra tudo

      final nomeEstrutura = (est.nome ?? '').toLowerCase(); //pega o nome
      final tituloEstrutura = (est.tipo ?? '')
          .toLowerCase(); //pega o titulo do edificio
      final busca = _searchQuery.toLowerCase();

      return nomeEstrutura.contains(busca) || tituloEstrutura.contains(busca);
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabeçalho dinâmico
        Row(
          children: [
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                backgroundImage: widget.empresaLogoUrl != null
                    ? NetworkImage(widget.empresaLogoUrl!) as ImageProvider
                    : const AssetImage('assets/images/logo_diavicon.png'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.empresaNome,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    widget.clienteNome,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.hintText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        const Center(
          child: Text(
            'Não viu a Estrutura? Solicite o acesso ao proprietário',
            style: TextStyle(fontSize: 12, color: AppColors.hintText),
          ),
        ),
        const SizedBox(height: 8),

        // atualização da barra de pesquisa
        CompactSearchBar(
          hintText: 'Conjunto estrutural ou estrutura',
          onChanged: (value) {
            setState(() {
              _searchQuery = value; // Atualiza a tela quando o usuário digita
            });
          },
        ),
        const SizedBox(height: 16),

        estruturasFiltradas.isEmpty
            // Se não tiver nada, mostra o texto centralizado no espaço vazio
            ? const Center(
                child: Text(
                  'Nenhuma estrutura encontrada.',
                  style: TextStyle(color: AppColors.hintText),
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: estruturasFiltradas.length,
                itemBuilder: (context, index) {
                  final est = estruturasFiltradas[index];
                  return CardEstrutura(
                    title: est.nome ?? 'Sem nome',
                    type: est.tipo ?? 'Tipo não definido',
                    details: est.descricao ?? '',
                    group: 'Conjunto Padrão',
                    imageUrl: est.imageUrl ?? '',
                    isSelected: _selectedStructures.contains(est.id),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedStructures.add(est.id); // Marca o checkbox
                          
                          // Abre o modal de sucesso no centro da tela
                          // Abre o modal de sucesso no centro da tela
                          showDiaviconModal(
                            context: context,
                            title: '', 
                            alignment: Alignment.center, 
                            margin: const EdgeInsets.symmetric(horizontal: 40), 
                            isScrollable: false,
                            
                            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0), 
                            
                            
                            body: Transform.translate(
                              offset: const Offset(0, -35), 
                              child: const EstruturaAdicionadaBody(),
                            ),
                          );
                          
                        } else {
                          _selectedStructures.remove(est.id); // Desmarca o checkbox
                        }
                      });
                    },
                  );
                },
              ),

        const SizedBox(height: 24),

        // Utilização dos Botões Padrão
        Row(
          children: [
            Expanded(
              child: CustomTextbutton(
                text: 'Solicitar acesso',
                onPressed: () {
                  // Reutilizando seu componente padronizado para agir como Dialog flutuante
                  showDiaviconModal(
                    context: context,
                    title: 'Solicitação de acesso à\nestruturas',
                    centerTitle: true, // Centraliza o texto do título
                    alignment: Alignment.center, // Faz ele flutuar no meio da tela
                    margin: const EdgeInsets.symmetric(horizontal: 24), // Desgruda das bordas laterais
                    body: const SolicitacaoAcessoBody(),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CompactButton(
                text: 'Nova',
                onPressed: () {
                  // fecha o outro modal
                  Navigator.pop(context);

                  // abre o modal de nova estrutura com uma animação subindo
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => 
                          NovaEstruturaScreen(projetoId: widget.projetoId),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        const begin = Offset(0.0, 1.0); 
                        const end = Offset.zero;        
                        const curve = Curves.easeInOutCubic; 

                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);

                        return SlideTransition(
                          position: offsetAnimation,
                          child: child,
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 750), // Tempo da animação
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}


//para chamar esse moda:
/*
showDiaviconModal(
                  context: context,
                  title: 'Incluir Estrutura',
                  height: MediaQuery.of(context).size.height * 0.80,
                  isScrollable: false,
                  margin: const EdgeInsets.fromLTRB(18, 150, 18, 0),
                  centerTitle: true,
                  body: IncluirEstruturaBody(),
*/