import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/modelo_relatorio_schema.dart';
import '../models/paleta_cores.dart';

// Aba "Decoração": borda das células (espessura + cor), se/como o título de
// cada seção aparece antes das informações, e se/onde o rótulo de cada campo
// de texto aparece (ex: "GUT: 45") — tudo aplicado a todo o modelo.
class DecoracaoEditor extends StatelessWidget {
  final DecoracaoGlobalConfig config;
  final ValueChanged<DecoracaoGlobalConfig> onChanged;

  const DecoracaoEditor({super.key, required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCartao(
          titulo: 'Bordas da tabela',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar bordas nas células', style: TextStyle(fontSize: 13)),
              value: config.bordaAtiva,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => onChanged(config.copyWith(bordaAtiva: v)),
            ),
            const SizedBox(height: 8),
            const Text('Espessura', style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            _buildGradeDuasColunas(
              EspessuraBorda.values.map((e) {
                final ativo = e == config.bordaEspessura;
                return ChoiceChip(
                  label: Text(e.rotulo),
                  selected: ativo,
                  onSelected: config.bordaAtiva ? (_) => onChanged(config.copyWith(bordaEspessura: e)) : null,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text('Cor', style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            Opacity(
              opacity: config.bordaAtiva ? 1 : 0.4,
              child: IgnorePointer(
                ignoring: !config.bordaAtiva,
                child: SeletorCorChips(
                  selecionada: config.bordaCor,
                  onSelecionada: (cor) => onChanged(config.copyWith(bordaCor: cor)),
                ),
              ),
            ),
          ],
        ),
        _buildCartao(
          titulo: 'Títulos das seções',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar título antes das informações', style: TextStyle(fontSize: 13)),
              value: config.mostrarTitulos,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => onChanged(config.copyWith(mostrarTitulos: v)),
            ),
            const SizedBox(height: 8),
            const Text('Alinhamento', style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            Opacity(
              opacity: config.mostrarTitulos ? 1 : 0.4,
              child: IgnorePointer(
                ignoring: !config.mostrarTitulos,
                child: _buildGradeDuasColunas(
                  AlinhamentoTitulo.values.map((a) {
                    final ativo = a == config.alinhamentoTitulo;
                    return ChoiceChip(
                      avatar: Icon(_iconeAlinhamento(a), size: 16),
                      label: Text(a.rotulo),
                      selected: ativo,
                      onSelected: (_) => onChanged(config.copyWith(alinhamentoTitulo: a)),
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        _buildCartao(
          titulo: 'Tamanho das fontes',
          children: [
            _buildFonteStepper('Título da seção', config.tamanhoFonteTitulo, (v) => onChanged(config.copyWith(tamanhoFonteTitulo: v))),
            _buildFonteStepper('Nome do campo/coluna', config.tamanhoFonteRotulo, (v) => onChanged(config.copyWith(tamanhoFonteRotulo: v))),
            _buildFonteStepper('Informação (valor)', config.tamanhoFonteValor, (v) => onChanged(config.copyWith(tamanhoFonteValor: v))),
          ],
        ),
        _buildCartao(
          titulo: 'Títulos dos campos',
          children: [
            const Text(
              'Mostra o nome do campo junto do valor. Ex: "G.U.T: 45", "Área Afetada: 75%".',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar título dos campos', style: TextStyle(fontSize: 13)),
              value: config.mostrarTituloCampos,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => onChanged(config.copyWith(mostrarTituloCampos: v)),
            ),
            const SizedBox(height: 8),
            const Text('Posição do título', style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            Opacity(
              opacity: config.mostrarTituloCampos ? 1 : 0.4,
              child: IgnorePointer(
                ignoring: !config.mostrarTituloCampos,
                child: _buildGradeDuasColunas(
                  PosicaoTituloCampo.values.map((p) {
                    final ativo = p == config.posicaoTituloCampo;
                    return ChoiceChip(
                      label: Text(p.rotulo),
                      selected: ativo,
                      onSelected: (_) => onChanged(config.copyWith(posicaoTituloCampo: p)),
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFonteStepper(String rotulo, double valor, ValueChanged<double> onAlterado) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(rotulo, style: const TextStyle(fontSize: 13, color: Colors.black87))),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: valor > 8 ? () => onAlterado(valor - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: AppColors.primary,
          ),
          SizedBox(width: 28, child: Text(valor.round().toString(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: valor < 32 ? () => onAlterado(valor + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  IconData _iconeAlinhamento(AlinhamentoTitulo a) {
    switch (a) {
      case AlinhamentoTitulo.esquerda:
        return Icons.format_align_left;
      case AlinhamentoTitulo.centro:
        return Icons.format_align_center;
      case AlinhamentoTitulo.direita:
        return Icons.format_align_right;
      case AlinhamentoTitulo.justificado:
        return Icons.format_align_justify;
    }
  }

  // Sempre 2 colunas — evita o overflow horizontal que dava com os chips
  // (com ícone + texto) numa única linha.
  Widget _buildGradeDuasColunas(List<Widget> itens) {
    final linhas = <Widget>[];
    for (var i = 0; i < itens.length; i += 2) {
      final segundo = i + 1 < itens.length ? itens[i + 1] : null;
      linhas.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(child: itens[i]),
              const SizedBox(width: 8),
              Expanded(child: segundo ?? const SizedBox.shrink()),
            ],
          ),
        ),
      );
    }
    return Column(children: linhas);
  }

  Widget _buildCartao({required String titulo, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D))),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
