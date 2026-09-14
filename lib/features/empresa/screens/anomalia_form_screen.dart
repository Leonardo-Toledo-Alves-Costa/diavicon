import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../providers/anomalias_provider.dart';
import '../providers/sistema_provider.dart';

const List<String> _escalaGut = ['1', '2', '3', '4', '5'];

const List<String> _tiposRisco = ['Humano', 'Ambiental', 'Material'];

const List<String> _classesRisco = ['Alto', 'Médio', 'Baixo'];

class AnomaliaFormScreen extends ConsumerStatefulWidget {
  final String empresaId;
  final AnomaliaModel? anomalia;

  const AnomaliaFormScreen({
    super.key,
    required this.empresaId,
    this.anomalia,
  });

  @override
  ConsumerState<AnomaliaFormScreen> createState() => _AnomaliaFormScreenState();
}

class _AnomaliaFormScreenState extends ConsumerState<AnomaliaFormScreen> {
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _gravidadeDescCtrl;
  late final TextEditingController _urgenciaDescCtrl;
  late final TextEditingController _tendenciaDescCtrl;
  late final TextEditingController _riscoDescCtrl;
  late final TextEditingController _majoracaoCtrl;

  String? _categoria;
  String? _sistemaConstrutivo;
  String? _gravidadeValor;
  String? _urgenciaValor;
  String? _tendenciaValor;
  String _tipoRisco = 'Humano';
  String _classeRisco = 'Alto';

  bool _isSaving = false;

  bool get _isEditing => widget.anomalia != null;

