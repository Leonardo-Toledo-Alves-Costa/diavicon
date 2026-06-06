import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/diavicon_alerts.dart';
import '../providers/empresas_projeto_provider.dart';
import '../widgets/modal_incluir_empresa.dart';
import '../../equipe/providers/equipe_provider.dart'; 

class ProjectCompaniesScreen extends ConsumerWidget {
  final String projetoId;

  const ProjectCompaniesScreen({super.key, required this.projetoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gestaoAsync = ref.watch(gestaoProjetoProvider(projetoId));
    final empresasConvidadasAsync = ref.watch(empresasVinculadasProjetoProvider(projetoId));
    
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background, // Usando a cor de fundo oficial
      appBar: AppBar(
        title: const Column(
          children: [
            Text(
              'Projeto',
              style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              'Empresas',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary, // 🔥 Oficial!
        elevation: 4,
        shadowColor: Colors.black26,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: AppColors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: AppColors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: gestaoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Erro ao carregar gestão: $err', style: const TextStyle(color: AppColors.error))),
        data: (gestaoData) {
          
          final empresaGestora = gestaoData?['empresas']; 

          return empresasConvidadasAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (err, _) => Center(child: Text('Erro ao carregar convidadas: $err', style: const TextStyle(color: AppColors.error))),
            data: (listaConvidadas) {
              
              List<Map<String, dynamic>> listaFinalExibicao = [];

              if (empresaGestora != null) {
                final endereco = empresaGestora['enderecos'];
                listaFinalExibicao.add({
                  'id': empresaGestora['id'],
                  'nome': empresaGestora['nome'] ?? 'Gestora Não Identificada',
                  'foto_url': empresaGestora['foto_url'] ?? '',
                  'cidade': endereco != null ? endereco['cidade'] : 'Belo Horizonte',
                  'uf': endereco != null ? endereco['estado'] : 'MG',
                  'status_vinculo': 'aceito',
                  'is_gestora': true,
                });
              }

              listaFinalExibicao.addAll(listaConvidadas);

              return ListView(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 16 + bottomPadding),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Empresas no projeto',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary, // 🔥 Oficial!
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          elevation: 2,
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            builder: (context) => ModalIncluirEmpresa(projetoId: projetoId),
                          );
                        },
                        child: const Text(
                          'Incluir',
                          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (listaFinalExibicao.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Text('Nenhuma empresa vinculada.', style: TextStyle(color: AppColors.hintText)),
                      ),
                    )
                  else
                    ...listaFinalExibicao.map((emp) => _buildEmpresaCard(context, ref, emp)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmpresaCard(BuildContext context, WidgetRef ref, Map<String, dynamic> emp) {
    String labelStatus = 'Integrante';
    Color corFundoBadge = const Color(0xFFE2F7E6); 
    Color corTextoBadge = const Color(0xFF31A04C); 

    if (emp['is_gestora'] == true) {
      labelStatus = 'Gestora';
      corFundoBadge = const Color(0xFFE2F7E6);
      corTextoBadge = const Color(0xFF31A04C);
    } else if (emp['status_vinculo'] == 'pendente') {
      labelStatus = 'Convidada';
      corFundoBadge = const Color(0xFFFFF3E0); 
      corTextoBadge = const Color(0xFFE65100); 
    } else if (emp['status_vinculo'] == 'recusado' || emp['status_vinculo'] == 'removida') {
      labelStatus = 'Removida';
      corFundoBadge = const Color(0xFFFFE5E5); 
      corTextoBadge = AppColors.error; 
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          if (emp['is_gestora']) {
            DiaviconAlerts.show(context, 'Ação Bloqueada', 'A empresa gestora não pode ser alterada aqui.', isAviso: true);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.greyVeryLight,
                backgroundImage: emp['foto_url'].toString().startsWith('http')
                    ? NetworkImage(emp['foto_url'])
                    : null,
                child: !emp['foto_url'].toString().startsWith('http')
                    ? const Icon(Icons.business, size: 32, color: AppColors.greyMedium)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp['nome'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${emp['cidade']} - ${emp['uf']}',
                      style: const TextStyle(color: AppColors.greyMediumDark, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Empresa Parceira', 
                      style: TextStyle(color: AppColors.greyMedium, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: corFundoBadge,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  labelStatus,
                  style: TextStyle(color: corTextoBadge, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}