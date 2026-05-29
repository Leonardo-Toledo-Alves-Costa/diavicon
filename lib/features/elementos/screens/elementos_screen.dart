import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../models/elemento_model.dart';
import '../providers/elemento_provider.dart';

/// Tela de listagem dos elementos estruturais de uma estrutura.
/// Rota: /estruturas/:estruturaId/elementos
class ElementosScreen extends ConsumerWidget {
  final String estruturaId;
  final String estruturaNome;

  const ElementosScreen({
    super.key,
    required this.estruturaId,
    required this.estruturaNome,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elementosAsync = ref.watch(elementosProvider(estruturaId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Elementos Estruturais',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            Text(
              estruturaNome,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.greyMedium,
              ),
            ),
          ],
        ),
      ),
      body: elementosAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(
                'Erro ao carregar elementos:\n$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.greyMedium),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
                onPressed: () =>
                    ref.read(elementosProvider(estruturaId).notifier).carregar(),
                child: const Text('Tentar novamente',
                    style: TextStyle(color: AppColors.white)),
              ),
            ],
          ),
        ),
        data: (elementos) => elementos.isEmpty
            ? _buildVazio(context)
            : _buildLista(context, ref, elementos),
      ),

      // ── FAB: Novo elemento ─────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: AppColors.white),
        label: const Text(
          'Novo Elemento',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: () => _abrirForm(context, ref, null),
      ),
    );
  }

  // ── Estado vazio ───────────────────────────────────────────────────────────
  Widget _buildVazio(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.foundation,
              size: 72, color: AppColors.greyLight),
          const SizedBox(height: 16),
          const Text(
            'Nenhum elemento cadastrado',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.greyMedium,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toque em "Novo Elemento" para começar',
            style: TextStyle(fontSize: 13, color: AppColors.greyLight),
          ),
        ],
      ),
    );
  }

  // ── Lista de elementos ─────────────────────────────────────────────────────
  Widget _buildLista(
    BuildContext context,
    WidgetRef ref,
    List<ElementoModel> elementos,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: elementos.length,
      itemBuilder: (context, index) {
        final el = elementos[index];
        return _ElementoCard(
          elemento: el,
          onEditar: () => _abrirForm(context, ref, el),
          onDeletar: () => _confirmarDelete(context, ref, el),
        );
      },
    );
  }

  // ── Abrir formulário ───────────────────────────────────────────────────────
  void _abrirForm(BuildContext context, WidgetRef ref, ElementoModel? elemento) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ElementoFormScreen(
          estruturaId: estruturaId,
          elemento: elemento,
          onSalvo: () => ref
              .read(elementosProvider(estruturaId).notifier)
              .carregar(),
        ),
      ),
    );
  }

  // ── Confirmar exclusão ─────────────────────────────────────────────────────
  Future<void> _confirmarDelete(
    BuildContext context,
    WidgetRef ref,
    ElementoModel elemento,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir elemento'),
        content: Text(
            'Deseja excluir "${elemento.nome}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.greyMedium)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      try {
        await ref
            .read(elementosProvider(estruturaId).notifier)
            .deletar(elemento.id!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Elemento excluído com sucesso.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir: $e')),
          );
        }
      }
    }
  }
}

// ─── Card do elemento ─────────────────────────────────────────────────────────
class _ElementoCard extends StatelessWidget {
  final ElementoModel elemento;
  final VoidCallback onEditar;
  final VoidCallback onDeletar;

