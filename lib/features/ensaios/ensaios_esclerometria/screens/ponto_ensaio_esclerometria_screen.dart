import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../ensaios_geral/providers/ensaios_provider.dart';
import '../../ensaios_geral/providers/ensaio_permissoes_provider.dart';
import '../../ensaios_geral/screens/galeria_ensaio_screen.dart';

import '../models/esclerometria_model.dart';
import '../repositories/esclerometria_repository.dart';
import 'analise_esclerometria_screen.dart';

/// Regra de aceitação/rejeição de leituras (ver mockup fornecido): cada
/// leitura é comparada contra a média de TODAS as leituras já coletadas; se
/// o desvio relativo passar de 10%, é rejeitada. A "média provisória"
/// exibida considera só as leituras aceitas. Recalculado do zero a cada
/// leitura adicionada/removida — leituras antigas podem trocar de status.
const int _kMinValidas = 5;
const double _kLimiarRejeicao = 0.10;

class PontoEnsaioEsclerometriaScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String pontoNome;
  final String elementoNome;
  final String tipoElemento;
  final String local;
  final String elementoId;
  final String? pontoGeralId;
  final String tipoEnsaioId;

  const PontoEnsaioEsclerometriaScreen({
    super.key,
    required this.projetoId,
    required this.pontoNome,
    required this.elementoNome,
    required this.tipoElemento,
    required this.local,
    required this.elementoId,
    this.pontoGeralId,
    required this.tipoEnsaioId,
  });

  @override
  ConsumerState<PontoEnsaioEsclerometriaScreen> createState() => _PontoEnsaioEsclerometriaScreenState();
}

class _PontoEnsaioEsclerometriaScreenState extends ConsumerState<PontoEnsaioEsclerometriaScreen> {
  bool _isEditingName = false;
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _hasChanges = false;
  bool _erroInputLeitura = false;

  late TextEditingController _nomePontoCtrl;
  late TextEditingController _indiceKCtrl;
  final TextEditingController _novaLeituraCtrl = TextEditingController();

  List<EsclerometriaLeituraModel> _leituras = [];
  DirecaoImpacto _direcao = DirecaoImpacto.horizontal;

  File? _fotoJanelaLocal;
  File? _fotoEnsaioLocal;
  String? _urlFotoJanela;
  String? _urlFotoEnsaio;

  String? _pontoGeralIdAtual;
  String? _esclerometriaIdAtual;

  @override
  void initState() {
    super.initState();
    _nomePontoCtrl = TextEditingController(text: widget.pontoNome);
    _indiceKCtrl = TextEditingController(text: '1');

    if (widget.pontoGeralId != null && widget.pontoGeralId!.isNotEmpty) {
      _pontoGeralIdAtual = widget.pontoGeralId;
    } else {
      _hasChanges = true;
    }

    _nomePontoCtrl.addListener(_onFieldChanged);
    _indiceKCtrl.addListener(_onFieldChanged);
    _carregarDadosExistentes();
  }

