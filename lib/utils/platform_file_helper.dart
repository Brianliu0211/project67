import 'dart:typed_data';
import 'platform_file_helper_stub.dart'
    if (dart.library.html) 'platform_file_helper_web.dart' as impl;

/// 跨平台檔案下載與選取輔助工具
///
/// 封裝 Web 原生 Blob / Anchor 下載與 FileUploadInputElement，
/// 並在 Non-Web (Dart VM / Flutter Test / Mobile) 環境安全降級，避免編譯阻斷。
class PlatformFileHelper {
  static Future<void> downloadFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) {
    return impl.downloadFileImpl(bytes: bytes, fileName: fileName, mimeType: mimeType);
  }

  static Future<Map<String, dynamic>?> pickFileWeb({
    required String accept,
  }) {
    return impl.pickFileWebImpl(accept: accept);
  }
}
