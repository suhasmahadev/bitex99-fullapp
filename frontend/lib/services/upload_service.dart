import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/api_constants.dart';

/// Replaces Firebase Storage uploads with multipart HTTP to backend.
class UploadService {
  final Dio _dio = apiClient.client;

  // Replaces: FirebaseStorage.instance.ref().putData()
  Future<String> uploadImage(
    Uint8List imageBytes,
    String fileName, {
    String type = 'restaurant',
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        imageBytes,
        filename: fileName,
      ),
      'type': type,
    });

    final response = await _dio.post(
      ApiConstants.upload,
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    return response.data['fullUrl'] ?? '';
  }
}