  const _ElementoCard({
    required this.elemento,
    required this.onEditar,
    required this.onDeletar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: const Icon(Icons.foundation, color: AppColors.primary),
        ),
        title: Text(
          elemento.nome ?? 'Sem nome',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (elemento.tipo != null)
              Text(
                elemento.tipo!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.greyMedium),
              ),
            if (elemento.topologia != null)
              Text(
                elemento.topologia!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.greyMedium),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.greyMedium),
          onSelected: (val) {
            if (val == 'editar') onEditar();
            if (val == 'deletar') onDeletar();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'editar',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18, color: AppColors.textDark),
                  SizedBox(width: 8),
                  Text('Editar'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'deletar',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Excluir',
                      style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMULÁRIO DE ELEMENTO (Create / Edit)
// ─────────────────────────────────────────────────────────────────────────────

class ElementoFormScreen extends ConsumerStatefulWidget {
  final String estruturaId;
  final ElementoModel? elemento; // null = criar, não-null = editar
  final VoidCallback? onSalvo;

  const ElementoFormScreen({
    super.key,
    required this.estruturaId,
    this.elemento,
    this.onSalvo,
  });

  @override
  ConsumerState<ElementoFormScreen> createState() =>
      _ElementoFormScreenState();
}

class _ElementoFormScreenState extends ConsumerState<ElementoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // ── Controllers ────────────────────────────────────────────────────────────
  final _nomeController = TextEditingController();
  final _dimensoesController = TextEditingController();
  final _secaoController = TextEditingController();
  final _observacoesController = TextEditingController();
  final _posXController = TextEditingController();
  final _posYController = TextEditingController();
  final _posZController = TextEditingController();

  // ── Dropdowns ──────────────────────────────────────────────────────────────
  String? _tipoSelecionado;
  String? _topologiaSelecionada;
  String? _revestimentoSelecionado;
  String? _microclimasSelecionado;
  String? _caaSelecionada;

  static const _tipos = [
    'Pilar', 'Viga', 'Laje', 'Fundação', 'Parede', 'Escada', 'Rampa', 'Outro',
  ];
  static const _topologias = [
    'Retangular', 'Circular', 'I', 'T', 'L', 'U', 'Outro',
  ];
  static const _revestimentos = [
    'Concreto aparente', 'Argamassa', 'Cerâmica', 'Pintura', 'Outro',
  ];
  static const _microclimas = [
    'Interior seco', 'Interior úmido', 'Exterior urbano',
    'Exterior industrial', 'Marinho', 'Submerso',
  ];
  static const _classes = ['I', 'II', 'III', 'IV'];

  // ── Fotos ──────────────────────────────────────────────────────────────────
  final List<String> _fotosExistentes = [];
  final List<String> _novasFotos = [];

  bool get _isEditing => widget.elemento != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _preencherDados();
  }

