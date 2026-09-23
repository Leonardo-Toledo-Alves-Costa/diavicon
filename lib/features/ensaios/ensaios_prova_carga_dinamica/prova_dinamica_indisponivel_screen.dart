import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// A prova de carga dinâmica (acelerometria) é analisada no aplicativo de
/// computador: os arquivos do equipamento têm milhões de leituras e centenas
/// de megabytes. No celular o ensaio aparece na lista, mas a análise abre
/// esta tela.
class ProvaDinamicaIndisponivelScreen extends StatelessWidget {
  final String? nomePonto;
  const ProvaDinamicaIndisponivelScreen({super.key, this.nomePonto});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prova de carga dinâmica'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.desktop_windows_outlined, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              Text(
                nomePonto == null || nomePonto!.isEmpty ? 'Análise no computador' : nomePonto!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'Este ensaio é analisado no aplicativo de computador, onde os arquivos do '
                'equipamento de acelerometria são importados e tratados.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
