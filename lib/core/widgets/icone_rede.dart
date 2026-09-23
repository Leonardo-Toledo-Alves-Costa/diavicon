import 'package:flutter/material.dart';

/// Canais de contato de uma empresa.
enum CanalContato { whatsapp, instagram, youtube, linkedin, facebook, site, email, telefone, endereco }

/// Ícones dos canais de contato, desenhados aqui mesmo.
///
/// O Material não traz marcas, e o que se usava antes (uma câmera para o
/// Instagram, um play genérico para o YouTube) não lembrava nada. Estes são
/// desenhos simples das formas que cada rede usa — o quadrado arredondado com
/// a lente do Instagram, o retângulo com o triângulo do YouTube, o "in" do
/// LinkedIn —, nas cores de cada uma. Não usa imagem nem pacote novo, então
/// vale igual no web e no celular.
class IconeRede extends StatelessWidget {
  final CanalContato canal;
  final double tamanho;

  /// Cor fixa; nulo usa a cor da marca (ou o tom do texto, nos canais que
  /// não são rede social).
  final Color? cor;

  const IconeRede(this.canal, {super.key, this.tamanho = 20, this.cor});

  /// Cor da marca de cada canal.
  static const cores = {
    CanalContato.whatsapp: Color(0xFF25D366),
    CanalContato.instagram: Color(0xFFE1306C),
    CanalContato.youtube: Color(0xFFFF0000),
    CanalContato.linkedin: Color(0xFF0A66C2),
    CanalContato.facebook: Color(0xFF1877F2),
  };

  static String rotulo(CanalContato canal) => switch (canal) {
        CanalContato.whatsapp => 'WhatsApp',
        CanalContato.instagram => 'Instagram',
        CanalContato.youtube => 'YouTube',
        CanalContato.linkedin => 'LinkedIn',
        CanalContato.facebook => 'Facebook',
        CanalContato.site => 'Site',
        CanalContato.email => 'E-mail',
        CanalContato.telefone => 'Telefone',
        CanalContato.endereco => 'Localização',
      };

  @override
  Widget build(BuildContext context) {
    final tom = cor ?? cores[canal] ?? IconTheme.of(context).color ?? const Color(0xFF2E3033);

    switch (canal) {
      case CanalContato.site:
        return Icon(Icons.language_rounded, size: tamanho, color: tom);
      case CanalContato.email:
        return Icon(Icons.mail_outline_rounded, size: tamanho, color: tom);
      case CanalContato.telefone:
        return Icon(Icons.call_outlined, size: tamanho, color: tom);
      case CanalContato.endereco:
        return Icon(Icons.place_outlined, size: tamanho, color: tom);
      default:
        return SizedBox(
          width: tamanho,
          height: tamanho,
          child: CustomPaint(painter: _PintorRede(canal, tom)),
        );
    }
  }
}

class _PintorRede extends CustomPainter {
  final CanalContato canal;
  final Color cor;

  _PintorRede(this.canal, this.cor);

  @override
  void paint(Canvas canvas, Size size) {
    // Tudo é desenhado numa caixa de 24 por 24 e depois escalado.
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    switch (canal) {
      case CanalContato.whatsapp:
        _whatsapp(canvas);
      case CanalContato.instagram:
        _instagram(canvas);
      case CanalContato.youtube:
        _youtube(canvas);
      case CanalContato.linkedin:
        _linkedin(canvas);
      case CanalContato.facebook:
        _facebook(canvas);
      default:
        break;
    }
    canvas.restore();
  }

  /// Balão de conversa com o fone dentro.
  void _whatsapp(Canvas canvas) {
    final cheio = Paint()..color = cor;
    final balao = Path()
      ..addOval(const Rect.fromLTWH(1.5, 1.5, 21, 21))
      // Bico do balão, no canto de baixo à esquerda.
      ..moveTo(4.6, 17.6)
      ..lineTo(1.4, 22.6)
      ..lineTo(7.4, 20.6)
      ..close();
    canvas.drawPath(balao, cheio);

    // Fone, em branco, no meio.
    final fone = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final caminho = Path()
      ..moveTo(9.0, 8.0)
      ..cubicTo(8.4, 9.6, 8.8, 11.4, 10.0, 12.6)
      ..cubicTo(11.2, 13.8, 13.0, 14.2, 14.6, 13.6)
      ..lineTo(16.2, 15.2)
      ..cubicTo(14.2, 17.0, 11.0, 16.6, 8.9, 14.5)
      ..cubicTo(6.8, 12.4, 6.4, 9.2, 8.2, 7.2)
      ..close();
    canvas.drawPath(caminho, Paint()..color = Colors.white);
    canvas.drawPath(caminho, fone..color = Colors.white);
  }

  /// Quadrado arredondado, lente e ponto.
  void _instagram(Canvas canvas) {
    final traco = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(2.5, 2.5, 19, 19), const Radius.circular(5.5)),
      traco,
    );
    canvas.drawCircle(const Offset(12, 12), 4.4, traco);
    canvas.drawCircle(const Offset(17.4, 6.6), 1.25, Paint()..color = cor);
  }

  /// Retângulo arredondado com o triângulo de play.
  void _youtube(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(1.5, 4.5, 21, 15), const Radius.circular(4.5)),
      Paint()..color = cor,
    );
    final play = Path()
      ..moveTo(10.0, 8.6)
      ..lineTo(16.2, 12.0)
      ..lineTo(10.0, 15.4)
      ..close();
    canvas.drawPath(play, Paint()..color = Colors.white);
  }

  /// Quadrado com o "in".
  void _linkedin(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(2, 2, 20, 20), const Radius.circular(4)),
      Paint()..color = cor,
    );
    final branco = Paint()..color = Colors.white;
    // "i" — ponto e haste.
    canvas.drawCircle(const Offset(7.2, 7.4), 1.45, branco);
    canvas.drawRect(const Rect.fromLTWH(5.9, 10.0, 2.6, 8.2), branco);
    // "n" — haste e o arco que vira a perna.
    canvas.drawRect(const Rect.fromLTWH(10.4, 10.0, 2.6, 8.2), branco);
    final n = Path()
      ..moveTo(13.0, 18.2)
      ..lineTo(13.0, 13.9)
      ..cubicTo(13.0, 11.4, 16.4, 11.2, 16.4, 13.9)
      ..lineTo(16.4, 18.2)
      ..lineTo(19.0, 18.2)
      ..lineTo(19.0, 13.5)
      ..cubicTo(19.0, 8.7, 13.6, 8.9, 13.0, 11.1)
      ..close();
    canvas.drawPath(n, branco);
  }

  /// Círculo com o "f".
  void _facebook(Canvas canvas) {
    canvas.drawCircle(const Offset(12, 12), 10.5, Paint()..color = cor);
    final branco = Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(11.0, 10.2, 3.0, 11.4), branco);
    canvas.drawRect(const Rect.fromLTWH(8.6, 10.2, 5.4, 2.8), branco);
    final curva = Path()
      ..moveTo(14.0, 10.2)
      ..lineTo(14.0, 8.6)
      ..cubicTo(14.0, 7.5, 14.6, 7.2, 16.0, 7.3)
      ..lineTo(16.0, 4.6)
      ..cubicTo(12.4, 4.0, 11.0, 5.6, 11.0, 8.4)
      ..lineTo(11.0, 10.2)
      ..close();
    canvas.drawPath(curva, branco);
  }

  @override
  bool shouldRepaint(covariant _PintorRede old) => old.canal != canal || old.cor != cor;
}
