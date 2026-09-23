import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../gastos/providers/gastos_providers.dart';
import '../../gastos/screens/analise_gastos_screen.dart';
import '../providers/empresa_profile_provider.dart';
import '../../planos/screens/meu_plano_screen.dart';
import 'empresa_informacoes_screen.dart'; // Tela do formulário
import 'painel_servicos_screen.dart';
import 'campos_menu_screen.dart';
import 'colaboradores_empresa.dart';
import 'padroes_empresa_screen.dart';
import 'package:diavicon/features/planos/acesso_plano.dart';
import '../../auth/providers/auth_provider.dart';
import '../../plataforma/screens/empresas_cadastradas_screen.dart';
import '../../plataforma/repositories/empresas_plataforma_repository.dart';
import '../../plataforma/widgets/confirmar_exclusao_empresa.dart';
import '../providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;

class EmpresaPainelScreen extends ConsumerWidget {
  final EmpresaDetalheModel empresa;

  const EmpresaPainelScreen({super.key, required this.empresa});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // O modelo que chega no construtor é um retrato do momento em que a tela
    // abriu. Depois de editar as informações ele fica velho, então o que vale
    // é o provider — que a tela de edição invalida ao salvar.
    final empresa = ref.watch(empresaDetalheProvider(this.empresa.id)).value ?? this.empresa;
    final adminEmpresa = ref.watch(ehAdminEmpresaProvider);
    final usuario = ref.watch(currentUserProvider);
    // Controle de empresas: só no painel da própria DIAVICON e só para o
    // administrador principal dela.
    final mostrarControleEmpresas = empresa.id == DIAVICON_EMPRESA_ID && ref.watch(ehAdminDiaviconProvider);
    // Excluir a empresa: só o administrador principal, no painel da própria
    // empresa. A DIAVICON nunca.
    final podeExcluirEmpresa = usuario != null &&
        usuario.ativo == true &&
        usuario.isAdminEmpresa == true &&
        usuario.empresaId == empresa.id &&
        empresa.id != DIAVICON_EMPRESA_ID;
    final location = (empresa.cidade != null && empresa.estado != null)
        ? '${empresa.cidade}, ${empresa.estado}' : 'Localização indisponível';
    final empresaId = empresa.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const CustomAppBar(
        title: 'Painel',
        showBackButton: true,
        showMenuButton: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Logo Centralizada
            CircleAvatar(
              radius: 46,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 42,
                backgroundImage: empresa.fotoUrl != null ? StorageNetworkImage(empresa.fotoUrl!) : null,
                child: empresa.fotoUrl == null ? const Icon(Icons.business, size: 40) : null,
              ),
            ),
            const SizedBox(height: 16),
            Text(empresa.nome, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (empresa.descricao != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(empresa.descricao!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              ),
            const SizedBox(height: 4),
            Text(empresa.cnpj , style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            Text(location, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            
            const SizedBox(height: 32),

            // Grid de Opções
            // Colunas pela largura: 2 no celular, mais em telas largas (antes
            // eram sempre 2 cartões enormes no computador).
            GridView.extent(
              maxCrossAxisExtent: 240,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _PainelCard(
                  icon: Icons.info_outline,
                  title: 'Informações\nda empresa',
                  onTap: () {
                    // Direciona para o formulário de informações adicionais
                    // Navegação pela raiz: este painel vive dentro do shell
                    // (barra inferior); um push comum ficaria aninhado ali
                    // dentro e a barra não sumiria.
                    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => EmpresaInformacoesScreen(empresa: empresa)));
                  },
                ),
                _PainelCard(
                  icon: Icons.people_outline,
                  title: 'Colaboradores\ncadastrados',
                  //badgeCount: '12', // Substitua pelos dados reais futuramente
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => ColaboradoresEmpresaScreen(empresaId: empresaId)));
                  },
                ),
                _PainelCard(
                  icon: Icons.store_outlined,
                  title: 'Serviços e\nprodutos',
                  //badgeCount: '07',
                  onTap: () {
                      Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => PainelServicosScreen(empresaId: empresa.id,
                                                                                                      empresaNome: empresa.nome,
                                                                                                      )));
                    },
                ),
                const _PainelCard(
                  icon: Icons.build_outlined,
                  title: 'Equipamentos',
                  emBreve: true,
                ),
                _PainelCard(
                  icon: Icons.backup_table,
                  title: 'Campos \npersonalizáveis ',
                  onTap: () {
                      Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => CamposMenuScreen(empresaId: empresa.id,

                                                                                                      )));

                  },
                ),
                const _PainelCard(
                  icon: Icons.business_outlined,
                  title: 'Estruturas sob\ngestão',
                  emBreve: true,
                ),
                _PainelCard(
                  icon: Icons.style_outlined,
                  title: 'Padrões da\nempresa',
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => PadroesEmpresaScreen(empresaId: empresaId)));
                  },
                ),
                // Análise gerencial de gastos: só admin (o RLS também só
                // devolve gastos de terceiros para admin).
                if (adminEmpresa)
                  _PainelCard(
                    icon: Icons.payments_outlined,
                    title: 'Análise de\ngastos',
                    onTap: () {
                      Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => GuardaModuloPlano(modulo: ModuloPlano.rdoGastos, child: AnaliseGastosScreen(empresaId: empresaId, empresaNome: empresa.nome))));
                    },
                  ),
                if (mostrarControleEmpresas)
                  _PainelCard(
                    icon: Icons.domain_verification_outlined,
                    title: 'Empresas\ncadastradas',
                    onTap: () {
                      Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const EmpresasCadastradasScreen()));
                    },
                  ),
                _PainelCard(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Meu Plano',
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const MeuPlanoScreen()));
                  },
                ),
              ],
            ),

            if (podeExcluirEmpresa) ...[
              const SizedBox(height: 32),
              _ZonaExclusao(empresa: empresa),
            ],
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

