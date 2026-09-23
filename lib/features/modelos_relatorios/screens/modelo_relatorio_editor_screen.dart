import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/ensaio_modelo_config.dart';
import '../models/modelo_relatorio_model.dart';
import '../models/modelo_relatorio_schema.dart';
import '../models/quadro_model.dart';
import '../providers/modelos_relatorio_provider.dart';
import '../widgets/decoracao_editor.dart';
import '../widgets/galeria_editor.dart';
import '../widgets/informacoes_iniciais_editor.dart';
import '../widgets/modelo_relatorio_preview.dart';
import '../widgets/quadro_editor.dart';
import '../widgets/referencial_editor.dart';
import '../widgets/registros_agrupados_editor.dart';
import '../widgets/resumo_editor.dart';

// Tela "acordeão" com as seções do relatório: cada uma liga/desliga com um
// Switch e expande inline pro editor daquela seção. Cabeçalho e Registros são
// montados com o editor de Quadro (Linha/Divisão/Slot); Galeria e Tabela
// Resumo têm editores próprios. Os campos/catálogos de "Registros",
// "Registros agrupados" e "Tabela resumo" variam por tipo de ensaio — ver
// `EnsaioModeloConfig`/`ensaiosModeloConfig` — Cabeçalho/Informações
// iniciais/Referencial/Galeria/Decoração são os mesmos pra qualquer ensaio.
// Uma segunda aba mostra a prévia do modelo com dados de exemplo.
class ModeloRelatorioEditorScreen extends ConsumerStatefulWidget {
  final String modeloId;
  final String tipoEnsaioNome;

  const ModeloRelatorioEditorScreen({super.key, required this.modeloId, required this.tipoEnsaioNome});

  @override
  ConsumerState<ModeloRelatorioEditorScreen> createState() => _ModeloRelatorioEditorScreenState();
}

