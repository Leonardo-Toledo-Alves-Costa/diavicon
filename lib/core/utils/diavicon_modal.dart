import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Modal padrão customizável do app.
/// 
/// - Por padrão: ocupa toda a largura, encosta na base e arredonda só o topo.
/// - Para centralizar na tela: use [alignment] = Alignment.center e adicione [margin].
/// - Para centralizar o título: [centerTitle] = true.
///
/// Exemplo de uso centralizado:
/// showDiaviconModal(
///   context: context,
///   title: 'Título',
///   body: const MeuWidget(),
///   margin: const EdgeInsets.symmetric(horizontal: 18),
///   alignment: Alignment.center,
///   centerTitle: true,
/// );
Future<T?> showDiaviconModal<T>({
  required BuildContext context,
  required String title,
  required Widget body,
  bool centerTitle = false,
  EdgeInsets margin = EdgeInsets.zero,
  Alignment alignment = Alignment.bottomCenter,
  BorderRadius? borderRadius,
  double? height,
  bool isScrollable = true,
  EdgeInsets? contentPadding,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      
      // Descobre se o teclado subiu
      final bottomInset = MediaQuery.of(context).viewInsets.bottom;
      final bool isKeyboardOpen = bottomInset > 0;

      //Proteção contra esmagamento: se o teclado abrir, reduz a margem do topo para apenas 16px
      final effectiveMargin = EdgeInsets.fromLTRB(
        margin.left,
        isKeyboardOpen ? 16.0 : margin.top, 
        margin.right,
        margin.bottom,
      );

      // Só arredondo todos os cantos se o modal não estiver colado na base da tela
      final bool isTouchingBottom = alignment == Alignment.bottomCenter && effectiveMargin.bottom == 0;
      final effectivePadding = contentPadding ?? const EdgeInsets.fromLTRB(24, 8, 24, 24);
      final effectiveBorderRadius = borderRadius ??
          (isTouchingBottom
              ? const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                )
              : BorderRadius.circular(24));

      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: effectiveMargin, 
            child: Container(
              height: height,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: effectiveBorderRadius,
              ),
              child: IntrinsicHeight( // 🚨 Adicionado para dar estabilidade ao cálculo de altura
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header: Título + Botão de fechar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 12, 4),
                      child: Stack( // 🔥 Trocado de Column para Stack para alinhar na mesma linha
                        alignment: Alignment.center,
                        children: [
                          if (title.isNotEmpty)
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                title,
                                textAlign: centerTitle ? TextAlign.center : TextAlign.start,
                                style: const TextStyle(
                                  color: AppColors.textDark,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.close, color: AppColors.hintText),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Flexible(
                      child: SingleChildScrollView(
                        // 🚨 Importante: isScrollable controla o scroll interno
                        physics: isScrollable ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
                        padding: effectivePadding,
                        child: body,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  );
}