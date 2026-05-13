import 'package:flutter/material.dart';

class RodapeSeguro extends StatelessWidget {
  final Color cor;
  
  const RodapeSeguro({super.key, this.cor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cor,
      child: const SafeArea(
        top: false,
        child: SizedBox.shrink(),
      ),
    );
  }
}