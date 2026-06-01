import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NovoRelatorioOption {
  final String id;
  final String label;

  const NovoRelatorioOption({required this.id, required this.label});

  @override
  String toString() => label;
}

class NovoRelatorioPopup extends StatefulWidget {
  final TextEditingController? nomeController;
  final List<NovoRelatorioOption> ensaios;
  final List<NovoRelatorioOption> empresas;
  final NovoRelatorioOption? ensaioSelecionado;
  final NovoRelatorioOption? empresaSelecionada;
  final ValueChanged<String>? onNomeChanged;
  final ValueChanged<NovoRelatorioOption?>? onEnsaioChanged;
  final ValueChanged<NovoRelatorioOption?>? onEmpresaChanged;
  final VoidCallback? onClose;
  final VoidCallback? onGenerate;
  final int tokensUsed;
  final int tokenLimit;
  final bool isGenerating;

  const NovoRelatorioPopup({
    super.key,
    this.nomeController,
    this.ensaios = const [],
    this.empresas = const [],
    this.ensaioSelecionado,
    this.empresaSelecionada,
    this.onNomeChanged,
    this.onEnsaioChanged,
    this.onEmpresaChanged,
    this.onClose,
    this.onGenerate,
    this.tokensUsed = 6,
    this.tokenLimit = 10,
    this.isGenerating = false,
  });

  @override
  State<NovoRelatorioPopup> createState() => _NovoRelatorioPopupState();
}

class _NovoRelatorioPopupState extends State<NovoRelatorioPopup> {
  late final TextEditingController _internalNomeController;
  NovoRelatorioOption? _internalEnsaioSelecionado;
  NovoRelatorioOption? _internalEmpresaSelecionada;

  TextEditingController get _nomeController =>
      widget.nomeController ?? _internalNomeController;

  NovoRelatorioOption? get _ensaioSelecionado =>
      widget.ensaioSelecionado ?? _internalEnsaioSelecionado;

  NovoRelatorioOption? get _empresaSelecionada =>
      widget.empresaSelecionada ?? _internalEmpresaSelecionada;

  @override
  void initState() {
    super.initState();
    _internalNomeController = TextEditingController();
    _internalEnsaioSelecionado = widget.ensaioSelecionado;
    _internalEmpresaSelecionada = widget.empresaSelecionada;
  }

