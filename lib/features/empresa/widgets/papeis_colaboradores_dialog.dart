import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Janela que explica os papéis de quem trabalha na empresa: Gestor,
/// Administrador, Colaborador com acesso ao painel e Colaborador.
///
/// As regras aqui são as que o app e o servidor aplicam de fato (Edge Function
/// `auth-operations` e as telas do painel). Se uma regra mudar lá, mude aqui
/// também — este texto é o que as pessoas vão ler para entender por que um
/// botão aparece ou não.
Future<void> mostrarPapeisColaboradores(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final largura = MediaQuery.sizeOf(ctx).width;
      return Dialog(
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: largura < 600 ? 16 : 40, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 8, 4),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Papéis na empresa',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E3033)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Do papel com mais poder para o com menos. Cada um inclui '
                        'tudo o que o papel de baixo pode fazer.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < _papeis.length; i++) ...[
                        _CartaoPapel(papel: _papeis[i], nivel: i + 1),
                        if (i < _papeis.length - 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade400),
                          ),
                      ],
                      const SizedBox(height: 14),
                      const _Observacoes(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Entendi', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Papel {
  final String nome;
  final String resumo;
  final IconData icone;
  final Color cor;
  final Color fundo;
  final List<String> pode;
  final List<String> naoPode;

  const _Papel({
    required this.nome,
    required this.resumo,
    required this.icone,
    required this.cor,
    required this.fundo,
    required this.pode,
    this.naoPode = const [],
  });
}

const _papeis = <_Papel>[
  _Papel(
    nome: 'Gestor da empresa',
    resumo: 'Responsável pela conta da empresa. É o ícone de certificado na lista.',
    icone: Icons.workspace_premium,
    cor: Color(0xFFA85A00),
    fundo: Color(0xFFFDF0E0),
    pode: [
      'Tudo o que o Administrador pode',
      'Tornar outro administrador Gestor',
      'Remover o papel de Gestor de outro Gestor',
      'Suspender, restaurar e excluir outro Gestor',
      'Excluir a empresa',
    ],
    naoPode: [
      'Deixar a empresa sem nenhum Gestor ativo',
      'Alterar o próprio acesso',
    ],
  ),
  _Papel(
    nome: 'Administrador',
    resumo: 'Cuida do dia a dia da empresa. Marcado como "admin" na lista.',
    icone: Icons.admin_panel_settings_outlined,
    cor: Color(0xFF1565A0),
    fundo: Color(0xFFE3F0FB),
    pode: [
      'Abrir e usar o Painel da empresa',
      'Convidar colaboradores',
      'Tornar ou deixar de ser admin, e liberar o acesso ao painel',
      'Suspender, restaurar e excluir colaboradores',
      'Cuidar de serviços e produtos, campos personalizáveis e conjuntos estruturais',
      'Ver a análise de gastos da empresa',
    ],
    naoPode: [
      'Tornar alguém Gestor',
      'Alterar, suspender ou excluir um Gestor',
      'Excluir a empresa',
    ],
  ),
  _Papel(
    nome: 'Colaborador com acesso ao painel',
    resumo: 'Acompanha a empresa sem administrar. É o ícone de olho na lista.',
    icone: Icons.visibility_outlined,
    cor: Color(0xFF00695C),
    fundo: Color(0xFFE0F2F1),
    pode: [
      'Tudo o que o Colaborador pode',
      'Abrir e consultar o Painel da empresa',
    ],
    naoPode: [
      'Convidar, alterar ou remover colaboradores',
      'Mudar as configurações da empresa',
    ],
  ),
  _Papel(
    nome: 'Colaborador',
    resumo: 'Trabalha nos projetos para os quais foi chamado.',
    icone: Icons.person_outline,
    cor: Color(0xFF5B5C5E),
    fundo: Color(0xFFEDEAE4),
    pode: [
      'Trabalhar nos projetos em que está na equipe',
      'Consultar estruturas, lançar ensaios e registros de campo',
      'Lançar os próprios gastos',
    ],
    naoPode: [
      'Abrir o Painel da empresa',
      'Criar conjuntos estruturais',
    ],
  ),
];

class _CartaoPapel extends StatelessWidget {
  final _Papel papel;
  final int nivel;

  const _CartaoPapel({required this.papel, required this.nivel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: papel.fundo, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: papel.fundo, shape: BoxShape.circle),
                child: Icon(papel.icone, size: 18, color: papel.cor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  papel.nome,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: papel.cor),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: papel.fundo, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  'nível $nivel',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: papel.cor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(papel.resumo, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.35)),
          const SizedBox(height: 10),
          for (final item in papel.pode) _Linha(texto: item, permitido: true),
          for (final item in papel.naoPode) _Linha(texto: item, permitido: false),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  final String texto;
  final bool permitido;

  const _Linha({required this.texto, required this.permitido});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            permitido ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
            size: 16,
            color: permitido ? const Color(0xFF2E9E62) : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: permitido ? const Color(0xFF2E3033) : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Observacoes extends StatelessWidget {
  const _Observacoes();

  @override
  Widget build(BuildContext context) {
    TextSpan negrito(String t) => TextSpan(text: t, style: const TextStyle(fontWeight: FontWeight.bold));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF7F6F3), borderRadius: BorderRadius.circular(10)),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF3E3E3D), height: 1.45),
          children: [
            negrito('Situação do acesso. '),
            const TextSpan(
              text: 'Independente do papel, cada pessoa pode estar ',
            ),
            negrito('ativa'),
            const TextSpan(text: ', com '),
            negrito('convite pendente'),
            const TextSpan(text: ' (ainda não fez o primeiro acesso) ou '),
            negrito('suspensa'),
            const TextSpan(
              text: ' — sai do app na hora e não consegue entrar de novo até um '
                  'administrador restaurar o acesso.',
            ),
          ],
        ),
      ),
    );
  }
}
