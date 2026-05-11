import 'package:diavicon/features/projetos/providers/clientes_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/modal_selecao_base.dart';
import '../providers/projeto_form_provider.dart';

class BuscaClienteModal extends ConsumerStatefulWidget {
  const BuscaClienteModal({super.key});

  @override
  ConsumerState<BuscaClienteModal> createState() => _BuscaClienteModalState();
}

class _BuscaClienteModalState extends ConsumerState<BuscaClienteModal> {
  final _buscaController = TextEditingController();
  String _termoBusca = '';

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  void _realizarBusca() {
    // Só atualiza o estado se tiver pelo menos 2 letras, pra não forçar o banco à toa
    if (_buscaController.text.trim().length >= 2) {
      setState(() {
        _termoBusca = _buscaController.text.trim();
      });
    } else if (_buscaController.text.trim().isEmpty) {
      setState(() {
        _termoBusca = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuta o provider GLOBAL, passando o que o usuário digitou
    final resultadosAsync = ref.watch(buscarTodasEmpresasProvider(_termoBusca));

    return ModalSelecaoBase(
      titulo: SizedBox(
        width: double.infinity,
        child: Text(
          'Pesquisar cliente cadastrado',
          style: AppTextStyles.tituloPrincipal,
          textAlign: TextAlign.start,
        ),
      ),
      filhos: [
        _buildCampoBusca(),
        const SizedBox(height: 24),
        
        // Controla o que aparece na tela dependendo do texto digitado
        if (_termoBusca.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'Digite o nome ou CNPJ para buscar.', 
                style: TextStyle(color: AppColors.greyMedium)
              ),
            ),
          )
        else
          // Lida com o carregamento, erro ou sucesso da busca no Supabase
          resultadosAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (err, stack) => Text('Erro na busca: $err', style: const TextStyle(color: Colors.red)),
            data: (empresasEncontradas) {
              if (empresasEncontradas.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Nenhum cliente encontrado.', 
                      style: TextStyle(color: AppColors.greyMedium)
                    ),
                  ),
                );
              }

              // Monta a lista de resultados reais do banco
              return Column(
                children: empresasEncontradas.map((empresa) {
                  // Pega o CNPJ ou usa um texto padrão
                  final String infoSubtitulo = empresa['cnpj'] != null && empresa['cnpj'].toString().isNotEmpty
                      ? 'CNPJ: ${empresa['cnpj']}'
                      : 'Cliente na plataforma';

                  return _buildItemCliente(
                    id: empresa['id'],
                    nome: empresa['nome'],
                    subtitulo: infoSubtitulo,
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCampoBusca() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nome do cliente', style: AppTextStyles.labelCampo),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _buscaController,
                onSubmitted: (_) => _realizarBusca(), 
                style: AppTextStyles.corpoTextoEscuro,
                decoration: InputDecoration(
                  hintText: 'Digite o nome...',
                  hintStyle: const TextStyle(color: AppColors.greyLight, fontSize: 14),
                  fillColor: AppColors.white,
                  filled: true,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.greyLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  // Ícone de lupa clicável
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: AppColors.primary),
                    onPressed: _realizarBusca,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.tune, color: AppColors.primary, size: 28),
          ],
        ),
      ],
    );
  }

  Widget _buildItemCliente({
    required String id, 
    required String nome, 
    required String subtitulo,
  }) {
    return InkWell(
      onTap: () {
        // Atualiza o estado do Rascunho com o ID e NOME REAIS do banco
        ref.read(projetoFormProvider.notifier).update((state) => state.copyWith(
              clienteId: id,
              clienteNome: nome,
              isNovoCliente: false, 
            ));
        
        // fecha este modal e volta para a tela de Novo Projeto
        Navigator.pop(context); 
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
                image: const DecorationImage(
                  image: AssetImage('assets/images/empresa.png'), 
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome,
                    style: AppTextStyles.corpoTextoEscuro.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: AppTextStyles.corpoTextoEscuro.copyWith(
                      color: AppColors.greyMedium, 
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}