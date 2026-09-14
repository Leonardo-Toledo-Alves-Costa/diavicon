import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/item_filter_field.dart';
import '../providers/anomalias_provider.dart';
import '../providers/campos_personalizaveis_provider.dart';
import '../providers/sistema_provider.dart';
import 'anomalia_form_screen.dart';

class AnomaliasScreen extends ConsumerStatefulWidget {
  final String empresaId;

  const AnomaliasScreen({super.key, required this.empresaId});

  @override
  ConsumerState<AnomaliasScreen> createState() => _AnomaliasScreenState();
}

class _AnomaliasScreenState extends ConsumerState<AnomaliasScreen> {
  String _busca = '';
  String _filtro = 'Todos';
  String? _sistemaFiltro;
  String? _categoriaFiltro;

  Future<void> _abrirFormulario(AnomaliaModel? item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnomaliaFormScreen(empresaId: widget.empresaId, anomalia: item),
      ),
    );
  }

  void _abrirModalVisualizacao(AnomaliaModel item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.nome,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => Navigator.pop(dialogContext),
                        child: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                    child: const Text('Padrão', style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                  _visualizacaoLinha('Descrição', item.descricao),
                  _visualizacaoLinha('Categoria', item.categoria),
                  _visualizacaoLinha('Sistema construtivo', item.sistemaConstrutivo),
                  _visualizacaoLinha('Gravidade', item.gravidadeValor, item.gravidadeDescricao),
                  _visualizacaoLinha('Urgência', item.urgenciaValor, item.urgenciaDescricao),
                  _visualizacaoLinha('Tendência', item.tendenciaValor, item.tendenciaDescricao),
                  _visualizacaoLinha('Tipo de risco', item.riscoTipo),
                  _visualizacaoLinha('Classe do risco', item.riscoValor, item.riscoDescricao),
                  _visualizacaoLinha('Majoração', item.riscoMajor != null ? '${item.riscoMajor}%' : null),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black26),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Fechar', style: TextStyle(color: Colors.black87)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _visualizacaoLinha(String label, String? valor, [String? descricao]) {
    final texto = [
      if (valor != null && valor.trim().isNotEmpty) valor,
      if (descricao != null && descricao.trim().isNotEmpty) descricao,
    ].join(' — ');
    if (texto.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(texto, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
        ],
      ),
    );
  }

  void _confirmarDelecao(AnomaliaModel item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Excluir anomalia?'),
          content: Text('Deseja realmente apagar "${item.nome}"? Esta ação não pode ser desfeita.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(dialogContext);

                try {
                  await Supabase.instance.client.from('anomalias').delete().eq('id', item.id);
                  ref.invalidate(anomaliasListProvider(widget.empresaId));
                  navigator.pop();
                  messenger.showSnackBar(const SnackBar(content: Text('Anomalia apagada com sucesso.'), backgroundColor: Colors.green));
                } on PostgrestException catch (e) {
                  navigator.pop();
                  messenger.showSnackBar(SnackBar(content: Text('Erro ao excluir: ${e.message}'), backgroundColor: Colors.red));
                } on AuthException catch (e) {
                  navigator.pop();
                  messenger.showSnackBar(SnackBar(content: Text('Erro ao excluir: ${e.message}'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Excluir', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(anomaliasListProvider(widget.empresaId));
    final sistemasAsync = ref.watch(sistemasDropdownProvider(widget.empresaId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'Empresa',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: const [
            Text('Empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Painel', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Anomalias e manifestações patológicas', style: TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Anomalias e manifestações patológicas',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA726),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    elevation: 0,
                  ),
                  onPressed: () => _abrirFormulario(null),
                  child: const Text('Novo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    onChanged: (val) => setState(() => _busca = val),
                    decoration: InputDecoration(
                      hintText: 'buscar anomalia',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF9F9F9),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.black12)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.black12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _filtro,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black87),
                    decoration: const InputDecoration(border: InputBorder.none),
                    items: ['Todos', 'Padrão', 'Criados'].map((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 14)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _filtro = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ItemFilterField(
              hintText: 'Sistema habitacional',
              selectedLabel: _sistemaFiltro,
              isLoading: sistemasAsync.isLoading,
              onClear: () => setState(() => _sistemaFiltro = null),
              onTap: () async {
                final itens = (sistemasAsync.value ?? const <CampoItemModel>[])
                    .map((s) => (value: s.nome, label: s.nome))
                    .toList();
                final resultado = await showItemFilterPickerSheet(
                  context: context,
                  titulo: 'Sistema Habitacional',
                  items: itens,
                  valorSelecionado: _sistemaFiltro,
                );
                if (resultado == null) return;
                setState(() {
                  _sistemaFiltro = resultado == kLimparFiltroValue ? null : resultado;
                });
              },
            ),
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categoriaAnomaliaOpcoes.map((categoria) {
                  final selecionada = _categoriaFiltro == categoria;
                  return FilterChip(
                    label: Text(categoria),
                    selected: selecionada,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: selecionada ? Colors.white : Colors.grey[800],
                      fontWeight: selecionada ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: const Color(0xFFF9F9F9),
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: selecionada ? AppColors.primary : Colors.black12),
                    ),
                    onSelected: (marcado) {
                      setState(() => _categoriaFiltro = marcado ? categoria : null);
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: listAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.red))),
                data: (itensOriginais) {
                  var itens = itensOriginais;

                  if (_busca.trim().isNotEmpty) {
                    final buscaLower = _busca.trim().toLowerCase();
                    itens = itens.where((item) => item.nome.toLowerCase().contains(buscaLower)).toList();
                  }

                  if (_filtro == 'Padrão') {
                    itens = itens.where((item) => item.isPadrao()).toList();
                  } else if (_filtro == 'Criados') {
                    itens = itens.where((item) => !item.isPadrao()).toList();
                  }

                  if (_sistemaFiltro != null) {
                    itens = itens.where((item) => item.sistemaConstrutivo == _sistemaFiltro).toList();
                  }

                  if (_categoriaFiltro != null) {
                    itens = itens.where((item) => item.categoria == _categoriaFiltro).toList();
                  }

                  if (itens.isEmpty) {
                    return const Center(child: Text('Nenhuma anomalia encontrada.', style: TextStyle(color: Colors.grey)));
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: itens.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: Colors.black12),
                    itemBuilder: (context, index) {
                      final item = itens[index];
                      final isPadrao = item.isPadrao();
                      final podeEditar = item.canEdit(widget.empresaId);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.nome,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isPadrao) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                          child: const Text('Padrão', style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (item.descricao != null && item.descricao!.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        item.descricao!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isPadrao)
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, color: Colors.blueGrey, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _abrirModalVisualizacao(item),
                              ),
                            if (podeEditar) ...[
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _abrirFormulario(item),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _confirmarDelecao(item),
                              ),
                            ],
                          ],
                        ),
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
