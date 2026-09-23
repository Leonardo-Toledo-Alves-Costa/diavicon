import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';
import 'package:diavicon/features/planos/acesso_plano.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../ensaios/ensaios_geral/screens/visualizar_pdf_screen.dart';
import '../../projetos/providers/projetos_provider.dart';
import '../models/gasto_model.dart';
import '../providers/gastos_providers.dart';
import '../repositories/gastos_repository.dart';
import '../utils/agregacao_gastos.dart';

/// Abre o formulário de gasto. Com [gasto] = edição (ou só leitura, quando o
/// gasto é de outra pessoa). [projetoFixoId]: projeto já escolhido.
/// Devolve `true` se algo foi gravado ou excluído.
Future<bool?> abrirFormularioGasto(
  BuildContext context, {
  GastoModel? gasto,
  String? projetoFixoId,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => GastoFormDialog(gasto: gasto, projetoFixoId: projetoFixoId),
  );
}

/// Abre o comprovante: PDF no visualizador do app, foto num zoom.
void abrirAnexoGasto(BuildContext context, String url, TipoAnexoGasto? tipo) {
  if (tipo == TipoAnexoGasto.pdf) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => VisualizarPdfScreen(url: url, titulo: 'Comprovante')));
    return;
  }
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          InteractiveViewer(
            child: ImagemStorage.network(
              url,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(32),
                child: Icon(Icons.broken_image, color: Colors.white, size: 48),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    ),
  );
}

class GastoFormDialog extends ConsumerStatefulWidget {
  final GastoModel? gasto;
  final String? projetoFixoId;

  const GastoFormDialog({super.key, this.gasto, this.projetoFixoId});

  @override
  ConsumerState<GastoFormDialog> createState() => _GastoFormDialogState();
}

class _GastoFormDialogState extends ConsumerState<GastoFormDialog> {
  final _valorCtrl = TextEditingController();

  late DateTime _data;
  String? _projetoId;
  String? _categoriaId;
  MeioPagamento _meio = MeioPagamento.credito;
  bool _reembolsavel = true;

  // Comprovante: arquivo novo escolhido agora, ou o que já estava salvo.
  File? _anexoNovo;
  TipoAnexoGasto? _anexoNovoTipo;
  String? _anexoExistente;
  TipoAnexoGasto? _anexoExistenteTipo;

  bool _salvando = false;
  String? _erro;

  bool get _edicao => widget.gasto != null;

  @override
  void initState() {
    super.initState();
    final g = widget.gasto;
    _data = g?.data ?? DateTime.now();
    _projetoId = g?.projetoId ?? widget.projetoFixoId;
    _categoriaId = g?.categoriaId;
    _meio = g?.meioPagamento ?? MeioPagamento.credito;
    _reembolsavel = g?.reembolsavel ?? true;
    _valorCtrl.text = g == null ? '' : g.valor.toStringAsFixed(2).replaceAll('.', ',');
    _anexoExistente = g?.anexoUrl;
    _anexoExistenteTipo = g?.anexoTipo;
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    super.dispose();
  }

  bool _somenteLeitura(String? uid) => widget.gasto != null && !widget.gasto!.podeEditar(uid);

