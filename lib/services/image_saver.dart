import 'dart:typed_data';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';

/// Writes an encoded image somewhere the user chooses.
abstract class ImageSaver {
  /// Returns the saved location, or `null` if the user cancelled.
  Future<String?> save(Uint8List bytes, String fileName, {String mimeType = 'image/png'});
}

/// Opens the system "save file" dialog (like ColorTrix): the document picker
/// on iOS, `ACTION_CREATE_DOCUMENT` on Android. Needs no permissions.
class FileDialogImageSaver implements ImageSaver {
  const FileDialogImageSaver();

  @override
  Future<String?> save(Uint8List bytes, String fileName, {String mimeType = 'image/png'}) {
    return FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(data: bytes, fileName: fileName, mimeTypesFilter: [mimeType]),
    );
  }
}

String exportFileName(DateTime now, {String extension = 'png'}) =>
    'bitmapper_${now.millisecondsSinceEpoch}.$extension';
