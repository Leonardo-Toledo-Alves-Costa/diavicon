import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/menu_app_bar.dart';
import '../widgets/novo_relatorio_popup.dart';
import '../widgets/right_menu_bar.dart';

enum ReportStatus { aprovado, postado }

class ReportItem {
  final String title;
  final String element;
  final String company;
  final String date;
  final ReportStatus status;

  const ReportItem({
    required this.title,
    required this.element,
    required this.company,
    required this.date,
    required this.status,
  });
}

class RelatoriosScreen extends StatefulWidget {
  final List<ReportItem>? reports;
  final VoidCallback? onNewReport;
  final ValueChanged<ReportItem>? onReportTap;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onOpenInformacoes;

  const RelatoriosScreen({
    super.key,
    this.reports,
    this.onNewReport,
    this.onReportTap,
    this.onSearchChanged,
    this.onOpenInformacoes,
  });

  static const List<ReportItem> _mockReports = [
    ReportItem(
      title: 'Nome do Relatório A',
      element: 'Elemento A',
      company: 'Empresa Engenharia',
      date: '22/03/2026',
      status: ReportStatus.aprovado,
    ),
    ReportItem(
      title: 'Nome do Relatório B',
      element: 'Elemento A',
      company: 'Empresa Engenharia',
      date: '15/02/2026',
      status: ReportStatus.postado,
    ),
    ReportItem(
      title: 'Nome do Relatório A',
      element: 'Elemento A',
      company: 'Empresa Engenharia',
      date: '28/03/2026',
      status: ReportStatus.aprovado,
    ),
  ];

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen> {
  final GlobalKey<RightMenuBarState> _rightMenuKey =
      GlobalKey<RightMenuBarState>();

  void _openNovoRelatorioPopup() {
    if (widget.onNewReport != null) {
      widget.onNewReport!();
      return;
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.42),
      builder: (dialogContext) => NovoRelatorioPopup(
        ensaios: const [
          NovoRelatorioOption(id: 'carbonatacao', label: 'Carbonatação'),
          NovoRelatorioOption(id: 'corrosao', label: 'Corrosão'),
          NovoRelatorioOption(id: 'resistividade', label: 'Resistividade'),
        ],
        empresas: const [
          NovoRelatorioOption(id: 'empresa-a', label: 'Empresa Engenharia'),
          NovoRelatorioOption(id: 'empresa-b', label: 'ABC Corp.'),
        ],
        onClose: () => Navigator.of(dialogContext).pop(),
        onGenerate: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleReports = widget.reports ?? RelatoriosScreen._mockReports;

    return RightMenuBar(
      key: _rightMenuKey,
      onInformacoesPressed: widget.onOpenInformacoes,
      onRelatoriosPressed: () {},
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: MenuAppBar(
          topTitle: 'Projeto',
          title: 'Elemento',
          bottomTitle: 'Relatórios',
          onMenuPressed: () => _rightMenuKey.currentState?.toggle(),
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth
                  .clamp(0.0, 390.0)
                  .toDouble();
              final horizontalPadding = contentWidth < 390
                  ? 20.0
                  : (contentWidth - 350) / 2;
              final innerWidth = (contentWidth - (horizontalPadding * 2))
                  .clamp(0.0, 350.0)
                  .toDouble();

              return SingleChildScrollView(
                child: Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        28,
                        horizontalPadding,
                        120,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Central de relatórios',
                            style: GoogleFonts.lato(
                              color: const Color(0xFF3E3E3D),
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _ReportSearchField(
                            width: innerWidth,
                            onChanged: widget.onSearchChanged,
                          ),
                          const SizedBox(height: 20),
                          _NewReportButton(
                            onPressed: _openNovoRelatorioPopup,
                            maxWidth: innerWidth,
                          ),
                          const SizedBox(height: 20),
                          for (final report in visibleReports) ...[
                            _ReportCard(
                              report: report,
                              width: innerWidth,
                              onTap: widget.onReportTap == null
                                  ? null
                                  : () => widget.onReportTap!(report),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReportSearchField extends StatelessWidget {
  final double width;
  final ValueChanged<String>? onChanged;

  const _ReportSearchField({required this.width, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x9ED9D9D9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        onChanged: onChanged,
        cursorColor: AppColors.primary,
        style: GoogleFonts.lato(
          color: AppColors.textDark,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Busque por ensaio',
          hintStyle: GoogleFonts.lato(
            color: const Color(0xFFCCCCCC),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          suffixIcon: const Icon(
            Icons.search,
            color: Color(0xFF686868),
            size: 22,
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 42,
            minHeight: 40,
          ),
          contentPadding: const EdgeInsets.only(
            left: 10,
            right: 4,
            top: 10,
            bottom: 10,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _NewReportButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double maxWidth;

  const _NewReportButton({required this.maxWidth, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: maxWidth < 158 ? maxWidth : 158,
      height: 31,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3A57E8).withOpacity(0.30),
              blurRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary,
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '+ Novo Relatório',
              maxLines: 1,
              style: GoogleFonts.lato(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportItem report;
  final double width;
  final VoidCallback? onTap;

  const _ReportCard({required this.report, required this.width, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 24, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _ReportCardText(report: report)),
                const SizedBox(width: 10),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: _ReportFileIcon(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportCardText extends StatelessWidget {
  final ReportItem report;

  const _ReportCardText({required this.report});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lato(
                  color: const Color(0xFF3E3E3D),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                report.element,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _cardDetailStyle(const Color(0xFF3E3E3D)),
              ),
              const SizedBox(height: 5),
              Text(
                report.company,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _cardDetailStyle(const Color(0xFF686868)),
              ),
              const SizedBox(height: 5),
              Text(
                report.date,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _cardDetailStyle(const Color(0xFF686868)),
              ),
            ],
          ),
        ),
        Positioned(
          right: 0,
          bottom: 1,
          child: _ReportStatusPill(status: report.status),
        ),
      ],
    );
  }

  TextStyle _cardDetailStyle(Color color) {
    return GoogleFonts.lato(
      color: color,
      fontSize: 14,
      fontWeight: FontWeight.w300,
      height: 1.1,
    );
  }
}

class _ReportStatusPill extends StatelessWidget {
  final ReportStatus status;

  const _ReportStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isApproved = status == ReportStatus.aprovado;

    return Container(
      width: 102,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isApproved ? const Color(0xFFE9FFE0) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isApproved ? 'Aprovado' : 'Postado',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          color: isApproved ? const Color(0xFF0F6B18) : const Color(0xFFF7941D),
          fontSize: 10.2,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

class _ReportFileIcon extends StatelessWidget {
  const _ReportFileIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(47, 51),
      painter: _ReportFileIconPainter(),
    );
  }
}

class _ReportFileIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final left = size.width * 0.20;
    final top = size.height * 0.08;
    final right = size.width * 0.85;
    final bottom = size.height * 0.92;
    final fold = size.width * 0.24;

    final path = Path()
      ..moveTo(left, top)
      ..lineTo(right - fold, top)
      ..lineTo(right, top + fold)
      ..lineTo(right, bottom)
      ..lineTo(left, bottom)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(right - fold, top),
      Offset(right - fold, top + fold),
      paint,
    );
    canvas.drawLine(
      Offset(right - fold, top + fold),
      Offset(right, top + fold),
      paint,
    );

    final lineLeft = left + size.width * 0.14;
    final lineRight = right - size.width * 0.14;
    canvas.drawLine(
      Offset(lineLeft, top + size.height * 0.34),
      Offset(lineLeft + size.width * 0.09, top + size.height * 0.34),
      paint,
    );
    canvas.drawLine(
      Offset(lineLeft, top + size.height * 0.49),
      Offset(lineRight, top + size.height * 0.49),
      paint,
    );
    canvas.drawLine(
      Offset(lineLeft, top + size.height * 0.64),
      Offset(lineRight, top + size.height * 0.64),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