  Future<void> _escolherAnexo() async {
    final temAnexo = _anexoNovo != null || _anexoExistente != null;
    final escolha = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (temAnexo)
              ListTile(
                leading: const Icon(Icons.visibility_outlined, color: AppColors.primary),
                title: const Text('Ver comprovante'),
                onTap: () => Navigator.pop(sheetContext, 'ver'),
              ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(sheetContext, 'galeria'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary),
              title: const Text('Anexar PDF'),
              onTap: () => Navigator.pop(sheetContext, 'pdf'),
            ),
            if (temAnexo)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Remover comprovante'),
                onTap: () => Navigator.pop(sheetContext, 'remover'),
              ),
          ],
        ),
      ),
    );
    if (escolha == null || !mounted) return;

    switch (escolha) {
      case 'ver':
        if (_anexoNovo != null) {
          if (_anexoNovoTipo == TipoAnexoGasto.foto) {
            showDialog(
              context: context,
              builder: (c) => Dialog(child: InteractiveViewer(child: Image.file(_anexoNovo!))),
            );
          }
        } else if (_anexoExistente != null) {
          abrirAnexoGasto(context, _anexoExistente!, _anexoExistenteTipo);
        }
      case 'camera':
      case 'galeria':
        // 2048px no maior lado: comprovante legível, sem subir foto de 12MP.
        final foto = await ImagePicker().pickImage(
          source: escolha == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 2048,
          maxHeight: 2048,
        );
        if (foto != null && mounted) {
          setState(() {
            _anexoNovo = File(foto.path);
            _anexoNovoTipo = TipoAnexoGasto.foto;
          });
        }
      case 'pdf':
        final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
        final path = res?.files.single.path;
        if (path != null && mounted) {
          setState(() {
            _anexoNovo = File(path);
            _anexoNovoTipo = TipoAnexoGasto.pdf;
          });
        }
      case 'remover':
        setState(() {
          _anexoNovo = null;
          _anexoNovoTipo = null;
          _anexoExistente = null;
          _anexoExistenteTipo = null;
        });
    }
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    // Plano sem espaço: nenhuma criação nova (o servidor também recusa).
    if (widget.gasto == null && !await verificarArmazenamento(context, ref)) return;
    if (!mounted) return;
    if (_salvando) return;
    final valor = lerValorDigitado(_valorCtrl.text);
    final String? erro = valor == null || valor <= 0
        ? 'Informe um valor maior que zero.'
        : _projetoId == null
            ? 'Escolha o projeto.'
            : _categoriaId == null
                ? 'Escolha a categoria.'
                : null;
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }

    final empresaId = ref.read(currentUserProvider)?.empresaId;
    if (empresaId == null) {
      setState(() => _erro = 'Seu usuário não está vinculado a uma empresa.');
      return;
    }

    setState(() {
      _salvando = true;
      _erro = null;
    });

    final repo = ref.read(gastosRepositoryProvider);
    final navigator = Navigator.of(context);
    String? anexoEnviado;
    try {
      // Comprovante primeiro: se o upload falhar, nada é gravado.
      if (_anexoNovo != null) {
        anexoEnviado = await repo.enviarAnexo(_anexoNovo!, empresaId: empresaId);
      }
      final anexoFinal = anexoEnviado ?? _anexoExistente;
      final tipoFinal = anexoEnviado != null ? _anexoNovoTipo : (_anexoExistente != null ? _anexoExistenteTipo : null);

      await repo.salvar(
        gastoId: widget.gasto?.id,
        empresaId: empresaId,
        dados: GastoModel.dadosParaGravar(
          projetoId: _projetoId!,
          categoriaId: _categoriaId!,
          reembolsavel: _reembolsavel,
          valor: valor!,
          data: _data,
          meioPagamento: _meio,
          anexoUrl: anexoFinal,
          anexoTipo: tipoFinal,
        ),
      );

      // O comprovante antigo saiu (trocado ou removido): apaga do Storage.
      final antigo = widget.gasto?.anexoUrl;
      if (antigo != null && antigo != anexoFinal) await repo.removerAnexo(antigo);

      invalidarGastos(ref);
      navigator.pop(true);
    } catch (e) {
      if (anexoEnviado != null) await repo.removerAnexo(anexoEnviado);
      if (mounted) {
        setState(() {
          _salvando = false;
          _erro = 'Não foi possível salvar: ${mensagemErroGastos(e)}';
        });
      }
    }
  }

  Future<void> _excluir() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir gasto'),
        content: const Text('Este gasto e o comprovante serão excluídos definitivamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Excluir', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _salvando = true);
    final navigator = Navigator.of(context);
    try {
      await ref.read(gastosRepositoryProvider).excluir(widget.gasto!);
      invalidarGastos(ref);
      navigator.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _erro = 'Não foi possível excluir: ${mensagemErroGastos(e)}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserProvider)?.id;
    final leitura = _somenteLeitura(uid);
    final projetosAsync = ref.watch(projectsProvider);
    final categoriasAsync = ref.watch(categoriasGastoProvider);

    final titulo = !_edicao ? 'Novo gasto' : (leitura ? 'Gasto' : 'Editar gasto');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(titulo, style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D)))),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _salvando ? null : () => Navigator.pop(context, false),
                ),
              ],
            ),
            if (leitura) _avisoSomenteLeitura(),
            const SizedBox(height: 8),
            // O botão do comprovante fica fora do AbsorbPointer: no modo
            // leitura ele continua abrindo o comprovante.
            Row(
              children: [
                _botaoAnexo(leitura),
                const SizedBox(width: 10),
                Expanded(
                  child: AbsorbPointer(
                    absorbing: leitura || _salvando,
                    child: InkWell(
                      onTap: _escolherData,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: _deco('Data'),
                        child: Text(formatarData(_data), style: GoogleFonts.lato(fontSize: 14)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AbsorbPointer(
              absorbing: leitura || _salvando,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  projetosAsync.when(
                    loading: () => const LinearProgressIndicator(color: AppColors.primary),
                    error: (e, _) => Text('Erro ao carregar projetos: $e'),
                    data: (projetos) {
                      final itens = [
                        for (final p in projetos) DropdownMenuItem(value: p.id, child: Text(p.nome, overflow: TextOverflow.ellipsis)),
                        // Gasto de um projeto que já não aparece na lista
                        // (ex.: saiu da equipe): mantém a opção para não quebrar o dropdown.
                        if (_projetoId != null && !projetos.any((p) => p.id == _projetoId))
                          DropdownMenuItem(value: _projetoId, child: Text(widget.gasto?.projetoNome ?? 'Projeto atual')),
                      ];
                      return DropdownButtonFormField<String>(
                        initialValue: _projetoId,
                        isExpanded: true,
                        decoration: _deco('Projeto'),
                        items: itens,
                        onChanged: widget.projetoFixoId != null && !_edicao ? null : (v) => setState(() => _projetoId = v),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  categoriasAsync.when(
                    loading: () => const LinearProgressIndicator(color: AppColors.primary),
                    error: (e, _) => Text(mensagemErroGastos(e), style: GoogleFonts.lato(fontSize: 12.5, color: AppColors.error)),
                    data: (todas) {
                      final categorias = [...todas];
                      if (_categoriaId != null && !categorias.any((c) => c.id == _categoriaId)) {
                        categorias.add(CategoriaGastoModel(id: _categoriaId!, empresaId: '', nome: widget.gasto?.categoriaNome ?? 'Categoria'));
                      }
                      // Categoria só é cadastrada pelo admin, em Padrões da
                      // empresa — aqui o usuário apenas escolhe.
                      if (categorias.isEmpty) {
                        return InputDecorator(
                          decoration: _deco('Categoria'),
                          child: Text(
                            'Nenhuma categoria cadastrada. Peça ao admin da empresa para cadastrar em Padrões da empresa › Categorias de gasto.',
                            style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: _categoriaId,
                        isExpanded: true,
                        decoration: _deco('Categoria'),
                        items: [for (final c in categorias) DropdownMenuItem(value: c.id, child: Text(c.nome))],
                        onChanged: (v) => setState(() => _categoriaId = v),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<MeioPagamento>(
                    initialValue: _meio,
                    isExpanded: true,
                    decoration: _deco('Meio de pagamento'),
                    items: [for (final m in MeioPagamento.values) DropdownMenuItem(value: m, child: Text(m.rotulo))],
                    onChanged: (v) => setState(() => _meio = v ?? _meio),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: Text('Reembolsável?', style: GoogleFonts.lato(fontSize: 14, color: const Color(0xFF3E3E3D)))),
                      Switch(
                        value: _reembolsavel,
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppColors.primary,
                        onChanged: (v) => setState(() => _reembolsavel = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _valorCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w700),
                    decoration: _deco('Valor (R\$)'),
                  ),
                ],
              ),
            ),
            if (_erro != null) ...[
              const SizedBox(height: 10),
              Text(_erro!, style: GoogleFonts.lato(fontSize: 12.5, color: AppColors.error)),
            ],
            const SizedBox(height: 16),
            if (!leitura)
              Row(
                children: [
                  if (_edicao)
                    IconButton(
                      tooltip: 'Excluir gasto',
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: _salvando ? null : _excluir,
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _salvando ? null : _salvar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _salvando
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _avisoSomenteLeitura() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Gasto de ${widget.gasto!.usuarioNome}. Somente o autor pode editá-lo.',
              style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botaoAnexo(bool leitura) {
    final temNovo = _anexoNovo != null;
    final tipo = temNovo ? _anexoNovoTipo : _anexoExistenteTipo;
    final temAnexo = temNovo || _anexoExistente != null;

    Widget conteudo;
    if (temNovo && tipo == TipoAnexoGasto.foto) {
      conteudo = ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image(image: ResizeImage(FileImage(_anexoNovo!), width: 150), fit: BoxFit.cover, width: 50, height: 50),
      );
    } else if (temAnexo) {
      conteudo = Icon(tipo == TipoAnexoGasto.pdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined, color: AppColors.primary);
    } else {
      conteudo = Icon(Icons.attach_file, color: Colors.grey.shade500);
    }

    return InkWell(
      onTap: _salvando
          ? null
          : leitura
              ? (_anexoExistente != null ? () => abrirAnexoGasto(context, _anexoExistente!, _anexoExistenteTipo) : null)
              : _escolherAnexo,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: temAnexo ? AppColors.primary : Colors.grey.shade400, width: temAnexo ? 1.5 : 1),
        ),
        child: conteudo,
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        labelText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
      );
}
