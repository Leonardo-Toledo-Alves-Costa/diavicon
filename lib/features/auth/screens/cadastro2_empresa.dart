import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Cadastro2Empresa extends StatefulWidget {
  final Map<String, dynamic> dadosUsuario;

  const Cadastro2Empresa({super.key, required this.dadosUsuario});

  @override
  State<Cadastro2Empresa> createState() => _Cadastro2EmpresaState();
}

class _Cadastro2EmpresaState extends State<Cadastro2Empresa> {
  final List<_QuestionarioPasso> _passos = const [
    _QuestionarioPasso(
      id: 'servicos',
      pergunta: 'Quais serviços você realiza?',
      chaveMapa: 'servicos',
      multiplaEscolha: true,
      opcoes: [
        'Execução de intervenções estruturais de reparo ou reforço, bem como manutenção',
        'Ensaios Não Destrutivos (END)',
        'Gerenciamento e monitoramento de estruturas',
        'Elaboração de planos de ensaio',
        'Gerenciamento de outras empresas de ensaios',
        'Consultoria acerca de estruturas',
        'Projeto de intervenções como recuperação e/ou reforço estrutural',
      ],
    ),
    _QuestionarioPasso(
      id: 'ensaios',
      pergunta: 'Você costuma gerenciar e/ou analisar dados de ensaios de outras empresas terceirizadas no seu projeto?',
      chaveMapa: 'tipos_ensaios',
      multiplaEscolha: false,
      opcoes: [
        'Somente gerencio e faço a ponte com o proprietário',
        'Gerencio e analiso para o diagnóstico da estrutura',
        'Apenas utilizo o resultado final e diagnóstico da empresa',
        'Nenhuma das alternativas',
      ],
    ),
    _QuestionarioPasso(
      id: 'gerenciamento_estrutura',
      pergunta: 'Geralmente como sua empresa gerencia/monitora uma estrutura?',
      chaveMapa: 'gerenciamento_estrutura',
      multiplaEscolha: false,
      opcoes: [
        'Gerenciamos intervenções sobre solicitações do proprietário',
        'Temos um acompanhamento periódico para realizar inspeções e ensaios',
        'Analisamos a demanda periódica de necessidade de ensaios e intervenções através de resultados e simulações',
        'Apenas gerenciamos os arquivos e histórico daquela estrutura',
        'Nenhuma das alternativas',
      ],
    ),
    _QuestionarioPasso(
      id: 'intervencoes',
      pergunta: 'Quais tipos de intervenções a sua empresa realiza?',
      chaveMapa: 'intervencoes',
      multiplaEscolha: false,
      opcoes: [
        'Reforço estrutural com base em projeto elaborado',
        'Fazemos elaboração e projeto do reforço e executamos',
        'Fazemos recuperação de alta complexidade',
        'Fazemos recuperações de baixa complexidade',
        'Damos manutenção básica',
      ],
    ),
    _QuestionarioPasso(
      id: 'engenharia_diagnostica',
      pergunta: 'Qual a experiência da sua empresa com a engenharia diagnóstica e de patologias?',
      chaveMapa: 'engenharia_diagnostica',
      multiplaEscolha: false,
      opcoes: [
        'Somos novos no mercado, ainda não realizamos ensaios',
        'Já realizamos alguns ensaios, mas ainda estamos crescendo a empresa',
        'Realizamos diversos ensaios e temos expertise na área',
        'Realizamos ensaio e damos consultoria estrutural',
        'Temos muita expertise e apenas oferecemos consultoria a diversos projetos e estruturas',
        'Não atuamos nessa área',
      ],
    ),
    _QuestionarioPasso(
      id: 'estruturas',
      pergunta: 'Quais tipos de estrutura sua empresa atende?',
      chaveMapa: 'estruturas',
      multiplaEscolha: true,
      opcoes: [
        'Residenciais',
        'Condomínios',
        'Comerciais',
        'Galpões',
        'Industriais',
        'Mineração',
        'Barragens',
        'Portuário',
        'OAEs',
        'Infraestrutura',
        'Saneamento',
        'Rodoviárias',
      ],
    ),
    _QuestionarioPasso(
      id: 'tamanho',
      pergunta: 'Tamanho da sua empresa:',
      chaveMapa: 'tamanho',
      multiplaEscolha: false,
      opcoes: [
        'Micro (02 ou menos colaboradores)',
        'Pequena (de 03 até 05 colaboradores)',
        'Média (de 6 até 10 colaboradores)',
        'Grande (acima de 10 colaboradores)',
      ],
    ),
    _QuestionarioPasso(
      id: 'complexidade',
      pergunta: 'De modo geral, qual a complexidade desses projetos?',
      chaveMapa: 'complexidade',
      multiplaEscolha: false,
      opcoes: [
        'Simples, normalmente uma única estrutura de médio porte',
        'Médio,  até 05 estruturas de médio porte',
        'Médio, mas trabalhamos com estruturas complexas',
        'Grande, uma ou mais grandes estruturas complexas, tendo várias relatórios',
        'Gigantes onde cada projeto contém várias estruturas complexas',
      ],
    ),
    _QuestionarioPasso(
      id: 'projetos',
      pergunta: 'Quantos projetos de diferentes estruturas sua empresa lida mensalmente de modo concomitante?',
      chaveMapa: 'projetos',
      multiplaEscolha: false,
      opcoes: [
        '1 a 5 projetos',
        '5 a 10 projetos',
        '10 a 50 projetos',
        'mais de 50 projetos',
      ],
    ),
    _QuestionarioPasso(
      id: 'relacionamento_relatorios',
      pergunta: 'Como você classificaria a relação da sua empresa para com relatórios a cerca de ensaios e diagnósticos estruturais?',
      chaveMapa: 'relacionamento_relatorios',
      multiplaEscolha: false,
      opcoes: [
        'Tranquila e harmônica, trabalhamos folgados e não atrasamos prazo',
        'Trabalhamos harmonicamente mas entregamos sempre em cima do prazo com risco de atrasar',
        'Trabalhamos apertado, as vezes atrasamos um ou outro relatório',
        'Trabalhamos acima do limite e temos a maioria dos relatórios atrasados',
        'Não trabalhamos com relatórios',
      ],
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
        passo.chaveMapa: _selecionadosPorPasso[passo.id]?.toList() ?? <String>[],
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
    final dadosAtualizados = {
      ...widget.dadosUsuario,
      ...respostas,
      'questionario_empresa': respostas,
    };

    context.go('/empresa/planos', extra: dadosAtualizados);
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
                        final isSingleChoice = passoAtual.multiplaEscolha == false;

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
                                  : AppColors.white,
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
                                        duration:
                                            const Duration(milliseconds: 200),
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
                                        duration:
                                            const Duration(milliseconds: 200),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: estaSelecionado
                                              ? AppColors.primary
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                            color: estaSelecionado
                                                ? AppColors.primary
                                                : AppColors.greyLight,
                                          ),
                                        ),
                                        child: estaSelecionado
                                            ? const Icon(
                                                Icons.check,
                                                color: AppColors.white,
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

  const _QuestionarioPasso({
    required this.id,
    required this.pergunta,
    required this.chaveMapa,
    required this.opcoes,
    this.multiplaEscolha = false,
  });
}
