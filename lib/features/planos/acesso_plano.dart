import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/diavicon_alerts.dart';
import 'model/planos_model.dart';
import 'planos_mensagens.dart';
import 'providers/armazenamento_provider.dart';
import 'providers/empresa_plano_atual_provider.dart';

/// Módulos que dependem do plano da empresa. A regra de cada um vem SEMPRE da
/// tabela `planos` do Supabase (os planos podem mudar a qualquer momento) —
/// aqui só se diz qual coluna libera qual módulo.
///
/// O servidor aplica as mesmas regras (migration
/// `20260919120000_regras_modulos_plano.sql`); a checagem no app serve para
/// explicar o bloqueio antes de a pessoa tentar, não para proteger os dados.
enum ModuloPlano {
  /// Aba "Estruturas" (monitoramento) — coluna `monitor` + `tokens_estrutura`.
  monitor,

  /// Gerar relatórios (ensaios, RDO, central e painel da empresa) — `gerar_relatorio`.
  relatorios,

  /// Telas de RDO e de gastos — `rdo_gastos`.
  rdoGastos,

  /// Dashboards de BI e seus modelos (equação, simulação) — `dashboard`.
  dashboard,

  /// Cadastrar serviços da empresa — `servicos`.
  servicos,

  /// Publicar no feed — `publicar_feed_edu`.
  publicarFeed,

  /// Patrocinar publicações no feed — `tokens_publicidade`.
  patrocinarFeed,

  /// Trabalhar sem internet — `offline`.
  offline,
}

extension ModuloPlanoTexto on ModuloPlano {
  String get nome => switch (this) {
        ModuloPlano.monitor => 'Monitoramento de estruturas',
        ModuloPlano.relatorios => 'Geração de relatórios',
        ModuloPlano.rdoGastos => 'RDO e gastos',
        ModuloPlano.dashboard => 'Dashboard',
        ModuloPlano.servicos => 'Cadastro de serviços',
        ModuloPlano.publicarFeed => 'Publicar no feed',
        ModuloPlano.patrocinarFeed => 'Patrocinar publicações',
        ModuloPlano.offline => 'Uso offline',
      };

  /// Frase do aviso de bloqueio ("Seu plano atual não inclui ...").
  String get _naoInclui => switch (this) {
        ModuloPlano.monitor => 'o monitoramento de estruturas',
        ModuloPlano.relatorios => 'a geração de relatórios',
        ModuloPlano.rdoGastos => 'o RDO e o controle de gastos',
        ModuloPlano.dashboard => 'o dashboard',
        ModuloPlano.servicos => 'o cadastro de serviços',
        ModuloPlano.publicarFeed => 'publicar no feed',
        ModuloPlano.patrocinarFeed => 'patrocinar publicações no feed',
        ModuloPlano.offline => 'o uso sem internet',
      };

  String get mensagemBloqueio => 'Seu plano atual não inclui $_naoInclui. $kMensagemContatoVendas';
}

extension RegrasPlano on PlanosModel {
  /// Se o plano libera o módulo. Tokens nulos contam como zero: na tabela, o
  /// Freemium tem 0 e os pagos ainda estão sem valor — nada é liberado sem um
  /// número definido.
  bool permite(ModuloPlano modulo) => switch (modulo) {
        ModuloPlano.monitor => monitor,
        ModuloPlano.relatorios => gerarRelatorio,
        ModuloPlano.rdoGastos => rdoGastos,
        ModuloPlano.dashboard => dashboard,
        ModuloPlano.servicos => servicos,
        ModuloPlano.publicarFeed => publicarFeedEdu,
        ModuloPlano.patrocinarFeed => (tokensPublicidade ?? 0) > 0,
        ModuloPlano.offline => offline,
      };

