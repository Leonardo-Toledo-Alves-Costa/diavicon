import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io'; // 🚨 IMPORTANTE: Adicionado para ler a foto local
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/modal_selecao_base.dart';
import '../providers/projeto_form_provider.dart';
import 'novo_cliente_modal.dart';
import 'busca_cliente_modal.dart';

class SelecaoClienteModal extends ConsumerWidget {
  const SelecaoClienteModal({super.key});

  ImageProvider _obterImagemCliente(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const AssetImage('assets/images/empresa.png');
    }
    if (imageUrl.startsWith('http')) {
      return StorageNetworkImage(imageUrl);
    }
    return FileImage(File(imageUrl));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Monitora o estado do formulário para saber se um cliente foi selecionado
    final projetoForm = ref.watch(projetoFormProvider);

    return ModalSelecaoBase(
      titulo: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Seu cliente já é cadastrado',
                style: AppTextStyles.tituloPrincipal,
              ),
            ),
            RichText(
              text: TextSpan(
                style: AppTextStyles.tituloPrincipal,
                children: [
                  TextSpan(
                    text: 'na DIAVICON',
                    style: TextStyle(color: AppColors.primary),
                  ),
                  const TextSpan(text: '?'),
                ],
              ),
            ),
          ],
        ),
      ),
      textoBotao: 'Convidar',
      aoPressionarBotao: () => Navigator.pop(context),
      filhos: [
        //  CADASTRAR NOVO
        _buildCardLaranja(
          onTap: () {
            Navigator.pop(context);
            showDialog(
              context: context,
              builder: (context) => const NovoClienteModal(),
            );
          },
          filho: Row(
            children: [
              Image.asset(
                'assets/images/user-star.png',
                width: 44,
                height: 44,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Quero cadastrar meu cliente',
                  style: AppTextStyles.corpoDestaqueBranco.copyWith(
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // BUSCA (Lógica de abertura do modal de busca completa)
        _buildCardLaranja(
          onTap: null,
          padding: const EdgeInsets.all(16),
          filho: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Meu Cliente já é Cadastrado',
                    style: AppTextStyles.corpoDestaqueBranco,
                  ),
                ),
              ),
              Text(
                'Entre com o código do seu cliente',
                style: AppTextStyles.corpoSubtextoBranco,
              ),
              const SizedBox(height: 12),

              TextField(
                readOnly: true,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const BuscaClienteModal(),
                  );
                },
                style: AppTextStyles.corpoTextoEscuro,
                decoration: InputDecoration(
                  hintText: projetoForm.clienteNome ?? 'AbCD123',
                  hintStyle: TextStyle(
                    color: projetoForm.clienteNome != null
                        ? AppColors.textPrimary
                        : AppColors.greyLight,
                  ),
                  fillColor: Colors.white,
                  filled: true,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: const Icon(
                    Icons.search,
                    color: AppColors.primary,
                  ),
                ),
              ),

              // Card de resultado aparece apenas se houver um cliente selecionado
              if (projetoForm.clienteNome != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        backgroundImage: _obterImagemCliente(
                          projetoForm.clienteFotoUrl,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              projetoForm.clienteNome!,
                              style: AppTextStyles.corpoSubtextoBranco.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              projetoForm.localCliente ?? 'Sem localização',
                              style: AppTextStyles.corpoSubtextoBranco.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardLaranja({
    required Widget filho,
    VoidCallback? onTap,
    EdgeInsets? padding,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: padding ?? const EdgeInsets.all(20),
            child: filho,
          ),
        ),
      ),
    );
  }
}
