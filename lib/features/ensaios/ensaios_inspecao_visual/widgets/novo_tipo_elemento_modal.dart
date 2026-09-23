import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/features/empresa/providers/campos_personalizaveis_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NovoTipoElementoModal extends ConsumerStatefulWidget {
  final String? empresaId;
  // Sistema já selecionado na tela de origem — pré-seleciona o dropdown
  // pra não obrigar o usuário a escolher de novo.
  final String? sistemaIdInicial;

  const NovoTipoElementoModal({super.key, this.empresaId, this.sistemaIdInicial});

  @override
  ConsumerState<NovoTipoElementoModal> createState() => _NovoTipoElementoModalState();
}

class _NovoTipoElementoModalState extends ConsumerState<NovoTipoElementoModal> {
  final _nomeController = TextEditingController();
  String? _sistemaSelecionadoId;
  List<Map<String, dynamic>> _sistemas = [];
  bool _carregandoSistemas = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sistemaSelecionadoId = widget.sistemaIdInicial;
    _carregarSistemas();
  }

  Future<void> _carregarSistemas() async {
    try {
      final supabase = Supabase.instance.client;
      var empresaId = widget.empresaId;

      if (empresaId == null) {
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          final userRes = await supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
          empresaId = userRes?['empresa_id']?.toString();
        }
      }

      final res = empresaId != null
          ? await supabase.from('sistemas_habitacionais').select('id, nome').inFilter('empresa_id', [empresaId, DIAVICON_EMPRESA_ID]).order('nome')
          : await supabase.from('sistemas_habitacionais').select('id, nome').eq('empresa_id', DIAVICON_EMPRESA_ID).order('nome');

      if (!mounted) return;
      setState(() {
        _sistemas = List<Map<String, dynamic>>.from(res);
        // Se o sistema pré-selecionado não existir na lista carregada (ex:
        // empresaId ainda não resolvido no primeiro build), evita manter um
        // value que o DropdownButton não reconhece.
        if (_sistemaSelecionadoId != null && !_sistemas.any((s) => s['id']?.toString() == _sistemaSelecionadoId)) {
          _sistemaSelecionadoId = null;
        }
      });
    } catch (_) {
      // Falha ao carregar não impede o modal de abrir; o dropdown só fica vazio.
    } finally {
      if (mounted) setState(() => _carregandoSistemas = false);
    }
  }

  Future<void> _salvar() async {
    // Trava síncrona de reentrância — o botão só fica desabilitado
    // (`onPressed: _isLoading || _sistemaSelecionadoId == null ? null :
    // _salvar`) a partir do PRÓXIMO rebuild/frame. Num toque duplo rápido, a
    // segunda chamada ainda acha o botão habilitado e entra aqui de novo
    // antes do rebuild acontecer. Este método sempre faz um INSERT em
    // `tipos_elemento` (não há ramo de UPDATE), então as duas chamadas
    // criariam dois tipos de elemento duplicados com o mesmo nome. Setar
    // `_isLoading` aqui é síncrono (setState muda o campo na hora, só o
    // rebuild é adiado), então a segunda chamada já vê `_isLoading == true`
    // e sai antes de inserir de novo.
    if (_isLoading) return;

    final nome = _nomeController.text.trim();
    if (nome.isEmpty || _sistemaSelecionadoId == null) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      // Busca a empresa do usuário ativo
      final userRes = await supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
      final minhaEmpresaId = userRes?['empresa_id'];

      // Preparando os dados garantindo as colunas do SQL
      Map<String, dynamic> insertData = {
        'nome': nome,
        'sistemas_id': _sistemaSelecionadoId,
      };

      // Confio que você criou a coluna 'empresa_id' no Supabase!
      if (minhaEmpresaId != null) {
        insertData['empresa_id'] = minhaEmpresaId;
      }

      await supabase.from('tipos_elemento').insert(insertData);

      if (mounted) Navigator.of(context).pop(nome);
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro do banco: ${e.message}'), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro inesperado: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Novo Tipo de Elemento',
              style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome (ex: Parede)',
                border: OutlineInputBorder()
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Sistema Habitacional:',
              style: GoogleFonts.lato(fontSize: 14, color: Colors.grey[700])
            ),
            const SizedBox(height: 8),

            _carregandoSistemas
                ? const LinearProgressIndicator(color: AppColors.primary)
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4)
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sistemaSelecionadoId,
                        isExpanded: true,
                        hint: Text('Selecione', style: TextStyle(color: Colors.grey.shade500)),
                        items: _sistemas.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['nome'].toString(), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() => _sistemaSelecionadoId = val),
                      ),
                    ),
                  ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading || _sistemaSelecionadoId == null ? null : _salvar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14)
              ),
              child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                : Text('Salvar', style: GoogleFonts.lato(color: Colors.white, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }
}
