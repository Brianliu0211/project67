import 'dart:typed_data';

Future<void> downloadFileImpl({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  // Non-web fallback (e.g. Flutter test / VM)
}

Future<Map<String, dynamic>?> pickFileWebImpl({
  required String accept,
}) async {
  return null;
}
