import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../model/planos_model.dart';
import '../planos_mensagens.dart';
import '../providers/armazenamento_provider.dart';
import '../providers/empresa_plano_atual_provider.dart';

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
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardPlano(plano),
                const SizedBox(height: 24),
                Text('Armazenamento', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 4),
                Text(
                  'Estimativa com base na quantidade de dados, fotos e relatórios cadastrados.',
                  style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyMedium),
                ),
                const SizedBox(height: 16),
                usoAsync.when(
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.primary))),
                  error: (err, _) => Text('Erro ao calcular armazenamento: $err', style: const TextStyle(color: AppColors.error)),
                  data: (uso) => _buildBarrasArmazenamento(uso),
                ),
                const SizedBox(height: 24),
                _buildAvisoVendas(),
              ],
            ),
          );
        },
      ),
    );
  }

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
            plano.valor > 0 ? 'R\$ ${plano.valor.toStringAsFixed(2)} / ${plano.vigenciaDias} dias' : 'Sem cobrança',
            style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text('Até ${plano.qtdUser} usuário(s)', style: GoogleFonts.lato(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
        ],
      ),
    );
  }

  Widget _buildBarrasArmazenamento(ArmazenamentoUso uso) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _barra('Total', uso.totalMb, uso.limiteMb.toDouble(), destaque: true),
        const SizedBox(height: 16),
        _barra('Dados', uso.dadosMb, uso.limiteMb.toDouble()),
        const SizedBox(height: 12),
        _barra('Fotos', uso.fotosMb, uso.limiteMb.toDouble()),
        const SizedBox(height: 12),
        _barra('Relatórios', uso.relatoriosMb, uso.limiteMb.toDouble()),
      ],
    );
  }

  Widget _barra(String label, double usadoMb, double limiteMb, {bool destaque = false}) {
    final percentual = limiteMb <= 0 ? 0.0 : (usadoMb / limiteMb).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: destaque ? const Color(0xFFFFF3E0) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: destaque ? null : Border.all(color: Colors.grey.shade200),
      ),
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
              color: percentual >= 1.0 ? AppColors.error : AppColors.primary,
              minHeight: destaque ? 10 : 8,
            ),
          ),
        ],
      ),
    );
  }
}