class _ModeloRelatorioEditorScreenState extends ConsumerState<ModeloRelatorioEditorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  ModeloRelatorioModel? _modelo;
  ModeloRelatorioSchema _schema = ModeloRelatorioSchema.vazio();
  String _secaoExpandida = '';
  bool _carregando = true;
  bool _salvando = false;
  bool _duplicando = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _carregar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final modelo = await ref.read(modelosRelatorioRepositoryProvider).buscarPorId(widget.modeloId);
      if (!mounted) return;
      setState(() {
        _modelo = modelo;
        _schema = ModeloRelatorioSchema.fromJson(modelo.schemaJson);
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      // Linhas com 3 divisões podem não somar 100% enquanto o usuário digita
      // livremente — normaliza só na hora de persistir, sem travar a edição.
      final schemaNormalizado = _schema.copyWith(
        cabecalho: _schema.cabecalho.copyWith(quadro: _schema.cabecalho.quadro.normalizado()),
        registros: _schema.registros.copyWith(quadro: _schema.registros.quadro.normalizado()),
        analiseElementos: _schema.analiseElementos.copyWith(quadro: _schema.analiseElementos.quadro.normalizado()),
        informacoesIniciais: _schema.informacoesIniciais.normalizado(),
        referencial: _schema.referencial.normalizado(),
        registrosAgrupados: _schema.registrosAgrupados.normalizado(),
      );
      await ref.read(modelosRelatorioRepositoryProvider).salvarSchema(widget.modeloId, schemaNormalizado.toJson());
      if (!mounted) return;
      setState(() => _schema = schemaNormalizado);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modelo salvo com sucesso!'), backgroundColor: Colors.green),
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

  Future<void> _duplicarParaEditar() async {
    final modelo = _modelo;
    if (modelo == null) return;
    final empresaId = ref.read(currentUserProvider)?.empresaId;
    if (empresaId == null) return;

    setState(() => _duplicando = true);
    try {
      final copia = await ref.read(modelosRelatorioRepositoryProvider).duplicarModelo(modelo, empresaId);
      ref.invalidate(resumoModelosEnsaioProvider(empresaId));
      ref.invalidate(modelosPorTipoEnsaioProvider(ModelosPorTipoParams(empresaId: empresaId, tipoEnsaioId: modelo.tipoEnsaioId)));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ModeloRelatorioEditorScreen(modeloId: copia.id, tipoEnsaioNome: widget.tipoEnsaioNome)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _duplicando = false);
    }
  }

  // Mesma regra de `ModelosRelatorioTipoScreen._podeEditar`: um modelo só é
  // editável por quem o produziu — a própria Diavicon pode editar os
  // modelos padrão dela, mas nenhuma outra empresa pode.
  bool get _somenteLeitura {
    final modelo = _modelo;
    if (modelo == null) return false;
    final empresaAtualId = ref.read(currentUserProvider)?.empresaId;
    return modelo.empresaId != empresaAtualId;
  }

  EnsaioModeloConfig get _config => resolverEnsaioModeloConfig(widget.tipoEnsaioNome) ?? ensaiosModeloConfig['Inspeção Visual']!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(_modelo?.nome ?? 'Modelo de relatório', overflow: TextOverflow.ellipsis),
        actions: [
          if (!_somenteLeitura)
            TextButton(
              onPressed: (_carregando || _salvando) ? null : _salvar,
              child: _salvando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: 'Editor'), Tab(text: 'Preview'), Tab(text: 'Decoração')],
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildEditorTab(),
                ModeloRelatorioPreview(schema: _schema, tipoEnsaioNome: widget.tipoEnsaioNome),
                DecoracaoEditor(
                  config: _schema.decoracao,
                  onChanged: (d) => setState(() => _schema = _schema.copyWith(decoracao: d)),
                ),
              ],
            ),
    );
  }

  Widget _buildEditorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_somenteLeitura) _buildBannerPadrao(),
          if (_somenteLeitura) const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              children: [
                _buildSecao(
                  id: 'cabecalho',
                  titulo: 'Cabeçalho',
                  ativo: _schema.cabecalho.ativo,
                  onAtivoChanged: (v) => setState(() => _schema = _schema.copyWith(cabecalho: _schema.cabecalho.copyWith(ativo: v))),
                  child: QuadroEditor(
                    quadro: _schema.cabecalho.quadro,
                    catalogo: camposCabecalho,
                    tiposPermitidos: const [TipoConteudoSlot.texto, TipoConteudoSlot.imagem],
                    somenteLeitura: _somenteLeitura,
                    onChanged: (q) => setState(() => _schema = _schema.copyWith(cabecalho: _schema.cabecalho.copyWith(quadro: q))),
                  ),
                ),
                const Divider(height: 1),
                _buildSecao(
                  id: 'informacoes_iniciais',
                  titulo: 'Informações iniciais',
                  ativo: _schema.informacoesIniciais.ativo,
                  onAtivoChanged: (v) => setState(
                      () => _schema = _schema.copyWith(informacoesIniciais: _schema.informacoesIniciais.copyWith(ativo: v))),
                  child: InformacoesIniciaisEditor(
                    config: _schema.informacoesIniciais,
                    somenteLeitura: _somenteLeitura,
                    onChanged: (c) => setState(() => _schema = _schema.copyWith(informacoesIniciais: c)),
                  ),
                ),
                const Divider(height: 1),
                _buildSecao(
                  id: 'referencial',
                  titulo: 'Referencial',
                  ativo: _schema.referencial.ativo,
                  onAtivoChanged: (v) =>
                      setState(() => _schema = _schema.copyWith(referencial: _schema.referencial.copyWith(ativo: v))),
                  child: ReferencialEditor(
                    config: _schema.referencial,
                    catalogosPermitidos: _config.catalogosReferencialPermitidos,
                    somenteLeitura: _somenteLeitura,
                    onChanged: (c) => setState(() => _schema = _schema.copyWith(referencial: c)),
                  ),
                ),
                const Divider(height: 1),
                _buildSecao(
                  id: 'registros',
                  titulo: 'Registros',
                  ativo: _schema.registros.ativo,
                  onAtivoChanged: (v) =>
                      setState(() => _schema = _schema.copyWith(registros: _schema.registros.copyWith(ativo: v))),
                  child: QuadroEditor(
                    quadro: _schema.registros.quadro,
                    catalogo: _config.camposRegistro,
                    tiposPermitidos: _config.tiposPermitidosRegistro,
                    legendaRepeticao: _config.legendaRegistros,
                    catalogoSubLista: _config.camposSubListaRegistro,
                    rotuloSubLista: _config.rotuloSubListaRegistro,
                    somenteLeitura: _somenteLeitura,
                    onChanged: (q) => setState(() => _schema = _schema.copyWith(registros: _schema.registros.copyWith(quadro: q))),
                  ),
                ),
                if (_config.suportaAnaliseElementos) ...[
                  const Divider(height: 1),
                  _buildSecao(
                    id: 'analise_elementos',
                    titulo: 'Análise de Elementos',
                    ativo: _schema.analiseElementos.ativo,
                    onAtivoChanged: (v) =>
                        setState(() => _schema = _schema.copyWith(analiseElementos: _schema.analiseElementos.copyWith(ativo: v))),
                    child: QuadroEditor(
                      quadro: _schema.analiseElementos.quadro,
                      catalogo: _config.camposAnaliseElementos,
                      tiposPermitidos: const [TipoConteudoSlot.texto],
                      legendaRepeticao: 'Repete automaticamente por elemento estrutural (só os com Longitudinal e Transversal)',
                      somenteLeitura: _somenteLeitura,
                      onChanged: (q) => setState(() => _schema = _schema.copyWith(analiseElementos: _schema.analiseElementos.copyWith(quadro: q))),
                    ),
                  ),
                ],
                if (_config.suportaRegistrosAgrupados) ...[
                  const Divider(height: 1),
                  _buildSecao(
                    id: 'registros_agrupados',
                    titulo: 'Registros agrupados',
                    ativo: _schema.registrosAgrupados.ativo,
                    onAtivoChanged: (v) =>
                        setState(() => _schema = _schema.copyWith(registrosAgrupados: _schema.registrosAgrupados.copyWith(ativo: v))),
                    child: RegistrosAgrupadosEditor(
                      config: _schema.registrosAgrupados,
                      campos: _config.camposEstatisticasAgrupadas,
                      camposGraficos: _config.camposGraficosAgrupados,
                      somenteLeitura: _somenteLeitura,
                      onChanged: (c) => setState(() => _schema = _schema.copyWith(registrosAgrupados: c)),
                    ),
                  ),
                ],
                if (_config.suportaGutSomatorio) ...[
                  const Divider(height: 1),
                  _buildSecao(
                    id: 'gut_somatorio',
                    titulo: 'GUT — Somatório de risco',
                    ativo: _schema.gutSomatorio.ativoPorEstrutura || _schema.gutSomatorio.ativoPorLocal,
                    onAtivoChanged: (v) => setState(() => _schema = _schema.copyWith(
                          gutSomatorio: v
                              ? _schema.gutSomatorio.copyWith(ativoPorEstrutura: true, ativoPorLocal: true)
                              : _schema.gutSomatorio.copyWith(ativoPorEstrutura: false, ativoPorLocal: false),
                        )),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('Somatório por Estrutura', style: TextStyle(fontSize: 13)),
                          value: _schema.gutSomatorio.ativoPorEstrutura,
                          activeThumbColor: AppColors.primary,
                          onChanged: _somenteLeitura
                              ? null
                              : (v) => setState(
                                  () => _schema = _schema.copyWith(gutSomatorio: _schema.gutSomatorio.copyWith(ativoPorEstrutura: v))),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('Somatório por Local', style: TextStyle(fontSize: 13)),
                          value: _schema.gutSomatorio.ativoPorLocal,
                          activeThumbColor: AppColors.primary,
                          onChanged: _somenteLeitura
                              ? null
                              : (v) =>
                                  setState(() => _schema = _schema.copyWith(gutSomatorio: _schema.gutSomatorio.copyWith(ativoPorLocal: v))),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 1),
                _buildSecao(
                  id: 'galeria',
                  titulo: 'Galeria',
                  ativo: _schema.galeria.ativo,
                  onAtivoChanged: (v) => setState(() => _schema = _schema.copyWith(galeria: _schema.galeria.copyWith(ativo: v))),
                  child: GaleriaEditor(
                    config: _schema.galeria,
                    onChanged: (c) => setState(() => _schema = _schema.copyWith(galeria: c)),
                  ),
                ),
                const Divider(height: 1),
                _buildSecao(
                  id: 'resumo',
                  titulo: 'Tabela resumo de registros',
                  ativo: _schema.resumo.ativo,
                  onAtivoChanged: (v) => setState(() => _schema = _schema.copyWith(resumo: _schema.resumo.copyWith(ativo: v))),
                  child: ResumoEditor(
                    config: _schema.resumo,
                    tabelas: _config.tabelasResumo,
                    onChanged: (c) => setState(() => _schema = _schema.copyWith(resumo: c)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBannerPadrao() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFFFF9800)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Este é um modelo padrão e não pode ser editado diretamente.',
              style: TextStyle(fontSize: 13, color: Color(0xFF8A5A00)),
            ),
          ),
          ElevatedButton(
            onPressed: _duplicando ? null : _duplicarParaEditar,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            child: _duplicando
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Duplicar para editar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSecao({
    required String id,
    required String titulo,
    required bool ativo,
    required ValueChanged<bool> onAtivoChanged,
    required Widget child,
  }) {
    final expandida = _secaoExpandida == id;
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _secaoExpandida = expandida ? '' : id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Icon(expandida ? Icons.keyboard_arrow_down : Icons.chevron_right, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF3E3E3D)),
                  ),
                ),
                Switch(
                  value: ativo,
                  activeThumbColor: AppColors.primary,
                  onChanged: _somenteLeitura ? null : onAtivoChanged,
                ),
              ],
            ),
          ),
        ),
        if (expandida)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: AbsorbPointer(
              absorbing: _somenteLeitura,
              child: Opacity(opacity: ativo ? 1 : 0.4, child: child),
            ),
          ),
      ],
    );
  }
}
