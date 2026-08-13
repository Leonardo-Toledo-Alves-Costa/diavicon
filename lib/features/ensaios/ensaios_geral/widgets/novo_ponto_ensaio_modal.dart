import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
// Certifique-se de que esses imports estão corretos para o seu projeto:
import '../../ensaios_carbonatacao/screens/ponto_ensaio_carbonatacao_screen.dart';
import '../providers/pontos_ensaio_provider.dart';
// Importando o mapa de rotas
import '../models/ensaios_routes_map.dart';
import '../providers/pontos_ensaio_provider.dart';


class NovoPontoEnsaioModal extends ConsumerStatefulWidget {
  final String estruturaId;
  final String tipoEnsaioNome;
  final String projetoId;
  final String tipoEnsaioId;

  const NovoPontoEnsaioModal({
    super.key,
    required this.projetoId,
    required this.estruturaId,
    required this.tipoEnsaioNome,
    required this.tipoEnsaioId,
  });

  @override
  ConsumerState<NovoPontoEnsaioModal> createState() => _NovoPontoEnsaioModalState();
}

class _NovoPontoEnsaioModalState extends ConsumerState<NovoPontoEnsaioModal> {
  final TextEditingController _nomeController = TextEditingController();
  String? _selectedLocal;
  String? _selectedElementoId; 

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  void _salvar(List<Map<String, dynamic>> elementos) {
    if (_nomeController.text.trim().isEmpty || _selectedElementoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o nome do ponto e selecione o elemento.')),
      );
      return;
    }

    // Busca o elemento filtrando pelo ID
    final elementosEncontrados = elementos.where((e) => e['id'].toString() == _selectedElementoId);

    if (elementosEncontrados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro interno: Elemento não encontrado.')),
      );
      return;
    }

    final elementoSelecionado = elementosEncontrados.first;

    Navigator.pop(context); // Fecha o modal

    // Utilizando o roteamento dinâmico através do EnsaioRoutesMap
    final Widget? telaFormulario = EnsaioRoutesMap.getFormularioScreen(
      tipoEnsaio: widget.tipoEnsaioNome,
      projetoId: widget.projetoId,
      pontoNome: _nomeController.text.trim(),
      elementoNome: elementoSelecionado['nome']?.toString() ?? 'Desconhecido',
      tipoElemento: elementoSelecionado['tipo']?.toString() ?? '-',
      local: _selectedLocal ?? 'Não informado',
      elementoId: _selectedElementoId!,
      pontoGeralId: '', // 👈 Enviando string vazia (ou nula se você aceitar) pois é um NOVO ponto
      tipoEnsaioId: widget.tipoEnsaioId,
    );

    if (telaFormulario != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => telaFormulario,
        ),
      );
      ref.invalidate(pontosEnsaioProvider);
    } else {
      // Caso a rota retorne null, exibe a mensagem de que não está implementado
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formulário não implementado para este ensaio.')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final elementosAsync = ref.watch(
      elementosEstruturaProvider(widget.estruturaId),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Novo ponto de ${widget.tipoEnsaioNome.toLowerCase()}',
                    style: GoogleFonts.lato(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3E3E3D),
                    ),
                    maxLines: 2,
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.topRight,
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            elementosAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Erro ao carregar dados: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (elementos) {
                if (elementos.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Nenhum elemento cadastrado nesta estrutura. Crie um elemento primeiro.',
                    ),
                  );
                }

                final locaisSet = elementos
                    .map((e) => e['local']?.toString().trim() ?? 'Sem local')
                    .where((l) => l.isNotEmpty)
                    .toSet();
                final locaisList = locaisSet.toList()..sort();

                final elementosFiltrados = _selectedLocal == null
                    ? <Map<String, dynamic>>[]
                    : elementos
                          .where(
                            (e) =>
                                (e['local']?.toString().trim() ??
                                    'Sem local') ==
                                _selectedLocal,
                          )
                          .toList();

                if (_selectedElementoId != null) {
                  final existeNoFiltro = elementosFiltrados.any(
                    (e) => e['id'].toString() == _selectedElementoId,
                  );
                  if (!existeNoFiltro) {
                    _selectedElementoId = null;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nome do ponto',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: const Color(0xFF888888),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nomeController,
                      decoration: InputDecoration(
                        hintText: 'Nome',
                        hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFD9D9D9),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFD9D9D9),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Local',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: const Color(0xFF888888),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFD9D9D9),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedLocal,
                                hint: const Text(
                                  'Selecione',
                                  style: TextStyle(color: Color(0xFFBDBDBD)),
                                ),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Color(0xFF686868),
                                ),
                                items: locaisList.map((local) {
                                  return DropdownMenuItem<String>(
                                    value: local,
                                    child: Text(
                                      local,
                                      style: const TextStyle(
                                        color: Color(0xFF3E3E3D),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedLocal = val;
                                    _selectedElementoId = null;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildAddButton(onPressed: () {}),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Elemento Estrutural',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: const Color(0xFF888888),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFD9D9D9),
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: _selectedLocal == null
                                  ? Colors.grey.shade100
                                  : Colors.white,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedElementoId,
                                hint: const Text(
                                  'Selecione',
                                  style: TextStyle(color: Color(0xFFBDBDBD)),
                                ),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Color(0xFF686868),
                                ),
                                disabledHint: const Text(
                                  'Selecione um local',
                                  style: TextStyle(color: Color(0xFFBDBDBD)),
                                ),
                                items: _selectedLocal == null
                                    ? null
                                    : elementosFiltrados.map((el) {
                                        return DropdownMenuItem<String>(
                                          value: el['id'].toString(),
                                          child: Text(
                                            el['nome'] ?? 'Sem nome',
                                            style: const TextStyle(
                                              color: Color(0xFF3E3E3D),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedElementoId = val);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildAddButton(onPressed: () {}),
                      ],
                    ),
                    const SizedBox(height: 32),

                    Center(
                      child: ElevatedButton(
                        onPressed: () => _salvar(elementos),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFA726),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Salvar',
                          style: GoogleFonts.lato(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton({required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFFFA726),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
    );
  }
}