  @override
  void initState() {
    super.initState();
    final a = widget.anomalia;
    _nomeCtrl = TextEditingController(text: a?.nome ?? '');
    _descCtrl = TextEditingController(text: a?.descricao ?? '');
    _gravidadeDescCtrl = TextEditingController(text: a?.gravidadeDescricao ?? '');
    _urgenciaDescCtrl = TextEditingController(text: a?.urgenciaDescricao ?? '');
    _tendenciaDescCtrl = TextEditingController(text: a?.tendenciaDescricao ?? '');
    _riscoDescCtrl = TextEditingController(text: a?.riscoDescricao ?? '');
    _majoracaoCtrl = TextEditingController(text: a?.riscoMajor ?? '00');

    _categoria = a?.categoria;
    _sistemaConstrutivo = a?.sistemaConstrutivo;
    _gravidadeValor = a?.gravidadeValor;
    _urgenciaValor = a?.urgenciaValor;
    _tendenciaValor = a?.tendenciaValor;
    _tipoRisco = a?.riscoTipo ?? 'Humano';
    _classeRisco = a?.riscoValor ?? 'Alto';
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _descCtrl.dispose();
    _gravidadeDescCtrl.dispose();
    _urgenciaDescCtrl.dispose();
    _tendenciaDescCtrl.dispose();
    _riscoDescCtrl.dispose();
    _majoracaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_nomeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome da anomalia.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final dados = AnomaliaModel(
        id: widget.anomalia?.id ?? '',
        nome: _nomeCtrl.text.trim(),
        descricao: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        categoria: _categoria,
        sistemaConstrutivo: _sistemaConstrutivo,
        gravidadeValor: _gravidadeValor,
        gravidadeDescricao: _gravidadeDescCtrl.text.trim().isEmpty
            ? null
            : _gravidadeDescCtrl.text.trim(),
        urgenciaValor: _urgenciaValor,
        urgenciaDescricao: _urgenciaDescCtrl.text.trim().isEmpty
            ? null
            : _urgenciaDescCtrl.text.trim(),
        tendenciaValor: _tendenciaValor,
        tendenciaDescricao: _tendenciaDescCtrl.text.trim().isEmpty
            ? null
            : _tendenciaDescCtrl.text.trim(),
        riscoTipo: _tipoRisco,
        riscoValor: _classeRisco,
        riscoDescricao: _riscoDescCtrl.text.trim().isEmpty
            ? null
            : _riscoDescCtrl.text.trim(),
        riscoMajor: _majoracaoCtrl.text.trim().isEmpty
            ? '00'
            : _majoracaoCtrl.text.trim(),
        empresaId: widget.empresaId,
      ).toMap();

      if (_isEditing) {
        await Supabase.instance.client
            .from('anomalias')
            .update(dados)
            .eq('id', widget.anomalia!.id);
      } else {
        await Supabase.instance.client.from('anomalias').insert(dados);
      }

      ref.invalidate(anomaliasListProvider(widget.empresaId));
      navigator.pop(true);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Salvo com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } on PostgrestException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erro: ${e.message}'), backgroundColor: Colors.red),
      );
      setState(() => _isSaving = false);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erro inesperado: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sistemasAsync = ref.watch(sistemasDropdownProvider(widget.empresaId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'Empresa',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            const Text('Empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            const Text(
              'Painel',
              style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Text(
              _isEditing ? 'Editar anomalia' : 'Nova anomalia',
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Identificação'),
            _LabeledField(label: 'Nome', child: _textField(_nomeCtrl)),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Descrição',
              child: _textField(_descCtrl, maxLines: 3),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Categoria',
              child: _dropdown(
                value: _categoria,
                items: categoriaAnomaliaOpcoes,
                onChanged: (v) => setState(() => _categoria = v),
              ),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Sistema construtivo',
              child: sistemasAsync.when(
                loading: () => const LinearProgressIndicator(color: AppColors.primary),
                error: (e, _) => Text(
                  'Erro ao carregar sistemas: $e',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
                data: (sistemas) {
                  final nomes = sistemas.map((s) => s.nome).toSet().toList();
                  return _dropdown(
                    value: nomes.contains(_sistemaConstrutivo) ? _sistemaConstrutivo : null,
                    items: nomes,
                    onChanged: (v) => setState(() => _sistemaConstrutivo = v),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),

            _SectionTitle('Classificação GUT'),
            _LabeledField(
              label: 'Gravidade (1 a 5)',
              child: _dropdown(
                value: _gravidadeValor,
                items: _escalaGut,
                onChanged: (v) => setState(() => _gravidadeValor = v),
              ),
            ),
            const SizedBox(height: 10),
            _LabeledField(
              label: 'Descrição da gravidade',
              child: _textField(_gravidadeDescCtrl, maxLines: 2),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Urgência (1 a 5)',
              child: _dropdown(
                value: _urgenciaValor,
                items: _escalaGut,
                onChanged: (v) => setState(() => _urgenciaValor = v),
              ),
            ),
            const SizedBox(height: 10),
            _LabeledField(
              label: 'Descrição da urgência',
              child: _textField(_urgenciaDescCtrl, maxLines: 2),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Tendência (1 a 5)',
              child: _dropdown(
                value: _tendenciaValor,
                items: _escalaGut,
                onChanged: (v) => setState(() => _tendenciaValor = v),
              ),
            ),
            const SizedBox(height: 10),
            _LabeledField(
              label: 'Descrição da tendência',
              child: _textField(_tendenciaDescCtrl, maxLines: 2),
            ),
            const SizedBox(height: 28),

            _SectionTitle('Risco'),
            _LabeledField(
              label: 'Tipo de risco',
              child: _dropdown(
                value: _tipoRisco,
                items: _tiposRisco,
                onChanged: (v) => setState(() => _tipoRisco = v ?? 'Humano'),
              ),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Classe do risco',
              child: _dropdown(
                value: _classeRisco,
                items: _classesRisco,
                onChanged: (v) => setState(() => _classeRisco = v ?? 'Alto'),
              ),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Descrição do risco',
              child: _textField(_riscoDescCtrl, maxLines: 2),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Majoração (%)',
              child: _textField(
                _majoracaoCtrl,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.black87)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E2E2E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isSaving ? null : _salvar,
                    child: _isSaving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _dropdown({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: const InputDecoration(border: InputBorder.none),
        hint: const Text('Selecione', style: TextStyle(fontSize: 14, color: Colors.grey)),
        items: items
            .map((item) => DropdownMenuItem<String>(value: item, child: Text(item, style: const TextStyle(fontSize: 14))))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.6),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}
