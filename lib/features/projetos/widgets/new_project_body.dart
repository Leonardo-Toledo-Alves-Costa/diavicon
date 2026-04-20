import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_dropdown_with_add.dart';

class NewProjectBody extends StatefulWidget {
  const NewProjectBody({super.key});

  @override
  State<NewProjectBody> createState() => _NewProjectBodyState();
}

class _NewProjectBodyState extends State<NewProjectBody> {
  final _nomeController = TextEditingController();
  String? _clienteSelecionado;

  @override
  Widget build(BuildContext context) {
    // Captura o padding inferior do sistema (barra de navegação)
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. SELETOR DE IMAGEM (Usando o asset empresa.png que você adicionou)
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 55,
                backgroundColor: const Color(0xFFE6E7E8), // Cinza oficial
                backgroundImage: const AssetImage('assets/images/empresa.png'),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.edit_note, color: AppColors.textDark, size: 24),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // 2. NOME DO PROJETO (Usando seu CustomTextField que já tem label interno)
        CustomTextField(
          label: 'Nome do projeto*',
          hint: 'Projeto ABC',
          controller: _nomeController,
          validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
        ),
        const SizedBox(height: 20),

        // 3. CLIENTE (Usando seu CustomDropdownWithAdd)
        CustomDropdownWithAdd<String>(
          label: 'Cliente*',
          hint: 'Selecione',
          value: _clienteSelecionado,
          items: const [
            DropdownMenuItem(value: '1', child: Text('Empresa Engenharia')),
          ],
          onChanged: (val) => setState(() => _clienteSelecionado = val),
          onAddPressed: () {
            // TODO: Lógica para novo cliente
          },
        ),
        
        const SizedBox(height: 40),

        // 4. BOTÃO CRIAR (Usando seu CustomButton padronizado)
        CustomButton(
          text: 'Criar',
          showArrow: false, // Conforme a print
          onPressed: () {
            // Lógica de salvamento
            Navigator.pop(context);
          },
        ),

        // 5. ESPAÇAMENTO DE SEGURANÇA (Para não ficar sob os botões do celular)
        // Se o bottomPadding for 0 (celulares com botões físicos), usamos 16 por padrão.
        SizedBox(height: bottomPadding > 0 ? bottomPadding : 16),
      ],
    );
  }
}