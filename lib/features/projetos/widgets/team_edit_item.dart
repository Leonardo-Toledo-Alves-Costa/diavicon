import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class TeamEditItem extends StatelessWidget {
  final String name;
  final String role;
  final String subRole;
  final bool isSelected;
  final ValueChanged<bool?> onChanged;

  const TeamEditItem({
    super.key,
    required this.name,
    required this.role,
    required this.subRole,
    required this.isSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
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
      child: Row(
        children: [
          // Foto do usuário [image_7b8e71.png]
          const CircleAvatar(
            radius: 28,
            backgroundImage: AssetImage('assets/images/user.png'),
          ),
          const SizedBox(width: 16),
          // Textos (Nome e Cargo)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(fontSize: 12, color: AppColors.hintText),
                ),
                Text(
                  subRole,
                  style: const TextStyle(fontSize: 12, color: AppColors.hintText),
                ),
              ],
            ),
          ),
          // Checkbox Laranja [image_7b8e71.png]
          Checkbox(
            value: isSelected,
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}