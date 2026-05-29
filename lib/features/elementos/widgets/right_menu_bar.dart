import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/features/elementos/screens/info_elementos_screen.dart';
import 'package:diavicon/features/elementos/screens/relatorios_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RightMenuBar extends StatefulWidget {
  const RightMenuBar({
    super.key,
    required this.child,
    this.onInformacoesPressed,
    this.onRelatoriosPressed,
    this.onDashboardPressed,
  });

  final Widget child;
  final VoidCallback? onInformacoesPressed;
  final VoidCallback? onRelatoriosPressed;
  final VoidCallback? onDashboardPressed;

  @override
  State<RightMenuBar> createState() => RightMenuBarState();
}

class RightMenuBarState extends State<RightMenuBar> {
  bool _isOpen = false;

  void toggle() {
    setState(() => _isOpen = !_isOpen);
  }

  void close() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
  }

  void _handleTap(_RightMenuDestination destination, VoidCallback? callback) {
    close();
    if (callback != null) {
      callback();
      return;
    }

    switch (destination) {
      case _RightMenuDestination.informacoes:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ElementoInfoScreen()),
        );
        return;
      case _RightMenuDestination.relatorios:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const RelatoriosScreen()),
        );
        return;
      case _RightMenuDestination.dashboard:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return LayoutBuilder(
      builder: (context, constraints) {
        final menuWidth = constraints.maxWidth < 360 ? 88.0 : 94.0;

        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (_isOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: close,
                  child: const SizedBox.expand(),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              top: topInset + 142,
              right: _isOpen ? 0 : -menuWidth - 8,
              bottom: 58,
              width: menuWidth,
              child: IgnorePointer(
                ignoring: !_isOpen,
                child: _RightMenuPanel(
                  onInformacoesPressed: () => _handleTap(
                    _RightMenuDestination.informacoes,
                    widget.onInformacoesPressed,
                  ),
                  onRelatoriosPressed: () => _handleTap(
                    _RightMenuDestination.relatorios,
                    widget.onRelatoriosPressed,
                  ),
                  onDashboardPressed: () => _handleTap(
                    _RightMenuDestination.dashboard,
                    widget.onDashboardPressed,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _RightMenuDestination { informacoes, relatorios, dashboard }

class _RightMenuPanel extends StatelessWidget {
  const _RightMenuPanel({
    this.onInformacoesPressed,
    this.onRelatoriosPressed,
    this.onDashboardPressed,
  });

  final VoidCallback? onInformacoesPressed;
  final VoidCallback? onRelatoriosPressed;
  final VoidCallback? onDashboardPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEAE7E5),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.26),
            blurRadius: 4,
            offset: const Offset(-2, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 18, 8, 18),
          child: Column(
            children: [
              Text(
                'Menu do\nElemento',
                textAlign: TextAlign.left,
                style: GoogleFonts.lato(
                  color: const Color(0xFF3E3E3D),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 24),
              _RightMenuButton(
                icon: Icons.info_outline,
                label: 'Informações',
                onPressed: onInformacoesPressed,
              ),
              const SizedBox(height: 24),
              _RightMenuButton(
                icon: Icons.file_copy_outlined,
                label: 'Relatórios',
                onPressed: onRelatoriosPressed,
              ),
              const SizedBox(height: 24),
              _RightMenuButton(
                icon: Icons.pie_chart_outline,
                label: 'Dashboard',
                onPressed: onDashboardPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RightMenuButton extends StatelessWidget {
  const _RightMenuButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 25),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
              color: const Color(0xFF686868),
              fontSize: 10,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
