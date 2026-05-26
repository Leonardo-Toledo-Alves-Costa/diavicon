import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class TeamEditItem extends StatefulWidget {
  final String name;
  final String role;
  final String subRole;
  final bool isSelected;
  final bool isUserGestor; // Se o cara desse card é o gestor
  final bool isViewerGestor; // Se quem está com o celular na mão tem permissão de gestor
  final ValueChanged<bool?> onChanged;
  final ValueChanged<bool> onToggleGestor;
  final VoidCallback onRemove;

  const TeamEditItem({
    super.key,
    required this.name,
    required this.role,
    required this.subRole,
    required this.isSelected,
    required this.isUserGestor,
    required this.isViewerGestor,
    required this.onChanged,
    required this.onToggleGestor,
    required this.onRemove,
  });

  @override
  State<TeamEditItem> createState() => _TeamEditItemState();
}

class _TeamEditItemState extends State<TeamEditItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // CABEÇALHO DO CARD (Sempre visível)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundImage: AssetImage('assets/images/user.png'),
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
                  // O checkbox ou "D" só aparece se não estiver expandido (seguindo o protótipo)
                  if (!_expanded)
                    Checkbox(
                      value: widget.isSelected,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: widget.onChanged,
                    ),
                ],
              ),
            ),
          ),
          
          // ÁREA EXPANDIDA (Visível ao clicar no card)
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  
                  // 🚨 SÓ MOSTRA O TOGGLE DE GESTOR SE O USUÁRIO LOGADO TIVER PERMISSÃO
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
                          activeColor: AppColors.primary,
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
                    'Ao remover integrante do projeto, ele perderá acesso aos dados desenvolvidos, mas ainda será vistos os dados criados e modificados por ele.',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  
                  // Botão de Remover vermelho
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