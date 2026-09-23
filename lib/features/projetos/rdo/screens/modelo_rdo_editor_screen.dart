import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/features/modelos_relatorios/models/quadro_model.dart';
import 'package:diavicon/features/modelos_relatorios/widgets/decoracao_editor.dart';
import 'package:diavicon/features/modelos_relatorios/widgets/galeria_editor.dart';
import 'package:diavicon/features/modelos_relatorios/widgets/informacoes_iniciais_editor.dart';
import 'package:diavicon/features/modelos_relatorios/widgets/quadro_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../models/campos_registro_rdo.dart';
import '../models/modelo_rdo_model.dart';
import '../models/modelo_rdo_schema.dart';
import '../providers/modelos_rdo_provider.dart';
import '../widgets/modelo_rdo_preview.dart';

/// Tela "acordeão" de um modelo de RDO — mesmo padrão de
/// `ModeloRelatorioEditorScreen` (3 abas: Editor/Preview/Decoração), sem
/// Referencial/Registros agrupados/Tabela resumo (não fazem sentido pro
/// RDO). "Registros" usa o mesmo `QuadroEditor` livre dos ensaios — os 7
/// campos fixos do RDO entram como catálogo (ver `campos_registro_rdo.dart`),
/// e Turnos é um bloco de repetição (sub-lista), igual a "Pontos de leitura"
/// da Resistividade ou "Anomalias" da Inspeção Visual.
class ModeloRdoEditorScreen extends ConsumerStatefulWidget {
  final String modeloId;

  const ModeloRdoEditorScreen({super.key, required this.modeloId});

  @override
  ConsumerState<ModeloRdoEditorScreen> createState() => _ModeloRdoEditorScreenState();
}

class _ModeloRdoEditorScreenState extends ConsumerState<ModeloRdoEditorScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  ModeloRdoModel? _modelo;
  ModeloRdoSchema _schema = ModeloRdoSchema.vazio();
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
      final modelo = await ref.read(modelosRdoRepositoryProvider).buscarPorId(widget.modeloId);
      if (!mounted) return;
      setState(() {
        _modelo = modelo;
        _schema = ModeloRdoSchema.fromJson(modelo.schemaJson);
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      final schemaNormalizado = _schema.copyWith(
        cabecalho: _schema.cabecalho.copyWith(quadro: _schema.cabecalho.quadro.normalizado()),
        registros: _schema.registros.copyWith(quadro: _schema.registros.quadro.normalizado()),
        informacoesIniciais: _schema.informacoesIniciais.normalizado(),
      );
      await ref.read(modelosRdoRepositoryProvider).salvarSchema(widget.modeloId, schemaNormalizado.toJson());
      if (!mounted) return;
      setState(() => _schema = schemaNormalizado);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modelo salvo com sucesso!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
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
      final copia = await ref.read(modelosRdoRepositoryProvider).duplicarModelo(modelo, empresaId);
      ref.invalidate(modelosRdoProvider(empresaId));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ModeloRdoEditorScreen(modeloId: copia.id)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _duplicando = false);
    }
  }

  // Um modelo só é editável por quem o criou — a empresa dona (via
  // `empresa_id`) pode editar o próprio; qualquer outro modelo visível
  // (ex.: modelo de outra empresa liberado por RLS) só pode ser duplicado.
  bool get _somenteLeitura {
    final modelo = _modelo;
    if (modelo == null) return false;
    return modelo.empresaId != ref.read(currentUserProvider)?.empresaId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(_modelo?.nome ?? 'Modelo de RDO', overflow: TextOverflow.ellipsis),
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
                ModeloRdoPreview(schema: _schema),
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
          if (_somenteLeitura) _buildBannerSomenteLeitura(),
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
                  id: 'registros',
                  titulo: 'Registros',
                  ativo: _schema.registros.ativo,
                  onAtivoChanged: (v) =>
                      setState(() => _schema = _schema.copyWith(registros: _schema.registros.copyWith(ativo: v))),
                  child: QuadroEditor(
                    quadro: _schema.registros.quadro,
                    catalogo: camposRegistroRdo,
                    tiposPermitidos: const [TipoConteudoSlot.texto, TipoConteudoSlot.subLista],
                    legendaRepeticao: 'Repete automaticamente por RDO do período',
                    catalogoSubLista: camposTurnoRdo,
                    rotuloSubLista: 'Turnos',
                    somenteLeitura: _somenteLeitura,
                    onChanged: (q) => setState(() => _schema = _schema.copyWith(registros: _schema.registros.copyWith(quadro: q))),
                  ),
                ),
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
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBannerSomenteLeitura() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFFFF9800)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Este modelo é de outra empresa e não pode ser editado diretamente.',
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
