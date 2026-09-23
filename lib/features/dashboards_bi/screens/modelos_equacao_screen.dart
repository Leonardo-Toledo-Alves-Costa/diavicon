import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/diavicon_alerts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../models/campos_bi_catalogo.dart';
import '../models/variavel_bi_model.dart';
import '../repositories/variavel_bi_repository.dart';
import '../widgets/editor_variavel_bi.dart';
import '../widgets/bi_tema.dart';

/// "Padrões da empresa > Modelos de equação" — as variáveis derivadas que a
/// empresa pode usar nos dashboards.
///
/// As variáveis da DIAVICON aparecem como padrão, somente-leitura, e são
/// duplicadas pra empresa quando alguém quer recalibrar os coeficientes —
/// mesmo mecanismo de "Modelos de Dashboard".
class ModelosEquacaoScreen extends ConsumerWidget {
  final String empresaId;
  const ModelosEquacaoScreen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variaveisAsync = ref.watch(variaveisBiProvider(empresaId));

    return Scaffold(
      backgroundColor: kBiFundo,
      appBar: const CustomAppBar(
        title: 'Empresa',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            Text('Padrões da empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Modelos de equação', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _criar(context, ref),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nova equação', style: TextStyle(color: Colors.white)),
      ),
      body: variaveisAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, s) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erro ao carregar as equações:\n$e', textAlign: TextAlign.center),
          ),
        ),
        data: (variaveis) {
          if (variaveis.isEmpty) return _vazio();
          return ListView(
            padding: preenchimentoListaBi(context),
            children: [
              Text(
                'Variáveis calculadas a partir de um ou mais ensaios. Ficam disponíveis nos dashboards '
                'da empresa.',
                style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[600], height: 1.4),
              ),
              const SizedBox(height: 16),
              ...variaveis.map((v) => _CardVariavel(
                    variavel: v,
                    empresaId: empresaId,
                    ehPadraoDiavicon: v.empresaId == DIAVICON_EMPRESA_ID && v.empresaId != empresaId,
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _vazio() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.functions, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'Nenhuma equação cadastrada',
                style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey[700]),
              ),
              const SizedBox(height: 6),
              Text(
                'Crie uma variável derivada combinando resultados de ensaios — por exemplo, estimar a '
                'resistência à compressão a partir da velocidade ultrassônica e do índice esclerométrico.',
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[600], height: 1.4),
              ),
            ],
          ),
        ),
      );

  Future<void> _criar(BuildContext context, WidgetRef ref) async {
    final usuario = ref.read(currentUserProvider);
    final variavel = await abrirEditorVariavelBi(
      context,
      empresaId: empresaId,
      criadoPor: usuario?.id,
    );
    if (variavel == null) return;
    try {
      await ref.read(variavelBiRepositoryProvider).criar(variavel);
      ref.invalidate(variaveisBiProvider(empresaId));
    } catch (e) {
      if (context.mounted) {
        DiaviconAlerts.show(context, 'Erro', 'Não foi possível salvar a equação: $e', isErro: true);
      }
    }
  }
}

class _CardVariavel extends ConsumerWidget {
  const _CardVariavel({required this.variavel, required this.empresaId, required this.ehPadraoDiavicon});

  final VariavelBiModel variavel;
  final String empresaId;
  final bool ehPadraoDiavicon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ensaios = variavel.fontesNecessarias
        .map((chave) => catalogoFontesBi.where((f) => f.chave == chave).firstOrNull?.rotulo ?? chave)
        .join(' + ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _abrir(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBiBorda),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.functions, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            variavel.unidade == null ? variavel.nome : '${variavel.nome} (${variavel.unidade})',
                            style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                          ),
                        ),
                        if (ehPadraoDiavicon) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Padrão DIAVICON',
                                style: TextStyle(fontSize: 9, color: Color(0xFFA85A00), fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            tooltip: 'Duplicar para minha empresa',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.copy_outlined, color: Colors.grey, size: 18),
                            onPressed: () => _duplicar(context, ref),
                          ),
                        ] else
                          IconButton(
                            tooltip: 'Excluir',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18),
                            onPressed: () => _excluir(context, ref),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(variavel.expressao,
                        style: GoogleFonts.robotoMono(fontSize: 11, color: Colors.grey[700])),
                    const SizedBox(height: 4),
                    Text(
                      variavel.ehMultiEnsaio ? 'Multi-ensaio: $ensaios' : 'Ensaio: $ensaios',
                      style: GoogleFonts.lato(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrir(BuildContext context, WidgetRef ref) async {
    final editada = await abrirEditorVariavelBi(
      context,
      empresaId: empresaId,
      existente: variavel,
      somenteLeitura: ehPadraoDiavicon,
    );
    if (editada == null) return;
    try {
      await ref.read(variavelBiRepositoryProvider).atualizar(variavel.id, editada);
      ref.invalidate(variaveisBiProvider(empresaId));
    } catch (e) {
      if (context.mounted) {
        DiaviconAlerts.show(context, 'Erro', 'Não foi possível salvar: $e', isErro: true);
      }
    }
  }

  Future<void> _duplicar(BuildContext context, WidgetRef ref) async {
    final usuario = ref.read(currentUserProvider);
    try {
      await ref.read(variavelBiRepositoryProvider).duplicar(
            variavel,
            empresaId: empresaId,
            criadoPor: usuario?.id,
          );
      ref.invalidate(variaveisBiProvider(empresaId));
    } catch (e) {
      if (context.mounted) {
        DiaviconAlerts.show(context, 'Erro', 'Não foi possível duplicar: $e', isErro: true);
      }
    }
  }

  Future<void> _excluir(BuildContext context, WidgetRef ref) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir equação'),
        content: Text(
          'Excluir "${variavel.nome}"? Os cards de dashboard que usam esta equação deixarão de '
          'calcular o valor.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    try {
      await ref.read(variavelBiRepositoryProvider).excluir(variavel.id);
      ref.invalidate(variaveisBiProvider(empresaId));
    } catch (e) {
      if (context.mounted) {
        DiaviconAlerts.show(context, 'Erro', 'Não foi possível excluir: $e', isErro: true);
      }
    }
  }
}
