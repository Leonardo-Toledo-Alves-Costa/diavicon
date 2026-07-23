import 'package:diavicon/features/equipe/providers/equipe_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart'; 
import '../../../core/widgets/diavicon_alerts.dart';
import '../providers/empresas_projeto_provider.dart';
import '../widgets/modal_incluir_empresa.dart';

class ProjectCompaniesScreen extends ConsumerWidget {
  final String projetoId;

  const ProjectCompaniesScreen({super.key, required this.projetoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gestaoAsync = ref.watch(gestaoProjetoProvider(projetoId));
    final empresasConvidadasAsync = ref.watch(empresasVinculadasProjetoProvider(projetoId));
    final minhaEmpresaAsync = ref.watch(minhaEmpresaProvider);
    
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar( 
        title: 'Empresas',
        showBackButton: true,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Projeto',
              style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
            ),
            Text(
              'Empresas',
              style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
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

              // 1. Adiciona a Gestora
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
                  'total_colaboradores': 0,
                });
              }

              //  Adiciona as Convidadas
              listaFinalExibicao.addAll(listaConvidadas);

              // Identifica e Insere "Minha Empresa"
              final minhaEmpresa = minhaEmpresaAsync.value;
              if (minhaEmpresa != null) {
                bool jaExiste = false;
                
                // Se ela já estiver na lista (como gestora ou convidada), marca a flag nela
                for (var emp in listaFinalExibicao) {
                  if (emp['id'] == minhaEmpresa['id']) {
                    emp['is_minha_empresa'] = true;
                    jaExiste = true;
                  }
                }
                
                // Se não estava no projeto, insere
                if (!jaExiste) {
                  final endereco = minhaEmpresa['enderecos'];
                  listaFinalExibicao.add({
                    'id': minhaEmpresa['id'],
                    'nome': minhaEmpresa['nome'] ?? 'Minha Empresa',
                    'foto_url': minhaEmpresa['foto_url'] ?? '',
                    'cidade': endereco != null ? endereco['cidade'] : 'Belo Horizonte',
                    'uf': endereco != null ? endereco['estado'] : 'MG',
                    'status_vinculo': 'aceito',
                    'is_gestora': false,
                    'is_minha_empresa': true, 
                    'total_colaboradores': 0, 
                  });
                }
              }

              // Ordena para a sua empresa ficar SEMPRE em primeiro lugar
              listaFinalExibicao.sort((a, b) {
                if (a['is_minha_empresa'] == true && b['is_minha_empresa'] != true) return -1;
                if (b['is_minha_empresa'] == true && a['is_minha_empresa'] != true) return 1;
                return 0;
              });

              return ListView(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 16 + bottomPadding), // Padding ajustado
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Empresas no projeto',
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF3E3E3D),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary, 
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
                        child: Text(
                          'Incluir',
                          style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
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
                    ...listaFinalExibicao.asMap().entries.map((entry) {
                      final index = entry.key;
                      final emp = entry.value;
                      final isMinhaEmpresa = emp['is_minha_empresa'] == true;
                      
                      Widget card = _buildEmpresaCard(context, ref, emp);

                      //  Se for a sua empresa e existirem outras na lista, coloca a linha de separação
                      if (isMinhaEmpresa && listaFinalExibicao.length > 1) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            card,
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1.5)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Text(
                                      'Outras Empresas', 
                                      style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyMedium, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1.5)),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                      
                      return card;
                    }),
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

    // Regras de cor das Badges
    if (emp['is_gestora'] == true) {
      labelStatus = emp['is_minha_empresa'] == true ? 'Sua Empresa (Gestora)' : 'Gestora';
      corFundoBadge = const Color(0xFFE2F7E6);
      corTextoBadge = const Color(0xFF31A04C);
    } else if (emp['is_minha_empresa'] == true) {
      labelStatus = 'Sua Empresa';
      corFundoBadge = AppColors.primary.withOpacity(0.15);
      corTextoBadge = AppColors.primary;
    } else if (emp['status_vinculo'] == 'pendente') {
      labelStatus = 'Convidada';
      corFundoBadge = AppColors.primary.withOpacity(0.15); 
      corTextoBadge = AppColors.primary; 
    } else if (emp['status_vinculo'] == 'recusado' || emp['status_vinculo'] == 'removida') {
      labelStatus = 'Removida';
      corFundoBadge = const Color(0xFFFFE5E5); 
      corTextoBadge = AppColors.error; 
    }

    final bool temFoto = emp['foto_url'] != null && emp['foto_url'].toString().startsWith('http');
    
    final int qtdColab = emp['total_colaboradores'] ?? 0;
    final String qtdFormatada = qtdColab.toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16), 
        onTap: () {
          if (emp['is_gestora']) {
            DiaviconAlerts.show(context, 'Ação Bloqueada', 'A empresa gestora não pode ser alterada aqui.', isAviso: true);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: emp['is_minha_empresa'] == true ? Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5) : null, 
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200, width: 1.5),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.transparent, 
                  backgroundImage: temFoto ? NetworkImage(emp['foto_url']) : null,
                  child: !temFoto ? const Icon(Icons.business, color: AppColors.greyMedium) : null,
                ),
              ),
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp['nome'],
                      style: GoogleFonts.lato(
                        fontWeight: FontWeight.w800, 
                        fontSize: 16, 
                        color: const Color(0xFF3E3E3D),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${emp['cidade']} - ${emp['uf']}',
                      style: GoogleFonts.lato(color: AppColors.greyMedium, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$qtdFormatada Colaboradores',
                      style: GoogleFonts.lato(color: AppColors.greyMedium, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: corFundoBadge,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  labelStatus,
                  style: GoogleFonts.lato(color: corTextoBadge, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}