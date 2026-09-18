import 'dart:typed_data';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';

/// Writes an encoded image somewhere the user chooses.
abstract class ImageSaver {
  /// Returns the saved location, or `null` if the user cancelled.
  Future<String?> save(Uint8List png, String fileName);
}

/// Opens the system "save file" dialog (like ColorTrix): the document picker
/// on iOS, `ACTION_CREATE_DOCUMENT` on Android. Needs no permissions.
class FileDialogImageSaver implements ImageSaver {
  const FileDialogImageSaver();

  @override
  Future<String?> save(Uint8List png, String fileName) {
    return FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(
        data: png,
        fileName: fileName,
        mimeTypesFilter: const ['image/png'],
      ),
    );
  }
}

String exportFileName(DateTime now) => 'bitmapper_${now.millisecondsSinceEpoch}.png';
