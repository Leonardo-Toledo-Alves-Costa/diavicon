import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/diavicon_alerts.dart';
import '../acesso_plano.dart';
import '../model/planos_model.dart';
import '../planos_mensagens.dart';
import '../providers/armazenamento_provider.dart';
import '../providers/empresa_plano_atual_provider.dart';
import '../providers/planos_provider.dart';
import '../../financeiro/financeiro_gestor.dart';

/// Plano pedido e ainda não ativado pela equipe. Erro (ex.: tabela ainda não
/// criada no Supabase) conta como "nenhum pedido".
final planoSolicitadoProvider = FutureProvider.autoDispose<String?>((ref) async {
  try {
    return await ref.watch(planosRepositoryProvider).planoSolicitadoPendente();
  } catch (_) {
    return null;
  }
});

/// Para onde vão os pedidos de troca de plano. E-mail, e não WhatsApp,
/// porque deixa rastro para os dois lados.
const String kEmailComercial = 'contato@diavicon.com';

class MeuPlanoScreen extends ConsumerWidget {
  const MeuPlanoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planoAsync = ref.watch(empresaPlanoAtualProvider);
    final usoAsync = ref.watch(armazenamentoUsoProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const CustomAppBar(title: 'Meu Plano', showBackButton: true, showMenuButton: false),
      body: planoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Erro ao carregar plano: $err')),
        data: (plano) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCardPlano(plano),
                    const SizedBox(height: 12),
                    // O aviso ficava no fim da página, onde a barra do
                    // sistema tapava metade dele — e é justamente a
                    // explicação de por que não dá para trocar de plano
                    // sozinho.
                    _buildAvisoVendas(),
                    const SizedBox(height: 24),
                    _titulo('O que o seu plano inclui'),
                    const SizedBox(height: 12),
                    _ListaRecursos(plano: plano),
                    const SizedBox(height: 24),
                    _titulo('Armazenamento'),
                    const SizedBox(height: 4),
                    Text(
                      'Fotos e relatórios pelo tamanho real dos arquivos. Dados cadastrados são estimados. Quando o limite é atingido, novas criações ficam bloqueadas até liberar espaço ou aumentar o plano.',
                      style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyMedium),
                    ),
                    const SizedBox(height: 16),
                    usoAsync.when(
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.primary))),
                      error: (err, _) => Text('Erro ao calcular armazenamento: $err', style: const TextStyle(color: AppColors.error)),
                      data: (uso) => _buildBarrasArmazenamento(uso),
                    ),
                    // Só o Gestor vê (contrato, boletos e notas fiscais).
                    const FinanceiroDoGestor(),
                    const SizedBox(height: 24),
                    _titulo('Outros planos'),
                    const SizedBox(height: 4),
                    Text(
                      'O pedido vai para a equipe Diavicon, que confirma com você e ativa o novo plano.',
                      style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyMedium),
                    ),
                    const SizedBox(height: 12),
                    _OutrosPlanos(planoAtualId: plano.id),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _titulo(String texto) =>
      Text(texto, style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark));

  Widget _buildAvisoVendas() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              kMensagemContatoVendas,
              style: GoogleFonts.lato(fontSize: 12, color: Colors.blue.shade900, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardPlano(PlanosModel plano) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plano.nome, style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          if (plano.descricao.isNotEmpty)
            Text(plano.descricao, style: GoogleFonts.lato(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
          const SizedBox(height: 16),
          Text(
            plano.valor > 0 ? '${_formatarValor(plano.valor)} / mês' : 'Sem cobrança',
            style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildBarrasArmazenamento(ArmazenamentoUso uso) {
    // Uma moldura só para o bloco, em vez de quatro cartões soltos com
    // aparências diferentes.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _barra('Total', uso.totalMb, uso.limiteMb.toDouble(), destaque: true),
          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1)),
          _barra('Dados', uso.dadosMb, uso.limiteMb.toDouble()),
          const SizedBox(height: 14),
          _barra('Fotos', uso.fotosMb, uso.limiteMb.toDouble()),
          const SizedBox(height: 14),
          _barra('Relatórios', uso.relatoriosMb, uso.limiteMb.toDouble()),
        ],
      ),
    );
  }

  /// Cor da barra pelo quanto já foi usado.
  ///
  /// Antes a barra do total nascia laranja, dentro de um cartão laranja
  /// claro, com pouquíssimo uso — dava a impressão de que o limite estava
  /// perto. Agora a cor só muda quando há de fato algo a observar.
  static Color _corDoUso(double percentual) {
    if (percentual >= 0.9) return AppColors.error;
    if (percentual >= 0.75) return const Color(0xFFE8A33D);
    return const Color(0xFF2E9E62);
  }

  Widget _barra(String label, double usadoMb, double limiteMb, {bool destaque = false}) {
    final percentual = limiteMb <= 0 ? 0.0 : (usadoMb / limiteMb).clamp(0.0, 1.0);
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: destaque ? 15 : 13)),
              Text(
                '${usadoMb.toStringAsFixed(1)} MB (${(percentual * 100).toStringAsFixed(0)}%)',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: destaque ? 15 : 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentual,
              backgroundColor: const Color(0xFFE0E0E0),
              color: _corDoUso(percentual),
              minHeight: destaque ? 10 : 8,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatarValor(double valor) => 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

class _ListaRecursos extends StatelessWidget {
  final PlanosModel plano;
  final bool compacto;

  const _ListaRecursos({required this.plano, this.compacto = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: compacto ? 4 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (final r in plano.recursos)
            Padding(
              padding: EdgeInsets.symmetric(vertical: compacto ? 3 : 6),
              child: Row(
                children: [
                  Icon(
                    r.incluso ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                    size: 18,
                    color: r.incluso ? AppColors.primary : Colors.grey.shade400,
                    semanticLabel: r.incluso ? 'Incluso' : 'Não incluso',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.texto,
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: r.incluso ? AppColors.textDark : Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _OutrosPlanos extends ConsumerStatefulWidget {
  final String planoAtualId;

  const _OutrosPlanos({required this.planoAtualId});

  @override
  ConsumerState<_OutrosPlanos> createState() => _OutrosPlanosState();
}

class _OutrosPlanosState extends ConsumerState<_OutrosPlanos> {
  String? _enviando;
  String? _aberto;

  /// Pergunta antes de pedir a troca, e o pedido sai por e-mail.
  ///
  /// A troca de plano não acontece dentro do app: quem ativa é a equipe
  /// Diavicon. Antes o botão tentava gravar o pedido direto e, quando isso
  /// falhava, a pessoa só via uma mensagem de erro, sem nenhum caminho para
  /// seguir. Agora a janela explica o que vai acontecer e o botão principal
  /// abre o e-mail já escrito — que fica registrado para os dois lados.
  Future<void> _solicitar(PlanosModel plano) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Solicitar o plano ${plano.nome}', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'A troca de plano é feita pela equipe Diavicon. Vamos abrir um e-mail '
          'para $kEmailComercial já preenchido com o plano escolhido — é só enviar.\n\n'
          'A equipe confirma com você e ativa o novo plano.',
          style: GoogleFonts.lato(fontSize: 13.5, height: 1.45),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Entendi', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.mail_outline, size: 18),
              label: const Text('Solicitar por e-mail', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    setState(() => _enviando = plano.id);
    try {
      // O registro no banco é bem-vindo, mas não é o canal do pedido: se a
      // gravação falhar, o e-mail resolve do mesmo jeito e a pessoa não
      // precisa saber de nada disso.
      try {
        await ref.read(planosRepositoryProvider).solicitarPlano(plano.id);
        ref.invalidate(planoSolicitadoProvider);
      } catch (_) {}

      final abriu = await _abrirEmailDePedido(plano);
      if (!mounted) return;
      if (abriu) {
        DiaviconAlerts.show(
          context,
          'E-mail aberto',
          'Confira a mensagem e envie. A equipe Diavicon responde para confirmar e ativar o plano ${plano.nome}.',
        );
      } else {
        DiaviconAlerts.show(
          context,
          'Não consegui abrir o e-mail',
          'Escreva para $kEmailComercial pedindo o plano ${plano.nome}.',
          isErro: true,
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = null);
    }
  }

  /// Abre o programa de e-mail com o pedido já escrito.
  Future<bool> _abrirEmailDePedido(PlanosModel plano) async {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final assunto = 'Solicitação de plano: ${plano.nome}';
    final corpo = [
      'Olá, equipe Diavicon.',
      '',
      'Gostaria de solicitar a mudança para o plano ${plano.nome}'
          '${plano.valor > 0 ? ' (${_formatarValor(plano.valor)} / mês)' : ''}.',
      '',
      if (email.isNotEmpty) 'Minha conta: $email',
      'Aguardo o retorno para confirmar e ativar.',
    ].join('\n');

    final endereco = Uri.parse(
      'mailto:$kEmailComercial'
      '?subject=${Uri.encodeComponent(assunto)}'
      '&body=${Uri.encodeComponent(corpo)}',
    );

    try {
      return await launchUrl(endereco, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final planosAsync = ref.watch(planosListProvider);
    final pendente = ref.watch(planoSolicitadoProvider).value;

    return planosAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.primary))),
      error: (_, _) => Text('Não foi possível carregar os planos.', style: GoogleFonts.lato(color: AppColors.error)),
      data: (planos) {
        if (planos.isEmpty) return const SizedBox.shrink();
        // O plano da empresa entra na lista junto com os outros, marcado como
        // atual: sem ele não dava para comparar o que se ganha ao subir.
        return Column(
          children: [
            for (final p in planos)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.id == widget.planoAtualId ? const Color(0xFFFDF4E7) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: p.id == widget.planoAtualId
                        ? AppColors.primary
                        : (pendente == p.id ? AppColors.primary : Colors.grey.shade200),
                    width: p.id == widget.planoAtualId ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(p.nome, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        ),
                        Text(
                          p.valor > 0 ? '${_formatarValor(p.valor)} / mês' : 'Grátis',
                          style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    if (p.id == widget.planoAtualId) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Plano atual da sua empresa',
                            style: GoogleFonts.lato(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (p.descricao.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(p.descricao, style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyMedium)),
                    ],
                    if (_aberto == p.id) ...[
                      const SizedBox(height: 10),
                      _ListaRecursos(plano: p, compacto: true),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _aberto = _aberto == p.id ? null : p.id),
                          child: Text(_aberto == p.id ? 'Esconder detalhes' : 'Ver o que inclui'),
                        ),
                        if (p.id == widget.planoAtualId)
                          const SizedBox.shrink()
                        else if (pendente == p.id)
                          Chip(
                            avatar: const Icon(Icons.schedule_rounded, size: 16, color: AppColors.primary),
                            label: const Text('Pedido enviado'),
                            backgroundColor: const Color(0xFFFFF3E0),
                            side: BorderSide.none,
                          )
                        else
                          FilledButton(
                            onPressed: _enviando != null ? null : () => _solicitar(p),
                            style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                            child: _enviando == p.id
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Solicitar este plano'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
