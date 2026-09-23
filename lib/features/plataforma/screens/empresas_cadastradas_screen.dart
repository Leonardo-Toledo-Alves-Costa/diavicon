import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/diavicon_alerts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../repositories/empresas_plataforma_repository.dart';
import '../widgets/confirmar_exclusao_empresa.dart';
import '../../financeiro/financeiro_empresa_screen.dart';
import '../../financeiro/financeiro_repository.dart';

final empresasPlataformaRepositoryProvider = Provider((ref) => EmpresasPlataformaRepository());

final empresasCadastradasProvider = FutureProvider.autoDispose<List<EmpresaResumo>>(
  (ref) => ref.watch(empresasPlataformaRepositoryProvider).listarEmpresas(),
  // Sem nova tentativa automática: um erro (sem permissão, função fora do
  // ar) deixava a tela girando para sempre em vez de mostrar a mensagem.
  retry: (_, _) => null,
);

/// Só o administrador principal (is_admin_empresa) da DIAVICON. O servidor
/// confere de novo em cada chamada.
final ehAdminDiaviconProvider = Provider<bool>((ref) {
  final u = ref.watch(currentUserProvider);
  return u != null && u.ativo == true && u.isAdminEmpresa == true && u.empresaId == DIAVICON_EMPRESA_ID;
});

enum _Ordem { recentes, nome, pontos, usuarios }

extension on _Ordem {
  String get rotulo => switch (this) {
        _Ordem.recentes => 'Mais recentes',
        _Ordem.nome => 'Nome (A–Z)',
        _Ordem.pontos => 'Mais pontos de ensaio',
        _Ordem.usuarios => 'Mais usuários',
      };
}

/// Controle de empresas cadastradas — painel da DIAVICON.
class EmpresasCadastradasScreen extends ConsumerStatefulWidget {
  const EmpresasCadastradasScreen({super.key});

  @override
  ConsumerState<EmpresasCadastradasScreen> createState() => _EmpresasCadastradasScreenState();
}