  @override
  void dispose() {
    _nomePontoCtrl.removeListener(_onFieldChanged);
    _nomePontoCtrl.dispose();
    _indiceKCtrl.dispose();
    _novaLeituraCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  // --- Regra de aceitação/rejeição ---
  double get _mediaGeral {
    if (_leituras.isEmpty) return 0;
    final soma = _leituras.fold<int>(0, (a, b) => a + b.valorQ);
    return soma / _leituras.length;
  }

  double _delta(EsclerometriaLeituraModel l) {
    final media = _mediaGeral;
    if (media == 0) return 0;
    return (l.valorQ - media) / media;
  }

  bool _aceita(EsclerometriaLeituraModel l) => _delta(l).abs() <= _kLimiarRejeicao;

  List<EsclerometriaLeituraModel> get _validas => _leituras.where(_aceita).toList();

  double get _mediaValida {
    final v = _validas;
    if (v.isEmpty) return 0;
    final soma = v.fold<int>(0, (a, b) => a + b.valorQ);
    return soma / v.length;
  }

  bool get _finalizavel => _validas.length >= _kMinValidas;

  int get _indiceK => int.tryParse(_indiceKCtrl.text.trim()) ?? 1;

  double get _resultadoFinal => _mediaValida * _indiceK;

  double get _desvioPadraoValidas {
    final v = _validas;
    if (v.length < 2) return 0;
    final media = _mediaValida;
    final somaQuad = v.fold<double>(0, (a, l) => a + (l.valorQ - media) * (l.valorQ - media));
    return math.sqrt(somaQuad / v.length);
  }

  double get _coefVariacao {
    final media = _mediaValida;
    if (media == 0) return 0;
    return (_desvioPadraoValidas / media) * 100;
  }

  // --- Banco de dados ---
  Future<void> _carregarDadosExistentes() async {
    if (_pontoGeralIdAtual == null) {
      setState(() => _isInitializing = false);
      return;
    }
    try {
      final supabase = Supabase.instance.client;

      final geralResp = await supabase.from('pontos_ensaios_geral').select('*').eq('id', _pontoGeralIdAtual!).maybeSingle();
      if (geralResp != null) _nomePontoCtrl.text = geralResp['nome_ponto'] ?? widget.pontoNome;

      final escResp = await supabase
          .from('ponto_ensaio_esclerometria')
          .select('*')
          .eq('ponto_geral_id', _pontoGeralIdAtual!)
          .maybeSingle();

      if (escResp != null) {
        _esclerometriaIdAtual = escResp['id'] as String;
        _direcao = DirecaoImpacto.fromGraus((escResp['inclinacao'] as num?)?.toInt());
        _indiceKCtrl.text = ((escResp['indice_k'] as num?)?.toInt() ?? 1).toString();
        _urlFotoJanela = escResp['foto_janela'];
        _urlFotoEnsaio = escResp['foto_ensaio'];

        final leiturasResp = await supabase
            .from('ponto_ensaio_esclerometria_leituras')
            .select('*')
            .eq('ponto_id', _esclerometriaIdAtual!)
            .order('criado_em', ascending: true);

        _leituras = (leiturasResp as List).map((l) => EsclerometriaLeituraModel.fromJson(l)).toList();
      }
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro DB: ${e.message}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasChanges = false;
        });
      }
    }
  }

  Future<void> _capturarFoto({required bool janela}) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Câmera'), onTap: () => Navigator.pop(context, ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galeria'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ],
        ),
      ),
    );

    if (source != null) {
      final image = await ImagePicker().pickImage(source: source, imageQuality: 80);
      if (image != null) {
        setState(() {
          if (janela) {
            _fotoJanelaLocal = File(image.path);
          } else {
            _fotoEnsaioLocal = File(image.path);
          }
          _hasChanges = true;
        });
      }
    }
  }

  void _adicionarLeitura() {
    final texto = _novaLeituraCtrl.text.trim();
    final valor = int.tryParse(texto);
    if (valor == null) {
      setState(() => _erroInputLeitura = true);
      return;
    }
    setState(() {
      _erroInputLeitura = false;
      _leituras.add(EsclerometriaLeituraModel(valorQ: valor, status: 'rejeitada'));
      _novaLeituraCtrl.clear();
      _hasChanges = true;
    });
  }

  void _abrirModalEditarLeitura(int index) {
    final leitura = _leituras[index];
    final ctrl = TextEditingController(text: leitura.valorQ.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Leitura ${index + 1}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: InputDecoration(hintText: 'Índice esclerométrico', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          OutlinedButton(
            onPressed: () async {
              if (leitura.id != null) {
                setState(() => _isLoading = true);
                await ref.read(esclerometriaRepositoryProvider).deletarLeitura(leitura.id!);
              }
              setState(() {
                _leituras.removeAt(index);
                _hasChanges = true;
                _isLoading = false;
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Apagar', style: TextStyle(color: AppColors.error)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final novoValor = int.tryParse(ctrl.text.trim());
              if (novoValor == null) return;
              setState(() {
                _leituras[index] = EsclerometriaLeituraModel(id: leitura.id, valorQ: novoValor, status: leitura.status);
                _hasChanges = true;
              });
              Navigator.pop(context);
            },
            child: const Text('Salvar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deletarPonto() async {
    if (_pontoGeralIdAtual == null) {
      Navigator.pop(context);
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Ponto'),
        content: const Text('Deseja realmente excluir este ponto de ensaio e todos os seus dados vinculados?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(esclerometriaRepositoryProvider).deletarPontoCompleto(_pontoGeralIdAtual!);
      if (mounted) {
        ref.invalidate(resumoEnsaiosProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ponto excluído com sucesso!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _salvarDados() async {
    setState(() => _isLoading = true);
    try {
      // Recalcula o status final de cada leitura antes de persistir (o
      // status pode ter mudado desde a última recomputação em tela).
      final leiturasFinal = _leituras.map((l) {
        return EsclerometriaLeituraModel(id: l.id, valorQ: l.valorQ, status: _aceita(l) ? 'aceita' : 'rejeitada');
      }).toList();

      final resultadoBadge = _finalizavel ? _resultadoFinal.toStringAsFixed(1) : 'Pendente';
      final corBadge = _finalizavel ? '#4CAF50' : '#BDBDBD';

      final model = EsclerometriaCompletoModel(
        idGeral: _pontoGeralIdAtual,
        idEsclerometria: _esclerometriaIdAtual,
        nomePonto: _nomePontoCtrl.text,
        elementoNome: widget.elementoNome,
        tipoElemento: widget.tipoElemento,
        local: widget.local,
        criadoEm: DateTime.now().toIso8601String(),
        resultado: resultadoBadge,
        resultadoCor: corBadge,
        urlFotoJanela: _urlFotoJanela,
        urlFotoEnsaio: _urlFotoEnsaio,
        inclinacao: _direcao.graus,
        indiceK: _indiceK,
        leituras: leiturasFinal,
      );

      final resultado = await ref.read(esclerometriaRepositoryProvider).salvarPonto(
            dados: model,
            projetoId: widget.projetoId,
            elementoId: widget.elementoId,
            tipoEnsaioId: widget.tipoEnsaioId,
            fotoJanelaNova: _fotoJanelaLocal,
            fotoEnsaioNova: _fotoEnsaioLocal,
          );

      if (mounted) {
        setState(() {
          _pontoGeralIdAtual = resultado['pontoGeralId'];
          _esclerometriaIdAtual = resultado['esclerometriaId'];
          _urlFotoJanela = resultado['urlFotoJanela'];
          _urlFotoEnsaio = resultado['urlFotoEnsaio'];
          _leituras = leiturasFinal;
          _hasChanges = false;
        });
        ref.invalidate(resumoEnsaiosProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));

    final permissoes = ref.watch(ensaioPermissoesProvider(_pontoGeralIdAtual ?? '')).value ?? EnsaioPermissoes.somenteVisualizar;

    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: MenuDrawerAppBar(
        title: 'Ponto de\nEnsaio',
        items: [
          Opacity(opacity: 0.4, child: DiaviconMenuItem(icon: Icons.info_outline, label: 'Informações', onTap: () {})),
          DiaviconMenuItem(
            icon: Icons.camera_alt_outlined,
            label: 'Fotos',
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              if (_pontoGeralIdAtual == null || _hasChanges) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Salve as informações primeiro.'), backgroundColor: Colors.orange),
                );
                return;
              }
              navigator.push(
                MaterialPageRoute(
                  builder: (context) => GaleriaEnsaioScreen(
                    pontoGeralId: _pontoGeralIdAtual!,
                    pontoNome: _nomePontoCtrl.text,
                    elementoNome: widget.elementoNome,
                    tipoElemento: widget.tipoElemento,
                    local: widget.local,
                    tipoEnsaio: widget.tipoEnsaioId,
                  ),
                ),
              );
            },
          ),
          DiaviconMenuItem(
            icon: Icons.show_chart_rounded,
            label: 'Análise',
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              if (_pontoGeralIdAtual == null || _hasChanges) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Salve o ponto primeiro para visualizar a análise.'), backgroundColor: Colors.orange),
                );
                return;
              }
              navigator.push(
                MaterialPageRoute(builder: (context) => AnaliseEsclerometriaScreen(pontoGeralId: _pontoGeralIdAtual!)),
              );
            },
          ),
          const Spacer(),
          const Divider(),
          if (permissoes.canDelete)
            IconButton(
              iconSize: 30,
              color: Colors.red.shade800,
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                Navigator.pop(context);
                _deletarPonto();
              },
            ),
        ],
      ),
      appBar: CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        titleWidget: Column(
          children: [
            Text('${widget.elementoNome} · ${widget.tipoElemento} · ${widget.local}',
                style: const TextStyle(fontSize: 10, color: Colors.white70), overflow: TextOverflow.ellipsis, maxLines: 1),
            const Text('Esclerometria', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!permissoes.canEdit)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.visibility_outlined, size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Somente visualização — apenas a empresa que criou este ensaio pode editá-lo.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            AbsorbPointer(
              absorbing: !permissoes.canEdit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // --- HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _isEditingName
                      ? TextField(controller: _nomePontoCtrl, style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold), onSubmitted: (_) => setState(() => _isEditingName = false))
                      : Text('${_nomePontoCtrl.text} - ${widget.elementoNome}', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                if (permissoes.canEdit)
                  IconButton(icon: Icon(_isEditingName ? Icons.check : Icons.edit_square), onPressed: () => setState(() => _isEditingName = !_isEditingName)),
              ],
            ),
            Text(widget.tipoElemento, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey)),
            Text(widget.local, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 24),

            // --- FOTOS ---
            Row(
              children: [
                Expanded(child: _buildFotoCard('Marcação da área', _fotoJanelaLocal, _urlFotoJanela, () => _capturarFoto(janela: true))),
                const SizedBox(width: 16),
                Expanded(child: _buildFotoCard('Realização do Ensaio', _fotoEnsaioLocal, _urlFotoEnsaio, () => _capturarFoto(janela: false))),
              ],
            ),
            const SizedBox(height: 24),

            // --- DIREÇÃO DO IMPACTO ---
            Text('Direção do impacto', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DirecaoImpacto.values.map((d) {
                final sel = d == _direcao;
                return GestureDetector(
                  onTap: () => setState(() {
                    _direcao = d;
                    _hasChanges = true;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFF2C2C2A) : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(d.label, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w500, color: sel ? Colors.white : const Color(0xFF686868))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // --- FATOR DE CORREÇÃO K ---
            Text('Fator de correção (k)', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _indiceKCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- LEITURAS VÁLIDAS / MÉDIA PROVISÓRIA ---
            Row(
              children: [
                Expanded(child: _buildStatCard('leituras válidas', '${_validas.length} / mín. $_kMinValidas')),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('média provisória', _validas.isEmpty ? '—' : _mediaValida.toStringAsFixed(1))),
              ],
            ),
            if (_finalizavel) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildStatCard('resultado final (média × k)', _resultadoFinal.toStringAsFixed(1), destaque: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCVarCard()),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // --- ADICIONAR LEITURA ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _novaLeituraCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      if (_erroInputLeitura) setState(() => _erroInputLeitura = false);
                    },
                    decoration: InputDecoration(
                      hintText: 'índice esclerométrico',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _adicionarLeitura,
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: const Text('adicionar', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                ),
              ],
            ),
            if (_erroInputLeitura)
              const Padding(padding: EdgeInsets.only(top: 6), child: Text('informe um valor de leitura', style: TextStyle(color: AppColors.error, fontSize: 12))),
            const SizedBox(height: 20),

            // --- LEITURAS COLETADAS ---
            Text('leituras coletadas', style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            const SizedBox(height: 8),
            if (_leituras.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('Nenhuma leitura adicionada.', style: GoogleFonts.lato(color: Colors.grey)))
            else
              ...List.generate(_leituras.length, (i) => i).reversed.map((i) => _buildLinhaLeitura(i)),

            const SizedBox(height: 32),
                ],
              ),
            ),

            // --- SALVAR / FINALIZAR ---
            if (permissoes.canEdit)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isLoading || !_finalizavel) ? null : _salvarDados,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _finalizavel ? const Color(0xFFFFA726) : Colors.grey.shade200,
                    disabledBackgroundColor: Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                      : Text(
                          _finalizavel ? 'Finalizar ponto (${_validas.length} leituras válidas)' : 'Finalizar ponto (mín. $_kMinValidas leituras válidas)',
                          style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: _finalizavel ? Colors.white : Colors.grey.shade500),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinhaLeitura(int index) {
    final leitura = _leituras[index];
    final delta = _delta(leitura);
    final aceita = _aceita(leitura);
    final deltaTxt = '${delta >= 0 ? '+' : ''}${(delta * 100).toStringAsFixed(1)}%';

    return GestureDetector(
      onTap: () => _abrirModalEditarLeitura(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('leitura ${index + 1}', style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                const SizedBox(width: 8),
                Text('${leitura.valorQ}', style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
              ],
            ),
            Row(
              children: [
                Text(deltaTxt, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: aceita ? const Color(0xFFE1F5EE) : const Color(0xFFFADCD8), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    aceita ? 'aceita' : 'rejeitada',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: aceita ? const Color(0xFF04342C) : const Color(0xFF7A2418)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCVarCard() {
    final isHomogeneo = _coefVariacao <= 15.0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Coef. de variação', style: TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Row(
            children: [
              Text('${_coefVariacao.toStringAsFixed(0)}%', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: isHomogeneo ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  isHomogeneo ? 'Homogêneo' : 'Heterogêneo',
                  style: TextStyle(fontSize: 9, color: isHomogeneo ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String valor, {bool destaque = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: destaque ? const Color(0xFFFFF3E0) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(valor, style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
        ],
      ),
    );
  }

  Widget _buildFotoCard(String titulo, File? fotoLocal, String? urlRemota, VoidCallback onTap) {
    ImageProvider? imageProvider;
    if (fotoLocal != null) {
      imageProvider = FileImage(fotoLocal);
    } else if (urlRemota != null && urlRemota.isNotEmpty) {
      imageProvider = NetworkImage(urlRemota);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(titulo, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                  image: imageProvider != null ? DecorationImage(image: imageProvider, fit: BoxFit.cover) : null,
                ),
                child: imageProvider == null ? const Center(child: Icon(Icons.camera_alt, color: Colors.grey)) : null,
              ),
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.edit_square, size: 20, color: Color(0xFF3E3E3D)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
