import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/api_constants.dart';

class AgentService {
  final Dio _dio = apiClient.client;

  Future<Map<String, dynamic>> submitKyc(
    Map<String, dynamic> kycData
  ) async {
    final response = await _dio.post(
      ApiConstants.agentKyc,
      data: kycData,
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getAgentProfile(String agentId) async {
    final response = await _dio.get('/agents/$agentId');
    return response.data;
  }

  Future<String> getKycStatus(String agentId) async {
    final response = await _dio.get(
      '${ApiConstants.agentKycStatus}/$agentId/kyc-status',
    );
    return response.data['status'];
  }

  Future<void> toggleOnlineStatus(
    String agentId,
    bool isOnline, {
    double? latitude,
    double? longitude,
  }) async {
    await _dio.put(
      '/agents/$agentId/online-status',
      data: {
        'isOnline': isOnline,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
  }

  Future<Map<String, dynamic>> getSurgeStatus() async {
    final response = await Dio(BaseOptions(baseUrl: ApiConstants.apiBase)).get(
      '/surge/status',
      queryParameters: {'city': 'KR Nagar'},
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> getEarnings(
    String agentId, {
    String period = 'today',
  }) async {
    final response = await _dio.get(
      '${ApiConstants.agentKycStatus}/$agentId/earnings',
      queryParameters: {'period': period},
    );
    return response.data;
  }

  Future<List<Map<String, dynamic>>> getPendingAgents() async {
    final response = await _dio.get(
      '${ApiConstants.adminAgents}/pending',
    );
    final List list = response.data['agents'] ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> approveAgent(String agentId) async {
    await _dio.put(
      '${ApiConstants.adminAgents}/$agentId/approve',
    );
  }

  Future<void> rejectAgent(
    String agentId,
    String reason,
  ) async {
    await _dio.put(
      '${ApiConstants.adminAgents}/$agentId/reject',
      data: {'rejectionReason': reason},
    );
  }
}
