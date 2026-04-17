import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../constants/app_colors.dart';

class FileUploadField extends StatelessWidget {
  final String label;
  final PlatformFile? selectedFile;
  final ValueChanged<PlatformFile?> onFilePicked;
  final List<String>? allowedExtensions;

  const FileUploadField({
    super.key,
    required this.label,
    required this.selectedFile,
    required this.onFilePicked,
    this.allowedExtensions,
  });

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
      );

      if (result != null) {
        onFilePicked(result.files.first);
      }
    } catch (e) {
      debugPrint('Erro ao selecionar arquivo: $e');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double size = bytes.toDouble();
    while (size > 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)}${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textDark, fontSize: 14),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickFile,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.inputBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.attach_file,
                  color: AppColors.hintText,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedFile != null ? selectedFile!.name : 'Selecione um arquivo',
                        style: TextStyle(
                          color: selectedFile != null ? AppColors.textDark : AppColors.hintText,
                          fontSize: 14,
                          fontWeight: selectedFile != null ? FontWeight.w500 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (selectedFile != null && selectedFile!.size > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatBytes(selectedFile!.size),
                          style: const TextStyle(
                            color: AppColors.hintText,
                            fontSize: 12,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
                if (selectedFile != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                    onPressed: () => onFilePicked(null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}