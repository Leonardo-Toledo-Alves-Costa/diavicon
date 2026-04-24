import 'package:diavicon/core/widgets/custom_text_button.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/compact_search_bar.dart'; 
import '../../../core/widgets/custom_button.dart';
import 'package:diavicon/features/estrutura/widgets/card_estrutura.dart';
// import '../../models/estrutura_model.dart'; 

class IncluirEstruturaBody extends StatefulWidget {
  final String empresaNome;
  final String clienteNome;
  final String? empresaLogoUrl;
  final List<dynamic> estruturas; // Substituir por EstruturaModel futuramente

  const IncluirEstruturaBody({
    super.key,
    required this.empresaNome,
    required this.clienteNome,
    this.empresaLogoUrl,
    required this.estruturas,
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
      if (_searchQuery.isEmpty) return true; // Se a busca estiver vazia, mostra tudo
      
      final nomeEstrutura = (est.nome ?? '').toLowerCase(); //pega o nome
      final tituloEstrutura = (est.tipo ?? '').toLowerCase(); //pega o titulo do edificio
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  Text(
                    widget.clienteNome,
                    style: const TextStyle(fontSize: 14, color: AppColors.hintText),
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

        
        
        Expanded(
          child: estruturasFiltradas.isEmpty
              // Se não tiver nada, mostra o texto centralizado no espaço vazio
              ? const Center(
                  child: Text(
                    'Nenhuma estrutura encontrada.',
                    style: TextStyle(color: AppColors.hintText),
                  ),
                )
              // Se tiver, mostra a lista que ocupa o espaço vazio e rola se precisar
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
                          if (val == true) _selectedStructures.add(est.id);
                          else _selectedStructures.remove(est.id);
                        });
                      },
                    );
                  },
                ),
        ),
        
        const SizedBox(height: 24),

        // Utilização dos Botões Padrão
        Row(
          children: [
            Expanded(
              child: CustomTextbutton(
                text: 'Solicitar acesso',
                onPressed: () {
                  // Lógica de solicitação
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomButton(
                text: 'Nova',
                showArrow: false,
                onPressed: () {
                  // Lógica para nova estrutura
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
                        margin: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                        centerTitle: true,
                        body: 
                         IncluirEstruturaBody(),
*/