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
      
      // Só arredondo todos os cantos se o modal não estiver colado na base da tela
      final bool isTouchingBottom = alignment == Alignment.bottomCenter && margin.bottom == 0;
      final effectivePadding = contentPadding ?? const EdgeInsets.fromLTRB(24, 8, 24, 24);
      final effectiveBorderRadius = borderRadius ??
          (isTouchingBottom
              ? const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                )
              : BorderRadius.circular(24));

      return Padding(
        // Garante que o teclado não vai cobrir o modal quando abrir
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: margin,
            child: Container(
              height: height,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: effectiveBorderRadius,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  
                  // Header: Título + Botão de fechar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 12, 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.close, color: AppColors.hintText),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        // Só desenha o título se ele não for vazio!
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
                      ],
                    ),
                  ),

                  // Body: com ou sem scroll dependendo da necessidade da view
                  Flexible(
                    child: isScrollable
                        ? SingleChildScrollView(
                            padding: effectivePadding,
                            child: body,
                          )
                        : Padding(
                            padding: effectivePadding,
                            child: body,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}