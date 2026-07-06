import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/shop.dart';
import '../models/user.dart';

class ShopService {
  ShopService(this._client);

  final ApiClient _client;

  Future<Shop> get() async {
    try {
      final res = await _client.get('/shop');
      return parseEnvelopeData(
        res,
        (data) => Shop.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Shop> update(Map<String, dynamic> body) async {
    try {
      final res = await _client.put('/shop', data: body);
      return parseEnvelopeData(
        res,
        (data) => Shop.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}

class BranchService {
  BranchService(this._client);

  final ApiClient _client;

  Future<List<Branch>> list() async {
    try {
      final res = await _client.get('/branches');
      return parseEnvelopeData(res, (data) => listFromData(data, Branch.fromJson));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}

class UsersService {
  UsersService(this._client);

  final ApiClient _client;

  Future<List<User>> list({Map<String, dynamic>? query}) async {
    try {
      final res = await _client.get('/users', queryParameters: query);
      return parseEnvelopeData(res, (data) => listFromData(data, User.fromJson));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
