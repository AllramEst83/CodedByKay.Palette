import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'app_messenger.dart';

class PickedImage {
  const PickedImage(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}

/// Wraps `file_picker` for image selection on Android and web.
class PickerService {
  const PickerService._();

  static Future<List<PickedImage>> pickImages({bool multiple = false}) async {
    try {
      final List<PlatformFile> files;
      if (multiple) {
        files = await FilePicker.pickFiles(type: FileType.image);
      } else {
        final PlatformFile? file = await FilePicker.pickFile(type: FileType.image);
        files = file == null ? <PlatformFile>[] : <PlatformFile>[file];
      }
      final List<PickedImage> out = <PickedImage>[];
      for (final PlatformFile file in files) {
        out.add(PickedImage(file.name, await file.readAsBytes()));
      }
      return out;
    } catch (err) {
      AppMessenger.show('Could not open the file picker: $err', isError: true);
      return <PickedImage>[];
    }
  }
}
