import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Cadastro1Cliente extends StatefulWidget {
  final Map<String, dynamic> dadosUsuario;

  const Cadastro1Cliente({super.key, required this.dadosUsuario});

  @override
  State<Cadastro1Cliente> createState() => _Cadastro1ClienteState();
}

class _Cadastro1ClienteState extends State<Cadastro1Cliente> {
  // Lista de serviços para o Checkbox
  final List<_QuestionarioPasso> _passos = const [
    _QuestionarioPasso(
      id: 'estrutura',
      pergunta: 'Quais tipos de estrutura sua empresa possui?',
      chaveMapa: 'estruturas',
      multiplaEscolha: true,
      opcoes: [
        'Residencial',
        'Comercial (shoppings, prédios comerciais)',
        'Industriais',
        'Galpões',
        'Mineiração',
        'Barragens',
        'Marinhas ou portuária',
        'OAEs',
        'Públicas',
        'Infraestrutura',
        'Saneamento',
        'Rodoviárias',
      ],
      ponto: [1, 2, 3, 2, 3, 3, 3, 3, 2, 3, 3, 3],
    ),
    _QuestionarioPasso(
      id: 'atuacao',
      pergunta: 'Qual atuação da sua empresa?',
      chaveMapa: 'atuacao_empresa',
      multiplaEscolha: true,
      opcoes: [
        'Residencial',
        'Comercial',
        'industrial',
        'Mineiração',
        'Portuária',
        'Pública',
        'Saneamento',
        'Rodoviária',
      ],
      ponto: [1, 2, 3, 3, 3, 2, 3, 3],
    ),
    _QuestionarioPasso(
      id: 'ativos',
      pergunta: 'Qual a quantidade de ativos estruturais da empresa?',
      chaveMapa: 'quantidade_ativos',
      multiplaEscolha: false,
      opcoes: [
        '1 a 5 ativos',
        '5 a 10 ativos',
        '10 a 50 ativos',
        '50 a 200 ativos',
        'Mais de 200 ativos',
      ],
      ponto: [1, 2, 3, 3, 3],
    ),
    _QuestionarioPasso(
      id: 'complexidade',
      pergunta: 'Qual a complexidade média desses ativos?',
      chaveMapa: 'complexidade_ativos',
      multiplaEscolha: false,
      opcoes: [
        'Baixa complexidades, são estruturas convencionais e pequenas ou médio porte',
        'Média complexidade, são estruturas de grande porte, com vários ambientes e funções diferentes',
        'Estruturas de grande porte, mas convencionais',
        'Alta complexidade, estruturas de grande porte com diversas especificidades construtivas',
        'Alta complexidade, sendo estruturas críticas cuja interdição/parada de um dia causa prejuízo financeiro significativo',
      ],
      ponto: [1, 2, 3, 3, 3],
    ),
    _QuestionarioPasso(
      id: 'gerenciamento',
      pergunta: 'Como a sua empresa gerencia os seus ativos?',
      chaveMapa: 'gerenciamento_ativos',
      multiplaEscolha: false,
      opcoes: [
        'Ainda não gerenciamos nossos ativos estruturais;',
        'Mantemos os registros de intervenções e inspeções realizadas devidamente armazenado e organizado;',
        'Temos gestão de inspeções periódicas para essa estrutura',
        'Temos modelos de previsão para execução de intervenções/inspeções na estrutura',
      ],
      ponto: [1, 2, 3, 3],
    ),
    _QuestionarioPasso(
      id: 'dores_cabeca',
      pergunta: 'Sua empresa já passou por alguma dessas dores de cabeça?',
      chaveMapa: 'dores_cabeca_empresa',
      multiplaEscolha: false,
      opcoes: [
        'Já perdemos dados históricos de ativos nossos (relatórios, ensaios, RDO\'s, intervenções)',
        'As vezes não sabemos se a estrutura precisa ou não de uma intervenção/inspeção?',
        'Já recebemos relatórios sobre nossos ativos que não revelaram nada para nós sobre a condição da estrutura',
        'As vezes esquecemos que já realizamos algum tipo de inspeção/inspeção na estrutura',
        'Temos atrasos críticos com empresas que realizam inspeções',
        'É tanto ativo estrutural que nem sabemos por onde começar a cadastrar ou monitorar',
        'Fizemos intervenções ou inspeções quando não precisava',
      ],
      ponto: [1, 2, 2, 3, 3, 3, 3],
    ),
  ];
  final Map<String, Set<String>> _selecionadosPorPasso = {};
  int _etapaAtual = 0;

