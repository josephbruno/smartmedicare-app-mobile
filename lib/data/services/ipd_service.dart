import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/api_response.dart';
import '../models/ipd.dart';

class IpdService {
  IpdService(this._client);

  final ApiClient _client;

  Future<List<IpdWard>> wards() async {
    try {
      final response = await _client.get('/ipd/wards');
      return parseEnvelopeData(
        response,
        (data) => listFromData(data, IpdWard.fromJson),
      );
    } on DioException catch (error) {
      ApiClient.throwFromDio(error);
    }
  }

  Future<({List<IpdAdmission> items, PaginationMeta? meta})> admissions({
    int page = 1,
    int perPage = 50,
    String? status,
  }) async {
    try {
      final response = await _client.get('/ipd/admissions', queryParameters: {
        'page': page,
        'per_page': perPage,
        if (status != null) 'status': status,
      });
      return parseEnvelopeList(response, IpdAdmission.fromJson);
    } on DioException catch (error) {
      ApiClient.throwFromDio(error);
    }
  }

  Future<IpdAdmission> admit(Map<String, dynamic> payload) async {
    try {
      final response = await _client.post('/ipd/admissions', data: payload);
      return parseEnvelopeData(
        response,
        (data) => IpdAdmission.fromJson(
          Map<String, dynamic>.from(data as Map),
        ),
      );
    } on DioException catch (error) {
      ApiClient.throwFromDio(error);
    }
  }

  Future<IpdAdmission> discharge(
    int admissionId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _client.post(
        '/ipd/admissions/$admissionId/discharge',
        data: payload,
      );
      return parseEnvelopeData(
        response,
        (data) => IpdAdmission.fromJson(
          Map<String, dynamic>.from(data as Map),
        ),
      );
    } on DioException catch (error) {
      ApiClient.throwFromDio(error);
    }
  }
}