  void _preencherDados() {
    final el = widget.elemento!;
    _nomeController.text = el.nome ?? '';
    _dimensoesController.text = el.dimensoes ?? '';
    _secaoController.text = el.secao ?? '';
    _observacoesController.text = el.observacoes ?? '';
    _posXController.text = el.posicaoX?.toString() ?? '';
    _posYController.text = el.posicaoY?.toString() ?? '';
    _posZController.text = el.posicaoZ?.toString() ?? '';
    _tipoSelecionado = el.tipo;
    _topologiaSelecionada = el.topologia;
    _revestimentoSelecionado = el.revestimento;
    _microclimasSelecionado = el.microclima;
    _caaSelecionada = el.caa;
    if (el.fotos != null) _fotosExistentes.addAll(el.fotos!);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _dimensoesController.dispose();
    _secaoController.dispose();
    _observacoesController.dispose();
    _posXController.dispose();
    _posYController.dispose();
    _posZController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Editar Elemento' : 'Novo Elemento',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
          ),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _salvar,
              child: const Text(
                'Salvar',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Fotos ───────────────────────────────────────────────────────
              _buildSecaoFotos(),
              const SizedBox(height: 24),

              // ── Identificação ───────────────────────────────────────────────
              _buildSectionTitle('Identificação'),
              const SizedBox(height: 12),

              _buildTextField(
                label: 'Nome',
                hint: 'Ex: Pilar P1',
                controller: _nomeController,
                obrigatorio: true,
              ),
              const SizedBox(height: 12),

              _buildDropdown(
                label: 'Tipo',
                hint: 'Selecione o tipo',
                valor: _tipoSelecionado,
                opcoes: _tipos,
                obrigatorio: true,
                onChanged: (val) => setState(() => _tipoSelecionado = val),
              ),
              const SizedBox(height: 12),

              _buildDropdown(
                label: 'Topologia',
                hint: 'Selecione a topologia',
                valor: _topologiaSelecionada,
                opcoes: _topologias,
                onChanged: (val) =>
                    setState(() => _topologiaSelecionada = val),
              ),
              const SizedBox(height: 12),

              _buildDropdown(
                label: 'Revestimento',
                hint: 'Selecione o revestimento',
                valor: _revestimentoSelecionado,
                opcoes: _revestimentos,
                onChanged: (val) =>
                    setState(() => _revestimentoSelecionado = val),
              ),
              const SizedBox(height: 24),

              // ── Dimensões ───────────────────────────────────────────────────
              _buildSectionTitle('Dimensões e Seção'),
              const SizedBox(height: 12),

              _buildTextField(
                label: 'Dimensões',
                hint: 'Ex: 30x50cm',
                controller: _dimensoesController,
              ),
              const SizedBox(height: 12),

              _buildTextField(
                label: 'Seção transversal',
                hint: 'Ex: Seção retangular 30x50',
                controller: _secaoController,
              ),
              const SizedBox(height: 24),

              // ── Posição ─────────────────────────────────────────────────────
              _buildSectionTitle('Posição na Estrutura'),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      label: 'X (m)',
                      hint: '0.00',
                      controller: _posXController,
                      teclado: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      label: 'Y (m)',
                      hint: '0.00',
                      controller: _posYController,
                      teclado: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      label: 'Z (m)',
                      hint: '0.00',
                      controller: _posZController,
                      teclado: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Microclima e CAA ────────────────────────────────────────────
              _buildSectionTitle('Exposição Ambiental'),
              const SizedBox(height: 12),

              _buildDropdown(
                label: 'Microclima',
                hint: 'Condição de exposição',
                valor: _microclimasSelecionado,
                opcoes: _microclimas,
                onChanged: (val) =>
                    setState(() => _microclimasSelecionado = val),
              ),
              const SizedBox(height: 12),

              _buildDropdown(
                label: 'Classe de Agressividade Ambiental (CAA)',
                hint: 'Selecione a classe',
                valor: _caaSelecionada,
                opcoes: _classes,
                onChanged: (val) => setState(() => _caaSelecionada = val),
              ),
              const SizedBox(height: 24),

              // ── Observações ─────────────────────────────────────────────────
              _buildSectionTitle('Observações'),
              const SizedBox(height: 12),

              _buildTextField(
                label: 'Observações adicionais',
                hint: 'Informações relevantes sobre o elemento...',
                controller: _observacoesController,
                maxLines: 4,
              ),
              const SizedBox(height: 32),

              // ── Botão salvar ────────────────────────────────────────────────
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isLoading ? null : _salvar,
                child: Text(
                  _isEditing ? 'Salvar Alterações' : 'Criar Elemento',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Seção de fotos ─────────────────────────────────────────────────────────
  Widget _buildSecaoFotos() {
    final todasFotos = [..._fotosExistentes, ..._novasFotos];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Fotos do Elemento'),
        const SizedBox(height: 12),

        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Botão adicionar foto
              GestureDetector(
                onTap: _adicionarFoto,
                child: Container(
                  width: 90,
                  height: 90,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: AppColors.greyVeryLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo,
                          color: AppColors.primary, size: 28),
                      SizedBox(height: 4),
                      Text(
                        'Adicionar',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Fotos já adicionadas
              ...todasFotos.asMap().entries.map((entry) {
                final index = entry.key;
                final foto = entry.value;
                final isLocal = index >= _fotosExistentes.length;

                return Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.greyVeryLight,
                        image: isLocal
                            ? DecorationImage(
                                image: FileImage(
                                    Uri.file(foto) as dynamic),
                                fit: BoxFit.cover,
                              )
                            : DecorationImage(
                                image: NetworkImage(foto),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => _removerFoto(index),
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor:
                              AppColors.error.withValues(alpha: 0.9),
                          child: const Icon(Icons.close,
                              size: 12, color: AppColors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _adicionarFoto() async {
    // TODO: usar image_picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seleção de foto em breve.')),
    );
  }

  void _removerFoto(int index) {
    setState(() {
      if (index < _fotosExistentes.length) {
        _fotosExistentes.removeAt(index);
      } else {
        _novasFotos.removeAt(index - _fotosExistentes.length);
      }
    });
  }

  // ── Salvar ─────────────────────────────────────────────────────────────────
  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final elemento = ElementoModel(
        id: widget.elemento?.id,
        nome: _nomeController.text.trim(),
        tipo: _tipoSelecionado,
        topologia: _topologiaSelecionada,
        revestimento: _revestimentoSelecionado,
        posicaoX: double.tryParse(_posXController.text),
        posicaoY: double.tryParse(_posYController.text),
        posicaoZ: double.tryParse(_posZController.text),
        dimensoes: _dimensoesController.text.trim(),
        secao: _secaoController.text.trim(),
        microclima: _microclimasSelecionado,
        caa: _caaSelecionada,
        estruturaId: widget.estruturaId,
        fotos: _fotosExistentes,
        observacoes: _observacoesController.text.trim(),
        ativo: true,
      );

      if (_isEditing) {
        await ref
            .read(elementosProvider(widget.estruturaId).notifier)
            .atualizar(elemento);
      } else {
        await ref
            .read(elementosProvider(widget.estruturaId).notifier)
            .criar(elemento);
      }

      widget.onSalvo?.call();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Elemento atualizado com sucesso!'
                : 'Elemento criado com sucesso!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helpers de UI ──────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String titulo) {
    return Text(
      titulo,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool obrigatorio = false,
    TextInputType teclado = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            )),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: teclado,
          maxLines: maxLines,
          validator: obrigatorio
              ? (val) => val == null || val.isEmpty ? 'Obrigatório' : null
              : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: AppColors.hintText, fontSize: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String hint,
    required String? valor,
    required List<String> opcoes,
    required void Function(String?) onChanged,
    bool obrigatorio = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            )),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: valor,
          hint: Text(hint,
              style: const TextStyle(color: AppColors.hintText)),
          validator: obrigatorio
              ? (val) => val == null ? 'Obrigatório' : null
              : null,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          items: opcoes
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}