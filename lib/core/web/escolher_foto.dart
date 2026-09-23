import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

/// De onde vem a foto quando o app roda no NAVEGADOR.
///
/// No computador não existe "tirar foto com a câmera" como no celular: o
/// seletor do navegador abre os arquivos do computador. As telas mostravam
/// a mesma folha do celular (Câmera / Galeria) e, ao escolher a câmera, nada
/// acontecia — a troca de foto parecia quebrada.
///
/// Uso nas telas, mantendo a folha do celular intacta:
///
///     final origem = origemFotoNoNavegador ?? await showModalBottomSheet<ImageSource>(...);
///
/// No navegador o `??` já devolve a galeria (arquivos) e a folha nem abre;
/// no celular o valor é nulo e tudo segue como antes.
ImageSource? get origemFotoNoNavegador => kIsWeb ? ImageSource.gallery : null;
