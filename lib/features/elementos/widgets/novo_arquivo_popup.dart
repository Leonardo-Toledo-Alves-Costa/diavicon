import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/features/estrutura/models/local_model.dart';
import 'package:diavicon/features/estrutura/providers/local_provider.dart';
import 'package:diavicon/features/elementos/widgets/novo_local_widget.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

class NovoArquivoResult {
  const NovoArquivoResult({
    required this.nome,
    required this.localId, 
    required this.arquivo,
  });

  final String nome;
  final String localId;
  final PlatformFile arquivo;
}

/// Abre o popup "Novo Arquivo" passando obrigatoriamente o [estruturaId]
Future<NovoArquivoResult?> showNovoArquivoPopup(BuildContext context, String estruturaId) {
  return showDialog<NovoArquivoResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => NovoArquivoPopup(estruturaId: estruturaId),
  );
}

class NovoArquivoPopup extends ConsumerStatefulWidget { 
  const NovoArquivoPopup({super.key, required this.estruturaId});

  final String estruturaId;

  @override
  ConsumerState<NovoArquivoPopup> createState() => _NovoArquivoPopupState();
}

class _NovoArquivoPopupState extends ConsumerState<NovoArquivoPopup> {
  final TextEditingController _nomeController = TextEditingController();
  String? _localSelecionadoId;
  PlatformFile? _arquivoSelecionado;

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  bool get _podeSalvar =>
      _nomeController.text.trim().isNotEmpty && 
      _localSelecionadoId != null && 
      _arquivoSelecionado != null;

  void _salvar() {
    if (!_podeSalvar) return;
    Navigator.of(context).pop(
      NovoArquivoResult(
        nome: _nomeController.text.trim(),
        localId: _localSelecionadoId!,
        arquivo: _arquivoSelecionado!,
      ),
    );
  }