class _EmpresasCadastradasScreenState extends ConsumerState<EmpresasCadastradasScreen> {
  final _busca = TextEditingController();
  _Ordem _ordem = _Ordem.recentes;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  List<EmpresaResumo> _filtrar(List<EmpresaResumo> empresas) {
    final termo = _busca.text.trim().toLowerCase();
    final soDigitos = termo.replaceAll(RegExp(r'\D'), '');
    final lista = empresas.where((e) {
      if (termo.isEmpty) return true;
      if (e.nome.toLowerCase().contains(termo)) return true;
      final cnpj = (e.cnpj ?? '').replaceAll(RegExp(r'\D'), '');
      return soDigitos.isNotEmpty && cnpj.contains(soDigitos);
    }).toList();
    final int Function(EmpresaResumo, EmpresaResumo) criterio = switch (_ordem) {
      _Ordem.recentes => (a, b) => (b.criadoEm ?? DateTime(1970)).compareTo(a.criadoEm ?? DateTime(1970)),
      _Ordem.nome => (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
      _Ordem.pontos => (a, b) => b.pontosEnsaio.compareTo(a.pontosEnsaio),
      _Ordem.usuarios => (a, b) => b.usuarios.compareTo(a.usuarios),
    };
    // A DIAVICON sempre no topo; o resto pela ordem escolhida.
    lista.sort((a, b) => a.protegida != b.protegida ? (a.protegida ? -1 : 1) : criterio(a, b));
    return lista;
  }

  Future<void> _excluir(EmpresaResumo empresa) async {
    final apagou = await confirmarExclusaoEmpresa(
      context,
      nomeEmpresa: empresa.nome,
      titulo: 'Excluir ${empresa.nome}?',
      consequencias: [
        'A empresa e ${_plural(empresa.usuarios, 'usuário', 'usuários')}, com as contas de acesso',
        '${_plural(empresa.projetos, 'projeto', 'projetos')} geridos por ela, com estruturas, elementos, ensaios, RDOs, gastos e relatórios',
        '${_plural(empresa.estruturas, 'estrutura', 'estruturas')} sob gestão',
        '${_plural(empresa.pontosEnsaio, 'ponto de ensaio', 'pontos de ensaio')} feitos pela empresa, inclusive em projetos de outras empresas',
        'Fotos, arquivos, publicações no feed e serviços cadastrados',
      ],
      aoConfirmar: (nome) async {
        await ref.read(empresasPlataformaRepositoryProvider).excluirEmpresa(empresaId: empresa.id, confirmacaoNome: nome);
      },
    );
    if (!apagou || !mounted) return;
    ref.invalidate(empresasCadastradasProvider);
    DiaviconAlerts.show(context, 'Empresa excluída', '${empresa.nome} e todos os seus dados foram apagados.');
  }

  @override
  Widget build(BuildContext context) {
    final autorizado = ref.watch(ehAdminDiaviconProvider);
    final empresasAsync = autorizado ? ref.watch(empresasCadastradasProvider) : null;
    // Avisos de cobrança nos cartões. Sem o financeiro no servidor, fica vazio.
    final resumoFinanceiro = autorizado ? (ref.watch(resumoFinanceiroProvider).value ?? const {}) : const <String, ResumoFinanceiroEmpresa>{};

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const CustomAppBar(title: 'Empresas cadastradas', showBackButton: true, showMenuButton: false),
      body: !autorizado
          ? const _Mensagem(icone: Icons.lock_outline_rounded, texto: 'Área restrita à administração da DIAVICON.')
          : empresasAsync!.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => _Mensagem(
                icone: Icons.cloud_off_rounded,
                texto: mensagemErroOperacao(e),
                acao: TextButton.icon(
                  onPressed: () => ref.invalidate(empresasCadastradasProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ),
              data: (empresas) {
                final visiveis = _filtrar(empresas);
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => ref.refresh(empresasCadastradasProvider.future),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final largura = c.maxWidth.clamp(0.0, 1200.0);
                      final colunas = largura >= 1000 ? 3 : (largura >= 640 ? 2 : 1);
                      return ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: ((c.maxWidth - largura) / 2) + 16,
                          vertical: 16,
                        ),
                        children: [
                          _Totais(empresas: empresas),
                          const SizedBox(height: 16),
                          _barraFiltros(colunas > 1),
                          const SizedBox(height: 8),
                          Text(
                            '${visiveis.length} de ${_plural(empresas.length, 'empresa', 'empresas')}',
                            style: const TextStyle(fontSize: 12, color: AppColors.greyMedium),
                          ),
                          const SizedBox(height: 12),
                          if (visiveis.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 40),
                              child: _Mensagem(icone: Icons.search_off_rounded, texto: 'Nenhuma empresa encontrada.'),
                            )
                          else
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final e in visiveis)
                                  SizedBox(
                                    width: (largura - 32 - 12 * (colunas - 1)) / colunas,
                                    child: _CartaoEmpresa(
                                      empresa: e,
                                      resumo: resumoFinanceiro[e.id],
                                      aoExcluir: () => _excluir(e),
                                      aoFinanceiro: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => FinanceiroEmpresaScreen(empresaId: e.id, empresaNome: e.nome, empresaCnpj: e.cnpj),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          const SizedBox(height: 40),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _barraFiltros(bool largo) {
    final busca = TextField(
      controller: _busca,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Buscar por nome ou CNPJ',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _busca.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpar busca',
                icon: const Icon(Icons.close),
                onPressed: () => setState(_busca.clear),
              ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
    final ordem = DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: DropdownButton<_Ordem>(
          value: _ordem,
          isExpanded: !largo,
          icon: const Icon(Icons.sort_rounded),
          items: [for (final o in _Ordem.values) DropdownMenuItem(value: o, child: Text(o.rotulo))],
          onChanged: (o) => setState(() => _ordem = o ?? _ordem),
        ),
      ),
    );
    if (largo) {
      return Row(children: [Expanded(child: busca), const SizedBox(width: 12), ordem]);
    }
    return Column(children: [busca, const SizedBox(height: 8), SizedBox(width: double.infinity, child: ordem)]);
  }
}

String _plural(int n, String singular, String plural) => '$n ${n == 1 ? singular : plural}';

class _Totais extends StatelessWidget {
  final List<EmpresaResumo> empresas;

  const _Totais({required this.empresas});

  @override
  Widget build(BuildContext context) {
    int soma(int Function(EmpresaResumo) f) => empresas.fold(0, (t, e) => t + f(e));
    final itens = [
      (Icons.business_outlined, 'Empresas', empresas.length),
      (Icons.people_outline, 'Usuários', soma((e) => e.usuarios)),
      (Icons.folder_open_outlined, 'Projetos', soma((e) => e.projetos)),
      (Icons.layers_outlined, 'Estruturas', soma((e) => e.estruturas)),
      (Icons.location_on_outlined, 'Pontos de ensaio', soma((e) => e.pontosEnsaio)),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (icone, rotulo, valor) in itens)
          Container(
            constraints: const BoxConstraints(minWidth: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icone, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$valor', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    Text(rotulo, style: const TextStyle(fontSize: 12, color: AppColors.greyMedium)),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CartaoEmpresa extends StatelessWidget {
  final EmpresaResumo empresa;
  final ResumoFinanceiroEmpresa? resumo;
  final VoidCallback aoExcluir;
  final VoidCallback aoFinanceiro;

  const _CartaoEmpresa({required this.empresa, this.resumo, required this.aoExcluir, required this.aoFinanceiro});

  String _data(DateTime? d) {
    if (d == null) return '—';
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    final e = empresa;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: e.protegida ? AppColors.primary : Colors.grey.shade200, width: e.protegida ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFFFF3E0),
                foregroundImage: (e.fotoUrl ?? '').isNotEmpty ? StorageNetworkImage(e.fotoUrl!) : null,
                child: Text(
                  e.nome.characters.first.toUpperCase(),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    Text(
                      e.cnpj?.isNotEmpty == true ? e.cnpj! : 'CNPJ não informado',
                      style: const TextStyle(fontSize: 12, color: AppColors.greyMedium),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Etiqueta(texto: e.plano ?? 'Sem plano', destaque: true),
              _Etiqueta(texto: 'Desde ${_data(e.criadoEm)}'),
              if (e.protegida) const _Etiqueta(texto: 'Protegida', icone: Icons.shield_outlined, destaque: true),
              if ((resumo?.atrasadas ?? 0) > 0)
                _Etiqueta(
                  texto: resumo!.atrasadas == 1 ? '1 cobrança atrasada' : '${resumo!.atrasadas} cobranças atrasadas',
                  icone: Icons.warning_amber_rounded,
                  alerta: true,
                )
              else if ((resumo?.emAberto ?? 0) > 0)
                _Etiqueta(texto: '${formatarReais(resumo!.valorEmAberto)} em aberto', icone: Icons.schedule_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Metrica(valor: e.usuarios, rotulo: 'Usuários'),
              _Metrica(valor: e.projetos, rotulo: 'Projetos'),
              _Metrica(valor: e.estruturas, rotulo: 'Estruturas'),
              _Metrica(valor: e.pontosEnsaio, rotulo: 'Pontos'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (!e.protegida)
                TextButton.icon(
                  onPressed: aoFinanceiro,
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFA85A00)),
                  icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                  label: const Text('Financeiro'),
                ),
              const Spacer(),
              e.protegida
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('A DIAVICON não pode ser excluída', style: TextStyle(fontSize: 12, color: AppColors.greyMedium)),
                  )
                : TextButton.icon(
                    onPressed: aoExcluir,
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Excluir empresa'),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final IconData? icone;
  final bool destaque;
  final bool alerta;

  const _Etiqueta({required this.texto, this.icone, this.destaque = false, this.alerta = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: alerta ? const Color(0xFFFDECEA) : (destaque ? const Color(0xFFFFF3E0) : const Color(0xFFF1F1F1)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 13, color: alerta ? const Color(0xFFC62828) : const Color(0xFFA85A00)),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: alerta ? const Color(0xFFC62828) : (destaque ? const Color(0xFFA85A00) : Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  final int valor;
  final String rotulo;

  const _Metrica({required this.valor, required this.rotulo});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text('$valor', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            Text(rotulo, style: const TextStyle(fontSize: 11, color: AppColors.greyMedium), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _Mensagem extends StatelessWidget {
  final IconData icone;
  final String texto;
  final Widget? acao;

  const _Mensagem({required this.icone, required this.texto, this.acao});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 44, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
            if (acao != null) ...[const SizedBox(height: 8), acao!],
          ],
        ),
      ),
    );
  }
}
