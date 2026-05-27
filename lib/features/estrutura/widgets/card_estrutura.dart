import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class CardEstrutura extends StatelessWidget {
  final String title;
  final String type;
  final String details;
  final String group;
  final bool isSelected;
  final ValueChanged<bool?> onChanged;
  final String? imageUrl; 
  final VoidCallback? onTap; 

  const CardEstrutura({
    super.key,
    required this.title,
    required this.type,
    required this.details,
    required this.group,
    required this.isSelected,
    required this.onChanged,
    this.imageUrl, 
    this.onTap, 
  });

  Widget _buildImage() {
    const String defaultAsset = 'assets/images/sem_estrutura.png';

    if (imageUrl == null || imageUrl!.isEmpty) {
      return Image.asset(defaultAsset, width: 56, height: 56, fit: BoxFit.cover);
    }

    if (imageUrl!.startsWith('http')) {
      return Image.network(
        imageUrl!, width: 56, height: 56, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(defaultAsset, width: 56, height: 56, fit: BoxFit.cover),
      );
    }

    return Image.asset(
      imageUrl!, width: 56, height: 56, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.asset(defaultAsset, width: 56, height: 56, fit: BoxFit.cover),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 👇 3. ENVOLVEMOS O CONTAINER NUM GESTURE DETECTOR 👇
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 6, 4, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19), 
          border: Border.all(
            color: const Color(0xFFE0E0E0).withOpacity(0.6), 
            width: 1,
          ),
         boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.23), 
              blurRadius: 10,                      
              spreadRadius: -6,                     
              offset: const Offset(0, 14),           
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 7.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: _buildImage(), 
              ),
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2), 
                    Text(type, style: const TextStyle(fontSize: 11, color: AppColors.hintText), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(details, style: const TextStyle(fontSize: 11, color: AppColors.hintText), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(group, style: const TextStyle(fontSize: 11, color: AppColors.hintText), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              
              Checkbox(
                value: isSelected,
                onChanged: onChanged,
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                side: const BorderSide(color: AppColors.inputBorder),
              ),
            ],
          ),
        ),
      ),
    );
  }
}