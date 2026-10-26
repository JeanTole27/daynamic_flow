import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../device_services.dart';

class ImagePickerPhotoService implements PhotoCaptureService {
  ImagePickerPhotoService();

  final _picker = ImagePicker();

  @override
  Future<Uint8List?> takePhoto() async {
    // Solo cámara (no galería): la evidencia debe tomarse en el momento.
    // Se reduce tamaño y calidad para no subir fotos de 10 MB por datos.
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 75,
      requestFullMetadata: false,
    );
    return file?.readAsBytes();
  }
}
