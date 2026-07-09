import 'dart:io';
import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:diavicon/features/elementos/providers/info_planejamento_provider.dart';
import 'package:diavicon/features/elementos/widgets/itens_contratados_modal.dart';
import 'package:diavicon/features/elementos/widgets/marcar_elemento_planejamento_modal.dart';
import 'package:diavicon/features/ensaios/widgets/lista_regioes_ensaio_modal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/compact_button.dart';
import 'package:diavicon/features/elementos/models/elemento_model.dart';
import 'package:diavicon/features/elementos/providers/elemento_provider.dart';
import 'package:diavicon/features/elementos/widgets/marcacao_planta_popup.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlanejamentoScreen extends ConsumerStatefulWidget {
  const PlanejamentoScreen({
    super.key,
    required this.estruturaId,
    required this.plantaId,
    required this.plantaUrl,
    required this.plantaTitulo,
    required this.plantaLocal,
  });

  final String estruturaId;
  final String plantaId;
  final String plantaUrl;
  final String plantaTitulo;
  final String plantaLocal;

  @override
  ConsumerState<PlanejamentoScreen> createState() => _PlanejamentoScreenState();
}

class _PlanejamentoScreenState extends ConsumerState<PlanejamentoScreen> {
  int _abaSelecionada = 0;
  bool _visualizarNomeElementos = true;

  double _tamanhoFonteNome = 12.0;
  String? _empresaSelecionadaId;

  @override
  void initState() {
    super.initState();
    _carregarPreferenciasPlanta();
  }

