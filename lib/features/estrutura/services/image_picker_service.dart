import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../core/constants/app_colors.dart';

class ImagePickerService {
  /// Abre a galeria e permite recortar a imagem selecionada.
  /// 
  /// [title] O título que aparece na barra superior da tela de recorte.
  /// [aspectRatio] A proporção desejada. Padrão é 16:9.
  Future<File?> pickAndCropImage({
    String title = 'Enquadrar Capa',
    CropAspectRatio aspectRatio = const CropAspectRatio(ratioX: 16, ratioY: 9),
  }) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(type: FileType.image);
      
      if (result != null && result.files.single.path != null) {
        final pickedFilePath = result.files.single.path!;

        CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFilePath,
          aspectRatio: aspectRatio, 
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: title,
              toolbarColor: AppColors.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.ratio16x9,
              lockAspectRatio: true,
              hideBottomControls: false,
            ),
            IOSUiSettings(
              title: title,
              aspectRatioLockEnabled: true,
              resetButtonHidden: true,
            ),
          ],
        );

        if (croppedFile != null) {
          return File(croppedFile.path);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Erro ao selecionar imagem: $e');
      return null;
    }
  }
}