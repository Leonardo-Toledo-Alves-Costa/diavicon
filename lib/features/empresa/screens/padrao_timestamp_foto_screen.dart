import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/foto_watermark_service.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../models/timestamp_foto_padrao_model.dart';
import '../repositories/timestamp_foto_padrao_repository.dart';

class PadraoTimestampFotoScreen extends ConsumerStatefulWidget {
  final String empresaId;

  const PadraoTimestampFotoScreen({super.key, required this.empresaId});

  @override
  ConsumerState<PadraoTimestampFotoScreen> createState() => _PadraoTimestampFotoScreenState();
}

class _PadraoTimestampFotoScreenState extends ConsumerState<PadraoTimestampFotoScreen> {
  TimestampFotoPadraoModel _padrao = const TimestampFotoPadraoModel(empresaId: '');
  bool _carregando = true;
  bool _salvando = false;
  bool _erroCarregar = false;

  @override
  void initState() {
    super.initState();
    _padrao = TimestampFotoPadraoModel(empresaId: widget.empresaId);
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erroCarregar = false;
    });
    try {
      final repo = ref.read(timestampFotoPadraoRepositoryProvider);
      final existente = await repo.buscarPadrao(widget.empresaId);
      if (!mounted) return;
      setState(() {
        if (existente != null) _padrao = existente;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erroCarregar = true;
      });
    }
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      final repo = ref.read(timestampFotoPadraoRepositoryProvider);
      final salvo = await repo.salvarPadrao(_padrao);
      if (!mounted) return;
      setState(() => _padrao = salvo);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Padrão de legenda salvo com sucesso!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Alignment _alinhamentoPreview(String posicao) {
    switch (posicao) {
      case 'Superior esquerdo':
        return Alignment.topLeft;
      case 'Superior direito':
        return Alignment.topRight;
      case 'Inferior esquerdo':
        return Alignment.bottomLeft;
      case 'Centro':
        return Alignment.center;
      case 'Inferior direito':
      default:
        return Alignment.bottomRight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const CustomAppBar(
        title: 'Empresa',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            Text('Padrões da empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Legenda nas fotos', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _erroCarregar
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Não foi possível carregar o padrão da empresa.'),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _carregar, child: const Text('Tentar novamente')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPreview(),
                      const SizedBox(height: 24),
                      _buildEstiloSection(),
                      const SizedBox(height: 24),
                      _buildCamposSection(),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _salvando ? null : _salvar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _salvando
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPreview() {
    final linhas = FotoWatermarkService.montarLinhas(
      _padrao,
      WatermarkFotoContexto(
        nomeProjeto: 'Projeto Exemplo',
        nomeConjuntoEstrutural: 'Conjunto A',
        nomeEstrutura: 'Estrutura 1',
        nomeLocal: 'Local X',
        nomeSistema: 'Sistema Estrutural',
        nomeTipoElemento: 'Pilar',
        nomeElementoEspecifico: 'P101',
        nomeEmpresa: 'Empresa XYZ',
        nomeUsuario: 'João Silva',
        latitude: -19.916681,
        longitude: -43.934493,
        descricaoImagem: 'Determinação de módulo de elasticidade e homogeneidade do concreto por via não destrutiva',
        capturadoEm: DateTime.now(),
      ),
    );

    final cor = FotoWatermarkService.corParaTexto(_padrao.cor);

    final crossAxis = _padrao.posicaoLegenda.contains('esquerdo')
        ? CrossAxisAlignment.start
        : _padrao.posicaoLegenda == 'Centro'
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.end;
    final textAlign = _padrao.posicaoLegenda.contains('esquerdo')
        ? TextAlign.left
        : _padrao.posicaoLegenda == 'Centro'
            ? TextAlign.center
            : TextAlign.right;

    // Foto de exemplo real (não um retângulo cinza) pra prévia refletir como a
    // legenda realmente fica sobre uma imagem — a posição usa Align/percentual,
    // então o resultado final não muda com o tamanho em pixels da foto real.
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Limita a largura da caixa de legenda ao espaço real da prévia,
            // senão uma descrição longa estoura (overflow) em vez de quebrar linha.
            final larguraMaximaLegenda = constraints.maxWidth - 28;
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/images/project_placeholder1.png', fit: BoxFit.cover),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black26],
                    ),
                  ),
                ),
                if (linhas.isNotEmpty || _padrao.logo)
                  Align(
                    alignment: _alinhamentoPreview(_padrao.posicaoLegenda),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: larguraMaximaLegenda),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (_padrao.logo)
                                Container(
                                  width: 34,
                                  height: 34,
                                  margin: EdgeInsets.only(right: linhas.isNotEmpty ? 16 : 0),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.apartment, size: 18, color: Colors.black45),
                                ),
                              if (linhas.isNotEmpty)
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: crossAxis,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (final linha in linhas)
                                        Text(
                                          linha,
                                          textAlign: textAlign,
                                          softWrap: true,
                                          style: TextStyle(
                                            color: cor,
                                            fontSize: _padrao.tamanho.toDouble().clamp(9, 22),
                                            fontWeight: FontWeight.w600,
                                            shadows: const [Shadow(color: Colors.black87, blurRadius: 3, offset: Offset(1, 1))],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEstiloSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildLabelDropdown(
                  label: 'Cor do texto',
                  value: _padrao.cor,
                  items: coresLegendaFoto,
                  onChanged: (v) => setState(() => _padrao = _padrao.copyWith(cor: v)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildTamanhoField(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLabelDropdown(
            label: 'Posição do texto',
            value: _padrao.posicaoLegenda,
            items: posicoesLegendaFoto,
            onChanged: (v) => setState(() => _padrao = _padrao.copyWith(posicaoLegenda: v)),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }

  Widget _buildTamanhoField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tamanho', style: TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 6),
        TextFormField(
          key: ValueKey(_padrao.tamanho),
          initialValue: _padrao.tamanho.toString(),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
          onChanged: (v) {
            final n = int.tryParse(v);
            if (n != null && n > 0) setState(() => _padrao = _padrao.copyWith(tamanho: n));
          },
        ),
      ],
    );
  }

  Widget _buildCamposSection() {
    final campos = <_CampoLegenda>[
      _CampoLegenda('Logo da empresa', _padrao.logo, (v) => _padrao = _padrao.copyWith(logo: v)),
      _CampoLegenda('Data', _padrao.data, (v) => _padrao = _padrao.copyWith(data: v)),
      _CampoLegenda('Hora', _padrao.hora, (v) => _padrao = _padrao.copyWith(hora: v)),
      _CampoLegenda('Nome do Projeto', _padrao.projeto, (v) => _padrao = _padrao.copyWith(projeto: v)),
      _CampoLegenda('Nome do Conjunto Estrutural', _padrao.conjuntoEstrutural, (v) => _padrao = _padrao.copyWith(conjuntoEstrutural: v)),
      _CampoLegenda('Nome da Estrutura', _padrao.estrutura, (v) => _padrao = _padrao.copyWith(estrutura: v)),
      _CampoLegenda('Nome do Local', _padrao.local, (v) => _padrao = _padrao.copyWith(local: v)),
      _CampoLegenda('Sistema', _padrao.sistema, (v) => _padrao = _padrao.copyWith(sistema: v)),
      _CampoLegenda('Tipo de Elemento', _padrao.tipoElemento, (v) => _padrao = _padrao.copyWith(tipoElemento: v)),
      _CampoLegenda('Elemento Específico', _padrao.elemento, (v) => _padrao = _padrao.copyWith(elemento: v)),
      _CampoLegenda('Latitude e Longitude', _padrao.latitudeLongitude, (v) => _padrao = _padrao.copyWith(latitudeLongitude: v)),
      _CampoLegenda('Descrição da imagem', _padrao.descricao, (v) => _padrao = _padrao.copyWith(descricao: v)),
      _CampoLegenda('Nome da Empresa', _padrao.nomeEmpresa, (v) => _padrao = _padrao.copyWith(nomeEmpresa: v)),
      _CampoLegenda('Nome do Usuário', _padrao.nomeUser, (v) => _padrao = _padrao.copyWith(nomeUser: v)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Text('Informações incluídas na legenda', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          _buildCamposGrid(campos),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Sempre exatamente 2 colunas, cada linha com altura própria (não corta
  // rótulos maiores como "Elemento Específico" ou "Nome do Conjunto Estrutural").
  Widget _buildCamposGrid(List<_CampoLegenda> campos) {
    final linhas = <Widget>[];
    for (var i = 0; i < campos.length; i += 2) {
      final primeiro = campos[i];
      final segundo = i + 1 < campos.length ? campos[i + 1] : null;
      linhas.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildCheckboxCampo(primeiro)),
            const SizedBox(width: 4),
            Expanded(child: segundo != null ? _buildCheckboxCampo(segundo) : const SizedBox.shrink()),
          ],
        ),
      );
    }
    return Column(children: linhas);
  }

  Widget _buildCheckboxCampo(_CampoLegenda c) {
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.primary,
      value: c.valor,
      title: Text(c.titulo, style: const TextStyle(fontSize: 13)),
      onChanged: (v) => setState(() => c.aoMudar(v ?? false)),
    );
  }
}

class _CampoLegenda {
  final String titulo;
  final bool valor;
  final void Function(bool) aoMudar;
  _CampoLegenda(this.titulo, this.valor, this.aoMudar);
}
