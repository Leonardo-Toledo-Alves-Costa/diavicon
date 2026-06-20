import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Resultado do popup "Novo Arquivo".
///
/// Mockado enquanto o upload real de plantas não está disponível (outro dev
/// cuida dessa parte). Quando o backend for liberado, [arquivoNome]/[arquivoTamanho]
/// virão do arquivo realmente enviado.
class NovoArquivoResult {
  const NovoArquivoResult({
    required this.nome,
    required this.localVinculado,
  });

  final String nome;
  final String? localVinculado;
}

/// Abre o popup "Novo Arquivo" e devolve o [NovoArquivoResult] ao salvar, ou
/// `null` se o usuário fechar sem salvar.
Future<NovoArquivoResult?> showNovoArquivoPopup(BuildContext context) {
  return showDialog<NovoArquivoResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => const NovoArquivoPopup(),
  );
}

/// Locais mockados para o seletor "Local Vinculado" (virão da estrutura quando
/// o backend for liberado).
const List<String> _locaisMock = <String>[
  '2º Subsolo',
  '3º Subsolo',
  '1º Andar',
  '2º Andar',
];

/// Popup de cadastro de um novo arquivo/planta da estrutura.
class NovoArquivoPopup extends StatefulWidget {
  const NovoArquivoPopup({super.key});

  @override
  State<NovoArquivoPopup> createState() => _NovoArquivoPopupState();
}

class _NovoArquivoPopupState extends State<NovoArquivoPopup> {
  final TextEditingController _nomeController = TextEditingController();
  String? _localVinculado;

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  bool get _podeSalvar =>
      _nomeController.text.trim().isNotEmpty && _localVinculado != null;

  void _salvar() {
    if (!_podeSalvar) return;
    Navigator.of(context).pop(
      NovoArquivoResult(
        nome: _nomeController.text.trim(),
        localVinculado: _localVinculado,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                // ── Cabeçalho: botão fechar ──────────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: _CloseButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                // ── Título ───────────────────────────────────────────────────
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
                // ── Nome do Arquivo ──────────────────────────────────────────
                const _CampoLabel(texto: 'Nome do Arquivo'),
                const SizedBox(height: 6),
                _NomeField(
                  controller: _nomeController,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 18),
                // ── Local Vinculado ──────────────────────────────────────────
                const _CampoLabel(texto: 'Local Vinculado'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _LocalDropdown(
                        valor: _localVinculado,
                        onChanged: (valor) =>
                            setState(() => _localVinculado = valor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _AddLocalButton(onPressed: () {}),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Arquivo anexado (mock) ───────────────────────────────────
                const _ArquivoAnexadoCard(
                  nome: 'proj_est_001.pdf',
                  tamanho: '3,46MB',
                ),
                const SizedBox(height: 20),
                // ── Botão salvar ─────────────────────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: _SalvarButton(
                    onPressed: _podeSalvar ? _salvar : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rótulo de campo com asterisco vermelho de obrigatório.
class _CampoLabel extends StatelessWidget {
  const _CampoLabel({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: texto,
        style: GoogleFonts.lato(
          color: const Color(0xFF626365),
          fontSize: 18,
          fontWeight: FontWeight.w300,
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Color(0xFFF71D21)),
          ),
        ],
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
      style: GoogleFonts.lato(
        color: const Color(0xFF626365),
        fontSize: 18,
        fontWeight: FontWeight.w300,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Nome',
        hintStyle: GoogleFonts.lato(
          color: const Color(0xFF626365).withValues(alpha: 0.87),
          fontSize: 18,
          fontWeight: FontWeight.w300,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF626365)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

class _LocalDropdown extends StatelessWidget {
  const _LocalDropdown({required this.valor, required this.onChanged});

  final String? valor;
  final ValueChanged<String?> onChanged;

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
          hint: Text(
            'Selecione',
            style: GoogleFonts.lato(
              color: const Color(0xFF313144),
              fontSize: 18,
              fontWeight: FontWeight.w300,
            ),
          ),
          style: GoogleFonts.lato(
            color: const Color(0xFF313144),
            fontSize: 18,
            fontWeight: FontWeight.w300,
          ),
          items: [
            for (final local in _locaisMock)
              DropdownMenuItem<String>(value: local, child: Text(local)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Botão "+" laranja para cadastrar um novo local (mock — cadastro de locais
/// fica a cargo de outra parte do app).
class _AddLocalButton extends StatelessWidget {
  const _AddLocalButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A57E8).withValues(alpha: 0.30),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
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

/// Card do arquivo anexado (mock). O upload real é responsabilidade de outra
/// parte do app.
class _ArquivoAnexadoCard extends StatelessWidget {
  const _ArquivoAnexadoCard({required this.nome, required this.tamanho});

  final String nome;
  final String tamanho;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 67,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 4),
          ),
        ],
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
                Text(
                  nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lato(
                    color: const Color(0xFF3E3E3D),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tamanho,
                  style: GoogleFonts.lato(
                    color: const Color(0xFF3E3E3D),
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
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
        boxShadow: onPressed == null
            ? const []
            : [
                BoxShadow(
                  color: const Color(0xFF3A57E8).withValues(alpha: 0.30),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          'Salvar',
          style: GoogleFonts.lato(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
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
        icon: Icon(
          Icons.close,
          color: const Color(0xFF626365).withValues(alpha: 0.40),
          size: 24,
        ),
      ),
    );
  }
}
