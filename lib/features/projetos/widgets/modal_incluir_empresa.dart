import 'package:diavicon/core/utils/formatters/cnpj_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/diavicon_alerts.dart';
import '../providers/empresas_projeto_provider.dart';


class ModalIncluirEmpresa extends ConsumerStatefulWidget {
  final String projetoId;

  const ModalIncluirEmpresa({super.key, required this.projetoId});

  @override
  ConsumerState<ModalIncluirEmpresa> createState() => _ModalIncluirEmpresaState();
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
      final empresa = await ref.read(empresasProjetoControllerProvider).buscarEmpresaParaPreview(_cnpjController.text);
      setState(() => _empresaEncontrada = empresa);
    } catch (e) {
      if (!mounted) return;
      DiaviconAlerts.show(context, 'Não Encontrada', e.toString().replaceAll('Exception: ', ''), isAviso: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _enviarConvite() async {
    if (_empresaEncontrada == null) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(empresasProjetoControllerProvider).enviarConviteEmpresa(
            projetoId: widget.projetoId,
            empresaConvidadaId: _empresaEncontrada!['id'],
          );

      if (!mounted) return;
      Navigator.of(context).pop(); 
      DiaviconAlerts.show(context, 'Sucesso!', 'Empresa convidada para o projeto.');

    } catch (e) {
      if (!mounted) return;
      DiaviconAlerts.show(context, 'Erro ao Vincular', e.toString().replaceAll('Exception: ', ''), isErro: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding, left: 24, right: 24, top: 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Vincular Nova Empresa',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
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
              // 🔥 AGORA SIM! MÁSCARA ATIVADA:
              inputFormatters: [CnpjFormatter.mask], 
              validator: (val) {
                if (val == null || val.isEmpty) return 'Obrigatório';
                if (CnpjFormatter.unformat(val).length < 14) return 'CNPJ Inválido'; 
                return null;
              },
            ),

            if (_empresaEncontrada != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.greyVeryLight,
                      backgroundImage: _empresaEncontrada!['foto_url'].toString().startsWith('http')
                          ? NetworkImage(_empresaEncontrada!['foto_url'])
                          : null,
                      child: !_empresaEncontrada!['foto_url'].toString().startsWith('http')
                          ? const Icon(Icons.business, color: AppColors.greyMedium)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _empresaEncontrada!['nome'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_empresaEncontrada!['enderecos'] != null)
                            Text(
                              '${_empresaEncontrada!['enderecos']['cidade']} - ${_empresaEncontrada!['enderecos']['estado']}',
                              style: const TextStyle(color: AppColors.greyMediumDark, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.error),
                      onPressed: () => setState(() => _empresaEncontrada = null),
                    )
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : CustomButton(
                    text: _empresaEncontrada == null ? 'Buscar Empresa' : 'Confirmar Convite',
                    onPressed: _empresaEncontrada == null ? _buscarEmpresa : _enviarConvite,
                    // Se o seu CustomButton tiver parâmetro de cor, use AppColors.primary nele também
                  ),
          ],
        ),
      ),
    );
  }
}