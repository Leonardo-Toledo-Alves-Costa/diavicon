import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class TeamEditItem extends StatefulWidget {
  final String name;
  final String role;
  final String subRole;
  final String? imageUrl; // 🔥 Novo parâmetro adicionado!
  final bool isSelected;
  final bool isUserGestor; 
  final bool isViewerGestor; 
  final ValueChanged<bool?> onChanged;
  final ValueChanged<bool> onToggleGestor;
  final VoidCallback onRemove;
  final bool isEditable;

  const TeamEditItem({
    super.key,
    required this.name,
    required this.role,
    required this.subRole,
    this.imageUrl, // 🔥 Recebe aqui
    required this.isSelected,
    required this.isUserGestor,
    required this.isViewerGestor,
    required this.onChanged,
    required this.onToggleGestor,
    required this.onRemove, 
    required this.isEditable,
  });

  @override
  State<TeamEditItem> createState() => _TeamEditItemState();
}

class _TeamEditItemState extends State<TeamEditItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // 🔥 Lógica simples: Tem link e começa com http? Então é da web. Se não, usa asset.
    final bool hasValidImage = widget.imageUrl != null && widget.imageUrl!.startsWith('http');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // CABEÇALHO DO CARD
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.isEditable ? () => setState(() => _expanded = !_expanded) : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.greyVeryLight,
                    // 🔥 Aplica a imagem dinâmica aqui
                    backgroundImage: hasValidImage 
                        ? StorageNetworkImage(widget.imageUrl!) 
                        : const AssetImage('assets/images/user.png') as ImageProvider,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          widget.role,
                          style: const TextStyle(fontSize: 12, color: AppColors.hintText),
                        ),
                        if (widget.subRole.isNotEmpty)
                          Text(
                            widget.subRole,
                            style: const TextStyle(fontSize: 12, color: AppColors.hintText),
                          ),
                      ],
                    ),
                  ),
                  if (!_expanded)
                    Checkbox(
                      value: widget.isSelected,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: widget.isEditable ? widget.onChanged : null,
                    ),
                ],
              ),
            ),
          ),
          
          // ÁREA EXPANDIDA (Visível apenas se o usuário clicou e TEM permissão)
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  
                  if (widget.isViewerGestor) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Gestor do projeto',
                          style: TextStyle(fontSize: 13, color: AppColors.hintText),
                        ),
                        Switch(
                          value: widget.isUserGestor,
                          activeThumbColor: AppColors.primary,
                          onChanged: widget.onToggleGestor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  const Text(
                    'Remover do Projeto',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ao remover integrante do projeto, ele perderá acesso aos dados desenvolvidos.',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: widget.onRemove,
                      child: const Text('Remover'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}