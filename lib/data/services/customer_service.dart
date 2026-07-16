import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/api_response.dart';
import '../models/customer.dart';

class CustomerService {
  CustomerService(this._client);

  final ApiClient _client;

  Future<List<Customer>> list({Map<String, dynamic>? query}) async {
    final result = await listPaginated(
      page: int.tryParse(query?['page']?.toString() ?? '') ?? 1,
      perPage: int.tryParse(query?['per_page']?.toString() ?? '') ?? 20,
      search: query?['search']?.toString(),
    );
    return result.items;
  }

  Future<({List<Customer> items, PaginationMeta? meta})> listPaginated({
    int page = 1,
    int perPage = 50,
    String? search,
  }) async {
    try {
      final res = await _client.get('/customers', queryParameters: {
        'page': page,
        'per_page': perPage,
        if (search != null && search.isNotEmpty) 'search': search,
      });
      return parseEnvelopeList(res, Customer.fromJson);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Customer> get(int id) async {
    try {
      final res = await _client.get('/customers/$id');
      return parseEnvelopeData(
        res,
        (data) => Customer.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<Customer>> search(String q) async {
    try {
      final res =
          await _client.get('/customers/search', queryParameters: {'q': q});
      return parseEnvelopeData(res, (data) => listFromData(data, Customer.fromJson));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Customer> create(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/customers', data: body);
      return parseEnvelopeData(
        res,
        (data) => Customer.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Customer> update(int id, Map<String, dynamic> body) async {
    try {
      final res = await _client.put('/customers/$id', data: body);
      return parseEnvelopeData(
        res,
        (data) => Customer.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Pet> createPet(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/pets', data: body);
      return parseEnvelopeData(
        res,
        (data) => Pet.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Pet> updatePet(int id, Map<String, dynamic> body) async {
    try {
      final res = await _client.put('/pets/$id', data: body);
      return parseEnvelopeData(
        res,
        (data) => Pet.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
