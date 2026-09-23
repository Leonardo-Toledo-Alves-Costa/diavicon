import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/modelo_relatorio_schema.dart';
import '../models/quadro_model.dart';
import 'quadro_editor.dart';

// Editor da seção "Referencial": lista livre de blocos, cada um vinculado a
// um catálogo de campos personalizáveis (Estrutura/Local/Elemento/Inspeção
// Visual e GUT). Cada bloco tem seu próprio Quadro (Linha/Divisão/Slot) pra
// escolher quais campos daquele catálogo aparecem no relatório.
class ReferencialEditor extends StatelessWidget {
  final ReferencialConfig config;
  final ValueChanged<ReferencialConfig> onChanged;
  final List<String> catalogosPermitidos;
  final bool somenteLeitura;

  const ReferencialEditor({
    super.key,
    required this.config,
    required this.onChanged,
    required this.catalogosPermitidos,
    this.somenteLeitura = false,
  });

  void _adicionarBloco(BuildContext context) async {
    final jaAdicionados = config.blocos.map((b) => b.catalogo).toSet();
    final disponiveis = catalogosReferencial
        .where((c) => catalogosPermitidos.contains(c.chave) && !jaAdicionados.contains(c.chave))
        .toList();
    if (disponiveis.isEmpty) return;

    final escolhido = await showModalBottomSheet<CatalogoReferencial>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        final grupos = <String, List<CatalogoReferencial>>{};
        for (final c in disponiveis) {
          grupos.putIfAbsent(c.grupo, () => []).add(c);
        }
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text('Adicionar catálogo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              for (final grupo in grupos.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(grupo.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                ),
                for (final catalogo in grupo.value)
                  ListTile(
                    title: Text(catalogo.rotulo),
                    onTap: () => Navigator.pop(context, catalogo),
                  ),
              ],
            ],
          ),
        );
      },
    );

    if (escolhido == null) return;
    final novoBloco = ReferencialBlocoConfig(id: gerarIdQuadro(), catalogo: escolhido.chave, quadro: Quadro.vazio());
    onChanged(config.copyWith(blocos: [...config.blocos, novoBloco]));
  }

  void _removerBloco(String id) {
    onChanged(config.copyWith(blocos: config.blocos.where((b) => b.id != id).toList()));
  }

  void _atualizarBloco(String id, Quadro quadro) {
    onChanged(config.copyWith(
      blocos: config.blocos.map((b) => b.id == id ? b.copyWith(quadro: quadro) : b).toList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mostra, pra cada catálogo escolhido, só os itens realmente usados neste relatório (funciona como um glossário).',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        for (final bloco in config.blocos) ...[
          _buildBloco(context, bloco),
          const Divider(height: 24),
        ],
        if (!somenteLeitura)
          OutlinedButton.icon(
            onPressed: () => _adicionarBloco(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Adicionar catálogo'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
          ),
      ],
    );
  }

  Widget _buildBloco(BuildContext context, ReferencialBlocoConfig bloco) {
    final catalogo = buscarCatalogoReferencial(bloco.catalogo);
    final titulo = catalogo?.rotulo ?? bloco.catalogo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D))),
            ),
            if (!somenteLeitura)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _removerBloco(bloco.id),
                icon: const Icon(Icons.close, size: 18, color: Colors.red),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (catalogo != null)
          QuadroEditor(
            quadro: bloco.quadro,
            catalogo: catalogo.campos,
            tiposPermitidos: const [TipoConteudoSlot.texto],
            legendaRepeticao: 'Repete automaticamente por item de "${catalogo.rotulo}" usado no relatório',
            somenteLeitura: somenteLeitura,
            onChanged: (q) => _atualizarBloco(bloco.id, q),
          ),
      ],
    );
  }
}
