import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/features/home/screens/perfil_header.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class PerfilMinhaPrivacidade extends StatefulWidget {
  const PerfilMinhaPrivacidade({super.key});

  @override
  State<PerfilMinhaPrivacidade> createState() => _PerfilMinhaPrivacidadeState();
}

class _PerfilMinhaPrivacidadeState extends State<PerfilMinhaPrivacidade> {
  bool _ajudaIA = true;
  bool _visibilidadePerfil = true;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: Column(
        children: [
          PerfilHeader(topPadding: topPadding, paginaAtual: 'Privacidade'),
          const SizedBox(height: 35),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -18),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Text(
                          'Privacidade',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3E3E3D),
                            fontFamily: 'Lato',
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Controle como suas informações são usadas e\ncompartilhadas com outras pessoas na\nDIAVICON.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.25,
                          color: Color(0xFF3E3E3D),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _PrivacySection(
                        title: 'Privacidade de dados',
                        description: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.25,
                              color: Color(0xFF3E3E3D),
                            ),
                            children: [
                              const TextSpan(
                                text:
                                    'Ajude a aprimorar os recursos com IA\nQuando esta opção estiver\nativada, usaremos seus dados para\ndesenvolver e aprimorar modelos de\nIA que impulsionam determinados\nrecursos na DIAVICON. ',
                              ),
                              TextSpan(
                                text: 'Saiba mais.',
                                style: const TextStyle(
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3E3E3D),
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    // open privacy details
                                  },
                              ),
                            ],
                          ),
                        ),
                        value: _ajudaIA,
                        onChanged: (value) {
                          setState(() => _ajudaIA = value);
                        },
                      ),
                      const SizedBox(height: 20),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFF808080),
                      ),
                      const SizedBox(height: 20),
                      _PrivacySection(
                        title: 'Visibilidade do perfil',
                        description: Text('Pessoas que fazem parte da sua\norganização'),
                        value: _visibilidadePerfil,
                        onChanged: (value) {
                          setState(() => _visibilidadePerfil = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final String title;
  final Widget description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrivacySection({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3E3E3D),
                  fontFamily: 'Lato',
                ),
              ),
              const SizedBox(height: 10),
              description,
            ],
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Switch.adaptive(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