  Set<String> _selecionadosDoPasso(String passoId) {
    return _selecionadosPorPasso.putIfAbsent(passoId, () => <String>{});
  }

  Map<String, List<String>> _respostasSelecionadas() {
    return {
      for (final passo in _passos)
        passo.chaveMapa:
            _selecionadosPorPasso[passo.id]?.toList() ?? <String>[],
    };
  }

  void _voltar() {
    if (_etapaAtual == 0) {
      context.pop();
      return;
    }

    setState(() => _etapaAtual--);
  }

  void _avancar() {
    final passoAtual = _passos[_etapaAtual];
    final selecionados = _selecionadosDoPasso(passoAtual.id);

    if (selecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos uma opção para continuar.'),
        ),
      );
      return;
    }

    if (_etapaAtual < _passos.length - 1) {
      setState(() => _etapaAtual++);
      return;
    }

    final respostas = _respostasSelecionadas();
    int pontos = 0;
    for (var entry in respostas.entries) {
      final passo = _passos.firstWhere((p) => p.chaveMapa == entry.key);
      final ponto = entry.value.fold<int>(0, (total, opcao) {
        final index = passo.opcoes.indexOf(opcao);
        if (index != -1 && index < passo.ponto.length) {
          return total + passo.ponto[index];
        }
        return total;
      });
      pontos += ponto;
    }
    final dadosAtualizados = {
      ...widget.dadosUsuario,
      ...respostas,
      'questionario_empresa': respostas,
      'pontos': pontos,
    };

    context.push('/register/cliente/planos', extra: dadosAtualizados);
  }

  @override
  Widget build(BuildContext context) {
    final passoAtual = _passos[_etapaAtual];
    final progresso = (_etapaAtual + 1) / _passos.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Image.asset(
                'assets/images/logo_diavicon.png',
                height: 150,
                fit: BoxFit.contain,
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progresso,
                  minHeight: 9,
                  backgroundColor: Colors.grey.shade500,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Container(
                  key: ValueKey('cabecalho-${passoAtual.id}'),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        passoAtual.pergunta,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    key: ValueKey('opcoes-${passoAtual.id}'),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: ListView.builder(
                      itemCount: passoAtual.opcoes.length,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (context, index) {
                        final opcao = passoAtual.opcoes[index];
                        final selecionados = _selecionadosDoPasso(
                          passoAtual.id,
                        );
                        final estaSelecionado = selecionados.contains(opcao);
                        final isSingleChoice =
                            passoAtual.multiplaEscolha == false;

                        return GestureDetector(
                          onTap: () => setState(() {
                            if (isSingleChoice) {
                              if (!estaSelecionado) {
                                selecionados
                                  ..clear()
                                  ..add(opcao);
                              }
                              return;
                            }

                            if (estaSelecionado) {
                              selecionados.remove(opcao);
                            } else {
                              selecionados.add(opcao);
                            }
                          }),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: estaSelecionado
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: estaSelecionado
                                    ? AppColors.primary
                                    : AppColors.inputBorder,
                                width: estaSelecionado ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                isSingleChoice
                                    ? AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.transparent,
                                          border: Border.all(
                                            color: estaSelecionado
                                                ? AppColors.primary
                                                : AppColors.greyLight,
                                          ),
                                        ),
                                        child: Center(
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            width: estaSelecionado ? 10 : 0,
                                            height: estaSelecionado ? 10 : 0,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      )
                                    : AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: estaSelecionado
                                              ? AppColors.primary
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: estaSelecionado
                                                ? AppColors.primary
                                                : AppColors.greyLight,
                                          ),
                                        ),
                                        child: estaSelecionado
                                            ? const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 14,
                                              )
                                            : null,
                                      ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    opcao,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: estaSelecionado
                                          ? Colors.black
                                          : AppColors.greyMediumDark,
                                      fontWeight: estaSelecionado
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(
                    onPressed: _voltar,
                    child: const Text(
                      '<   Voltar',
                      style: TextStyle(color: AppColors.primary, fontSize: 16),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _avancar,
                      child: const Text(
                        'Avançar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionarioPasso {
  final String id;
  final String pergunta;
  final String chaveMapa;
  final List<String> opcoes;
  final bool multiplaEscolha;
  final List<int> ponto;

  const _QuestionarioPasso({
    required this.id,
    required this.pergunta,
    required this.chaveMapa,
    required this.opcoes,
    this.multiplaEscolha = false,
    this.ponto = const [],
  });
}
