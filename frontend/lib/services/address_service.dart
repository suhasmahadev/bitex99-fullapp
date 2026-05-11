import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_constants.dart';
import '../models/models.dart';

class AddressService {
  final Dio _dio = apiClient.client;

  Future<List<AddressModel>> getAddresses() async {
    final response = await _dio.get(ApiConstants.addresses);
    final list = response.data['addresses'] ?? response.data['data'] ?? [];
    return (list as List)
        .map((item) => AddressModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<AddressModel> addAddress(Map<String, dynamic> data) async {
    final response = await _dio.post(ApiConstants.addresses, data: data);
    return AddressModel.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<void> setDefault(String id) async {
    await _dio.patch('${ApiConstants.addresses}/$id/set-default');
  }

  Future<void> delete(String id) async {
    await _dio.delete('${ApiConstants.addresses}/$id');
  }
}