  // Busca como a planta foi salva da última vez
  Future<void> _carregarPreferenciasPlanta() async {
    try {
      final resp = await Supabase.instance.client
          .from('plantas') // Ajuste se a tabela tiver outro nome
          .select('mostrar_nomes, tamanho_fonte_nomes')
          .eq('id', widget.plantaId)
          .maybeSingle();

      if (resp != null && mounted) {
        setState(() {
          if (resp['mostrar_nomes'] != null)
            _visualizarNomeElementos = resp['mostrar_nomes'];
          if (resp['tamanho_fonte_nomes'] != null)
            _tamanhoFonteNome = (resp['tamanho_fonte_nomes'] as num).toDouble();
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar preferências da planta: $e');
    }
  }

  //  Salva as configurações sempre que o usuário mexer
  Future<void> _salvarPreferenciasPlanta() async {
    try {
      await Supabase.instance.client
          .from('plantas') // Ajuste se a tabela tiver outro nome
          .update({
            'mostrar_nomes': _visualizarNomeElementos,
            'tamanho_fonte_nomes': _tamanhoFonteNome,
          })
          .eq('id', widget.plantaId);
    } catch (e) {
      debugPrint('Erro ao salvar preferências da planta: $e');
    }
  }

  void _abrirSeletorElementosParaPosicionar() async {
    final elementoEscolhido = await showModalBottomSheet<ElementoModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          MarcarElementoPlanejamentoModal(estruturaId: widget.estruturaId),
    );

    if (elementoEscolhido != null) {
      _iniciarMarcacaoElemento(elementoEscolhido);
    }
  }

  Future<void> _iniciarMarcacaoElemento(ElementoModel elemento) async {
    String formatoPadrao = 'Retângulo';

    try {
      final resp = await Supabase.instance.client
          .from('tipos_elemento')
          .select('formato_marcacao')
          .eq('nome', elemento.tipo ?? '')
          .maybeSingle();

      if (resp != null && resp['formato_marcacao'] != null) {
        formatoPadrao = resp['formato_marcacao'];
      }
    } catch (e) {
      debugPrint('Erro ao buscar formato: $e');
    }

    final resultado = await showMarcacaoPlantaPopup(
      context,
      arquivoUrl: widget.plantaUrl,
      plantaId: widget.plantaId,
      estruturaId: widget.estruturaId,
      nomeElemento: elemento.nome,
      inicial: MarcacaoPlanta(
        x: 0.5,
        y: 0.5,
        plantaId: widget.plantaId,
        tipoMarcacao: formatoPadrao,
        largura: 0.12,
        altura: 0.06,
        nomeX: 0.5,
        nomeY: 0.5 - 0.06,
      ),
    );

    if (resultado == null) return;

    try {
      final elementoAtualizado = ElementoModel(
        id: elemento.id,
        estruturaId: elemento.estruturaId,
        nome: elemento.nome,
        tipo: elemento.tipo,
        local: elemento.local,
        tipologiaEstrutural: elemento.tipologiaEstrutural,
        revestimento: elemento.revestimento,
        latitude: elemento.latitude,
        longitude: elemento.longitude,
        posicaoX: resultado.x,
        posicaoY: resultado.y,
        posicaoZ: elemento.posicaoZ,
        plantaId: widget.plantaId,
        tipoMarcacao: resultado.tipoMarcacao,
        marcacaoLargura: resultado.largura,
        marcacaoAltura: resultado.altura,
        marcacaoRotacao: resultado.rotacao,
        dimensoes: elemento.dimensoes,
        secao: elemento.secao,
        microclima: elemento.microclima,
        caa: elemento.caa,
        fotos: elemento.fotos,
        observacoes: elemento.observacoes,
        ativo: elemento.ativo,
        criadoEm: elemento.criadoEm,
        marcacaoCor: resultado.cor,
        marcacaoNomeX: resultado.nomeX,
        marcacaoNomeY: resultado.nomeY,
      );

      await ref
          .read(elementoRepositoryProvider)
          .atualizarElemento(elementoAtualizado);
      if (!mounted) return;

      ref.invalidate(todosElementosPorEstruturaProvider(widget.estruturaId));
      ref.invalidate(elementosPorEstruturaProvider(widget.estruturaId));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elemento posicionado com sucesso na planta!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar posição: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCabecalhoPlanta(),
          _buildCustomTabBar(),

          Expanded(
            child: _abaSelecionada == 0
                ? _buildAbaElementos()
                : _buildAbaRegioesEnsaio(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.5),
      centerTitle: true,
      toolbarHeight: 75,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        children: [
          Text(
            'Projeto',
            style: GoogleFonts.lato(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
          Text(
            'Estrutura',
            style: GoogleFonts.lato(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Planejamento',
            style: GoogleFonts.lato(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildCabecalhoPlanta() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Image.asset('assets/images/pdf.png', width: 36, height: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.plantaTitulo,
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3E3E3D),
                  ),
                ),
                Text(
                  widget.plantaLocal,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF686868),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFD9D9D9), width: 2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTabButton(titulo: 'Elementos', index: 0),
            _buildTabButton(titulo: 'Regiões de Ensaio', index: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({required String titulo, required int index}) {
    final isSelected = _abaSelecionada == index;
    return GestureDetector(
      onTap: () => setState(() => _abaSelecionada = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          titulo,
          style: GoogleFonts.lato(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF686868),
          ),
        ),
      ),
    );
  }

  Widget _buildAbaElementos() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Nome dos elementos',
                    style: GoogleFonts.lato(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3E3E3D),
                    ),
                  ),
                ),
              ),

              IconButton(
                icon: Icon(
                  _visualizarNomeElementos
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: _visualizarNomeElementos
                      ? AppColors.primary
                      : AppColors.greyMedium,
                  size: 24,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(
                    () => _visualizarNomeElementos = !_visualizarNomeElementos,
                  );
                  _salvarPreferenciasPlanta();
                },
              ),

              Visibility(
                visible: _visualizarNomeElementos,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: AppColors.greyMedium,
                            size: 22,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              if (_tamanhoFonteNome > 2.0)
                                _tamanhoFonteNome -= 2.0;
                            });
                            _salvarPreferenciasPlanta();
                          },
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_tamanhoFonteNome.toInt()}',
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF3E3E3D),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              if (_tamanhoFonteNome < 32.0)
                                _tamanhoFonteNome += 2.0;
                            });
                            _salvarPreferenciasPlanta();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9),
              border: Border.all(color: const Color(0xFF686868)),
            ),
            child: _VisualizadorPlantaPlanejamento(
              arquivoUrl: widget.plantaUrl,
              estruturaId: widget.estruturaId,
              plantaId: widget.plantaId,
              mostrarNomes: _visualizarNomeElementos,
              tamanhoFonteNome: _tamanhoFonteNome,
            ),
          ),
        ),

        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: CompactButton(
              text: 'Adicionar elemento em Planta',
              height: 52,
              onPressed: _abrirSeletorElementosParaPosicionar,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAbaRegioesEnsaio() {
    final infoAsync = ref.watch(infoPlanejamentoProvider(widget.estruturaId));

    return infoAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (err, _) => Center(
        child: Text(
          'Erro ao carregar: $err',
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (info) {
        final minhaEmpresaId = info['minhaEmpresaId'];
        final gestoraId = info['gestoraId'];
        final List<Map<String, dynamic>> empresas = info['empresas'];

        if (empresas.isEmpty)
          return const Center(child: Text('Nenhuma empresa disponível.'));

        final isGestora = minhaEmpresaId == gestoraId;
        String valorDropdown =
            _empresaSelecionadaId ?? minhaEmpresaId ?? empresas.first['id'];

        if (!empresas.any((e) => e['id'] == valorDropdown)) {
          valorDropdown = empresas.first['id'];
        }

        final empSelecionada = empresas.firstWhere(
          (e) => e['id'] == valorDropdown,
        );

        Widget dropdown = Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD9D9D9), width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: valorDropdown,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.greyMedium,
              ),
              items: empresas.map((emp) {
                return DropdownMenuItem<String>(
                  value: emp['id'],
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.greyVeryLight,
                        backgroundImage: emp['foto_url'] != null
                            ? NetworkImage(emp['foto_url'])
                            : null,
                        child: emp['foto_url'] == null
                            ? const Icon(
                                Icons.business,
                                size: 16,
                                color: AppColors.primary,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        emp['nome'],
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3E3E3D),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (isGestora && val != null)
                  setState(() => _empresaSelecionadaId = val);
              },
            ),
          ),
        );

        if (!isGestora) {
          dropdown = GestureDetector(
            onTap: () => DiaviconAlerts.show(
              context,
              'Acesso Restrito',
              'Apenas a gestora do projeto pode alterar.',
              isAviso: true,
            ),
            child: AbsorbPointer(child: dropdown),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: dropdown,
            ),

            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D9D9),
                  border: Border.all(color: const Color(0xFF686868)),
                ),
                child: _VisualizadorPlantaPlanejamento(
                  arquivoUrl: widget.plantaUrl,
                  estruturaId: widget.estruturaId,
                  plantaId: widget.plantaId,
                  mostrarNomes: true,
                  tamanhoFonteNome: _tamanhoFonteNome,
                  empresaIdParaRegioes: valorDropdown,
                ),
              ),
            ),

            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    // 🔥 BOTÃO 1: Quantitativos Contratados (Idêntico ao Protótipo)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (valorDropdown == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Selecione uma empresa no filtro primeiro!',
                                ),
                              ),
                            );
                            return;
                          }
                          showItensContratadosModal(
                            context,
                            empresaId: empSelecionada['id'],
                            empresaNome: empSelecionada['nome'],
                            empresaFotoUrl: empSelecionada['foto_url'],
                          );
                        },
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              26,
                            ), // Deixa arredondado tipo pílula
                            border: Border.all(
                              color: const Color(0xFFD9D9D9),
                              width: 1.5,
                            ), // Borda cinza do protótipo
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/icone_quantitativos.png',
                                width: 24,
                                height: 24,
                                // Fallback para não quebrar a tela enquanto você baixa o PNG:
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.assignment_turned_in,
                                  color: Color(0xFF686868),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Quantitativos\nContratados',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.lato(
                                  color: const Color(
                                    0xFF686868,
                                  ), // Texto cinza escuro
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 🔥 BOTÃO 2: Regiões de Ensaio (Idêntico ao Protótipo)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          showListaRegioesModal(
                            context,
                            estruturaId: widget.estruturaId,
                            plantaId: widget.plantaId,
                            plantaUrl: widget.plantaUrl,
                            empresaIdSelecionada: empSelecionada['id'],
                            empresaNome: empSelecionada['nome'],
                            empresaFotoUrl: empSelecionada['foto_url'],
                          );
                        },
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/icone_regioes.png',
                                width: 24,
                                height: 24,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.science_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Regiões de\nEnsaio',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.lato(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFiltroEnsaioCard({
    required String titulo,
    required String contador,
    required bool selecionado,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selecionado ? const Color(0xFFF2F9F7) : const Color(0xFFF5F5F5),
        border: Border.all(
          color: selecionado
              ? const Color(0xFF238E5A)
              : const Color(0xFFD9D9D9),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
              fontSize: 12,
              color: const Color(0xFF3E3E3D),
            ),
          ),
          Text(
            contador,
            style: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF686868),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisualizadorPlantaPlanejamento extends ConsumerStatefulWidget {
  const _VisualizadorPlantaPlanejamento({
    required this.arquivoUrl,
    required this.estruturaId,
    required this.plantaId,
    required this.mostrarNomes,
    required this.tamanhoFonteNome,
    this.empresaIdParaRegioes,
  });

  final String arquivoUrl;
  final String estruturaId;
  final String plantaId;
  final bool mostrarNomes;
  final double tamanhoFonteNome;
  final String? empresaIdParaRegioes;

  @override
  ConsumerState<_VisualizadorPlantaPlanejamento> createState() =>
      _VisualizadorPlantaPlanejamentoState();
}