  @override
  void didUpdateWidget(covariant NovoRelatorioPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ensaioSelecionado != widget.ensaioSelecionado) {
      _internalEnsaioSelecionado = widget.ensaioSelecionado;
    }
    if (oldWidget.empresaSelecionada != widget.empresaSelecionada) {
      _internalEmpresaSelecionada = widget.empresaSelecionada;
    }
  }

  @override
  void dispose() {
    _internalNomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableWidth = mediaQuery.size.width - 32;
    final popupWidth = availableWidth.clamp(280.0, 350.0).toDouble();
    final horizontalScale = popupWidth / 350;
    final popupHeight = (400 * horizontalScale).clamp(360.0, 400.0).toDouble();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: popupWidth,
        height: popupHeight,
        child: Material(
          color: Colors.white,
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                left: 21 * horizontalScale,
                top: 40 * horizontalScale,
                right: 14,
                child: Text(
                  'Novo Relatório',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lato(
                    color: const Color(0xFF3E3E3D),
                    fontSize: 24 * horizontalScale,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
              Positioned(
                top: 14 * horizontalScale,
                right: 12 * horizontalScale,
                child: _CloseButton(onPressed: widget.onClose),
              ),
              Positioned(
                left: 19 * horizontalScale,
                top: 91 * horizontalScale,
                width: 286 * horizontalScale,
                child: _NovoRelatorioTextField(
                  label: 'Nome do Relatório',
                  hint: 'Nome',
                  controller: _nomeController,
                  onChanged: widget.onNomeChanged,
                  scale: horizontalScale,
                ),
              ),
              Positioned(
                left: 19 * horizontalScale,
                top: 165 * horizontalScale,
                width: 286 * horizontalScale,
                child: _NovoRelatorioDropdown(
                  label: 'Ensaios Realizados',
                  value: _matchingValue(_ensaioSelecionado, widget.ensaios),
                  items: widget.ensaios,
                  onChanged: (value) {
                    setState(() => _internalEnsaioSelecionado = value);
                    widget.onEnsaioChanged?.call(value);
                  },
                  trailingIcon: const _SlidersIcon(),
                  dropdownWidthFactor: 250 / 286,
                  scale: horizontalScale,
                ),
              ),
              Positioned(
                left: 19 * horizontalScale,
                top: 243 * horizontalScale,
                width: 284 * horizontalScale,
                child: _NovoRelatorioDropdown(
                  label: 'Dados das Empresas',
                  value: _matchingValue(_empresaSelecionada, widget.empresas),
                  items: widget.empresas,
                  onChanged: (value) {
                    setState(() => _internalEmpresaSelecionada = value);
                    widget.onEmpresaChanged?.call(value);
                  },
                  scale: horizontalScale,
                ),
              ),
              Positioned(
                left: 19 * horizontalScale,
                top: 345 * horizontalScale,
                width: 194 * horizontalScale,
                child: Text(
                  'Tokens Utilizados: ${widget.tokensUsed}/${widget.tokenLimit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.wixMadeforDisplay(
                    color: const Color(0xDD424141),
                    fontSize: 16 * horizontalScale,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
              ),
              Positioned(
                left: 220 * horizontalScale,
                top: 344 * horizontalScale,
                width: 85 * horizontalScale,
                height: 32 * horizontalScale,
                child: _GenerateButton(
                  isLoading: widget.isGenerating,
                  onPressed: widget.isGenerating ? null : widget.onGenerate,
                  scale: horizontalScale,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  NovoRelatorioOption? _matchingValue(
    NovoRelatorioOption? selected,
    List<NovoRelatorioOption> options,
  ) {
    if (selected == null) return null;
    for (final option in options) {
      if (option.id == selected.id) return option;
    }
    return null;
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _CloseButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: onPressed ?? () => Navigator.maybePop(context),
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

class _NovoRelatorioTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final double scale;

  const _NovoRelatorioTextField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.scale,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(text: label, scale: scale),
        SizedBox(height: 3 * scale),
        SizedBox(
          height: 40 * scale,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            cursorColor: AppColors.primary,
            style: _fieldTextStyle(scale, const Color(0xDD626365), 20),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: _fieldTextStyle(scale, const Color(0xDD626365), 20),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 13 * scale,
                vertical: 8 * scale,
              ),
              filled: true,
              fillColor: Colors.white,
              border: _inputBorder(10),
              enabledBorder: _inputBorder(10),
              focusedBorder: _inputBorder(10, color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _NovoRelatorioDropdown extends StatelessWidget {
  final String label;
  final NovoRelatorioOption? value;
  final List<NovoRelatorioOption> items;
  final ValueChanged<NovoRelatorioOption?> onChanged;
  final Widget? trailingIcon;
  final double dropdownWidthFactor;
  final double scale;

  const _NovoRelatorioDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.scale,
    this.trailingIcon,
    this.dropdownWidthFactor = 1,
  });

  @override
  Widget build(BuildContext context) {
    final dropdownWidth = (284 * dropdownWidthFactor) * scale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(text: label, scale: scale),
        SizedBox(height: 4 * scale),
        Row(
          children: [
            SizedBox(
              width: dropdownWidth,
              height: 40 * scale,
              child: DropdownButtonFormField<NovoRelatorioOption>(
                initialValue: value,
                items: items
                    .map(
                      (option) => DropdownMenuItem<NovoRelatorioOption>(
                        value: option,
                        child: Text(
                          option.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
                isExpanded: true,
                style: _fieldTextStyle(scale, const Color(0xFF313144), 18),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: const Color(0xFF313144),
                  size: 22 * scale,
                ),
                decoration: InputDecoration(
                  hintText: 'Selecione',
                  hintStyle: _fieldTextStyle(
                    scale,
                    const Color(0xFF313144),
                    18,
                  ),
                  isDense: true,
                  contentPadding: EdgeInsets.only(
                    left: 18 * scale,
                    right: 8 * scale,
                    top: 10 * scale,
                    bottom: 10 * scale,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: _inputBorder(8),
                  enabledBorder: _inputBorder(8),
                  focusedBorder: _inputBorder(8, color: AppColors.primary),
                ),
              ),
            ),
            if (trailingIcon != null) ...[
              SizedBox(width: 10 * scale),
              SizedBox(
                width: 24 * scale,
                height: 24 * scale,
                child: FittedBox(child: trailingIcon),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final double scale;

  const _FieldLabel({required this.text, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.lato(
        color: AppColors.textDark,
        fontSize: 20 * scale,
        fontWeight: FontWeight.w300,
        height: 1.2,
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final double scale;

  const _GenerateButton({
    required this.isLoading,
    required this.scale,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A57E8).withValues(alpha: 0.30),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.65),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 8 * scale),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 14 * scale,
                height: 14 * scale,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Gerar',
                  maxLines: 1,
                  style: GoogleFonts.lato(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
      ),
    );
  }
}

class _SlidersIcon extends StatelessWidget {
  const _SlidersIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 24),
      painter: _SlidersIconPainter(),
    );
  }
}

class _SlidersIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final y1 = size.height * 0.32;
    final y2 = size.height * 0.50;
    final y3 = size.height * 0.68;

    canvas.drawLine(
      Offset(size.width * 0.18, y1),
      Offset(size.width * 0.82, y1),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.18, y2),
      Offset(size.width * 0.82, y2),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.18, y3),
      Offset(size.width * 0.82, y3),
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.38, y1),
      2.1,
      paint..style = PaintingStyle.fill,
    );
    canvas.drawCircle(Offset(size.width * 0.62, y2), 2.1, paint);
    canvas.drawCircle(Offset(size.width * 0.46, y3), 2.1, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

TextStyle _fieldTextStyle(double scale, Color color, double fontSize) {
  return GoogleFonts.lato(
    color: color,
    fontSize: fontSize * scale,
    fontWeight: FontWeight.w300,
    height: 1,
    letterSpacing: 0.54 * scale,
  );
}

OutlineInputBorder _inputBorder(
  double radius, {
  Color color = AppColors.textDark,
}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide(color: color),
  );
}
