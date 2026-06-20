import 'package:diavicon/core/utils/formatters/cnpj_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/diavicon_alerts.dart';
import '../providers/empresas_projeto_provider.dart';

class ModalIncluirEmpresa extends ConsumerStatefulWidget {
  final String projetoId;

  const ModalIncluirEmpresa({super.key, required this.projetoId});

  @override
  ConsumerState<ModalIncluirEmpresa> createState() =>
      _ModalIncluirEmpresaState();
}

class _ModalIncluirEmpresaState extends ConsumerState<ModalIncluirEmpresa> {
  final _formKey = GlobalKey<FormState>();
  final _cnpjController = TextEditingController();

  bool _isLoading = false;
  Map<String, dynamic>? _empresaEncontrada;

  @override
  void dispose() {
    _cnpjController.dispose();
    super.dispose();
  }

  Future<void> _buscarEmpresa() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _empresaEncontrada = null;
    });

    try {
      final empresa = await ref
          .read(empresasProjetoControllerProvider)
          .buscarEmpresaParaPreview(_cnpjController.text);
      setState(() => _empresaEncontrada = empresa);
    } catch (e) {
      if (!mounted) return;
      DiaviconAlerts.show(
        context,
        'Não Encontrada',
        e.toString().replaceAll('Exception: ', ''),
        isAviso: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _enviarConvite() async {
    if (_empresaEncontrada == null) return;

    setState(() => _isLoading = true);

    try {
      await ref
          .read(empresasProjetoControllerProvider)
          .enviarConviteEmpresa(
            projetoId: widget.projetoId,
            empresaConvidadaId: _empresaEncontrada!['id'],
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      DiaviconAlerts.show(
        context,
        'Sucesso!',
        'Empresa convidada para o projeto.',
      );
    } catch (e) {
      if (!mounted) return;
      DiaviconAlerts.show(
        context,
        'Erro ao Vincular',
        e.toString().replaceAll('Exception: ', ''),
        isErro: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calcula o padding inferior para não ficar atrás do teclado
    final bottomPadding =
        MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom +
        24;

    // 🔥 A CORREÇÃO VISUAL COMEÇA AQUI:
    // Envolvemos tudo em um Container com cor branca e bordas superiores.
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white, // 🔥 FUNDO BRANCO TOTAL
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        // Mantemos os paddings internos, ajustando apenas o topo para o Container
        padding: EdgeInsets.only(
          bottom: bottomPadding,
          left: 24,
          right: 24,
          top: 32,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra indicadora de "puxar" do modal (Opcional, mas fica bonito)
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.greyLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const Text(
                'Vincular Nova Empresa',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _empresaEncontrada == null
                    ? 'Insira o CNPJ da empresa que deseja incluir como colaboradora.'
                    : 'Empresa encontrada! Confirme para enviar o convite.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.hintText, fontSize: 14),
              ),
              const SizedBox(height: 24),

              CustomTextField(
                label: 'CNPJ da Empresa',
                hint: '00.000.000/0001-00',
                controller: _cnpjController,
                keyboardType: TextInputType.number,
                enabled: _empresaEncontrada == null && !_isLoading,
                inputFormatters: [CnpjFormatter.mask],
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Obrigatório';
                  if (CnpjFormatter.unformat(val).length < 14)
                    return 'CNPJ Inválido';
                  return null;
                },
              ),

              // RESULTADO DA BUSCA (Visual Prototipagem Clean)
              if (_empresaEncontrada != null) ...[
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar com fundo branco e sombra suave (Fica igual a prot)
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors
                            .transparent, // Transparente para usar o branco do container
                        backgroundImage:
                            _empresaEncontrada!['foto_url']
                                    ?.toString()
                                    .startsWith('http') ==
                                true
                            ? NetworkImage(_empresaEncontrada!['foto_url'])
                            : null,
                        child:
                            _empresaEncontrada!['foto_url']
                                    ?.toString()
                                    .startsWith('http') !=
                                true
                            ? const Icon(
                                Icons.business,
                                color: AppColors.greyMedium,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _empresaEncontrada!['nome'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600, // Peso médio/bold
                              fontSize: 16,
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          if (_empresaEncontrada!['enderecos'] != null)
                            Text(
                              '${_empresaEncontrada!['enderecos']['cidade']} - ${_empresaEncontrada!['enderecos']['estado']}',
                              style: const TextStyle(
                                color: AppColors.greyMedium,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Botão de limpar a busca (Discreto)
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.greyMedium,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _empresaEncontrada = null),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),

              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : CustomButton(
                      text: _empresaEncontrada == null
                          ? 'Buscar Empresa'
                          : 'Confirmar Convite',
                      onPressed: _empresaEncontrada == null
                          ? _buscarEmpresa
                          : _enviarConvite,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