  /// Linhas "o que o plano inclui", montadas a partir das colunas da tabela —
  /// usadas na escolha do plano no cadastro e na tela "Meu Plano".
  List<({String texto, bool incluso})> get recursos {
    String armazenamento() {
      if (armazenamentoMb >= 1024) {
        final gb = armazenamentoMb / 1024;
        return '${gb == gb.roundToDouble() ? gb.toStringAsFixed(0) : gb.toStringAsFixed(1)} GB de armazenamento';
      }
      return '$armazenamentoMb MB de armazenamento';
    }

    final tokensEstrutura = this.tokensEstrutura ?? 0;
    final tokensPublicidade = this.tokensPublicidade ?? 0;
    return [
      (texto: qtdUser == 1 ? '1 usuário' : 'Até $qtdUser usuários', incluso: true),
      (texto: armazenamento(), incluso: true),
      (texto: 'Ensaios, coleta e análises', incluso: true),
      (texto: 'Geração de relatórios', incluso: gerarRelatorio),
      (texto: 'RDO e controle de gastos', incluso: rdoGastos),
      (texto: 'Dashboard', incluso: dashboard),
      (
        texto: monitor && tokensEstrutura > 0
            ? 'Monitoramento de até $tokensEstrutura estrutura${tokensEstrutura == 1 ? '' : 's'}'
            : 'Monitoramento de estruturas',
        incluso: monitor,
      ),
      (texto: 'Cadastro de serviços da empresa', incluso: servicos),
      (texto: 'Publicar no feed', incluso: publicarFeedEdu),
      (
        texto: tokensPublicidade > 0 ? '$tokensPublicidade publicações patrocinadas' : 'Publicações patrocinadas',
        incluso: tokensPublicidade > 0,
      ),
      // "Uso offline" fica fora da lista enquanto o app não tiver modo offline
      // — a coluna `offline` já existe, mas prometer isso hoje seria falso.
      (texto: ads ? 'Com anúncios' : 'Sem anúncios', incluso: !ads),
    ];
  }
}

/// Plano já carregado (sem esperar). Enquanto carrega, devolve `null` — quem
/// usa isso para esconder/mostrar algo NÃO deve bloquear enquanto é `null`.
PlanosModel? planoCarregado(WidgetRef ref) => ref.watch(empresaPlanoAtualProvider).value;

/// Confere o módulo antes de abrir uma tela ou executar uma ação. Se o plano
/// não libera, mostra o aviso padrão e devolve `false`.
Future<bool> verificarModuloPlano(BuildContext context, WidgetRef ref, ModuloPlano modulo) async {
  PlanosModel plano;
  try {
    plano = await ref.read(empresaPlanoAtualProvider.future);
  } catch (_) {
    // Sem conseguir ler o plano (ex.: sem internet) não se bloqueia aqui: o
    // servidor recusa a gravação se o plano não permitir.
    return true;
  }
  if (plano.permite(modulo)) return true;
  if (context.mounted) {
    DiaviconAlerts.show(context, 'Recurso do seu plano', modulo.mensagemBloqueio, isAviso: true);
  }
  return false;
}

/// Mensagem do bloqueio por armazenamento. É a mesma que o servidor devolve
/// (migration 20260921100000_cota_armazenamento.sql).
const String kMensagemArmazenamentoCheio =
    'O armazenamento do seu plano está cheio. Apague arquivos que não usa mais ou entre em contato com o time de vendas da Diavicon para aumentar o seu plano.';

/// Confere se ainda há espaço no plano antes de uma criação (projeto,
/// estrutura, elemento, ponto de ensaio, leitura, foto, relatório, RDO,
/// gasto, serviço ou post). Se o armazenamento acabou, mostra o aviso e
/// devolve `false`.
///
/// Sem conseguir calcular (ex.: sem internet), deixa seguir: o servidor
/// recusa a gravação se o espaço tiver acabado.
Future<bool> verificarArmazenamento(BuildContext context, WidgetRef ref, {double tamanhoEstimadoMb = 0}) async {
  bool pode;
  try {
    ref.invalidate(armazenamentoUsoProvider);
    pode = await podeAdicionarArquivo(ref, tamanhoEstimadoMb: tamanhoEstimadoMb);
  } catch (_) {
    return true;
  }
  if (pode) return true;
  if (context.mounted) {
    DiaviconAlerts.show(context, 'Armazenamento cheio', kMensagemArmazenamentoCheio, isAviso: true);
  }
  return false;
}

/// Envolve uma tela inteira de um módulo pago. Cobre quem chega pelo endereço
/// (no navegador dá para digitar a URL) ou por um atalho esquecido.
class GuardaModuloPlano extends ConsumerWidget {
  final ModuloPlano modulo;
  final Widget child;

  const GuardaModuloPlano({super.key, required this.modulo, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planoAsync = ref.watch(empresaPlanoAtualProvider);
    return planoAsync.when(
      // Erro ao ler o plano: deixa passar; o servidor continua aplicando a regra.
      error: (_, _) => child,
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      data: (plano) => plano.permite(modulo) ? child : TelaModuloBloqueado(modulo: modulo),
    );
  }
}

class TelaModuloBloqueado extends StatelessWidget {
  final ModuloPlano modulo;

  const TelaModuloBloqueado({super.key, required this.modulo});

  @override
  Widget build(BuildContext context) {
    final podeVoltar = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: podeVoltar ? AppBar(backgroundColor: AppColors.background, elevation: 0) : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  modulo.nome,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                Text(
                  modulo.mensagemBloqueio,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.greyMedium),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
