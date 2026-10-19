import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'app_messenger.dart';

/// Saves exported PNG bytes: a download on web, a save dialog on Android.
class ExportService {
  const ExportService._();

  static Future<void> savePng(Uint8List bytes, String fileName) async {
    try {
      final Uri? saved = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'image/png',
        dialogTitle: 'Save image',
        type: FileType.image,
      );
      if (saved == null) return;
      AppMessenger.show('Saved $fileName');
    } catch (err) {
      AppMessenger.show('Error exporting image: $err', isError: true);
    }
  }
}
