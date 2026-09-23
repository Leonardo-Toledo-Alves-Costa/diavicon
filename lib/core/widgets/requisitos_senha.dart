import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Um requisito da senha, com o teste que diz se ele já foi cumprido.
class RequisitoSenha {
  final String texto;
  final bool Function(String) cumprido;
  const RequisitoSenha(this.texto, this.cumprido);
}

/// Regras de senha nova, na mesma ordem em que aparecem na tela.
///
/// Ficam aqui, num lugar só, porque valem para o cadastro e para a
/// recuperação de senha — e a mesma lista alimenta a validação
/// (`ValidatorsCadastro.senha`) e este aviso.
const requisitosSenha = <RequisitoSenha>[
  RequisitoSenha('Pelo menos 8 caracteres', _temOitoCaracteres),
  RequisitoSenha('Uma letra maiúscula', _temMaiuscula),
  RequisitoSenha('Uma letra minúscula', _temMinuscula),
  RequisitoSenha('Um número', _temNumero),
];

bool _temOitoCaracteres(String v) => v.length >= 8;
bool _temMaiuscula(String v) => RegExp(r'[A-ZÀ-Þ]').hasMatch(v);
bool _temMinuscula(String v) => RegExp(r'[a-zß-ÿ]').hasMatch(v);
bool _temNumero(String v) => RegExp(r'\d').hasMatch(v);

/// Verdadeiro quando a senha cumpre todos os requisitos.
bool senhaAtendeRequisitos(String senha) =>
    requisitosSenha.every((r) => r.cumprido(senha));

/// Lista dos requisitos da senha, que vai marcando o que já foi cumprido
/// enquanto a pessoa digita. Fica abaixo do campo de senha nas telas de
/// cadastro e de recuperação.
class RequisitosSenha extends StatelessWidget {
  /// O que está escrito no campo de senha agora.
  final String senha;

  /// Mostra os itens ainda não cumpridos em vermelho — ligado só depois de o
  /// usuário tentar enviar o formulário.
  final bool marcarFaltantes;

  const RequisitosSenha({super.key, required this.senha, this.marcarFaltantes = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A senha precisa ter:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          for (final requisito in requisitosSenha)
            _LinhaRequisito(
              texto: requisito.texto,
              cumprido: requisito.cumprido(senha),
              marcarFaltante: marcarFaltantes,
            ),
        ],
      ),
    );
  }
}

class _LinhaRequisito extends StatelessWidget {
  final String texto;
  final bool cumprido;
  final bool marcarFaltante;

  const _LinhaRequisito({required this.texto, required this.cumprido, required this.marcarFaltante});

  @override
  Widget build(BuildContext context) {
    final cor = cumprido
        ? const Color(0xFF2E7D32)
        : (marcarFaltante ? const Color(0xFFC62828) : Colors.grey.shade600);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            cumprido ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 15,
            color: cumprido ? const Color(0xFF2E7D32) : (marcarFaltante ? const Color(0xFFC62828) : Colors.grey.shade400),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12.5,
                color: cor,
                fontWeight: cumprido ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra simples de força da senha, do vermelho ao verde conforme os
/// requisitos vão sendo cumpridos.
class ForcaSenha extends StatelessWidget {
  final String senha;
  const ForcaSenha({super.key, required this.senha});

  @override
  Widget build(BuildContext context) {
    final cumpridos = requisitosSenha.where((r) => r.cumprido(senha)).length;
    final fracao = senha.isEmpty ? 0.0 : cumpridos / requisitosSenha.length;
    final cor = switch (cumpridos) {
      4 => const Color(0xFF2E7D32),
      3 => AppColors.primary,
      _ => const Color(0xFFC62828),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: fracao,
          minHeight: 4,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(senha.isEmpty ? Colors.grey.shade300 : cor),
        ),
      ),
    );
  }
}
