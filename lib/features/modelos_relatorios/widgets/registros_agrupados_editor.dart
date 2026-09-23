import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/modelo_relatorio_schema.dart';
import '../models/quadro_model.dart';
import 'quadro_editor.dart';

// Editor da seção "Registros agrupados": só existe pra ensaios que suportam
// agregação por grupo (ver EnsaioModeloConfig.suportaRegistrosAgrupados) —
// escolhe a hierarquia de agrupamento, as colunas estatísticas da tabela por
// grupo, e monta um Quadro livre (linha/divisão) com os gráficos-resumo —
// mesmo editor usado em Cabeçalho/Registros, então dá pra criar quantas
// linhas quiser e decidir onde cada gráfico específico entra.
class RegistrosAgrupadosEditor extends StatelessWidget {
  final RegistrosAgrupadosConfig config;
  final List<CampoCatalogo> campos;
  final List<CampoCatalogo> camposGraficos;
  final ValueChanged<RegistrosAgrupadosConfig> onChanged;
  final bool somenteLeitura;

  const RegistrosAgrupadosEditor({
    super.key,
    required this.config,
    required this.campos,
    required this.camposGraficos,
    required this.onChanged,
    this.somenteLeitura = false,
  });

  Future<void> _adicionarColuna(BuildContext context) async {
    final usados = config.colunas.map((c) => c.campoVinculado).toSet();
    final disponiveis = campos.where((c) => !usados.contains(c.chave)).toList();
    if (disponiveis.isEmpty) return;

    final campo = await showModalBottomSheet<CampoCatalogo>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('Adicionar coluna', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            for (final c in disponiveis) ListTile(title: Text(c.rotulo), onTap: () => Navigator.pop(context, c)),
          ],
        ),
      ),
    );
    if (campo == null) return;

    onChanged(config.copyWith(colunas: [
      ...config.colunas,
      ResumoColuna(id: campo.chave, rotulo: campo.rotulo, campoVinculado: campo.chave, tabela: null),
    ]));
  }

  void _moverColuna(int index, int delta) {
    final lista = List<ResumoColuna>.from(config.colunas);
    final novoIndex = index + delta;
    if (novoIndex < 0 || novoIndex >= lista.length) return;
    final item = lista.removeAt(index);
    lista.insert(novoIndex, item);
    onChanged(config.copyWith(colunas: lista));
  }

  void _removerColuna(int index) {
    final lista = List<ResumoColuna>.from(config.colunas)..removeAt(index);
    onChanged(config.copyWith(colunas: lista));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Agrupar por', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D))),
        const SizedBox(height: 4),
        for (final h in HierarquiaAgrupamento.values)
          RadioListTile<HierarquiaAgrupamento>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
            value: h,
            groupValue: config.hierarquia,
            title: Text(h.rotulo, style: const TextStyle(fontSize: 13)),
            onChanged: somenteLeitura ? null : (v) => onChanged(config.copyWith(hierarquia: v)),
          ),
        const SizedBox(height: 16),
        const Text('Colunas da tabela por grupo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D))),
        const SizedBox(height: 8),
        for (var i = 0; i < config.colunas.length; i++) _buildLinhaColuna(i),
        if (!somenteLeitura)
          TextButton.icon(
            onPressed: () => _adicionarColuna(context),
            icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
            label: const Text('Adicionar coluna', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        const SizedBox(height: 16),
        const Text('Gráficos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D))),
        const SizedBox(height: 8),
        QuadroEditor(
          quadro: config.graficos,
          catalogo: camposGraficos,
          tiposPermitidos: const [TipoConteudoSlot.imagem],
          somenteLeitura: somenteLeitura,
          onChanged: (q) => onChanged(config.copyWith(graficos: q)),
        ),
      ],
    );
  }

  Widget _buildLinhaColuna(int index) {
    final coluna = config.colunas[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: index > 0 ? () => _moverColuna(index, -1) : null,
                child: Icon(Icons.keyboard_arrow_up, size: 18, color: index > 0 ? Colors.black54 : Colors.black26),
              ),
              InkWell(
                onTap: index < config.colunas.length - 1 ? () => _moverColuna(index, 1) : null,
                child: Icon(Icons.keyboard_arrow_down, size: 18, color: index < config.colunas.length - 1 ? Colors.black54 : Colors.black26),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(coluna.rotulo, style: const TextStyle(fontSize: 13, color: Colors.black87))),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _removerColuna(index),
            icon: const Icon(Icons.close, size: 18, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