  Future<void> _selecionarArquivo() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );

    if (result != null) {
      setState(() {
        _arquivoSelecionado = result.files.single;
        if (_nomeController.text.isEmpty) {
          _nomeController.text = _arquivoSelecionado!.name.split('.').first;
        }
      });
    }
  }

  // Abre o modal de criar local e atualiza a lista do dropdown na hora
  // Abre o modal de criar local, o próprio modal salva no banco, e devolve o ID!
  Future<void> _criarNovoLocal() async {
    final novoLocalId = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      // 🔥 AQUI: Agora passamos o estruturaId pro Modal fazer o trabalho duro!
      builder: (_) => NovoLocalModal(estruturaId: widget.estruturaId), 
    );

    if (novoLocalId != null && mounted) {
      // Como o Modal já salvou no Supabase, nós só atualizamos a lista da tela
      ref.invalidate(locaisPorEstruturaProvider(widget.estruturaId));
      
      setState(() {
        _localSelecionadoId = novoLocalId; // Já seleciona o dropdown magicamente
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escutando a lista de locais reais vindas do Supabase
    final locaisAsync = ref.watch(locaisPorEstruturaProvider(widget.estruturaId));

    final mediaQuery = MediaQuery.of(context);
    final largura = (mediaQuery.size.width - 32).clamp(280.0, 350.0).toDouble();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: largura,
        child: Material(
          color: Colors.white,
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(19, 14, 19, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: _CloseButton(onPressed: () => Navigator.of(context).maybePop()),
                ),
                Text(
                  'Novo Arquivo',
                  style: GoogleFonts.lato(
                    color: const Color(0xFF3E3E3D),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                const _CampoLabel(texto: 'Nome do Arquivo'),
                const SizedBox(height: 6),
                _NomeField(
                  controller: _nomeController,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 18),
                const _CampoLabel(texto: 'Local Vinculado'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: locaisAsync.when(
                        loading: () => const Center(child: LinearProgressIndicator(color: AppColors.primary)),
                        error: (err, _) => Text('Erro ao carregar locais', style: TextStyle(color: AppColors.error, fontSize: 12)),
                        data: (locais) {
                          // 🔥 TRATAMENTO DE LISTA VAZIA
                          if (locais.isEmpty) {
                            return _EmptyLocalButton(onPressed: _criarNovoLocal);
                          }
                          
                          // Garante que o valor selecionado seja válido
                          if (_localSelecionadoId != null && !locais.any((l) => l.id == _localSelecionadoId)) {
                             _localSelecionadoId = null;
                          }

                          return _LocalDropdown(
                            valor: _localSelecionadoId,
                            locais: locais,
                            onChanged: (valor) => setState(() => _localSelecionadoId = valor),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    _AddLocalButton(onPressed: _criarNovoLocal),
                  ],
                ),
                const SizedBox(height: 16),
                if (_arquivoSelecionado != null)
                  _ArquivoAnexadoCard(
                    nome: _arquivoSelecionado!.name,
                    tamanho: '${(_arquivoSelecionado!.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                    onRemove: () => setState(() => _arquivoSelecionado = null),
                  )
                else
                  GestureDetector(
                    onTap: _selecionarArquivo,
                    child: Container(
                      height: 67,
                      decoration: BoxDecoration(
                        color: AppColors.greyVeryLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('Selecionar PDF ou Imagem', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: _SalvarButton(onPressed: _podeSalvar ? _salvar : null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CampoLabel extends StatelessWidget {
  const _CampoLabel({required this.texto});
  final String texto;
  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: texto,
        style: GoogleFonts.lato(color: const Color(0xFF626365), fontSize: 18, fontWeight: FontWeight.w300),
        children: const [TextSpan(text: ' *', style: TextStyle(color: Color(0xFFF71D21)))],
      ),
    );
  }
}

class _NomeField extends StatelessWidget {
  const _NomeField({required this.controller, this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.lato(color: const Color(0xFF626365), fontSize: 18, fontWeight: FontWeight.w300),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Nome',
        hintStyle: GoogleFonts.lato(color: const Color(0xFF626365).withOpacity(0.87), fontSize: 18, fontWeight: FontWeight.w300),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF626365))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.4)),
      ),
    );
  }
}

class _LocalDropdown extends StatelessWidget {
  const _LocalDropdown({required this.valor, required this.onChanged, required this.locais});
  final String? valor;
  final ValueChanged<String?> onChanged;
  final List<LocalModel> locais; 

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF626365)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valor,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF313144)),
          hint: Text('Selecione', style: GoogleFonts.lato(color: const Color(0xFF313144), fontSize: 18, fontWeight: FontWeight.w300)),
          style: GoogleFonts.lato(color: const Color(0xFF313144), fontSize: 18, fontWeight: FontWeight.w300),
          items: [
            for (final local in locais)
              DropdownMenuItem<String>(
                value: local.id, 
                child: Text(local.nome),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _AddLocalButton extends StatelessWidget {
  const _AddLocalButton({this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: const Color(0xFF3A57E8).withOpacity(0.30), blurRadius: 2, offset: const Offset(0, 2))],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          minimumSize: const Size(40, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
    );
  }
}

class _ArquivoAnexadoCard extends StatelessWidget {
  const _ArquivoAnexadoCard({required this.nome, required this.tamanho, required this.onRemove});
  final String nome;
  final String tamanho;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 67,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file, color: Color(0xFF3E3E3D), size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(color: const Color(0xFF3E3E3D), fontSize: 16, fontWeight: FontWeight.w400)),
                const SizedBox(height: 4),
                Text(tamanho, style: GoogleFonts.lato(color: const Color(0xFF3E3E3D), fontSize: 14, fontWeight: FontWeight.w300)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: onRemove),
        ],
      ),
    );
  }
}

class _SalvarButton extends StatelessWidget {
  const _SalvarButton({this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: onPressed == null ? const [] : [BoxShadow(color: const Color(0xFF3A57E8).withOpacity(0.30), blurRadius: 2, offset: const Offset(0, 2))],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Text('Salvar', style: GoogleFonts.lato(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400, height: 1)),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        splashRadius: 18,
        icon: Icon(Icons.close, color: const Color(0xFF626365).withOpacity(0.40), size: 24),
      ),
    );
  }
}

// arquivo: novo_arquivo_popup.dart
class _EmptyLocalButton extends StatelessWidget {
  const _EmptyLocalButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.greyVeryLight,
          border: Border.all(color: AppColors.error.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          'Nenhum local cadastrado. Toque no +',
          style: GoogleFonts.lato(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}