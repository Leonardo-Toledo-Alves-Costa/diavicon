import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

//por padrão o modal oculpa toda a extensão da tela horizontalmente, aredonda so as bordas de cima
//por padrão vem tambem encostado na parte inferior da tela e titulo a esquerda
//para afastar das bordas laterais do setar as margens laterais (margin.right e margin.left) com um valor maior que 0   
//para fazer o modal aparecer no centro da tela ao invez de na base setar o Alignment como Alignment.center
//para centralizar o texto setar a variavel centerTitle = true

/*ex que afasta da borda lateral, coloca o modal no centro da tela e centraliza o titulo : 
    showDiaviconModal(
                        context: context,
                        title: 'titulo',
                        body: const exemplo(),
                        margin: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                        alignment: Alignment.center,
                        centerTitle = true,
                      );
*/

Future<T?> showDiaviconModal<T>({
  required BuildContext context,
  required String title,
  required Widget body,
  // variavel para centralizar o titulo
  bool centerTitle = false,
  // Margens laterais (afastamento das bordas da tela)
  EdgeInsets margin = EdgeInsets.zero,
  // Alinhamento (bottomCenter para encostado, center para o meio da tela)
  Alignment alignment = Alignment.bottomCenter,
  // arredondamento das bordas
  BorderRadius? borderRadius,
  //variavel para caso o tamanho do modal seja fixo
  double? height, 
  //variavel para desativar o scroll
  bool isScrollable = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      // Lógica inteligente de bordas: 
      // O modal só é considerado "encostado" se o alinhamento for no fundo E a margem inferior for zero.
      // Em qualquer outro caso (como Alignment.center), ele deve arredondar todos os cantos.
      final bool isTouchingBottom = alignment == Alignment.bottomCenter && margin.bottom== 0;
      final effectiveBorderRadius = borderRadius ?? (isTouchingBottom 
          ? const BorderRadius.only(
              topLeft: Radius.circular(24), 
              topRight: Radius.circular(24)
            )
          : BorderRadius.circular(24));

      return Padding(
        padding: EdgeInsets.only(
          // Ajuste automático para o teclado não cobrir o modal
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: margin,
            child: Container(
              height: height, //aplica a altura se fornecida
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
                  // Cabeçalho do Modal (Título + Botão X)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 12, 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botão de Fechar (Sempre no canto superior direito)
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.close, color: AppColors.hintText),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),

                        // Título (Centralizado ou à Esquerda)
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
                  
                  //SE SCROLLABLE FOR FALSE, REMOVE O SINGLECHILDSCROLLVIEW GLOBAL
                  Flexible(
                    child: isScrollable 
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: body,
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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