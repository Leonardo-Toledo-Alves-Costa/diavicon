import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_dropdown.dart';
import '../../../core/widgets/custom_dropdown_with_add.dart';
import '../models/estrutura_model.dart';
import '../widgets/proprietario_vinculo_section.dart';
import '../widgets/header_imagem_editavel.dart';
import '../widgets/mapa_preview_widget.dart';
import '../widgets/estrutura_home_header.dart';

class EstruturaInformacaoScreen extends ConsumerStatefulWidget {
  final EstruturaModel estrutura;
  final String projetoId;

  const EstruturaInformacaoScreen({
    super.key,
    required this.estrutura,
    required this.projetoId,
  });

  @override
  ConsumerState<EstruturaInformacaoScreen> createState() =>
      _EstruturaInformacaoScreenState();
}

class _EstruturaInformacaoScreenState
    extends ConsumerState<EstruturaInformacaoScreen> {
  final double _fieldSpacing = 16.0;

  // Controladores de Texto
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _idadeController = TextEditingController();
  final _latController = TextEditingController();
  final _longController = TextEditingController();
  final _cepController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _numeroController = TextEditingController();
  final _paisController = TextEditingController();
  final _ufController = TextEditingController();



  String? _clean(String? val) =>
      (val != null && val.trim().isNotEmpty) ? val : null;

  @override
  void initState() {
    super.initState();
    final e = widget.estrutura;
    _nomeController.text = e.nome ?? '';
    _descricaoController.text = e.descricao ?? '';
    _idadeController.text = e.anoConcepcao?.toString() ?? '';
    _latController.text = e.latitude?.toString() ?? '';
    _longController.text = e.longitude?.toString() ?? '';
    _cepController.text = e.cep ?? '';
    _enderecoController.text = e.endereco ?? '';
    _cidadeController.text = e.cidade ?? '';
    _numeroController.text = e.numero ?? '';
    _paisController.text = e.pais ?? '';
    _ufController.text = e.uf ?? '';

  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _idadeController.dispose();
    _latController.dispose();
    _longController.dispose();
    _cepController.dispose();
    _enderecoController.dispose();
    _cidadeController.dispose();
    _numeroController.dispose();
    _paisController.dispose();
    _ufController.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    double? latAtual = double.tryParse(_latController.text.trim());
    double? longAtual = double.tryParse(_longController.text.trim());

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(
        title: 'Estrutura\nInformações',
        showBackButton: true,
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EstruturaHomeHeader(
              imageUrl: widget.estrutura.imageUrl,
              status: widget.estrutura.status ?? 'Pendente',
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AbsorbPointer(
                    absorbing: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomTextField(
                          label: 'Nome',
                          hint: 'Sem nome',
                          controller: _nomeController,
                          enabled: false,
                        ),
                        SizedBox(height: _fieldSpacing),
                        const Text(
                          'Descrição',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.hintText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _descricaoController,
                          maxLines: 4,
                          enabled: false,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.inputBorder,
                              ),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.inputBorder,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // Seção do Proprietário
                  ProprietarioVinculoSection(projetoId: widget.projetoId),
                  const SizedBox(height: 24),

                  AbsorbPointer(
                    absorbing: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cadastro',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 👇 4. CAA E IDADE AGORA SÃO TEXTFIELDS NORMAIS DESATIVADOS
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: CustomTextField(
                                label: 'CAA',
                                hint: '-',
                                controller: TextEditingController(
                                  text: widget.estrutura.caa ?? 'Não Informado',
                                ),
                                enabled: false,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: CustomTextField(
                                label: 'Ano de construção',
                                hint: '-',
                                controller: _idadeController,
                                enabled: false,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: _fieldSpacing),

                        CustomTextField(
                          label: 'Conjunto Estrutural',
                          hint: '-',
                          controller: TextEditingController(
                            text:
                                widget.estrutura.conjuntoNome ??
                                'Não Informado',
                          ),
                          enabled: false,
                        ),
                        SizedBox(height: _fieldSpacing),
                        CustomTextField(
                          label: 'Utilização da estrutura',
                          hint: '-',
                          controller: TextEditingController(
                            text:
                                widget.estrutura.utilizacaoNome ??
                                'Não Informado',
                          ),
                          enabled: false,
                        ),
                        SizedBox(height: _fieldSpacing),
                        CustomTextField(
                          label: 'Tipo de estrutura',
                          hint: '-',
                          controller: TextEditingController(
                            text: widget.estrutura.tipoNome ?? 'Não Informado',
                          ),
                          enabled: false,
                        ),
                        SizedBox(height: _fieldSpacing),
                        CustomTextField(
                          label: 'Tipologia estrutural',
                          hint: '-',
                          controller: TextEditingController(
                            text:
                                widget.estrutura.tipologiaNome ??
                                'Não Informado',
                          ),
                          enabled: false,
                        ),
                        SizedBox(height: _fieldSpacing),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: CustomTextField(
                                label: 'Latitude',
                                hint: '-',
                                controller: _latController,
                                enabled: false,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: CustomTextField(
                                label: 'Longitude',
                                hint: '-',
                                controller: _longController,
                                enabled: false,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: _fieldSpacing),
                        CustomTextField(
                          label: 'CEP',
                          hint: '-',
                          controller: _cepController,
                          enabled: false,
                        ),
                        SizedBox(height: _fieldSpacing),
                        CustomTextField(
                          label: 'Endereço',
                          hint: '-',
                          controller: _enderecoController,
                          enabled: false,
                        ),
                        SizedBox(height: _fieldSpacing),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                label: 'Cidade',
                                hint: '-',
                                controller: _cidadeController,
                                enabled: false,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                label: 'Número',
                                hint: '-',
                                controller: _numeroController,
                                enabled: false,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: _fieldSpacing),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                label: 'País',
                                hint: '-',
                                controller: _paisController,
                                enabled: false,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                label: 'UF',
                                hint: '-',
                                controller: _ufController,
                                enabled: false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        MapaPreviewWidget(
                          latitude: latAtual,
                          longitude: longAtual,
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