/// Excluir a conta da empresa: apaga a empresa, o administrador, os
/// colaboradores e todos os dados (edge function `delete_own_company`).
class _ZonaExclusao extends ConsumerWidget {
  final EmpresaDetalheModel empresa;

  const _ZonaExclusao({required this.empresa});

  Future<void> _excluir(BuildContext context, WidgetRef ref) async {
    final apagou = await confirmarExclusaoEmpresa(
      context,
      nomeEmpresa: empresa.nome,
      titulo: 'Excluir a conta da empresa?',
      consequencias: const [
        'A empresa e a sua conta de acesso, com a de todos os colaboradores',
        'Os projetos geridos pela empresa, com estruturas, elementos, ensaios, RDOs, gastos e relatórios',
        'Os pontos de ensaio feitos pela empresa, inclusive em projetos de outras empresas',
        'Fotos, arquivos, publicações no feed e serviços cadastrados',
      ],
      aoConfirmar: (nome) async {
        await EmpresasPlataformaRepository().excluirMinhaEmpresa(confirmacaoNome: nome);
      },
    );
    if (!apagou) return;
    // A conta não existe mais: encerra a sessão e o roteador volta ao login.
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5C2C0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Excluir conta da empresa', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFB3261E))),
          const SizedBox(height: 6),
          Text(
            'Apaga definitivamente a empresa, a sua conta, as dos colaboradores e todos os dados. Não pode ser desfeito.',
            style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey[800]),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _excluir(context, ref),
            icon: const Icon(Icons.delete_forever_outlined, size: 18),
            label: const Text('Excluir conta da empresa'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB3261E),
              side: const BorderSide(color: Color(0xFFB3261E)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PainelCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  /// Área que ainda não tem tela: o cartão fica apagado, sem toque, com o
  /// selo "Em breve" no lugar da contagem.
  final bool emBreve;

  const _PainelCard({
    required this.icon,
    required this.title,
    this.onTap,
    this.emBreve = false,
  });

  @override
  Widget build(BuildContext context) {
    final corTexto = emBreve ? Colors.black38 : const Color(0xFF333333);

    return Opacity(
      opacity: emBreve ? 0.65 : 1,
      child: GestureDetector(
        onTap: emBreve ? null : onTap,
        child: Container(
          decoration: BoxDecoration(
            color: emBreve ? const Color(0xFFF7F6F4) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: emBreve ? Colors.black26 : Colors.black54),
                  if (emBreve)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Em breve',
                        style: TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: corTexto)),
            ],
          ),
        ),
      ),
    );
  }
}