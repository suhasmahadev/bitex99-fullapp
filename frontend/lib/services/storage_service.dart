import 'dart:io';
import 'dart:typed_data';
import '../services/upload_service.dart';

/// StorageService — thin wrapper kept for backward compatibility.
/// Internally delegates to UploadService (multipart HTTP → backend).
/// Replaces: Firebase Storage uploads.
class StorageService {
  final _uploadService = UploadService();

  /// Uploads a file from [path] and returns the public URL.
  Future<String> uploadImage(String path, File file) async {
    try {
      final bytes = await file.readAsBytes();
      final name = path.split('/').last;
      return await _uploadService.uploadImage(
        Uint8List.fromList(bytes),
        name,
      );
    } catch (e) {
      return '';
    }
  }
}
