import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:diavicon/core/utils/diavicon_modal.dart';
import 'package:diavicon/core/widgets/compact_button.dart';
import 'package:diavicon/core/widgets/custom_text_button.dart';
import 'package:diavicon/features/estrutura/widgets/estrutura_adicionada_body.dart';
import 'package:diavicon/features/estrutura/screens/nova_estrutura_body.dart';
import 'package:diavicon/features/estrutura/widgets/solicitacao_acesso_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/compact_search_bar.dart';
import 'package:diavicon/features/estrutura/widgets/card_estrutura.dart';
import '../providers/estrutura_provider.dart'; 
import '../models/estrutura_model.dart';
import 'package:diavicon/features/estrutura/screens/estrutura_home.dart';

class IncluirEstruturaBody extends ConsumerStatefulWidget {
  final String empresaNome;
  final String clienteNome;
  final String? empresaLogoUrl;
  final String projetoId;

  const IncluirEstruturaBody({
    super.key,
    required this.empresaNome,
    required this.clienteNome,
    this.empresaLogoUrl,
    required this.projetoId,
  });

  @override
  ConsumerState<IncluirEstruturaBody> createState() => _IncluirEstruturaBodyState();
}

class _IncluirEstruturaBodyState extends ConsumerState<IncluirEstruturaBody> {
  final Set<String> _selectedStructures = {};
  String _searchQuery = '';
  bool _isInitialized = false;

  @override
  Widget build(BuildContext context) {
    //verifica se a empresa é tmb cliente
    final bool isGestoraIgualCliente = widget.empresaNome.trim() == widget.clienteNome.trim();

    ref.listen<AsyncValue<List<EstruturaModel>>>(
      projetoEstruturasProvider(widget.projetoId),
      (previous, next) {
        next.whenData((estruturasVinculadas) {
          setState(() {
            _selectedStructures.clear();
            for (var est in estruturasVinculadas) {
              _selectedStructures.add(est.id);
            }
          });
        });
      },
    );

    final estruturasAsync = ref.watch(minhasEstruturasProvider(widget.projetoId));
    final vinculadasAsync = ref.watch(projetoEstruturasProvider(widget.projetoId));

    if (!_isInitialized) {
      vinculadasAsync.whenData((estruturasVinculadas) {
        for (var est in estruturasVinculadas) {
          _selectedStructures.add(est.id);
        }
        _isInitialized = true;
      });
    }

    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: estruturasAsync.when(
        loading: () => const SizedBox(height: 400, child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
        error: (err, stack) => Center(child: Text('Erro ao carregar: $err')),
        data: (minhasEstruturas) {
          
          final estruturasFiltradas = minhasEstruturas.where((est) {
            if (_searchQuery.isEmpty) return true;
            final nomeEstrutura = (est.nome ?? '').toLowerCase();
            final tituloEstrutura = (est.tipoId ?? '').toLowerCase();
            final busca = _searchQuery.toLowerCase();
            return nomeEstrutura.contains(busca) || tituloEstrutura.contains(busca);
          }).toList();

          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.68, 
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabeçalho dinâmico
                // Cabeçalho dinâmico
                Row(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle, 
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]
                      ),
                      child: ClipOval(
                        child: widget.empresaLogoUrl != null && widget.empresaLogoUrl!.isNotEmpty
                            ? ImagemStorage.network(
                                widget.empresaLogoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Image.asset(
                                  'assets/images/logo_diavicon.png',
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Image.asset(
                                'assets/images/logo_diavicon.png',
                                fit: BoxFit.contain,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.empresaNome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          Text(widget.clienteNome, style: const TextStyle(fontSize: 14, color: AppColors.hintText)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (!isGestoraIgualCliente) ...[
                  const Center(child: Text('Não viu a Estrutura? Solicite o acesso ao proprietário', style: TextStyle(fontSize: 12, color: AppColors.hintText))),
                  const SizedBox(height: 8),
                ],

                CompactSearchBar(
                  hintText: 'Conjunto estrutural ou estrutura',
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: estruturasFiltradas.isEmpty
                      ? const Center(child: Text('Nenhuma estrutura encontrada.', style: TextStyle(color: AppColors.hintText)))
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: estruturasFiltradas.length,
                          itemBuilder: (context, index) {
                            final est = estruturasFiltradas[index];
                            return CardEstrutura(
                            title: est.nome ?? 'Sem nome',
                            type: '${est.tipologiaNome ?? 'Sem tipologia'} - ${est.tipoNome ?? 'Sem tipo'}',
                            details: '${est.idadeCalculada} Anos   CAA ${est.caa ?? '-'}',
                            group: est.conjuntoNome ?? 'Sem conjunto vinculado',
                            imageUrl: est.imageUrl ?? '',
                            isSelected: _selectedStructures.contains(est.id),
                            onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EstruturaHomeScreen(
                                      estrutura: est,
                                      projetoId: widget.projetoId,
                                    ),
                                  ),
                                );
                              },
                            onChanged: (val) async {
                              setState(() {
                                if (val == true) {
                                  _selectedStructures.add(est.id);
                                } else {
                                  _selectedStructures.remove(est.id);
                                }
                              });
                                try {
                                  if (val == true) {
                                    await ref.read(estruturaRepositoryProvider).vincularEstrutura(est.id, widget.projetoId);
                                    if (context.mounted) {
                                      showDiaviconModal(
                                        context: context,
                                        title: '',
                                        alignment: Alignment.center,
                                        margin: const EdgeInsets.symmetric(horizontal: 40),
                                        isScrollable: false,
                                        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                                        body: Transform.translate(offset: const Offset(0, -35), child: const EstruturaAdicionadaBody()),
                                      );
                                    }
                                  } else {
                                    await ref.read(estruturaRepositoryProvider).desvincularEstrutura(est.id, widget.projetoId);
                                  }
                                  ref.invalidate(projetoEstruturasProvider(widget.projetoId));
                                } catch (e) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedStructures.remove(est.id);
                                    } else {
                                      _selectedStructures.add(est.id);
                                    }
                                  });
                                }
                              },
                            );
                          },
                        ),
                ),

                const SizedBox(height: 24),

                // Linha dos botões
                Row(
                  children: [
                    if (!isGestoraIgualCliente) ...[
                      Expanded(
                        child: CustomTextbutton(
                          text: 'Solicitar acesso',
                          onPressed: () {
                            showDiaviconModal(
                              context: context,
                              title: 'Solicitação de acesso à\nestruturas',
                              centerTitle: true,
                              alignment: Alignment.center,
                              margin: const EdgeInsets.symmetric(horizontal: 24),
                              body: const SolicitacaoAcessoBody(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    
                    // botão de criar Nova
                    Expanded(
                      child: CompactButton(
                        text: 'Nova',
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => NovaEstruturaScreen(projetoId: widget.projetoId),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                var tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero).chain(CurveTween(curve: Curves.easeInOutCubic));
                                return SlideTransition(position: animation.drive(tween), child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 750),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
              ],
            ),
          );
        },
      ),
    );
  }
}