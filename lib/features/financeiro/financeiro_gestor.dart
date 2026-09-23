import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/providers/auth_provider.dart';
import 'financeiro_empresa_screen.dart' show abrirAnexoFinanceiro;
import 'financeiro_repository.dart';
import 'financeiro_widgets.dart';

/// Meu Plano › Financeiro: contrato e cobranças da própria empresa, com
/// boleto e nota fiscal para baixar. Só para o Gestor (is_admin_empresa); o
/// servidor aplica a mesma regra. Para os demais, não aparece nada.
class FinanceiroDoGestor extends ConsumerStatefulWidget {
  const FinanceiroDoGestor({super.key});

  @override
  ConsumerState<FinanceiroDoGestor> createState() => _FinanceiroDoGestorState();
}

class _FinanceiroDoGestorState extends ConsumerState<FinanceiroDoGestor> {
  static const _limiteInicial = 6;
  bool _verTodas = false;

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(currentUserProvider);
    final empresaId = u?.empresaId;
    if (u == null || u.ativo != true || u.isAdminEmpresa != true || empresaId == null) {
      return const SizedBox.shrink();
    }

    final contratoAsync = ref.watch(contratoAtivoProvider(empresaId));
    final cobrancasAsync = ref.watch(cobrancasEmpresaProvider(empresaId));

    // Servidor sem a atualização, ou nada lançado ainda: a seção fica
    // escondida em vez de mostrar erro ao cliente.
    if (contratoAsync.hasError || cobrancasAsync.hasError) return const SizedBox.shrink();
    final contrato = contratoAsync.value;
    final cobrancas = cobrancasAsync.value;
    if (contrato == null && (cobrancas == null || cobrancas.isEmpty)) return const SizedBox.shrink();

    final lista = cobrancas ?? const <CobrancaEmpresa>[];
    final atrasadas = lista.where((c) => c.status == StatusCobranca.atrasado).toList();
    final abertas = lista.where((c) => c.emAberto).toList();
    final visiveis = _verTodas ? lista : lista.take(_limiteInicial).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: CartaoFinanceiro(
        titulo: 'Financeiro',
        child: LayoutBuilder(builder: (context, c) {
          final largo = c.maxWidth >= 700;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (contrato != null)
                Text(
                  'Contrato: ${contrato.planoNome ?? 'plano'} · ${formatarReais(contrato.valorMensal)}/mês · vencimento todo dia ${contrato.diaVencimento}',
                  style: const TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF2E3033), fontWeight: FontWeight.w600),
                ),
              if (atrasadas.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: corStatusCobranca(StatusCobranca.atrasado)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          atrasadas.length == 1
                              ? 'Há 1 cobrança em atraso (${formatarReais(atrasadas.first.valor)}). Se já pagou, desconsidere: a baixa pode levar alguns dias.'
                              : 'Há ${atrasadas.length} cobranças em atraso (${formatarReais(atrasadas.fold(0, (s, c) => s + c.valor))}).',
                          style: TextStyle(fontSize: 13, height: 1.4, color: corStatusCobranca(StatusCobranca.atrasado), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (abertas.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Em aberto: ${formatarReais(abertas.fold(0, (s, c) => s + c.valor))}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B6D70)),
                ),
              ],
              if (cobrancasAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              for (final cob in visiveis)
                LinhaCobranca(
                  cobranca: cob,
                  largo: largo,
                  aoAbrirAnexo: (tipo) => abrirAnexoFinanceiro(context, ref, cob, tipo),
                ),
              if (lista.length > _limiteInicial)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _verTodas = !_verTodas),
                    child: Text(_verTodas ? 'Mostrar menos' : 'Ver todas (${lista.length})'),
                  ),
                ),
              const SizedBox(height: 6),
              const Text(
                'Dúvidas sobre cobrança ou nota fiscal: fale com o time da DIAVICON.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B6D70)),
              ),
            ],
          );
        }),
      ),
    );
  }
}
