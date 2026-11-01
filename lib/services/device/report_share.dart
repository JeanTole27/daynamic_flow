import 'dart:io';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Guarda el archivo en la carpeta temporal y abre el menú de compartir del
/// teléfono (WhatsApp, correo, Drive, Archivos…).
Future<void> shareReportFile({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
  required String subject,
  Rect? origin,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: mimeType)],
      subject: subject,
      // En iPad el menú necesita saber desde dónde se abre.
      sharePositionOrigin: origin,
    ),
  );
}
