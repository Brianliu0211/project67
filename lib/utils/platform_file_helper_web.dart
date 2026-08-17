// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadFileImpl({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

Future<Map<String, dynamic>?> pickFileWebImpl({
  required String accept,
}) async {
  final uploadInput = html.FileUploadInputElement();
  uploadInput.accept = accept;
  uploadInput.click();

  await uploadInput.onChange.first;
  if (uploadInput.files != null && uploadInput.files!.isNotEmpty) {
    final file = uploadInput.files!.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);

    await reader.onLoadEnd.first;
    final result = reader.result;
    Uint8List bytes;
    if (result is ByteBuffer) {
      bytes = Uint8List.view(result);
    } else if (result is Uint8List) {
      bytes = result;
    } else {
      bytes = Uint8List(0);
    }

    return {
      'name': file.name,
      'bytes': bytes,
    };
  }
  return null;
}
