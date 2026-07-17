import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/api_response.dart';
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

  Future<Branch> create(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/branches', data: body);
      return parseEnvelopeData(
        res,
        (data) => Branch.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Branch> update(int id, Map<String, dynamic> body) async {
    try {
      final res = await _client.put('/branches/$id', data: body);
      return parseEnvelopeData(
        res,
        (data) => Branch.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}

class UsersService {
  UsersService(this._client);

  final ApiClient _client;

  Future<List<User>> list({Map<String, dynamic>? query}) async {
    final result = await listPaginated(
      page: int.tryParse(query?['page']?.toString() ?? '') ?? 1,
      perPage: int.tryParse(query?['per_page']?.toString() ?? '') ?? 20,
    );
    return result.items;
  }

  Future<({List<User> items, PaginationMeta? meta})> listPaginated({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final res = await _client.get('/users', queryParameters: {
        'page': page,
        'per_page': perPage,
      });
      return parseEnvelopeList(res, User.fromJson);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<User> create(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/users', data: body);
      return parseEnvelopeData(
        res,
        (data) => User.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<User> update(int id, Map<String, dynamic> body) async {
    try {
      final res = await _client.put('/users/$id', data: body);
      return parseEnvelopeData(
        res,
        (data) => User.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<({String value, String label})>> listRoles() async {
    try {
      final res = await _client.get('/users/roles');
      final rows = parseEnvelopeData(res, (data) => listFromData(data, (j) => j));
      return rows
          .map(
            (j) => (
              value: j['value']?.toString() ?? '',
              label: j['label']?.toString() ?? j['value']?.toString() ?? '',
            ),
          )
          .where((r) => r.value.isNotEmpty)
          .toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
