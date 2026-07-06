import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/emr.dart';

class DoctorService {
  DoctorService(this._client);

  final ApiClient _client;

  Future<List<Doctor>> list({Map<String, dynamic>? query}) async {
    try {
      final res = await _client.get('/doctors', queryParameters: query);
      return parseEnvelopeData(res, (data) => listFromData(data, Doctor.fromJson));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Doctor> create(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/doctors', data: body);
      return parseEnvelopeData(
        res,
        (data) => Doctor.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Doctor> updateProfile(int id, Map<String, dynamic> body) async {
    try {
      final res = await _client.put('/doctors/$id/profile', data: body);
      return parseEnvelopeData(
        res,
        (data) => Doctor.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Doctor> toggleAvailability(int id) async {
    try {
      final res = await _client.post('/doctors/$id/toggle-availability');
      return parseEnvelopeData(
        res,
        (data) => Doctor.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _client.delete('/doctors/$id');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
