import 'package:flutter/material.dart';

import '../models/modelo_relatorio_schema.dart';
import '../models/quadro_model.dart';
import 'quadro_editor.dart';

// "Informações iniciais": 3 blocos de repetição fixos (equipe, empresas do
// projeto, estruturas do projeto), cada um editado com o mesmo Quadro
// (Linha/Divisão/Slot) usado em Registros e Cabeçalho.
class InformacoesIniciaisEditor extends StatelessWidget {
  final InformacoesIniciaisConfig config;
  final ValueChanged<InformacoesIniciaisConfig> onChanged;
  final bool somenteLeitura;

  const InformacoesIniciaisEditor({
    super.key,
    required this.config,
    required this.onChanged,
    this.somenteLeitura = false,
  });

  static const _tiposPermitidos = [TipoConteudoSlot.texto, TipoConteudoSlot.imagem];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBloco(
          titulo: 'Informação da equipe',
          legenda: 'Repete automaticamente por membro da equipe do projeto',
          quadro: config.equipe,
          catalogo: camposEquipe,
          onChangedQuadro: (q) => onChanged(config.copyWith(equipe: q)),
        ),
        const Divider(height: 24),
        _buildBloco(
          titulo: 'Informação de empresas no projeto',
          legenda: 'Repete automaticamente por empresa participante do projeto',
          quadro: config.empresas,
          catalogo: camposEmpresasProjeto,
          onChangedQuadro: (q) => onChanged(config.copyWith(empresas: q)),
        ),
        const Divider(height: 24),
        _buildBloco(
          titulo: 'Estruturas no projeto',
          legenda: 'Repete automaticamente por estrutura do projeto',
          quadro: config.estruturas,
          catalogo: camposEstruturasProjeto,
          onChangedQuadro: (q) => onChanged(config.copyWith(estruturas: q)),
        ),
        const Divider(height: 24),
        _buildBloco(
          titulo: 'Locais da estrutura',
          legenda: 'Repete automaticamente por local da estrutura (aparece antes dos registros)',
          quadro: config.locais,
          catalogo: camposLocal,
          onChangedQuadro: (q) => onChanged(config.copyWith(locais: q)),
        ),
      ],
    );
  }

  Widget _buildBloco({
    required String titulo,
    required String legenda,
    required Quadro quadro,
    required List<CampoCatalogo> catalogo,
    required ValueChanged<Quadro> onChangedQuadro,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D))),
        const SizedBox(height: 6),
        QuadroEditor(
          quadro: quadro,
          catalogo: catalogo,
          tiposPermitidos: _tiposPermitidos,
          legendaRepeticao: legenda,
          somenteLeitura: somenteLeitura,
          onChanged: onChangedQuadro,
        ),
      ],
    );
  }
}