class _VisualizadorPlantaPlanejamentoState
    extends ConsumerState<_VisualizadorPlantaPlanejamento> {
  bool _isPdf = false, _isLoading = false;
  Uint8List? _imageBytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _carregarMidia();
  }

  Future<void> _carregarMidia() async {
    final urlLower = widget.arquivoUrl.toLowerCase();
    if (urlLower.contains('.pdf')) {
      setState(() {
        _isPdf = true;
        _isLoading = true;
      });
      try {
        final request = await HttpClient().getUrl(Uri.parse(widget.arquivoUrl));
        final response = await request.close();
        if (response.statusCode != 200)
          throw Exception('Status: ${response.statusCode}');
        final bytes = await consolidateHttpClientResponseBytes(response);
        final doc = await PdfDocument.openData(bytes);
        final page = await doc.getPage(1);

        double w = page.width;
        double h = page.height;
        if (w < 1000) {
          w *= 2.0;
          h *= 2.0;
        }
        const maxDim = 2500.0;
        if (w > maxDim || h > maxDim) {
          final prop = w / h;
          if (w > h) {
            w = maxDim;
            h = maxDim / prop;
          } else {
            h = maxDim;
            w = maxDim * prop;
          }
        }
        final pageImg = await page.render(
          width: w,
          height: h,
          format: PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
        );
        if (pageImg != null && mounted)
          setState(() => _imageBytes = pageImg.bytes);
        await page.close();
        await doc.close();
      } catch (e) {
        if (mounted) setState(() => _error = e.toString());
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    if (_error != null)
      return Center(
        child: Text(
          'Erro: $_error',
          style: const TextStyle(color: Colors.red, fontSize: 12),
        ),
      );

    final elementosAsync = ref.watch(
      elementosPorEstruturaProvider(widget.estruturaId),
    );

    AsyncValue<List<dynamic>>? regioesAsync;
    if (widget.empresaIdParaRegioes != null) {
      regioesAsync = ref.watch(
        regioesEnsaioProvider(
          RegioesFiltro(
            plantaId: widget.plantaId,
            empresaId: widget.empresaIdParaRegioes!,
          ),
        ),
      );
    }

    return elementosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erro ao carregar pinos: $err')),
      data: (elementos) {
        final elementosDaPlanta = elementos
            .where(
              (el) =>
                  el.plantaId == widget.plantaId &&
                  el.posicaoX != null &&
                  el.posicaoY != null,
            )
            .toList();

        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          child: Center(
            child: Stack(
              children: [
                _isPdf
                    ? (_imageBytes != null
                          ? Image.memory(_imageBytes!)
                          : const SizedBox())
                    : Image.network(widget.arquivoUrl),

                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;

                      List<Widget> marcacoesRegioes = [];
                      if (regioesAsync != null && regioesAsync.value != null) {
                        marcacoesRegioes = regioesAsync.value!.map((regiao) {
                          final cx = regiao.posicaoX * w;
                          final cy = regiao.posicaoY * h;
                          final wPino = regiao.marcacaoLargura * w;
                          final hPino = regiao.marcacaoAltura * h;
                          final corPino = Color(
                            int.parse(
                              regiao.corMarcacao.replaceFirst('#', '0xff'),
                            ),
                          ).withOpacity(0.85);

                          return Positioned(
                            left: cx - (wPino / 2),
                            top: cy - (hPino / 2),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PinoDinamico(
                                  tipoMarcacao: regiao.tipoMarcacao,
                                  largura: wPino,
                                  altura: hPino,
                                  rotacao: regiao.marcacaoRotacao,
                                  corBase: corPino,
                                  mostrarNumero: false,
                                ),
                                Text(
                                  regiao.numero.toString(),
                                  style: GoogleFonts.lato(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black45,
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList();
                      }

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (widget.empresaIdParaRegioes == null)
                            ...elementosDaPlanta.expand<Widget>((el) {
                              final cx = el.posicaoX! * w;
                              final cy = el.posicaoY! * h;
                              final wPino = (el.marcacaoLargura ?? 0.12) * w;
                              final hPino = (el.marcacaoAltura ?? 0.06) * h;
                              final corVizinho = el.marcacaoCor != null
                                  ? Color(
                                      int.parse(
                                        el.marcacaoCor!.replaceFirst(
                                          '#',
                                          '0xff',
                                        ),
                                      ),
                                    )
                                  : Colors.orange;

                              final pino = Positioned(
                                left: cx - (wPino / 2),
                                top: cy - (hPino / 2),
                                child: PinoDinamico(
                                  tipoMarcacao: el.tipoMarcacao ?? 'Retângulo',
                                  largura: wPino,
                                  altura: hPino,
                                  rotacao: el.marcacaoRotacao ?? 0.0,
                                  corBase: corVizinho,
                                ),
                              );

                              Widget? nomeVizinho;
                              if (widget.mostrarNomes &&
                                  el.nome != null &&
                                  el.nome!.isNotEmpty) {
                                double nx = el.marcacaoNomeX ?? el.posicaoX!;
                                double ny = el.marcacaoNomeY ?? el.posicaoY!;
                                if (ny < -1.0 ||
                                    ny > 2.0 ||
                                    (nx == 0.0 && ny == 0.0)) {
                                  nx = el.posicaoX!;
                                  ny = el.posicaoY! - 0.06;
                                }

                                nomeVizinho = Positioned(
                                  left: nx * w,
                                  top: ny * h,
                                  child: IgnorePointer(
                                    child: FractionalTranslation(
                                      translation: const Offset(-0.5, -0.5),
                                      child: Text(
                                        el.nome!,
                                        style: TextStyle(
                                          color: corVizinho,
                                          fontSize: widget.tamanhoFonteNome,
                                          fontWeight: FontWeight.bold,
                                          shadows: const [
                                            Shadow(
                                              color: Colors.white,
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return [
                                pino,
                                if (nomeVizinho != null) nomeVizinho,
                              ];
                            }),

                          ...marcacoesRegioes,
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
