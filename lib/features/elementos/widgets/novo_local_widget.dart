import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/compact_button.dart';
import 'package:diavicon/core/widgets/custom_dropdown_with_add.dart';
import 'package:diavicon/core/widgets/custom_text_field.dart';
import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:diavicon/features/elementos/widgets/nova_opcao_modal.dart';
import 'package:diavicon/features/estrutura/providers/local_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class NovoLocalModal extends ConsumerStatefulWidget {
  final String? estruturaId;
  const NovoLocalModal({super.key, this.estruturaId});

  @override
  ConsumerState<NovoLocalModal> createState() => _NovoLocalModalState();
}

class _NovoLocalModalState extends ConsumerState<NovoLocalModal> {
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();

  String? _tipologiaSelecionada;
  String? _condicaoSelecionada;

  bool _isLoading = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _adicionarTipologia() async {
    final novaOpcao = await showNovaOpcaoModal(
      context,
      titulo: 'Nova Tipologia do Local',
      label: 'Nome da Tipologia',
    );

    if (novaOpcao != null && novaOpcao.trim().isNotEmpty) {
      final opcaoFormatada = novaOpcao.trim();
      final repo = ref.read(localRepositoryProvider);
      final user = ref.read(currentUserProvider);
      final empresaId = user?.empresaId;

      if (empresaId != null) {
        try {
          // Salva no banco de dados novo!
          await repo.criarTipologiaLocal(opcaoFormatada, empresaId);
          setState(() {
            _tipologiaSelecionada = opcaoFormatada;
          });
        } catch (e) {
          if (mounted) {
            DiaviconAlerts.show(
              context,
              'Erro',
              'Erro ao salvar Tipologia',
              isErro: true,
            );
          }
        }
      }
    }
  }

  Future<void> _adicionarCondicao() async {
    final novaOpcao = await showNovaOpcaoModal(
      context,
      titulo: 'Nova Condição de Exposição',
      label: 'Nome da Condição',
    );

    if (novaOpcao != null && novaOpcao.trim().isNotEmpty) {
      final opcaoFormatada = novaOpcao.trim();
      final repo = ref.read(localRepositoryProvider);
      final user = ref.read(currentUserProvider);
      final empresaId = user?.empresaId;

      if (empresaId != null) {
        try {
          // Salva no banco de dados novo!
          await repo.criarCondicaoLocal(opcaoFormatada, empresaId);
          setState(() {
            _condicaoSelecionada = opcaoFormatada;
          });
        } catch (e) {
          if (mounted) {
            DiaviconAlerts.show(
              context,
              'Erro',
              'Erro ao salvar Condição',
              isErro: true,
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Puxa as listas oficiais do banco de dados em tempo real
    final tipologiasAsync = ref.watch(tipologiasLocalProvider);
    final condicoesAsync = ref.watch(condicoesLocalProvider);

    List<String> tipologiaOptions = List<String>.from(
      tipologiasAsync.value ?? [],
    );
    List<String> condicoesOptions = List<String>.from(
      condicoesAsync.value ?? [],
    );

    // Garante que a opção que você acabou de criar esteja na lista para o Dropdown não quebrar
    if (_tipologiaSelecionada != null &&
        !tipologiaOptions.contains(_tipologiaSelecionada!)) {
      tipologiaOptions.add(_tipologiaSelecionada!);
    }
    if (_condicaoSelecionada != null &&
        !condicoesOptions.contains(_condicaoSelecionada!)) {
      condicoesOptions.add(_condicaoSelecionada!);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              offset: Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Novo Local na Estrutura',
                          style: GoogleFonts.lato(
                            color: const Color(0xFF3E3E3D),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(
                          Icons.close,
                          color: AppColors.greyMedium,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  CustomTextField(
                    label: 'Nome do Local',
                    hint: 'Ex: Garagem Subsolo',
                    controller: _nomeController,
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),

                  CustomDropdownWithAdd<String>(
                    label: 'Tipologia do Local',
                    hint: 'Selecione',
                    value: _tipologiaSelecionada,
                    items: tipologiaOptions
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _tipologiaSelecionada = val),
                    onAddPressed: _adicionarTipologia,
                    isRequired: true,
                    tooltip: 'Adicione ou selecione o tipo do local.',
                  ),
                  const SizedBox(height: 16),

                  CustomDropdownWithAdd<String>(
                    label: 'Condição de Exposição',
                    hint: 'Selecione',
                    value: _condicaoSelecionada,
                    items: condicoesOptions
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _condicaoSelecionada = val),
                    onAddPressed: _adicionarCondicao,
                    isRequired: true,
                    tooltip: 'Adicione ou selecione a condição de exposição.',
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    label: 'Descrição',
                    hint: 'Adicione uma descrição (opcional)',
                    controller: _descricaoController,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 32),

                  Center(
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: AppColors.primary,
                          )
                        : CompactButton(
                            width: 120,
                            text: 'Salvar',
                            onPressed: () async {
                              final nome = _nomeController.text.trim();

                              if (nome.isEmpty) {
                                DiaviconAlerts.show(
                                  context,
                                  'Campo obrigatório',
                                  'Informe o nome do local.',
                                  isErro: true,
                                );
                                return;
                              }
                              if (_tipologiaSelecionada == null) {
                                DiaviconAlerts.show(
                                  context,
                                  'Campo obrigatório',
                                  'Selecione a tipologia.',
                                  isErro: true,
                                );
                                return;
                              }
                              if (_condicaoSelecionada == null) {
                                DiaviconAlerts.show(
                                  context,
                                  'Campo obrigatório',
                                  'Selecione a condição de exposição.',
                                  isErro: true,
                                );
                                return;
                              }
                              if (widget.estruturaId == null) {
                                DiaviconAlerts.show(
                                  context,
                                  'Erro crítico',
                                  'ID da estrutura não foi informado para este local.',
                                  isErro: true,
                                );
                                return;
                              }

                              setState(() => _isLoading = true);
                              try {
                                final repo = ref.read(localRepositoryProvider);

                                final localCriado = await repo.criarLocal(
                                  estruturaId: widget.estruturaId!,
                                  nome: nome,
                                  tipologia: _tipologiaSelecionada,
                                  condicao: _condicaoSelecionada,
                                  descricao: _descricaoController.text.trim(),
                                );

                                ref.invalidate(
                                  locaisPorEstruturaProvider(
                                    widget.estruturaId!,
                                  ),
                                );

                                if (!context.mounted) return;
                                Navigator.of(context).pop(localCriado);
                              } catch (e) {
                                if (!context.mounted) return;
                                DiaviconAlerts.show(
                                  context,
                                  'Erro',
                                  'Falha ao salvar local: $e',
                                  isErro: true,
                                );
                                setState(() => _isLoading = false);
                              }
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
